#!/bin/bash

# We need elevated permissions for a small subset of setup tasks. Isolate these
# here so that we can test/qa scripts without babysitting them.

# Bail on any errors
set -e

SCRIPT=$(basename $0)

usage() {
    cat << EOF
usage: $SCRIPT [options]
  --root <dir> Use specified directory as root (instead of HOME).
EOF
}

# Install in $HOME by default, but can set an alternate destination via $1.
ROOT="${ROOT:-$HOME}"

# Process command line arguments
while [[ "$1" != "" ]]; do
    case $1 in
        -r | --root)
            shift
            ROOT=$1
            ;;
        -h | --help)
            usage
            exit 0
            ;;
        *)
            usage
            exit 1
            ;;
    esac
    shift
done

# The directory to which all repositories will be cloned.
REPOS_DIR="$ROOT/khan"

# Derived path location constants
DEVTOOLS_DIR="$REPOS_DIR/devtools"

# Load shared setup functions.
. "$DEVTOOLS_DIR"/khan-dotfiles/shared-functions.sh

install_protoc() {
    # If the user has a homebrew version of protobuf installed, uninstall it so
    # we can manually install our own version in /usr/local.
    if brew list --formula | grep -q '^protobuf$'; then
        info "Uninstalling homebrew version of protobuf\n"
        brew uninstall protobuf
    fi

    brew install -q wget

    # The mac and linux installation process is the same from here on out aside
    # from the platform-dependent zip archive.
    install_protoc_common https://github.com/protocolbuffers/protobuf/releases/download/v3.4.0/protoc-3.4.0-osx-x86_64.zip
}

# TODO(ericbrown): Detect pre-requisites (i.e. brew, etc.)

# Run sudo once at the beginning to get the necessary permissions.
echo "This setup script needs your password to install things as root."
sudo sh -c 'echo Thanks'

if [[ $(uname -m) = "arm64" ]]; then
    # install rosetta on M1 (required for openjdk, python2 and other things)
    # This will work here, but it requires input and I'd rather just have it in docs
    #sudo softwareupdate --install-rosetta

    # Add homebrew to path on M1 macs
    export PATH=/opt/homebrew/bin:$PATH
fi

# Add github to known_hosts (one less prompt when QAing script)
mkdir -p ~/.ssh
grep -q github.com ~/.ssh/known_hosts 2>/dev/null || \
    echo "github.com ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAq2A7hRGmdnm9tUDbO9IDSwBK6TbQa+PXYPCPy6rbTrTtw7PHkccKrpp0yVhp5HdEIcKr6pLlVDBfOLX9QUsyCOV0wzfjIJNlGEYsdlLJizHhbn2mUjvSAHQqZETYP81eFzLQNnPHt4EVVUh7VfDESU84KezmD5QlWpXLmvU31/yMf+Se8xhHTvKSCZIFImWwoG6mbUoWf9nzpIoaSjB+weqqUUmpaaasXVal72J+UX2B+2RPW3RcT0eOzQgqlJL3RKrTJvdsjE3JEAvGq3lGHSZXy28G3skua2SmVi/w4yCE6gbODqnTWlg7+wC604ydGXA8VJiS5ap43JXiUFFAaQ==" \
        >> ~/.ssh/known_hosts

"$DEVTOOLS_DIR"/khan-dotfiles/bin/install-mac-homebrew.py

# Other brew related installers that require sudo

"$DEVTOOLS_DIR"/khan-dotfiles/bin/install-mac-mkcert.py

"$DEVTOOLS_DIR"/khan-dotfiles/bin/edit-system-config.sh

# It used to be we needed to install xcode-tools, now homebrew does this for us
#"$DEVTOOLS_DIR"/khan-dotfiles/bin/install-mac-gcc.sh

install_protoc

# We use java for our google cloud dataflow jobs that live in webapp
# (as well as in khan-linter for linting those jobs)
install_mac_java
