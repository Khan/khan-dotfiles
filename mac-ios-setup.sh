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

ensure_mac_os # Function defined in shared-functions.sh.
clone_mobile_repo
install_xcodes

# Most of the mobile development setup is delegated to a script in the mobile
# repo. This keeps the code close to the dependencies and tools that use it and
# makes it easier to maintain.
if [ ! -f "$REPOS_DIR/mobile/setup.sh" ]; then
    err_and_exit "ERROR: Could not find mobile repo's setup.sh script at: $REPOS_DIR/mobile/setup.sh\n" \
                 "Please ask for help in #mobile on Slack."
    exit 1
fi
"$REPOS_DIR/mobile/setup.sh"

update "Done! Complete setup instructions at \
https://khanacademy.atlassian.net/wiki/spaces/MG/pages/49284528/iOS+Environment+Setup"
