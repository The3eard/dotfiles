# dotfiles

Terminal and editor setup for macOS and Linux: zsh (no framework), starship, Ghostty, Helix, Zed, git, bat, fzf, gh and glab.

## Install

```sh
git clone https://github.com/The3eard/dotfiles.git ~/Projects/dotfiles
cd ~/Projects/dotfiles
./install.sh          # packages + links
./install.sh link     # links only
```

`install.sh` is idempotent. Any file it replaces with a symlink is moved to `~/.dotfiles-backup/<timestamp>/`.

| Step | macOS | Linux (apt / dnf / pacman) |
|---|---|---|
| Base | Xcode Command Line Tools | build tools, zsh, flatpak |
| CLI tools | `brew bundle` (Brewfile) | same Brewfile via Homebrew on Linux |
| Apps | casks in the Brewfile | Zed (official script), Ghostty (snap), Docker Engine, 0xProto Nerd Font, flatpaks |
| Toolchains | SDKMAN (Java/Maven/Tomcat), fnm + Node LTS, rustup, Claude Code | same |

## Layout

```
zsh/        zshrc, zshenv, profile and the vendored sudo plugin
git/        gitconfig and global ignore
config/     everything that lives in ~/.config
claude/     Claude Code: CLAUDE.md, agent team, status line, dotfiles skill, settings
scripts/    helpers linked into ~/.scripts
Brewfile    packages for both systems
```

## Not in the repo

These files are created on first install and never committed:

- `~/.secrets`: API keys and tokens, sourced by the zshrc. Template: [`secrets.example`](secrets.example).
- `~/.gitconfig.local`: git name and email (included from `gitconfig`).
- `~/.zshrc.local`: machine-specific aliases, sourced at the end of the zshrc.

## Manual configuration

Things `install.sh` cannot decide for you. None of them is a bug; each is a value that depends on the machine or the account.

### Files to fill in

| File | What to set |
|---|---|
| `~/.secrets` | API keys and tokens (see [`secrets.example`](secrets.example)). `creds` needs the `AWS_SSO_*` variables; zsh-ai needs `GEMINI_API_KEY`. |
| `~/.gitconfig.local` | `user.name` and `user.email` (and a signing key if you use one). |
| `~/.zshrc.local` | Optional: aliases and helpers that only make sense on that machine. |
| `~/.claude/user-profile.yaml` | Created by the `kojima` agent on its first run: name, language, Jira site/project, GitLab host and ids. |

### Logins

Tokens are never stored in the repo. After installing, run:

```sh
gh auth login
glab auth login          # once per GitLab host
claude                   # sign in on first launch
creds                    # AWS SSO credentials (needs the AWS_SSO_* vars)
```

### Per-machine values in linked files

These files are symlinks into the repo, so changing them shows up in `git status`. Commit the change, or hide it locally with `git update-index --skip-worktree <file>`.

- **Zed: Java path for jdtls.** `config/zed/settings.json` → `lsp.jdtls.settings.java_home` is an absolute path, because Zed expands neither `~` nor environment variables. Set it to `$HOME/.sdkman/candidates/java/current` with your real home directory, e.g. `/home/<user>/...` on Linux.

### Copied once, then yours

- **`~/.claude/settings.json`** is copied only when it does not exist, because Claude Code rewrites it from `/config`. Review `attribution` (the email used in commits and PRs) and `permissions.allow` (add the MCP servers you use on that machine).

### Linux differences

- **Ghostty:** the `macos-*` options are ignored, and the `global:` keybind (quick terminal on `super+grave`) is macOS only; bind it in your desktop environment instead. If `snap` is missing, install Ghostty by hand from its docs.
- **Docker:** log out and back in after the first install so the `docker` group applies.
- **Starship:** the Docker module looks for the Docker Desktop process, so it stays hidden with Docker Engine.
- **Desktop apps:** they come from Flathub; the macOS-only ones (Maccy, MiddleClick, OnyX, AWS VPN Client) have no Linux equivalent installed.

### Toolchains

- **Java, Maven and Tomcat** are installed per project: run `sdk env install` inside a repo with a `.sdkmanrc`.
- **Node** gets the latest LTS as the default; projects with an `.nvmrc` ask for `fnm install` when their version is missing.
