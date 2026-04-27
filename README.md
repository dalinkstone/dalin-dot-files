# dalin-dot-files

Personal macOS dotfiles. Bootstrapped on a fresh machine with one command.

## quick start

```sh
git clone https://github.com/dalinkstone/dalin-dot-files.git ~/dalin-dot-files
cd ~/dalin-dot-files
./setup.sh
```

The script is idempotent — re-run it to upgrade everything in place. Existing
dotfiles are moved to `~/.dotfiles_backup/<timestamp>/` before symlinks are
created, so nothing is overwritten silently.

## what gets installed

Driven by [`setup.sh`](setup.sh) and [`Brewfile`](Brewfile):

- Xcode command line tools (GUI prompt) and full Xcode via `mas` if signed in
- Homebrew, then everything in the Brewfile (formulae and casks):
  - CLIs: `awscli`, `bat`, `bun`, `docker-compose`, `eza`, `fd`, `ffmpeg`,
    `fzf`, `gh`, `git`, `gnupg`, `go`, `lazydocker`, `lazygit`, `mas`, `mpv`,
    `neovim`, `node`, `nvm`, `opencode`, `pyenv`, `ripgrep`, `tmux`, `uv`,
    `yt-dlp`, `zoxide`, etc.
  - Apps: 1Password (+ CLI), AltTab, Docker, HiddenBar, Notion, Obsidian,
    Raycast, Rectangle, Slack, Spotify, Stats, Tailscale, Zoom
- Oh My Zsh, Powerlevel10k, `zsh-autosuggestions`, `zsh-syntax-highlighting`
- tmux plugin manager (`tpm`)
- Language toolchains: latest LTS Node via `nvm`, latest stable Python via
  `pyenv`, Ruby via `rvm`
- Symlinks: `.zshrc`, `.zprofile`, `.zlogin`, `.tmux.conf`, `.p10k.zsh`,
  `~/.config/nvim`, `~/.config/raycast`
- Terminal.app theme (`DarkTyrael.terminal`) imported on first run, with
  `tyrael.png` (bundled in the repo) wired up as the background image — the
  bookmark is regenerated at install time so it resolves on whatever machine
  is running the script (Terminal's bookmarks hardcode the volume UUID, so
  the one stored in the .terminal file can't be reused across machines)
- Default shell switched to `/bin/zsh` via `chsh`
- macOS system settings: Dock (right side, auto-hide, no recents), menu-bar
  clock (time only, 24-hour), Finder (list view, path/status bar, hidden
  files, home as default), trackpad tap-to-click, screenshots saved to
  `~/Screenshots`
- Non-Homebrew tools fetched directly from upstream:
  - **Daytona** — `~/main/` is created and `github.com/daytonaio/daytona`
    is cloned to `~/main/daytona`. The installer is not run.
  - **Claude Code** via the official installer (`https://claude.ai/install.sh`)
  - **OpenAI Codex** via `npm install -g @openai/codex`

## manual steps the script can't automate

- **Raycast Brew sync** — open Raycast → Store → install the "Brew" extension
  to manage Homebrew packages from Raycast.
- **Xcode (App Store)** — sign into the App Store first, then re-run
  `./setup.sh` or run `mas install 497799835`.
- **Tailscale / 1Password / Spotify** — first launch each app to grant
  permissions and sign in.
- **Menu bar icons** — System Settings → Control Center to hide Wi-Fi,
  Bluetooth, Sound, etc.
- **HiddenBar** — open it to configure which menu bar icons to collapse.

## features

I'll post screenshots here of what each piece looks like and what the
highlights of the config are.
