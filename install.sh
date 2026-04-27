#!/usr/bin/env bash
# dalin-dot-files installer.
#
# One-shot bootstrap for a fresh macOS machine. Idempotent: re-running upgrades
# what is already there and skips what is current. Existing dotfiles are moved
# into ~/.dotfiles_backup/<timestamp>/ before being replaced with symlinks.
#
# Usage (from a freshly cloned repo):
#   ./install.sh
#
# Notes
#   - Do not run with sudo. The script asks for elevation only where needed
#     (Homebrew, the Daytona installer, and some casks).
#   - Some steps are interactive: the Xcode CLT installer opens a GUI dialog;
#     a few casks (Docker, Tailscale) prompt for an admin password.

set -euo pipefail
IFS=$'\n\t'

# ---------- helpers -----------------------------------------------------------

DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd -P )"
BACKUP_DIR="$HOME/.dotfiles_backup/$(date +%Y%m%d-%H%M%S)"

c() { local code="$1"; shift; printf '\033[%sm%s\033[0m' "$code" "$*"; }
log()  { printf '%s %s\n' "$(c 34 '[dotfiles]')"      "$*"; }
ok()   { printf '%s %s\n' "$(c 32 '[dotfiles ok]')"   "$*"; }
warn() { printf '%s %s\n' "$(c 33 '[dotfiles warn]')" "$*" >&2; }
die()  { printf '%s %s\n' "$(c 31 '[dotfiles fatal]')" "$*" >&2; exit 1; }

has() { command -v "$1" >/dev/null 2>&1; }

ensure_dir() { [[ -d "$1" ]] || mkdir -p "$1"; }

backup_path() {
  local target="$1"
  if [[ -e "$target" || -L "$target" ]]; then
    ensure_dir "$BACKUP_DIR"
    log "backing up $target → $BACKUP_DIR/"
    mv "$target" "$BACKUP_DIR/$(basename "$target")"
  fi
}

# Symlink src → dst. No-op if dst already points at src; otherwise back up dst
# and create the link. Never overwrites without backing up.
link() {
  local src="$1" dst="$2"
  [[ -e "$src" || -L "$src" ]] || die "missing source: $src"
  ensure_dir "$(dirname "$dst")"
  if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then
    return 0
  fi
  backup_path "$dst"
  ln -s "$src" "$dst"
  ok "linked $dst → $src"
}

clone_or_update() {
  local url="$1" dest="$2"
  if [[ -d "$dest/.git" ]]; then
    git -C "$dest" pull --ff-only --quiet || warn "could not fast-forward $dest"
  else
    ensure_dir "$(dirname "$dest")"
    git clone --depth=1 "$url" "$dest"
  fi
}

# ---------- preflight ---------------------------------------------------------

[[ "$(uname -s)" == "Darwin" ]] || die "macOS only — detected $(uname -s)."
[[ "$(id -u)" -ne 0 ]]          || die "do not run with sudo; the script elevates only when needed."

log "dotfiles repo: $DOTFILES_DIR"

# ---------- Xcode command line tools -----------------------------------------

install_xcode_clt() {
  if xcode-select -p >/dev/null 2>&1; then
    ok "Xcode command line tools already present"
    return 0
  fi
  log "installing Xcode command line tools — accept the GUI prompt that appears"
  xcode-select --install || true
  log "waiting for the install to finish (poll every 10s)"
  until xcode-select -p >/dev/null 2>&1; do sleep 10; done
  ok "Xcode command line tools installed"
}

# ---------- Homebrew + Brewfile ----------------------------------------------

install_homebrew() {
  if has brew; then
    ok "Homebrew already installed"
  else
    log "installing Homebrew (will request sudo)"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  else
    die "Homebrew install reported success but brew binary not found"
  fi
}

run_brew_bundle() {
  log "updating Homebrew metadata"
  brew update
  log "running brew bundle (this will take a while on a fresh machine)"
  brew bundle --file="$DOTFILES_DIR/Brewfile"
  log "upgrading any out-of-date formulae and casks"
  brew upgrade
  brew cleanup
  ok "Homebrew bundle complete"
}

# ---------- Oh My Zsh + plugins + theme --------------------------------------

ZSH_DIR="${ZSH:-$HOME/.oh-my-zsh}"
ZSH_CUSTOM_DIR="${ZSH_CUSTOM:-$ZSH_DIR/custom}"

install_oh_my_zsh() {
  if [[ -d "$ZSH_DIR" ]]; then
    ok "oh-my-zsh already installed"
    return 0
  fi
  log "installing oh-my-zsh (unattended; will not chsh or overwrite .zshrc)"
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
}

install_zsh_extras() {
  ensure_dir "$ZSH_CUSTOM_DIR/plugins"
  ensure_dir "$ZSH_CUSTOM_DIR/themes"
  clone_or_update https://github.com/zsh-users/zsh-autosuggestions.git \
    "$ZSH_CUSTOM_DIR/plugins/zsh-autosuggestions"
  clone_or_update https://github.com/zsh-users/zsh-syntax-highlighting.git \
    "$ZSH_CUSTOM_DIR/plugins/zsh-syntax-highlighting"
  clone_or_update https://github.com/romkatv/powerlevel10k.git \
    "$ZSH_CUSTOM_DIR/themes/powerlevel10k"
  ok "oh-my-zsh plugins and theme up to date"
}

# ---------- tmux plugin manager ----------------------------------------------

install_tpm() {
  clone_or_update https://github.com/tmux-plugins/tpm.git "$HOME/.tmux/plugins/tpm"
  ok "tmux plugin manager ready"
}

# ---------- dotfile symlinks --------------------------------------------------

link_dotfiles() {
  link "$DOTFILES_DIR/.zshrc"     "$HOME/.zshrc"
  link "$DOTFILES_DIR/.zprofile"  "$HOME/.zprofile"
  link "$DOTFILES_DIR/.zlogin"    "$HOME/.zlogin"
  link "$DOTFILES_DIR/.tmux.conf" "$HOME/.tmux.conf"
  link "$DOTFILES_DIR/.p10k.zsh"  "$HOME/.p10k.zsh"
  ensure_dir "$HOME/.config"
  link "$DOTFILES_DIR/.config/nvim" "$HOME/.config/nvim"
}

# ---------- non-Homebrew CLIs -------------------------------------------------

clone_daytona_repo() {
  local main_dir="$HOME/main"
  local dest="$main_dir/daytona"
  ensure_dir "$main_dir"
  if [[ -d "$dest/.git" ]]; then
    log "Daytona repo already cloned at $dest; pulling latest"
    git -C "$dest" pull --ff-only --quiet || warn "could not fast-forward $dest"
  else
    log "cloning daytonaio/daytona into $dest"
    git clone https://github.com/daytonaio/daytona.git "$dest"
  fi
  ok "Daytona source ready at $dest (installer not executed)"
}

install_claude_code() {
  if has claude; then
    ok "Claude Code already installed"
    return 0
  fi
  log "installing Claude Code via the official installer"
  curl -fsSL https://claude.ai/install.sh | bash
}

install_codex() {
  if has codex; then
    ok "OpenAI Codex already installed"
    return 0
  fi
  if ! has npm; then
    warn "npm not on PATH; skipping Codex install. Re-run after a shell restart."
    return 0
  fi
  log "installing OpenAI Codex via npm"
  npm install -g @openai/codex
}

# ---------- Mac App Store apps -----------------------------------------------

XCODE_APP_STORE_ID=497799835

install_xcode_full() {
  if [[ -d "/Applications/Xcode.app" ]]; then
    ok "Xcode.app already installed"
    return 0
  fi
  if ! has mas; then
    warn "mas not installed; skipping full Xcode. brew bundle should have installed it."
    return 0
  fi
  if ! mas account >/dev/null 2>&1; then
    warn "not signed into the App Store. Sign in via the App Store app, then run:"
    warn "    mas install $XCODE_APP_STORE_ID"
    return 0
  fi
  log "installing Xcode from the Mac App Store (large download)"
  mas install "$XCODE_APP_STORE_ID"
}

# ---------- summary ----------------------------------------------------------

print_summary() {
  cat <<SUMMARY

$(c 32 '✓ dotfiles install complete')

manual / out-of-band steps remaining

  • Rippling     — no Homebrew or CLI install. Download the Mac client from
                   https://app.rippling.com (or the SSO portal your employer uses).
  • Lovable      — web product only (https://lovable.dev). No native install.
  • Raycast Brew — open Raycast → Store → install the "Brew" extension. It
                   auto-syncs against installed Homebrew formulae and casks
                   (and can read this Brewfile at $DOTFILES_DIR/Brewfile).
  • Xcode        — if the App Store wasn't signed in the script skipped it.
                   After signing in: mas install $XCODE_APP_STORE_ID
  • Tailscale    — open the menu-bar icon and sign in.
  • 1Password    — first launch grants permissions and links to the CLI (op).

backups (if any) are under: $BACKUP_DIR

restart the shell or run 'exec zsh -l' to load the new config.
SUMMARY
}

# ---------- main -------------------------------------------------------------

main() {
  install_xcode_clt
  install_homebrew
  run_brew_bundle
  install_oh_my_zsh
  install_zsh_extras
  install_tpm
  link_dotfiles
  clone_daytona_repo
  install_claude_code
  install_codex
  install_xcode_full
  print_summary
}

main "$@"
