#!/usr/bin/env sh

# Bail on any errors
set -e

# Install in $HOME by default, but can set an alternate destination via $1.
ROOT=${1-$HOME}
mkdir -p "$ROOT"

# the directory all repositories will be cloned to
REPOS_DIR="$ROOT/khan"

# derived path location constants
DEVTOOLS_DIR="$REPOS_DIR/devtools"
KACLONE_BIN="$DEVTOOLS_DIR/ka-clone/bin/ka-clone"

# Load shared setup functions.
. "$DEVTOOLS_DIR"/khan-dotfiles/shared-functions.sh

# We want to run this only with the brew version of python, NOT OSX's python3
install_keeper $(brew --prefix)/bin/python3
echo

create_default_keeper_config

echo
echo "To test keeper is working, run: mykeeper list"
echo "(KA alias mykeeper='keeper --config \$HOME/.keeper-config.json')"
