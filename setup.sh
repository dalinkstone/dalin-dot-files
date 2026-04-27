#!/usr/bin/env bash
# dalin-dot-files setup.
#
# One-shot bootstrap for a fresh macOS machine. Idempotent: re-running upgrades
# what is already there and skips what is current. Existing dotfiles are moved
# into ~/.dotfiles_backup/<timestamp>/ before being replaced with symlinks.
#
# Usage (from a freshly cloned repo):
#   ./setup.sh
#
# Notes
#   - Do not run with sudo. The script asks for elevation only where needed
#     (Homebrew, RVM, chsh, and some casks).
#   - Some steps are interactive: the Xcode CLT installer opens a GUI dialog;
#     a few casks (Docker, Tailscale) prompt for an admin password; chsh asks
#     for your login password.

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

# ---------- powerlevel10k fonts ----------------------------------------------

# p10k's README points users at four specific TTFs hosted in
# romkatv/powerlevel10k-media. They register as "MesloLGS NF" in the macOS
# font picker, which is the exact name p10k's setup wizard tells you to pick.
# The Homebrew cask `font-meslo-lg-nerd-font` is the same patched glyph set
# but installs ~70 variant files under different names ("MesloLGS Nerd Font"),
# so we fetch the curated four directly to match p10k's docs.
install_p10k_fonts() {
  local font_dir="$HOME/Library/Fonts"
  local base="https://github.com/romkatv/powerlevel10k-media/raw/master"
  local fonts=(
    "MesloLGS NF Regular.ttf"
    "MesloLGS NF Bold.ttf"
    "MesloLGS NF Italic.ttf"
    "MesloLGS NF Bold Italic.ttf"
  )
  ensure_dir "$font_dir"
  local installed=0
  for f in "${fonts[@]}"; do
    if [[ -f "$font_dir/$f" ]]; then
      continue
    fi
    log "downloading $f"
    # GitHub's raw URL needs the spaces percent-encoded.
    local encoded="${f// /%20}"
    if curl -fsSL "$base/$encoded" -o "$font_dir/$f"; then
      installed=$((installed + 1))
    else
      warn "failed to download $f"
      rm -f "$font_dir/$f"
    fi
  done
  if (( installed > 0 )); then
    ok "installed $installed MesloLGS NF font(s); restart Terminal.app to see them in the font picker"
  else
    ok "MesloLGS NF fonts already present"
  fi
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
  if [[ -d "$DOTFILES_DIR/.config/raycast" ]]; then
    link "$DOTFILES_DIR/.config/raycast" "$HOME/.config/raycast"
  fi
}

# ---------- Terminal.app theme -----------------------------------------------

# A Terminal.app .terminal file embeds the background image as a Foundation
# bookmark — an absolute alias that hardcodes the file path AND the volume
# UUID, so the bookmark stored in the repo is only valid on the machine that
# generated it. Regenerate one for the current machine before importing.
generate_bookmark_b64() {
  local target="$1"
  swift - "$target" <<'SWIFT'
import Foundation
let path = CommandLine.arguments[1]
let url = URL(fileURLWithPath: path)
do {
  let bookmark = try url.bookmarkData()
  let archive = try NSKeyedArchiver.archivedData(withRootObject: bookmark, requiringSecureCoding: false)
  print(archive.base64EncodedString())
} catch {
  FileHandle.standardError.write("error: \(error)\n".data(using: .utf8)!)
  exit(1)
}
SWIFT
}

import_terminal_theme() {
  local theme="$DOTFILES_DIR/DarkTyrael.terminal"
  local wallpaper="$DOTFILES_DIR/tyrael.png"

  [[ -f "$theme" ]] || { warn "DarkTyrael.terminal not found; skipping theme import"; return 0; }

  # Terminal.app keys imported profiles by the .terminal file's basename,
  # not by the `name` field inside the plist — so the staged copy must be
  # called DarkTyrael.terminal exactly, otherwise we end up with sibling
  # profiles (DarkTyrael.A1B2C3, etc.) every time the script runs. Stage
  # it inside a unique temp directory to keep that filename stable.
  local staged_dir staged
  staged_dir="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-terminal.XXXXXX")"
  staged="$staged_dir/DarkTyrael.terminal"
  cp "$theme" "$staged"

  if [[ ! -f "$wallpaper" ]]; then
    warn "wallpaper $wallpaper not found; theme will import without background image"
  elif ! has swift; then
    warn "swift not on PATH (Xcode CLT?); theme will import without refreshed bookmark"
  else
    log "regenerating BackgroundImageBookmark for $wallpaper"
    local b64
    if b64=$(generate_bookmark_b64 "$wallpaper"); then
      plutil -replace BackgroundImageBookmark -data "$b64" "$staged"
      ok "bookmark refreshed"
    else
      warn "bookmark generation failed; theme will import with stale bookmark"
    fi
  fi

  log "importing Terminal.app theme (DarkTyrael)"
  open "$staged"
  ok "theme imported — set DarkTyrael as default in Terminal → Settings if desired"
}

# ---------- language toolchains ----------------------------------------------

install_node_via_nvm() {
  export NVM_DIR="$HOME/.nvm"
  ensure_dir "$NVM_DIR"
  if [[ -s /opt/homebrew/opt/nvm/nvm.sh ]]; then
    \. /opt/homebrew/opt/nvm/nvm.sh
  elif [[ -s /usr/local/opt/nvm/nvm.sh ]]; then
    \. /usr/local/opt/nvm/nvm.sh
  else
    warn "nvm.sh not found; skipping Node install. Re-run after brew bundle."
    return 0
  fi
  if has node; then
    ok "Node already installed: $(node --version)"
  else
    log "installing latest LTS Node via nvm"
    nvm install --lts
  fi
}

install_python_via_pyenv() {
  if ! has pyenv; then
    warn "pyenv not on PATH; skipping Python install"
    return 0
  fi
  eval "$(pyenv init -)" 2>/dev/null || true
  if [[ -n "$(pyenv versions --bare 2>/dev/null)" ]]; then
    ok "Python already installed via pyenv: $(pyenv version-name)"
    return 0
  fi
  log "installing latest stable Python via pyenv"
  local latest_py
  latest_py=$(pyenv install --list | grep -E '^\s*3\.[0-9]+\.[0-9]+$' | tail -1 | tr -d ' ')
  pyenv install "$latest_py"
  pyenv global "$latest_py"
  ok "installed Python $latest_py"
}

install_rvm() {
  if [[ -d "$HOME/.rvm" ]]; then
    ok "RVM already installed"
    return 0
  fi

  # The RVM installer verifies its tarball against two GPG signatures and
  # aborts if neither key is in the local keyring. pool.sks-keyservers.net
  # was sunset in 2021, so prefer the official .asc files served by rvm.io
  # and fall back to keyserver.ubuntu.com.
  if has gpg; then
    log "importing RVM signing keys (mpapis + pkuczynski)"
    if curl -fsSL https://rvm.io/mpapis.asc | gpg --import - 2>/dev/null \
        && curl -fsSL https://rvm.io/pkuczynski.asc | gpg --import - 2>/dev/null; then
      ok "RVM signing keys imported from rvm.io"
    else
      warn "rvm.io key fetch failed; trying hkp://keyserver.ubuntu.com"
      gpg --keyserver hkp://keyserver.ubuntu.com --recv-keys \
        409B6B1796C275462A1703113804BB82D39DC0E3 \
        7D2BAF1CF37B13E2069D6956105BD0E739499BDB \
        || warn "keyserver fallback also failed; RVM install may abort at signature check"
    fi
  else
    warn "gpg not on PATH; RVM install will likely fail signature verification"
  fi

  log "installing RVM (Ruby Version Manager)"
  curl -sSL https://get.rvm.io | bash -s stable
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
  if [[ -d /Applications/Xcode.app ]]; then
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

# ---------- default shell ----------------------------------------------------

set_default_shell() {
  local current
  current=$(dscl . -read "/Users/$(whoami)" UserShell 2>/dev/null | awk '{print $2}')
  if [[ "$current" == "/bin/zsh" ]]; then
    ok "default shell is already zsh"
    return 0
  fi
  log "setting default shell to /bin/zsh (will prompt for your password)"
  chsh -s /bin/zsh
}

# ---------- macOS system settings --------------------------------------------

configure_macos_settings() {
  log "configuring macOS system settings"

  # Dock: right side, small, auto-hide, no recents, no default apps
  defaults write com.apple.dock orientation -string "right"
  defaults write com.apple.dock tilesize -integer 36
  defaults write com.apple.dock autohide -bool true
  defaults write com.apple.dock autohide-delay -float 0
  defaults write com.apple.dock autohide-time-modifier -float 0.4
  defaults write com.apple.dock show-recents -bool false
  defaults write com.apple.dock persistent-apps -array
  defaults write com.apple.dock persistent-others -array
  defaults write com.apple.dock minimize-to-application -bool true

  # Menu bar clock: time only, 24-hour, no day-of-week
  defaults write com.apple.menuextra.clock ShowDate -int 2
  defaults write com.apple.menuextra.clock IsAnalog -bool false
  defaults write com.apple.menuextra.clock Show24Hour -bool true
  defaults write com.apple.menuextra.clock ShowDayOfWeek -bool false

  # Finder: list view, extensions, path/status bar, home-folder default
  defaults write NSGlobalDomain AppleShowAllExtensions -bool true
  defaults write com.apple.finder ShowPathbar -bool true
  defaults write com.apple.finder ShowStatusBar -bool true
  defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
  defaults write com.apple.finder NewWindowTarget -string "PfHm"
  defaults write com.apple.finder NewWindowTargetPath -string "file://${HOME}/"
  defaults write com.apple.finder AppleShowAllFiles -bool true
  defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
  defaults write com.apple.finder _FXSortFoldersFirst -bool true
  defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"

  # Trackpad: tap to click
  defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
  defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
  defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
  defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

  # General UI: expanded save/print panels
  defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
  defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true
  defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
  defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true

  # Screenshots: save to ~/Screenshots, PNG, no shadow
  ensure_dir "$HOME/Screenshots"
  defaults write com.apple.screencapture location -string "$HOME/Screenshots"
  defaults write com.apple.screencapture type -string "png"
  defaults write com.apple.screencapture disable-shadow -bool true

  log "restarting Dock, Finder, and SystemUIServer to apply changes"
  killall Dock 2>/dev/null || true
  killall Finder 2>/dev/null || true
  killall SystemUIServer 2>/dev/null || true
  ok "macOS settings applied"
}

# ---------- summary ----------------------------------------------------------

print_summary() {
  cat <<SUMMARY

$(c 32 '✓ dotfiles setup complete')

next steps

  1. Restart your terminal (or run: exec zsh -l) to load the new config.
  2. In tmux, press prefix + I to install tmux plugins.
  3. Open Raycast, AltTab, Rectangle, and Stats once to grant permissions.
  4. Run 'claude' to set up Claude Code with your API key.
  5. Run 'aws configure' if you need AWS CLI credentials.

manual / out-of-band steps

  • Rippling     — no Homebrew or CLI install. Download the Mac client from
                   https://app.rippling.com (or your employer's SSO portal).
  • Lovable      — web product only (https://lovable.dev). No native install.
  • Raycast Brew — open Raycast → Store → install the "Brew" extension. It
                   auto-syncs against installed Homebrew formulae and casks
                   (and can read $DOTFILES_DIR/Brewfile).
  • Xcode        — if the App Store wasn't signed in the script skipped it.
                   After signing in: mas install $XCODE_APP_STORE_ID
  • Tailscale    — open the menu-bar icon and sign in.
  • 1Password    — first launch grants permissions and links to the CLI (op).
  • Menu bar     — System Settings → Control Center to hide icons you don't
                   want (Wi-Fi, Bluetooth, Sound, etc.).
  • HiddenBar    — open it to configure which menu bar icons to collapse.
  • Mouse        — System Settings → Mouse to configure button clicks.

backups (if any) are under: $BACKUP_DIR
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
  install_p10k_fonts
  link_dotfiles
  import_terminal_theme
  install_node_via_nvm
  install_python_via_pyenv
  install_rvm
  clone_daytona_repo
  install_claude_code
  install_codex
  install_xcode_full
  set_default_shell
  configure_macos_settings
  print_summary
}

main "$@"
