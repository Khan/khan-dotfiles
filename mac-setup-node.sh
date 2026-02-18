#!/bin/bash

# This script can be run independently to set up Node.js via mise.
# It also cleans up old node homebrew formulas and nvm installations.

# Bail on any errors
set -e

# Load shared setup functions.
DEVTOOLS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
. "$DEVTOOLS_DIR"/khan-dotfiles/shared-functions.sh
. "$DEVTOOLS_DIR"/khan-dotfiles/mac-shared-functions.sh

install_mise

# Uninstall other Node.js installations to avoid conflicts with the
# mise installation.
uninstall_node
uninstall_nvm

# Creates or updates ~/.config/mise/config.toml
mise use -g node@20.20.0

# Verify the Node.js version:
node -v # Should print "v20.20.0".

# Download and install pnpm:
corepack enable pnpm

# This ensures that shims for `pnpm` are created
mise reshim
