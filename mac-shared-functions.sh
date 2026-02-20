#!/bin/bash

# Shared functions for mac setup scripts. Source this file after
# sourcing shared-functions.sh.

install_mise_mac() {
    if ! which mise >/dev/null 2>&1; then
        info "Installing mise\n"
        brew install mise
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

uninstall_node_mac() {
    # Uninstall node@16 if it was installed via brew
    if brew ls --versions node@16 >/dev/null ; then
        brew uninstall node@16
    fi

    # Uninstall node@20 if it was installed via brew
    if brew ls --versions node@20 >/dev/null ; then
        brew uninstall node@20
    fi

    # Uninstall nvm if it was installed via brew.
    if brew ls --versions nvm >/dev/null 2>&1; then
        brew uninstall nvm
    fi

    # Uninstall fnm if it was installed via brew.
    if brew ls --versions fnm >/dev/null 2>&1; then
        brew uninstall fnm
    fi

    # Remove nvm and fnm configuration lines from shell rc files.
    # These lines may have trailing comments, so we match from the start
    # of the line up to (and including) any trailing comment.
    for rcfile in ~/.bashrc ~/.bash_profile ~/.zshrc; do
        if [ -f "$rcfile" ]; then
            sed -i '' '/^export NVM_DIR="\$HOME\/\.nvm"/d' "$rcfile"
            sed -i '' '/^\[ -s "\$NVM_DIR\/nvm\.sh" \]/d' "$rcfile"
            sed -i '' '/^\[ -s "\$NVM_DIR\/bash_completion" \]/d' "$rcfile"
            sed -i '' '/^eval "\$(fnm env --use-on-cd)"/d' "$rcfile"
        fi
    done

    # Remove fnm configuration line from fish config if present.
    local fish_config=~/.config/fish/config.fish
    if [ -f "$fish_config" ]; then
        sed -i '' '/^fnm env --use-on-cd | source/d' "$fish_config"
    fi

    # Remove the nvm installation directory.
    if [ -d "$HOME/.nvm" ]; then
        rm -rf "$HOME/.nvm"
    fi
}
