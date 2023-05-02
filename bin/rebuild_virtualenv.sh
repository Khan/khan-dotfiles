#!/bin/bash

# Quick way to rebuild the python virtualenv.  This is a common way to end up
# with a broken dev setup; and we don't need to re-run all of khan-dotfiles to
# fix it.  This script is best-effort: if something goes wrong we'll just tell
# the user to fall back to khan-dotfiles.

# Bail on any errors
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd -P )/.."
KHAN_DIR="$SCRIPT_DIR/../.."

venv_exit_warning() {
    echo "***   FATAL ERROR: unable to rebuild virtualenv!   ***"
    echo "***    Try a full run of khan-dotfiles instead,    ***"
    echo "***            or contact @dev-support.            ***"
}

trap venv_exit_warning EXIT

# Load shared setup functions.
. "$SCRIPT_DIR"/shared-functions.sh

# We're about to do an rm -rf; make sure it looks like the right directory.
# For most (all) users, $VIRTUAL_ENV should be $HOME/.virtualenv/khan27 but
# we'll be a little flexible.
if [[ "$VIRTUAL_ENV" != */.virtualenv/khan27 ]]; then
    echo "VIRTUAL_ENV=$VIRTUAL_ENV doesn't look like a " \
        "Khan virtualenv, not removing."
    exit 1
fi

echo "Ensure proper version of python2 virutalenv is installed"
install_python2_virtualenv

echo "Cleaning out old virtualenv"
rm -rf "$VIRTUAL_ENV"
# We probably just removed `which python`, force the shell to find a new one.
hash -r
echo "Creating and activating new virtualenv"
create_and_activate_virtualenv "$VIRTUAL_ENV"   # from shared-functions.sh
echo "Reinstalling webapp deps"
( cd "$KHAN_DIR/webapp" && make python_deps )
echo "Success!  You may need to restart any open terminals or running dev-servers."

trap - EXIT
