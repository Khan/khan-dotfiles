#!/bin/bash

# This script can be run independently to set up Node.js via mise.
# It also cleans up old node apt packages and nvm installations.

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

# Use `mise` to install `node`, `pnpm`, and other tools and set up shims.
setup_mise
