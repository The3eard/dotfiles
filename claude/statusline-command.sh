#!/bin/bash

# ANSI palette slots, not hex — so the status line inherits whatever theme the
# terminal has active and stays readable in both light and dark mode. Hardcoded
# truecolor (the previous Xcode Dark HC hex) ignores the terminal theme entirely:
# C_TEXT was #FFFFFF, i.e. invisible on any light background.
# Slot 7 (37) is deliberately unused — it is the light grey, unreadable on light
# backgrounds. Dim text uses 90 (slot 8), which exists for exactly that purpose.
C_MAUVE=$'\033[35m'      # magenta — model (fable), output style
C_BLUE=$'\033[34m'       # blue    — dir, model (haiku)
C_SAPPHIRE=$'\033[34m'   # blue    — git branch clean
C_SKY=$'\033[36m'        # cyan    — git icon, session name
C_TEAL=$'\033[36m'       # cyan    — session time
C_GREEN=$'\033[32m'      # green   — git ahead/staged, context ok
C_YELLOW=$'\033[33m'     # yellow  — context mid, vim INSERT, model (sonnet)
C_PEACH=$'\033[91m'      # br red  — effort high (orange-ish slot)
C_RED=$'\033[31m'        # red     — git dirty/behind, model (opus)
# bold red, not bright magenta: slot 13 measures 1.94:1 on Latte, worse than the
# hex it replaced. Bold distinguishes "critical" from plain dirty-red by weight.
C_MAROON=$'\033[1;31m'   # bold red— context critical, effort max
C_LAVENDER=$'\033[35m'   # magenta — worktree
# Faint (SGR 2) on the default foreground, not slot 8: no single slot is mid-tone
# in both modes — slot 8 measures 1.77:1 on Apple System Colors dark and slot 7
# measures 2.87:1 on Apple System Colors Light. Faint dims whatever the theme's
# foreground is, so it adapts instead of picking a fixed colour.
C_OVERLAY=$'\033[2;39m'  # faint fg— separators only (decorative glyphs, dim by intent)
C_SUBTEXT=$'\033[39m'    # default fg — secondary label text, must stay readable
C_TEXT=$'\033[39m'       # default foreground — main text, always theme-correct
C_RESET=$'\033[0m'
C_BOLD=$'\033[1m'

SEP=$(printf "${C_OVERLAY}│${C_RESET}")

# Nerdfonts icons — defined via printf to survive file encoding
ICON_FOLDER=$(printf '\xef\x81\xbb')      # U+F07B nf-fa-folder
ICON_WORKTREE=$(printf '\xef\x86\xbb')    # U+F1BB nf-fa-tree
ICON_GIT=$(printf '\xee\x82\xa0')          # U+E0A0 nf-dev-git_branch
ICON_CIRCLE=$(printf '\xef\x84\x91')       # U+F111 nf-fa-circle

# Read JSON input
input=$(cat)

# Current working directory
cwd=$(echo "$input" | jq -r '.workspace.current_dir')
dir_name=$(basename "$cwd")

# ---------------------------------------------------------------------------
# Model — prefer display_name from JSON (e.g. "Claude Sonnet 4.5" → "Sonnet 4.5")
#         fallback: parse model ID by family when display_name is absent
# ---------------------------------------------------------------------------
model_id=$(echo "$input" | jq -r '.model.id')
model_display_name=$(echo "$input" | jq -r '.model.display_name // empty')
if [ -n "$model_display_name" ] && [ "$model_display_name" != "null" ]; then
  # Strip leading "Claude " prefix to avoid duplicating with the icon
  model_short="${model_display_name#Claude }"
else
  # Fallback: derive from model ID
  case "$model_id" in
    *"opus"*)   model_family="Opus"    ;;
    *"sonnet"*) model_family="Sonnet"  ;;
    *"haiku"*)  model_family="Haiku"   ;;
    *)          model_family="Claude"  ;;
  esac
  model_version=$(echo "$model_id" | grep -oE '([0-9]+-[0-9]+|[0-9]+)$' | tr '-' '.')
  if [ -n "$model_version" ]; then
    model_short="${model_family} ${model_version}"
  else
    model_short="$model_family"
  fi
fi
# Color by capability tier: haiku=blue, sonnet=yellow, opus=red, fable=purple (ultra)
model_check=$(echo "$model_id $model_display_name" | tr '[:upper:]' '[:lower:]')
case "$model_check" in
  *fable*)  model_color="${C_MAUVE}"  ;;
  *opus*)   model_color="${C_RED}"    ;;
  *sonnet*) model_color="${C_YELLOW}" ;;
  *haiku*)  model_color="${C_BLUE}"   ;;
  *)        model_color="${C_SUBTEXT}" ;;
esac
model_display=$(printf "󰧑 ${model_color}%s${C_RESET}" "$model_short")

# ---------------------------------------------------------------------------
# Effort level — from JSON input (live), fallback to ~/.claude/settings.json
# ---------------------------------------------------------------------------
effort_info=""
effort_level=$(echo "$input" | jq -r '.effort.level // empty')
if [ -z "$effort_level" ]; then
  effort_level=$(jq -r '.effortLevel // empty' "$HOME/.claude/settings.json" 2>/dev/null)
fi
if [ -n "$effort_level" ]; then
  effort_icon=""
  # Cold-to-hot scale: low=blue, medium=yellow, high=peach, xhigh=red, max=pink
  # ultracode renders purple, matching the Claude Code UI
  case "$effort_level" in
    ultracode) effort_color="${C_MAUVE}" ;;
    max)       effort_color="${C_MAROON}" ;;
    xhigh)     effort_color="${C_RED}"    ;;
    high)      effort_color="${C_PEACH}"  ;;
    medium)    effort_color="${C_YELLOW}" ;;
    low)       effort_color="${C_BLUE}"   ;;
    *)         effort_color="${C_SUBTEXT}" ;;
  esac
  effort_info=$(printf " %s${effort_color}%s %s${C_RESET}" "$SEP" "$effort_icon" "$effort_level")
fi

# ---------------------------------------------------------------------------
# Context window — only shown from 80% usage (yellow 80-89, red >= 90)
# ---------------------------------------------------------------------------
context_info=""
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // 0')
if [ "$used_pct" != "null" ] && awk "BEGIN {exit !($used_pct >= 80)}"; then
  if awk "BEGIN {exit !($used_pct >= 90)}"; then
    context_icon="${C_RED}${ICON_CIRCLE}${C_RESET}"
  else
    context_icon="${C_YELLOW}${ICON_CIRCLE}${C_RESET}"
  fi
  pct_display=$(printf "%.0f%%" "$used_pct")
  context_info=$(printf " %s %s ${C_TEXT}%s${C_RESET}" "$SEP" "$context_icon" "$pct_display")
fi

# ---------------------------------------------------------------------------
# Git — branch, dirty state, staged/unstaged counts, stash, ahead/behind
# ---------------------------------------------------------------------------
git_info=""
git_details=""
if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
  GIT="git -C $cwd -c core.useBuiltinFSMonitor=false -c core.fsmonitor=false"

  branch=$($GIT branch --show-current 2>/dev/null || $GIT rev-parse --short HEAD 2>/dev/null)

  # Staged and unstaged file counts
  staged=$($GIT diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')
  unstaged=$($GIT diff --name-only 2>/dev/null | wc -l | tr -d ' ')

  is_dirty=false
  [ "$staged" -gt 0 ] || [ "$unstaged" -gt 0 ] && is_dirty=true

  if $is_dirty; then
    git_info=$(printf "${C_SKY}${ICON_GIT} ${C_RED}%s${C_RESET}" "$branch")
  else
    git_info=$(printf "${C_SKY}${ICON_GIT} ${C_SAPPHIRE}%s${C_RESET}" "$branch")
  fi

  # Build change summary: +staged ~unstaged ?untracked
  change_parts=""
  [ "$staged" -gt 0 ]    && change_parts+=$(printf " ${C_GREEN}+%d${C_RESET}" "$staged")
  [ "$unstaged" -gt 0 ]  && change_parts+=$(printf " ${C_YELLOW}~%d${C_RESET}" "$unstaged")

  # Ahead/behind — try upstream, fallback to origin/<branch>
  upstream=$($GIT rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null)
  if [ -z "$upstream" ]; then
    $GIT rev-parse --verify "origin/$branch" >/dev/null 2>&1 && upstream="origin/$branch"
  fi
  if [ -n "$upstream" ]; then
    counts=$($GIT rev-list --left-right --count HEAD..."$upstream" 2>/dev/null)
    if [ -n "$counts" ]; then
      ahead=$(echo "$counts" | awk '{print $1}')
      behind=$(echo "$counts" | awk '{print $2}')
      [ "$ahead" -gt 0 ]  && change_parts+=$(printf " ${C_GREEN}↑%d${C_RESET}" "$ahead")
      [ "$behind" -gt 0 ] && change_parts+=$(printf " ${C_RED}↓%d${C_RESET}" "$behind")
    fi
  fi

  [ -n "$change_parts" ] && git_details=$(printf "${C_OVERLAY}[${C_RESET}%s${C_OVERLAY}]${C_RESET}" "$change_parts")
fi

# ---------------------------------------------------------------------------
# Worktree — branch already shown in git_info, so only show name here
# ---------------------------------------------------------------------------
worktree_info=""
worktree_name=$(echo "$input" | jq -r '.worktree.name // empty')

# ---------------------------------------------------------------------------
# Session name
# ---------------------------------------------------------------------------
session_name=$(echo "$input" | jq -r '.session_name // empty')
session_name_info=""
[ -n "$session_name" ] && session_name_info=$(printf "${C_SKY} %s${C_RESET}" "$session_name")

# ---------------------------------------------------------------------------
# Vim mode
# ---------------------------------------------------------------------------
vim_mode=$(echo "$input" | jq -r '.vim.mode // empty')
vim_indicator=""
if [ -n "$vim_mode" ]; then
  if [ "$vim_mode" = "NORMAL" ]; then
    vim_indicator=$(printf " ${C_GREEN}[N]${C_RESET}")
  else
    vim_indicator=$(printf " ${C_YELLOW}[I]${C_RESET}")
  fi
fi

# ---------------------------------------------------------------------------
# Output style
# ---------------------------------------------------------------------------
output_style=$(echo "$input" | jq -r '.output_style.name // empty')
style_info=""
[ -n "$output_style" ] && [ "$output_style" != "default" ] && \
  style_info=$(printf " ${C_MAUVE}󰉁 %s${C_RESET}" "$output_style")

# ---------------------------------------------------------------------------
# Assemble status line
# Format:  [icon] dir   branch [+s ~u ↑↓]  │  󰧑 Model  │  effort  [│  ctx% >= 80] [vim] [style]
# icon: tree glyph when in a worktree, folder otherwise
# ---------------------------------------------------------------------------
if [ -n "$worktree_name" ]; then
  printf "${C_BOLD}${C_GREEN}${ICON_WORKTREE} %s${C_RESET}" "$dir_name"
else
  printf "${C_BOLD}${C_BLUE}${ICON_FOLDER} %s${C_RESET}" "$dir_name"
fi

printf " %s" "$git_info"
[ -n "$git_details" ] && printf " %b" "$git_details"

printf " %s " "$SEP"
printf "%s" "$model_display"
[ -n "$effort_info" ] && printf "%s" "$effort_info"

[ -n "$context_info" ]      && printf "%s" "$context_info"
[ -n "$session_name_info" ] && printf " %s%s" "$SEP" "$session_name_info"
[ -n "$vim_indicator" ]     && printf "%s" "$vim_indicator"
[ -n "$style_info" ]        && printf " %s%s" "$SEP" "$style_info"

exit 0
