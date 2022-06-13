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

# Xcodes is a tool to manage which version of Xcode is installed
install_xcodes() {
    if ! which xcodes; then
        update "Installing xcodes utility..."

        XCODES_WORKING_DIR=$(mktemp -d)
        # Make sure we cleanup on exit
        trap 'rm -rf -- "$XCODES_WORKING_DIR"' EXIT

        # We _don't_ use Homebrew here. The Homebrew install of `xcodes`
        # requires a functioning Xcode install, which we most likely don't if
        # this is a clean OS install. So we just download the latest binary
        # release from Github.
        curl -sL https://api.github.com/repos/RobotsAndPencils/xcodes/releases/latest | \
            jq -r '.assets[].browser_download_url' | \
            grep xcodes.zip | \
            wget -nv -O "$XCODES_WORKING_DIR/xcodes.zip" -i -

        unzip "$XCODES_WORKING_DIR/xcodes.zip" -d "$XCODES_WORKING_DIR/"
        sudo install -C -v "$XCODES_WORKING_DIR/xcodes" /usr/local/bin/
    fi
}

# Ensure Carthage is installed. Carthage is used to manage some dependencies and
# is required to compile the app.
install_carthage() {
    if ! which carthage; then
        update "Installing Carthage..."
        brew install carthage
    fi
}

install_fastlane() {
    update "Installing Fastlane and Cocoapods..."
    (cd "$REPOS_DIR/mobile/ios"; bundle install)
}

ensure_mac_os # Function defined in shared-functions.sh.
# TODO(hannah): Ensure setup.sh has already been run.
clone_mobile_repo
install_xcodes
install_carthage
install_fastlane
install_homebrew_libraries
install_react_native_dependencies

update "Done! Complete setup instructions at \
https://khanacademy.atlassian.net/wiki/spaces/MG/pages/49284528/iOS+Environment+Setup"
