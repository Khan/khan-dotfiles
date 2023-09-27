#!/usr/bin/env bash

set -e -o pipefail

# This file should be sourced from within a Bash-ish shell

# Ensure the Mobile Github repo is cloned.
clone_mobile_repo() {
    if [ ! -d "$REPOS_DIR/mobile" ]; then
        update "Cloning mobile repository..."
        kaclone_repo git@github.com:Khan/mobile "$REPOS_DIR/" --email="$gitmail"
    fi
}
