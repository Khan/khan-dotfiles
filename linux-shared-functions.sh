#!/bin/bash

# Shared functions for linux setup scripts. Source this file after
# sourcing shared-functions.sh.

install_mise_linux() {
    if ! which mise >/dev/null 2>&1; then
        info "Installing mise\n"
        sudo apt update -y && sudo apt install -y curl
        sudo install -dm 755 /etc/apt/keyrings
        curl -fSs https://mise.jdx.dev/gpg-key.pub | sudo tee /etc/apt/keyrings/mise-archive-keyring.asc 1> /dev/null
        echo "deb [signed-by=/etc/apt/keyrings/mise-archive-keyring.asc] https://mise.jdx.dev/deb stable main" | sudo tee /etc/apt/sources.list.d/mise.list
        sudo apt update -y
        sudo apt install -y mise
    else
        info "Updating mise\n"
        sudo apt update -y && sudo apt install -y mise
        success "mise updated to $(mise --version)"
    fi
}

# Returns true if a binary is on PATH and not provided by mise shims.
_non_mise_binary_on_path() {
    local bin="$1"
    local bin_path
    bin_path="$(which "$bin" 2>/dev/null)" || return 1
    [[ "$bin_path" == "$HOME/.local/share/mise/shims/"* ]] && return 1
    return 0
}

uninstall_node_linux() {
    # --- Detect phase: determine what changes are needed ---
    local has_nodesource=false has_nodejs_pkg=false has_nvm_dir=false
    local -a rc_files_with_nvm=()

    [ -f /etc/apt/sources.list.d/nodesource.list ] && has_nodesource=true
    dpkg -l nodejs 2>/dev/null | grep -q ^ii && has_nodejs_pkg=true
    [ -d "$HOME/.nvm" ] && has_nvm_dir=true

    for rcfile in ~/.bashrc ~/.bash_profile ~/.zshrc; do
        if [ -f "$rcfile" ] && grep -qE '^export NVM_DIR=|^\[ -s "\$NVM_DIR' "$rcfile"; then
            rc_files_with_nvm+=("$rcfile")
        fi
    done

    # --- Build list of pending changes ---
    local -a changes=()
    $has_nodesource  && changes+=("Remove nodesource apt repository files")
    $has_nodejs_pkg  && changes+=("Purge nodejs apt package")
    for rcfile in "${rc_files_with_nvm[@]}"; do
        changes+=("Remove nvm config lines from $rcfile")
    done
    $has_nvm_dir && changes+=("Remove ~/.nvm directory")

    if [ ${#changes[@]} -eq 0 ]; then
        # Check if node or pnpm still exist on the current path
        if _non_mise_binary_on_path node || _non_mise_binary_on_path pnpm; then
            error "node and/or pnpm are still on the current PATH but no managed installations were found."
            exit 1
        fi
        return
    fi

    # --- Prompt phase: show list and ask once ---
    notice "The following changes will be made to remove old Node.js installations:"
    for change in "${changes[@]}"; do
        notice "  - $change"
    done
    echo
    if [ "$(get_yn_input "Proceed with the above changes?" y)" != "y" ]; then
        return
    fi

    # --- Execute phase ---
    if $has_nodesource; then
        sudo rm -f /etc/apt/sources.list.d/nodesource.list
        sudo rm -f /etc/apt/preferences.d/nodejs
        sudo rm -f /usr/share/keyrings/nodesource.gpg
        sudo apt-get update -qq -y
    fi
    if $has_nodejs_pkg; then
        sudo apt-get purge -y nodejs
    fi
    for rcfile in "${rc_files_with_nvm[@]}"; do
        sed -i '/^export NVM_DIR="\$HOME\/\.nvm"/d' "$rcfile"
        sed -i '/^\[ -s "\$NVM_DIR\/nvm\.sh" \]/d' "$rcfile"
        sed -i '/^\[ -s "\$NVM_DIR\/bash_completion" \]/d' "$rcfile"
    done
    if $has_nvm_dir; then
        rm -rf "$HOME/.nvm"
    fi

    # Check if node or pnpm still exist on the current path
    if _non_mise_binary_on_path node || _non_mise_binary_on_path pnpm; then
        error "node and/or pnpm are still on the current PATH. Uninstall may have failed."
        exit 1
    fi
}
