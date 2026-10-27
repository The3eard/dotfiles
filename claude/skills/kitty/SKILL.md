---
name: kitty
description: Drives the user's kitty terminal through remote control (`kitten @`) to show things beside the conversation instead of dumping them in chat. Use to show a diff before a push gate, open a tab in a worktree or directory the user has to look at, follow logs live in a split, or read the output of another kitty window the user points at ("mira el split de la derecha", "lee el error de la otra ventana"). Triggers: "kitty", "ábreme un split", "ábreme un tab", "enséñame el diff", "mira la otra ventana".
---

# kitty

The user works in kitty (`splits` layout). Remote control is socket-only (`allow_remote_control socket-only`, `listen_on unix:/tmp/kitty-{kitty_pid}` in `~/.config/kitty/kitty.conf`). The Bash tool has no TTY, so every `kitten @` call goes through `$KITTY_LISTEN_ON`.

## Availability

kitty is usable only when `$KITTY_LISTEN_ON` is set and `kitten @ ls >/dev/null` succeeds. Otherwise work in chat as usual; mention it only if the user asked for kitty. `$KITTY_WINDOW_ID` is the window this session runs in; every recipe anchors on it.

## Rules

- Never take focus: `--keep-focus` on every `launch`. The user decides when to look.
- Tag every window opened: `--var claude_owner=$KITTY_WINDOW_ID --var claude_role=<diff|logs|dir|...>`. Close only windows with this session's `claude_owner`, and reuse a role instead of stacking a second one.
- What runs in an opened window bypasses Claude Code's permission checks, so launch only viewers (`git diff`, `less`, `lnav`, `tail -F`, a plain shell) or tools the user drives (`lazygit`, `hx`). Never a command that changes anything on its own.
- Never `send-text`, `send-key`, `action`, `close-window` or `close-tab` on a window this session did not open, unless the user asks for that exact thing.
- `get-text` reads the user's screens, which may hold secrets: only on a window the user pointed at, and quote back only what the task needs.
- No secrets on a launched command line: `kitten @ ls` exposes it.
- Launched commands get kitty's environment, not this shell's; pass `--env "PATH=$PATH"` so Homebrew tools resolve.

## Recipes

Common prefix for a window next to this session, in its tab:

```bash
kitten @ launch --match "window_id:$KITTY_WINDOW_ID" --next-to "id:$KITTY_WINDOW_ID" --keep-focus \
  --env "PATH=$PATH" --var claude_owner=$KITTY_WINDOW_ID --var claude_role=<role> ...
```

**Diff in a split** (before a push gate, or when the user asks to see changes). Git's `diff.external` is difftastic and the pager closes the window on `q`; the user zooms it with `cmd+shift+enter`.

```bash
<prefix, role=diff> --location=vsplit --title "diff <base>...<sha>" --cwd "<repo>" \
  git diff <base>...<sha>
```

For an interactive look (stage, browse history) launch `lazygit` with the same prefix instead.

**Tab in a directory** (a worktree, a cherry-pick conflict, generated files). No command means the user's shell.

```bash
kitten @ launch --type=tab --next-to "id:$KITTY_WINDOW_ID" --keep-focus \
  --var claude_owner=$KITTY_WINDOW_ID --var claude_role=dir --tab-title "<TICKET> <what>" --cwd "<dir>"
```

**Live logs in a split.** Local file with `lnav <file>` (`butcher` keeps full logs on disk), remote with `ssh <host> tail -F <path>`.

```bash
<prefix, role=logs> --location=hsplit --title "logs <what>" lnav "<file>"
```

**Read another window.** List the windows of this tab, pick the one the user means (by title, cwd or foreground command; `recent:1` is the window the user was in just before), and ask when it is ambiguous. `foreground_processes` is unordered (this session's own window can list `caffeinate` before `claude`), so the listing shows every program name, never full command lines.

```bash
kitten @ ls --match-tab "window_id:$KITTY_WINDOW_ID" \
  | jq -r '.[].tabs[].windows[] | "\(.id)\t\(.title)\t\(.cwd)\t\(.foreground_processes | map(.cmdline[0] | split("/")[-1]) | unique | join(","))"'
kitten @ get-text --match id:<N> --extent last_non_empty_output   # or screen, all
```

**Tab title for pipeline state** (`<TICKET> · review r2`); an empty title gives the tab back to the window's own title.

```bash
kitten @ set-tab-title --match "window_id:$KITTY_WINDOW_ID" "<title>"
```

**Clean up** when the user is done, or before reopening a role:

```bash
kitten @ close-window --ignore-no-match --match "var:claude_owner=$KITTY_WINDOW_ID and var:claude_role=<role>"
```
