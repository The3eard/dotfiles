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
scripts/    helpers linked into ~/.scripts
Brewfile    packages for both systems
```

## Not in the repo

These files are created on first install and never committed:

- `~/.secrets`: API keys and tokens, sourced by the zshrc. Template: [`secrets.example`](secrets.example).
- `~/.gitconfig.local`: git name and email (included from `gitconfig`).
- `~/.zshrc.local`: machine-specific aliases, sourced at the end of the zshrc.
