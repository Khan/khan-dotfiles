#!/usr/bin/env sh

# This script is needed on rare occasions where devops wants to test khan-dotfiles
# or where a DEV's environment needs a more complete reset.

echo "This script needs your password to remove things as root."
sudo sh -c 'echo Thanks'

/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"
sudo rm -rf /opt/homebrew

sudo arch -x86_64 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"
sudo rm -rf /usr/local/Homebrew
rm -rf ~/.virtualenv/khan27

# Remove other things that may upgrade if user reinstalls
sudo rm -rf ~/Library/Caches/pip
sudo rm -rf ~/.npm
sudo rm -rf ~/.yarnrc
sudo rm -rf ~/go
