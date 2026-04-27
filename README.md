# dalin-dot-files

Personal macOS dotfiles. Bootstrapped on a fresh machine with one command.

## quick start

```sh
git clone https://github.com/dalinkstone/dalin-dot-files.git ~/dalin-dot-files
cd ~/dalin-dot-files
./install.sh
```

The installer is idempotent — re-run it to upgrade everything in place. Existing
dotfiles are moved to `~/.dotfiles_backup/<timestamp>/` before symlinks are
created, so nothing is overwritten silently.

## what gets installed

Driven by [`install.sh`](install.sh) and [`Brewfile`](Brewfile):

- Xcode command line tools (GUI prompt) and full Xcode via `mas` if signed in
- Homebrew, then everything in the Brewfile (formulae and casks):
  - CLIs: `bat`, `bun`, `eza`, `fd`, `fzf`, `gh`, `git`, `gnupg`, `go`,
    `lazydocker`, `lazygit`, `mas`, `neovim`, `node`, `nvm`, `opencode`,
    `pyenv`, `ripgrep`, `tmux`, `zoxide`, etc.
  - Apps: 1Password (+ CLI), AltTab, Docker, HiddenBar, Notion, Obsidian,
    Raycast, Rectangle, Slack, Spotify, Stats, Tailscale, Zoom
- Oh My Zsh, Powerlevel10k, `zsh-autosuggestions`, `zsh-syntax-highlighting`
- tmux plugin manager (`tpm`)
- Symlinks: `.zshrc`, `.zprofile`, `.zlogin`, `.tmux.conf`, `.p10k.zsh`,
  `~/.config/nvim`
- Non-Homebrew tools fetched directly from upstream:
  - **Daytona** — `~/main/` is created and `github.com/daytonaio/daytona`
    is cloned to `~/main/daytona`. The installer is not run.
  - **Claude Code** via the official installer (`https://claude.ai/install.sh`)
  - **OpenAI Codex** via `npm install -g @openai/codex`

## manual steps the script can't automate

- **Raycast Brew sync** — open Raycast → Store → install the "Brew" extension
  to manage Homebrew packages from Raycast.
- **Xcode (App Store)** — sign into the App Store first, then re-run
  `./install.sh` or run `mas install 497799835`.
- **Tailscale / 1Password / Spotify** — first launch each app to grant
  permissions and sign in.

## features

I'll post screenshots here of what each piece looks like and what the
highlights of the config are.
