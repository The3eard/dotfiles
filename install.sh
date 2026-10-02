#!/usr/bin/env bash
# Bootstraps this setup on macOS or Linux (apt, dnf or pacman).
#
#   ./install.sh          install packages, then link the dotfiles
#   ./install.sh link     only link the dotfiles
#
# CLI tools come from the Brewfile on both systems (Homebrew on Linux), so the
# same versions and paths apply everywhere. Existing files that would be
# replaced by a link are moved to ~/.dotfiles-backup/<timestamp>/. Safe to re-run.

set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
OS="$(uname -s)"

info() { printf '\033[1;34m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$1" >&2; }
has()  { command -v "$1" >/dev/null 2>&1; }

# ── Packages ─────────────────────────────────────────────────────────────────

install_macos_prereqs() {
	if ! xcode-select -p >/dev/null 2>&1; then
		info "Installing Xcode Command Line Tools (finish the dialog, then re-run)"
		xcode-select --install
		exit 0
	fi
}

install_linux_prereqs() {
	info "Installing base packages (Homebrew build deps, zsh, flatpak)"
	if has apt-get; then
		sudo apt-get update
		sudo apt-get install -y build-essential procps curl file git zsh flatpak unzip fontconfig
	elif has dnf; then
		sudo dnf group install -y development-tools || sudo dnf groupinstall -y "Development Tools"
		sudo dnf install -y procps-ng curl file git zsh flatpak unzip fontconfig
	elif has pacman; then
		sudo pacman -Syu --needed --noconfirm base-devel procps-ng curl file git zsh flatpak unzip fontconfig
	else
		warn "Unsupported package manager: install build tools, curl, git, zsh and unzip manually"
	fi
}

install_homebrew() {
	if ! has brew; then
		info "Installing Homebrew"
		NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	fi
	for prefix in /opt/homebrew /home/linuxbrew/.linuxbrew; do
		[[ -x "$prefix/bin/brew" ]] && eval "$("$prefix/bin/brew" shellenv)"
	done
	info "Installing Brewfile packages"
	# Apps installed outside Homebrew make their cask fail; the rest still installs.
	brew bundle --file="$DOTFILES/Brewfile" || warn "Some Brewfile entries failed (see above)"
}

install_linux_apps() {
	if ! has zed; then
		info "Installing Zed"
		curl -fsSL https://zed.dev/install.sh | sh
	fi

	if ! has ghostty; then
		if has snap; then
			info "Installing Ghostty (snap)"
			sudo snap install ghostty --classic
		else
			warn "Install Ghostty from https://ghostty.org/docs/install/binary#linux-(official)"
		fi
	fi

	if ! has docker; then
		info "Installing Docker Engine"
		curl -fsSL https://get.docker.com | sudo sh
		sudo usermod -aG docker "$USER"
	fi

	local font_dir="$HOME/.local/share/fonts/0xProto"
	if [[ ! -d "$font_dir" ]]; then
		info "Installing 0xProto Nerd Font"
		mkdir -p "$font_dir"
		curl -fsSLo /tmp/0xProto.zip https://github.com/ryanoasis/nerd-fonts/releases/latest/download/0xProto.zip
		unzip -oq /tmp/0xProto.zip -d "$font_dir"
		rm -f /tmp/0xProto.zip
		fc-cache -f "$font_dir"
	fi

	if has flatpak; then
		info "Installing desktop apps (flatpak)"
		flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
		flatpak install --user -y --noninteractive flathub \
			com.google.Chrome com.slack.Slack com.discordapp.Discord com.spotify.Client \
			rest.insomnia.Insomnia com.jetbrains.IntelliJ-IDEA-Ultimate org.libreoffice.LibreOffice \
			io.github.mimbrero.WhatsAppDesktop ||
			warn "Some flatpaks failed (see above)"
	fi
}

install_toolchains() {
	if [[ ! -d "$HOME/.sdkman" ]]; then
		info "Installing SDKMAN"
		curl -fsSL "https://get.sdkman.io?rcupdate=false" | bash
	fi
	# The zshrc auto-switch hook replaces SDKMAN's own cd hook.
	sed -i.bak 's/^sdkman_auto_env=.*/sdkman_auto_env=false/' "$HOME/.sdkman/etc/config" &&
		rm -f "$HOME/.sdkman/etc/config.bak"

	if ! fnm list 2>/dev/null | grep -q default; then
		info "Installing Node LTS with fnm"
		fnm install --lts
		fnm default "$(fnm list | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | sort -V | tail -1)"
	fi
	eval "$(fnm env --shell bash)"
	fnm use default >/dev/null
	has codegraph || npm install -g @colbymchenry/codegraph

	if [[ ! -x "$HOME/.cargo/bin/rustup" ]]; then
		info "Installing Rust (rustup)"
		curl -fsSL https://sh.rustup.rs | sh -s -- -y --no-modify-path
	fi

	if ! has claude && [[ ! -x "$HOME/.local/bin/claude" ]]; then
		info "Installing Claude Code"
		curl -fsSL https://claude.ai/install.sh | bash
	fi
	local claude_bin
	claude_bin="$(command -v claude || echo "$HOME/.local/bin/claude")"
	"$claude_bin" mcp get codegraph >/dev/null 2>&1 ||
		"$claude_bin" mcp add --scope user codegraph -- codegraph serve --mcp
}

set_default_shell() {
	local zsh_path
	zsh_path="$(command -v zsh)"
	if [[ "$(basename "${SHELL:-}")" != zsh ]]; then
		grep -qx "$zsh_path" /etc/shells || echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
		info "Setting zsh as the login shell"
		chsh -s "$zsh_path"
	fi
}

# ── Links ────────────────────────────────────────────────────────────────────

# Links $1 (relative to the repo) at $2, backing up whatever was there.
link() {
	local src="$DOTFILES/$1" dst="$2"
	if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then
		return
	fi
	if [[ -e "$dst" || -L "$dst" ]]; then
		mkdir -p "$BACKUP_DIR/$(dirname "${dst#"$HOME"/}")"
		mv "$dst" "$BACKUP_DIR/${dst#"$HOME"/}"
	fi
	mkdir -p "$(dirname "$dst")"
	ln -s "$src" "$dst"
	echo "  $dst → $1"
}

link_dotfiles() {
	info "Linking dotfiles"
	link zsh/zshrc                          "$HOME/.zshrc"
	link zsh/zshenv                         "$HOME/.zshenv"
	link zsh/profile                        "$HOME/.profile"
	link zsh/plugins/sudo.plugin.zsh        "$HOME/.config/zsh/plugins/sudo.plugin.zsh"
	link git/gitconfig                      "$HOME/.gitconfig"
	link git/ignore                         "$HOME/.config/git/ignore"
	link config/starship.toml               "$HOME/.config/starship.toml"
	link config/ghostty/config              "$HOME/.config/ghostty/config"
	link config/ghostty/themes              "$HOME/.config/ghostty/themes"
	link config/helix/config.toml           "$HOME/.config/helix/config.toml"
	link config/helix/themes/transparent.toml "$HOME/.config/helix/themes/transparent.toml"
	link config/bat/config                  "$HOME/.config/bat/config"
	link config/zed/settings.json           "$HOME/.config/zed/settings.json"
	link config/zed/keymap.json             "$HOME/.config/zed/keymap.json"
	link config/gh/config.yml               "$HOME/.config/gh/config.yml"
	link config/glab-cli/aliases.yml        "$HOME/.config/glab-cli/aliases.yml"
	link scripts/aws-sso-login.sh           "$HOME/.scripts/aws-sso-login.sh"
	link claude/CLAUDE.md                   "$HOME/.claude/CLAUDE.md"
	link claude/statusline-command.sh       "$HOME/.claude/statusline-command.sh"
	link claude/skills/dotfiles             "$HOME/.claude/skills/dotfiles"
	local agent
	for agent in "$DOTFILES"/claude/agents/*.md; do
		link "claude/agents/$(basename "$agent")" "$HOME/.claude/agents/$(basename "$agent")"
	done

	# Claude Code rewrites settings.json from /config, so it is a starting copy, not a link.
	if [[ ! -e "$HOME/.claude/settings.json" ]]; then
		cp "$DOTFILES/claude/settings.json" "$HOME/.claude/settings.json"
		echo "  $HOME/.claude/settings.json ← claude/settings.json (copy)"
	fi

	if [[ ! -e "$HOME/.secrets" ]]; then
		install -m 600 "$DOTFILES/secrets.example" "$HOME/.secrets"
		warn "Created ~/.secrets from the template: fill in your keys"
	fi
	if [[ ! -e "$HOME/.gitconfig.local" ]]; then
		printf '[user]\n\tname = \n\temail = \n' >"$HOME/.gitconfig.local"
		warn "Created ~/.gitconfig.local: set your git name and email"
	fi
	[[ -d "$BACKUP_DIR" ]] && info "Previous files saved in $BACKUP_DIR"
	return 0
}

# ── Main ─────────────────────────────────────────────────────────────────────

main() {
	if [[ "${1:-}" != link ]]; then
		case "$OS" in
			Darwin) install_macos_prereqs ;;
			Linux)  install_linux_prereqs ;;
			*)      warn "Unsupported OS: $OS"; exit 1 ;;
		esac
		install_homebrew
		[[ "$OS" == Linux ]] && install_linux_apps
		install_toolchains
		set_default_shell
	fi
	link_dotfiles
	info "Done. Open a new terminal (or run: exec zsh)"
}

main "$@"
