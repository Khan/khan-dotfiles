#!/bin/bash
set -e -o pipefail

# This script sets up developers to work on the iOS app and/or test using an
# iOS emulator. This script can only be run on Mac OSs. (iOS development can
# only be done on Macs.)

# Install in $HOME by default, or an alternate destination specified via $1.
ROOT=${1-$HOME}
mkdir -p "$ROOT"

# The directory to which all repositories will be cloned.
REPOS_DIR="$ROOT/khan"

# Derived path location constants
# TODO(abdul): define these in shared-functions.sh instead (it's also defined mac-android-setup).
DEVTOOLS_DIR="$REPOS_DIR/devtools"
KACLONE_BIN="$DEVTOOLS_DIR/ka-clone/bin/ka-clone"

# Load shared setup functions.
. "$REPOS_DIR/devtools/khan-dotfiles/shared-functions.sh"
. "$REPOS_DIR/devtools/khan-dotfiles/mobile-functions.sh"

# Ensure Carthage is installed. Carthage is used to manage some dependencies and
# is required to compile the app.
install_carthage() {
    if ! which carthage; then
        update "Installing Carthage..."
        brew install carthage
    fi
}

install_fastlane() {
    if ! which fastlane; then
        update "Installing fastlane..."
        sudo gem install fastlane --no-document --verbose

        # Make sure the gem install dir is in our PATH
        if ! command -v fastlane &>/dev/null; then
            echo "export PATH=$(gem environment gemdir)/bin:$PATH" >>~/.bash_profile
        fi
    fi
}

ensure_mac_os # Function defined in shared-functions.sh.
# TODO(hannah): Ensure setup.sh has already been run.
clone_mobile_repo
install_carthage
install_fastlane
install_homebrew_libraries
install_react_native_dependencies

update "Done! Complete setup instructions at \
https://docs.google.com/document/d/15FxEYI7l_p4mMv3SYFSIM6cxiOz6I4pxEvzDLFle-eE"
