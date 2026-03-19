# dalin-dot-files
these are my dot files that I am currently using on my personal and work Macbooks. i have chose to run Omakub by DHH on my personal desktop because it meets my needs and makes good use of the hardware. this is for if i want to change my desktop setup in the future and also for every single computer i will hereafter ever set up.

## installation
Clone this repo, then run `chmod +x setup.sh && ./setup.sh` from the repo directory. The script is idempotent, so it will skip anything already installed, and it handles everything from Homebrew and CLI tools to symlinking dotfiles and configuring macOS system settings. It will prompt you once to install Xcode Command Line Tools if they're not present and will ask for your password when setting zsh as the default shell. After it finishes, restart your terminal and follow the printed next steps (installing tmux plugins, granting app permissions, etc.).

## features
i will post screenshots here of what each piece looks like and what the highlights of the config are.
