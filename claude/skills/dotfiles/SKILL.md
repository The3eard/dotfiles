---
name: dotfiles
description: Map and conventions of this macOS/Linux terminal setup (the dotfiles repo). Use when editing ~/.zshrc, shell aliases/functions, starship, kitty, Helix, Zed, git, bat or lnav config, helper scripts in ~/.scripts, or SDKMAN/fnm version switching. Triggers: "zshrc", "alias", "dotfiles", "terminal config", "prompt", "kitty", "helix config", "add a tool to my shell".
---

# Dotfiles

## `~/.zshrc` is the source of truth

Every file in the config map below is a symlink into the dotfiles repo (`~/Projects/dotfiles`, linked by its `install.sh`): edit and commit there. Secrets go in `~/.secrets`, never in the repo.

Heavily documented (~600 lines, table-of-contents header). Read it before changing anything shell-related. Startup is ~80 ms; measure with `time zsh -i -c exit` (or `zmodload zsh/zprof`) after any change. Sections:

1. **Dependencies**: copy-paste install commands for a fresh machine (brew formulae, casks, vendored plugins). Keep it in sync when adding or removing a tool.
2. **Shell core**: plain zsh, no framework (Oh My Zsh is gone). Options, history, `compinit` + completion styles, key bindings, and the only vendored plugin (`sudo`, in `~/.config/zsh/plugins/`).
3. **Environment**: `EDITOR`, `VISUAL`, PATH, `JAVA_HOME`/`CATALINA_HOME`, secrets sourcing.
4. **Aliases**: grouped by category, each commented with its purpose.
5. **FZF**: Catppuccin theming + interactive functions (`ff`, `fdd`, `rgi`, `fkill`).
6. **External plugins**: fast-syntax-highlighting, autosuggestions, zsh-ai (from Homebrew).
7. **Initializations**: SDKMAN, zoxide, starship. Order matters: starship last.
8. **fnm + quiet version auto-switch**: `chpwd`/`precmd` hook that switches Java/Maven/Tomcat (SDKMAN) and Node (fnm) when `cd`-ing into `~/Projects/*`, printing one summary line. Warns, never auto-installs. Requires `sdkman_auto_env=false` and no `fnm env --use-on-cd`.

When adding a tool, update both its install command in §1 and its config/alias in the relevant later section, so the file stays self-bootstrapping.

## Config map

| Tool | Config | Notes |
|---|---|---|
| zsh | `~/.zshrc`, `~/.zshenv`, `~/.profile` | the last two only source `~/.cargo/env` |
| starship | `~/.config/starship.toml` | Xcode Dark HC palette |
| kitty | `~/.config/kitty/kitty.conf` | `splits` layout, `cmd` keybindings; `dark-theme.auto.conf` (GitHub Dark) and `light-theme.auto.conf` follow the OS appearance. Most of `kitty.conf` is the stock commented reference |
| git | `~/.gitconfig`, `~/.config/git/ignore` | difftastic as difftool; `gh` as credential helper |
| bat | `~/.config/bat/` + `BAT_THEME` | Catppuccin Mocha |
| Helix (`hx`) | `~/.config/helix/config.toml` + themes | `$EDITOR`; aliased as `vi`/`vim`/`editor`. Neovim is gone |
| Zed | `~/.config/zed/` | `$VISUAL="zed --wait"`; CLI symlinked at `~/.local/bin/zed` → `/Applications/Zed.app/Contents/MacOS/cli` |
| lnav | `~/.config/lnav/` | |
| ssh | `~/.ssh/config` | `SetEnv TERM=xterm-256color` for all hosts: remotes lack kitty's terminfo |
| gh / glab | `~/.config/gh/`, `~/.config/glab-cli/` | |

Terminal tool colours reference ANSI slots, never hex, so they follow the kitty theme; never slots 7/11 for text.

## Helper scripts (`~/.scripts/`)

- `aws-sso-login.sh` → alias `creds` (`creds [-e dev|prod]`, default dev). Refreshes AWS SSO credentials.

Machine-specific aliases and scripts (work tools, internal hosts) live in `~/.zshrc.local`, sourced at the end of `~/.zshrc` and never committed.

## Toolchain managers

- **fnm** (`~/.local/share/fnm`): Node, driven by `.nvmrc`. Global npm packages are per version. Anything that needs a stable Node path outside the shell (e.g. the `codegraph` MCP server in `~/.claude.json`) uses `~/.local/share/fnm/aliases/default/`, not a versioned path.
- **SDKMAN** (`~/.sdkman`): Java / Maven / Tomcat, driven by `.sdkmanrc`. `JAVA_HOME` and `CATALINA_HOME` point at its `current` symlinks.

`~/Projects/` holds the projects; the auto-switch hook is scoped to `~/Projects/*`.
