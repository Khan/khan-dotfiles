#!/bin/bash

# Shared functions for mac setup scripts. Source this file after
# sourcing shared-functions.sh.

install_mise_mac() {
    # This deactivates Mise's automatic activation for Fish as we want to
    # use shims and not Homebrew's auto-activated default!
    # See: https://mise.jdx.dev/configuration.html#mise-fish-auto-activate-1
    if [ "$(basename "$SHELL")" = "fish" ]; then
        fish --command "set -U MISE_FISH_AUTO_ACTIVATE 0"
    fi

    if ! which mise >/dev/null 2>&1; then
        info "Installing mise\n"

        # Although many users don't use Fish, setting this here prevents
        # auto-activation during install _and_ doesn't bother other shells at
        # all.
        env MISE_FISH_AUTO_ACTIVATE=0 brew install mise
    else
        info "Updating mise\n"
        brew upgrade mise
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

uninstall_node_mac() {
    # --- Detect phase: determine what changes are needed ---
    local has_node_brew=false has_node16_brew=false has_node20_brew=false
    local has_nvm_brew=false has_fnm_brew=false has_nvm_dir=false
    local fish_has_fnm=false
    local -a rc_files_with_nvm=()
    local fish_config=~/.config/fish/config.fish

    brew ls --versions node >/dev/null 2>&1 && has_node_brew=true
    brew ls --versions node@16 >/dev/null 2>&1 && has_node16_brew=true
    brew ls --versions node@20 >/dev/null 2>&1 && has_node20_brew=true
    brew ls --versions nvm >/dev/null 2>&1 && has_nvm_brew=true
    brew ls --versions fnm >/dev/null 2>&1 && has_fnm_brew=true
    [ -d "$HOME/.nvm" ] && has_nvm_dir=true
    [ -f "$fish_config" ] && grep -qF 'fnm env --use-on-cd | source' "$fish_config" && fish_has_fnm=true

    for rcfile in ~/.bashrc ~/.bash_profile ~/.zshrc ~/.zprofile; do
        if [ -f "$rcfile" ] && grep -qE '^export NVM_DIR=|^\[ -s "\$NVM_DIR|^eval "\$\(fnm env' "$rcfile"; then
            rc_files_with_nvm+=("$rcfile")
        fi
    done

    # --- Build list of pending changes ---
    local -a changes=()
    $has_node_brew   && changes+=("Uninstall node (brew formula)")
    $has_node16_brew && changes+=("Uninstall node@16 (brew formula)")
    $has_node20_brew && changes+=("Uninstall node@20 (brew formula)")
    $has_nvm_brew && changes+=("Uninstall nvm (brew formula)")
    $has_fnm_brew && changes+=("Uninstall fnm (brew formula)")
    for rcfile in "${rc_files_with_nvm[@]}"; do
        changes+=("Remove nvm/fnm config lines from $rcfile")
    done
    $fish_has_fnm && changes+=("Remove fnm config line from $fish_config")
    $has_nvm_dir  && changes+=("Remove ~/.nvm directory")

    if [ ${#changes[@]} -eq 0 ]; then
        # Check if node or pnpm still exist on the current path
        if _non_mise_binary_on_path node || _non_mise_binary_on_path pnpm; then
            error "node and/or pnpm are still on the current PATH but no brew-managed installations were found."
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
    if $has_node_brew; then
        # We _try_ to uninstall node, but if it's depended on by other pacakges,
        # we can't. So in that case we fall back to simply unlinking it so it no
        # longer appears in the `bin` folder for Homebrew. Packages that depend
        # on it will continue to work after unlinking it.
        brew uninstall node || brew unlink node
    fi
    if $has_node16_brew; then
        brew uninstall node@16
    fi
    if $has_node20_brew; then
        brew uninstall node@20
    fi
    if $has_nvm_brew; then
        brew uninstall nvm
    fi
    if $has_fnm_brew; then
        brew uninstall fnm
    fi
    for rcfile in "${rc_files_with_nvm[@]}"; do
        sed -i '' '/^export NVM_DIR="\$HOME\/\.nvm"/d' "$rcfile"
        sed -i '' '/^\[ -s "\$NVM_DIR\/nvm\.sh" \]/d' "$rcfile"
        sed -i '' '/^\[ -s "\$NVM_DIR\/bash_completion" \]/d' "$rcfile"
        sed -i '' '/^eval "\$(fnm env --use-on-cd)"/d' "$rcfile"
    done
    if $fish_has_fnm; then
        sed -i '' '/^fnm env --use-on-cd | source/d' "$fish_config"
    fi
    if $has_nvm_dir; then
        rm -rf "$HOME/.nvm"
    fi

    # Check if node or pnpm still exist on the current path
    if _non_mise_binary_on_path node || _non_mise_binary_on_path pnpm; then
        error "node and/or pnpm are still on the current PATH. Uninstall may have failed."
        exit 1
    fi
}
