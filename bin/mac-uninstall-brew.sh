#!/usr/bin/env sh

# This script is needed on rare occasions where devops wants to test khan-dotfiles
# or where a DEV's environment needs a more complete reset.

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd -P )/.."
. "$SCRIPT_DIR/shared-functions.sh"

# WARNING: This could delete your current shell which can *appear* to brick
# your mac. Running chsh -s /bin/bash first might be adivsable if using bash.
# (I've not found an easy way to detect this.)
echo "If your shell is set to /usr/local/bin/bash, this script could delete it."
if [ "$(get_yn_input "Would you like to continue?" "n")" != "y" ]; then
    exit 0
fi

set -e

# TODO(ebrown): Remove postgres? Remove redis?

IS_MAC_ARM=$(test "$(uname -m)" = "arm64" && echo arm64 || echo "")

echo "This script needs your password to remove things as root."
sudo sh -c 'echo Thanks'

if [[ -n "${IS_MAC_ARM}" ]]; then
    if [[ -e "/opt/homebrew/bin/brew" ]]; then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"
        sudo rm -rf /opt/homebrew
        sudo rm -rf /opt/homebrew/var/postgresql*
    fi
fi

if [[ -e "/usr/local/bin/brew" ]]; then
    sudo arch -x86_64 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"
    sudo rm -rf /usr/local/Caskroom
    sudo rm -rf /usr/local/Homebrew
    sudo rm -rf /usr/local/var/homebrew
    # The following deletes data and pesky pid file (that frequently causes issues)
    sudo rm -rf /usr/local/var/postgresql*
fi

echo "Removing the (obsolete) khan python2 virtualenv..."
rm -rf ~/.virtualenv/khan27

echo "Removing other things that may upgrade if user reinstalls..."
sudo rm -rf ~/Library/Caches/pip
sudo rm -rf ~/.npm
sudo rm -rf ~/.yarnrc
pnpm store prune
sudo rm -rf ~/go
echo "Done"
