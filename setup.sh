#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "==> Dalin's Mac Setup Script"
echo "    Dotfiles directory: $DOTFILES_DIR"
echo ""

# --- Xcode Command Line Tools ---
if ! xcode-select -p &>/dev/null; then
  echo "==> Installing Xcode Command Line Tools..."
  xcode-select --install
  echo "    Press any key after the installation finishes."
  read -r -n 1
else
  echo "==> Xcode Command Line Tools already installed."
fi

# --- Homebrew ---
if ! command -v brew &>/dev/null; then
  echo "==> Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
else
  echo "==> Homebrew already installed."
fi

# --- Brew Bundle ---
echo "==> Installing Homebrew packages from Brewfile..."
echo "    This installs: git, neovim, tmux, fzf, ripgrep, bat, eza, zoxide,"
echo "    go, pyenv, nvm, gh, awscli, ffmpeg, yt-dlp, mpv, lazygit, lazydocker,"
echo "    docker-compose, and casks: Docker, AltTab, Stats, Raycast, Rectangle,"
echo "    Obsidian, HiddenBar, Zoom"
brew bundle --file="$DOTFILES_DIR/Brewfile"

# --- Oh My Zsh ---
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  echo "==> Installing Oh My Zsh..."
  RUNZSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
  echo "==> Oh My Zsh already installed."
fi

# --- Powerlevel10k theme ---
P10K_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
if [ ! -d "$P10K_DIR" ]; then
  echo "==> Installing Powerlevel10k theme..."
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
else
  echo "==> Powerlevel10k already installed."
fi

# --- Zsh plugins ---
ZSH_CUSTOM_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

if [ ! -d "$ZSH_CUSTOM_DIR/plugins/zsh-autosuggestions" ]; then
  echo "==> Installing zsh-autosuggestions..."
  git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM_DIR/plugins/zsh-autosuggestions"
else
  echo "==> zsh-autosuggestions already installed."
fi

if [ ! -d "$ZSH_CUSTOM_DIR/plugins/zsh-syntax-highlighting" ]; then
  echo "==> Installing zsh-syntax-highlighting..."
  git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM_DIR/plugins/zsh-syntax-highlighting"
else
  echo "==> zsh-syntax-highlighting already installed."
fi

# --- Symlink dotfiles ---
echo "==> Symlinking dotfiles..."

link_file() {
  local src="$1"
  local dest="$2"
  if [ -L "$dest" ]; then
    echo "    Removing existing symlink: $dest"
    rm "$dest"
  elif [ -f "$dest" ] || [ -d "$dest" ]; then
    echo "    Backing up existing: $dest -> ${dest}.backup"
    mv "$dest" "${dest}.backup"
  fi
  ln -s "$src" "$dest"
  echo "    Linked: $dest -> $src"
}

link_file "$DOTFILES_DIR/.zshrc"    "$HOME/.zshrc"
link_file "$DOTFILES_DIR/.zprofile" "$HOME/.zprofile"
link_file "$DOTFILES_DIR/.zlogin"   "$HOME/.zlogin"
link_file "$DOTFILES_DIR/.p10k.zsh" "$HOME/.p10k.zsh"
link_file "$DOTFILES_DIR/.tmux.conf" "$HOME/.tmux.conf"

# --- Neovim config ---
echo "==> Symlinking Neovim config..."
mkdir -p "$HOME/.config"
link_file "$DOTFILES_DIR/.config/nvim" "$HOME/.config/nvim"

# --- Raycast config ---
echo "==> Symlinking Raycast config..."
mkdir -p "$HOME/.config"
link_file "$DOTFILES_DIR/.config/raycast" "$HOME/.config/raycast"

# --- Terminal theme ---
if [ -f "$DOTFILES_DIR/DarkTyrael.terminal" ]; then
  echo "==> Importing Terminal.app theme (DarkTyrael)..."
  open "$DOTFILES_DIR/DarkTyrael.terminal"
  echo "    Theme imported. Set it as default in Terminal > Preferences if desired."
fi

# --- TPM (Tmux Plugin Manager) ---
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
  echo "==> Installing Tmux Plugin Manager (TPM)..."
  git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
else
  echo "==> TPM already installed."
fi

# --- NVM + Node ---
export NVM_DIR="$HOME/.nvm"
mkdir -p "$NVM_DIR"
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"

if ! command -v node &>/dev/null; then
  echo "==> Installing latest LTS Node via NVM..."
  nvm install --lts
else
  echo "==> Node already installed: $(node --version)"
fi

# --- Python via pyenv ---
eval "$(pyenv init -)" 2>/dev/null || true
if [ -z "$(pyenv versions --bare 2>/dev/null)" ]; then
  echo "==> Installing latest Python via pyenv..."
  LATEST_PY=$(pyenv install --list | grep -E '^\s*3\.[0-9]+\.[0-9]+$' | tail -1 | tr -d ' ')
  pyenv install "$LATEST_PY"
  pyenv global "$LATEST_PY"
  echo "    Installed Python $LATEST_PY"
else
  echo "==> Python already installed via pyenv: $(pyenv version-name)"
fi

# --- Claude Code ---
if ! command -v claude &>/dev/null; then
  echo "==> Installing Claude Code..."
  npm install -g @anthropic-ai/claude-code
else
  echo "==> Claude Code already installed."
fi

# --- RVM (for Ruby) ---
if [ ! -d "$HOME/.rvm" ]; then
  echo "==> Installing RVM..."
  curl -sSL https://get.rvm.io | bash -s stable
else
  echo "==> RVM already installed."
fi

# --- Set default shell to zsh ---
CURRENT_SHELL=$(dscl . -read /Users/"$(whoami)" UserShell | awk '{print $2}')
if [ "$CURRENT_SHELL" != "/bin/zsh" ]; then
  echo "==> Setting default shell to zsh..."
  chsh -s /bin/zsh
else
  echo "==> Default shell is already zsh."
fi

# =============================================================================
# macOS System Settings
# =============================================================================
echo ""
echo "==> Configuring macOS system settings..."

# --- Dock ---
echo "    Dock: move to right side, small size, auto-hide, remove default apps"
# Position on right
defaults write com.apple.dock orientation -string "right"
# Small tile size
defaults write com.apple.dock tilesize -integer 36
# Auto-hide the dock
defaults write com.apple.dock autohide -bool true
# Speed up auto-hide animation
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -float 0.4
# Don't show recent apps in the dock
defaults write com.apple.dock show-recents -bool false
# Remove all default apps from the dock
defaults write com.apple.dock persistent-apps -array
defaults write com.apple.dock persistent-others -array
# Minimize windows into their application icon
defaults write com.apple.dock minimize-to-application -bool true

# --- Menu Bar Clock ---
echo "    Clock: show time only (no date)"
# Show only the time, hide date
defaults write com.apple.menuextra.clock ShowDate -int 2
# Use digital clock
defaults write com.apple.menuextra.clock IsAnalog -bool false
# 24-hour format (remove if you prefer 12-hour)
defaults write com.apple.menuextra.clock Show24Hour -bool true
# Hide day of week
defaults write com.apple.menuextra.clock ShowDayOfWeek -bool false

# --- Finder ---
echo "    Finder: list view, show extensions, path bar, status bar, home folder default"
# Show all file extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
# Show path bar at bottom of Finder
defaults write com.apple.finder ShowPathbar -bool true
# Show status bar at bottom of Finder
defaults write com.apple.finder ShowStatusBar -bool true
# Default to list view in all windows (Nlsv = list, icnv = icon, clmv = column, glyv = gallery)
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
# New Finder windows open home folder
defaults write com.apple.finder NewWindowTarget -string "PfHm"
defaults write com.apple.finder NewWindowTargetPath -string "file://${HOME}/"
# Show hidden files
defaults write com.apple.finder AppleShowAllFiles -bool true
# Disable warning when changing file extensions
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false
# Keep folders on top when sorting by name
defaults write com.apple.finder _FXSortFoldersFirst -bool true
# Search the current folder by default
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"

# --- Trackpad ---
echo "    Trackpad: tap to click"
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

# --- General UI ---
echo "    General: expand save/print panels, disable natural scroll direction"
# Expand save panel by default
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true
# Expand print panel by default
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint2 -bool true

# --- Screenshots ---
echo "    Screenshots: save to ~/Screenshots"
mkdir -p "$HOME/Screenshots"
defaults write com.apple.screencapture location -string "$HOME/Screenshots"
# Save as PNG
defaults write com.apple.screencapture type -string "png"
# Disable shadow in screenshots
defaults write com.apple.screencapture disable-shadow -bool true

# --- Restart affected apps ---
echo "    Restarting Dock and Finder to apply changes..."
killall Dock 2>/dev/null || true
killall Finder 2>/dev/null || true
killall SystemUIServer 2>/dev/null || true

echo ""
echo "==> Setup complete!"
echo ""
echo "    Next steps:"
echo "    1. Restart your terminal (or run: source ~/.zshrc)"
echo "    2. In tmux, press prefix + I to install tmux plugins"
echo "    3. Open Raycast, AltTab, Rectangle, and Stats to grant permissions & configure"
echo "    4. Run 'claude' to set up Claude Code with your API key"
echo "    5. Run 'aws configure' to set up AWS CLI"
echo ""
echo "    Manual steps (cannot be reliably scripted):"
echo "    - Menu bar: Open System Settings > Control Center to hide icons"
echo "      (Wi-Fi, Bluetooth, Sound, etc. — choose 'Don't Show in Menu Bar')"
echo "    - Mouse: Open System Settings > Mouse to configure button clicks"
echo "    - HiddenBar: Open it to configure which menu bar icons to collapse"
echo ""
