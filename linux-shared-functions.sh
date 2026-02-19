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
        success "mise already installed"
    fi

    # .profile.khan and .zprofile.khan handle mise activate for bash and zsh.
    # For fish, we need to add it to the fish config file directly.
    if [ "$(basename "$SHELL")" = "fish" ]; then
        local rcfile=~/.config/fish/config.fish
        local activate_line='mise activate fish --shims | source'
        if [ -f "$rcfile" ] && grep -qF 'mise activate' "$rcfile"; then
            success "mise activate already in $rcfile"
        else
            info "Adding mise activate to $rcfile\n"
            mkdir -p ~/.config/fish
            echo "$activate_line" >> "$rcfile"
        fi
    fi
}

uninstall_node_linux() {
    # Remove the nodesource apt repo and nodejs apt package if present,
    # since we now manage node via mise.
    if [ -f /etc/apt/sources.list.d/nodesource.list ]; then
        sudo rm -f /etc/apt/sources.list.d/nodesource.list
        sudo rm -f /etc/apt/preferences.d/nodejs
        sudo rm -f /usr/share/keyrings/nodesource.gpg
        sudo apt-get update -qq -y
    fi
    if dpkg -l nodejs 2>/dev/null | grep -q ^ii; then
        sudo apt-get purge -y nodejs
    fi

    # Remove nvm configuration lines from shell rc files.
    # These lines may have trailing comments, so we match from the start
    # of the line up to (and including) any trailing comment.
    for rcfile in ~/.bashrc ~/.bash_profile ~/.zshrc; do
        if [ -f "$rcfile" ]; then
            sed -i '/^export NVM_DIR="\$HOME\/\.nvm"/d' "$rcfile"
            sed -i '/^\[ -s "\$NVM_DIR\/nvm\.sh" \]/d' "$rcfile"
            sed -i '/^\[ -s "\$NVM_DIR\/bash_completion" \]/d' "$rcfile"
        fi
    done

    # Remove the nvm installation directory.
    if [ -d "$HOME/.nvm" ]; then
        rm -rf "$HOME/.nvm"
    fi
}
