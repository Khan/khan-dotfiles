#!/bin/bash

# Bail on any errors
set -e

# Install in $HOME by default, but can set an alternate destination via $1.
ROOT=${1-$HOME}
mkdir -p "$ROOT"

# the directory all repositories will be cloned to
REPOS_DIR="$ROOT/khan"

# derived path location constants
DEVTOOLS_DIR="$REPOS_DIR/devtools"

# Load shared setup functions.
. "$DEVTOOLS_DIR"/khan-dotfiles/shared-functions.sh

trap exit_warning EXIT   # from shared-functions.sh

# Set up .arcrc: we can't update this through the standard process
# because it has secrets embedded in it, but our arcanist fork will
# do the updates for us.
setup_arc() {
    if [ ! -f "$HOME/.arcrc" ]; then
        echo "Time to set up arc to talk to Phabricator!"
        echo "First, go make sure you're logged in and your"
        echo "account is set up (use Google OAuth to create"
        echo "an account, if you haven't).  Click here to start:"
        echo "  -->  https://phabricator.khanacademy.org  <--"
        echo -n "Press enter when you're logged in: "
        read
        # This is added to PATh by dotfiles, but those may not be sourced yet.
        PATH="$DEVTOOLS_DIR/arcanist/khan-bin:$PATH"
        arc install-certificate -- https://phabricator.khanacademy.org
    fi
}

setup_arc           # pre-req: clone_repos

trap - EXIT
