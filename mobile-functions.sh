#!/usr/bin/env bash

set -e -o pipefail

# This file should be sourced from within a Bash-ish shell

install_homebrew_libraries() {
    update "Installing Homebrew dependencies..."
    # The mobile project requires these Homebrew packages
    brew install pkg-config cairo libpng jpeg giflib pango zopfli

    if ! brew tap | grep "getsentry/tools";
    then
        brew tap getsentry/tools
    fi

    brew install getsentry/tools/sentry-cli
}

# Ensure the Mobile Github repo is cloned.
clone_mobile_repo() {
    if [ ! -d "$REPOS_DIR/mobile" ]; then
        update "Cloning mobile repository..."
        kaclone_repo git@github.com:Khan/mobile "$REPOS_DIR/" --email="$gitmail"
    fi
}

install_react_native_dependencies() {
    update "Installing react-native dependencies..."
    (cd "$REPOS_DIR/mobile"; yarn)
}
