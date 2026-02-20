#!/bin/bash

# This script can use to install `mise` on Linux independently of the rest
# of the khan-dotfiles setup.
#
# It also cleans up old installations of `node` to avoid conflicts with the
# `mise` installation.

# Bail on any errors
set -e

# Load shared setup functions.
DEVTOOLS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
. "$DEVTOOLS_DIR"/khan-dotfiles/shared-functions.sh
. "$DEVTOOLS_DIR"/khan-dotfiles/linux-shared-functions.sh

# Uninstall other Node.js installations to avoid conflicts with the
# mise installation.
uninstall_node_linux

# `mise` is a tool used for managing tools.
install_mise_linux

# finish setting up `mise` and install all of the tools it manages
# such as `node`, `pnpm`, etc.
setup_mise
