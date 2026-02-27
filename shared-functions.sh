bad_usage_get_yn_input=100

# for printing standard echoish messages
notice() {
    printf "         $1\n"
}

# for printing logging messages that *may* be replaced by
# a success/warn/error message
info() {
    printf "  [ \033[00;34m..\033[0m ] $1"
}

# for printing prompts that expect user input and will be
# replaced by a success/warn/error message
user() {
    printf "\r  [ \033[0;33m??\033[0m ] $1 "
}

# for replacing previous input prompts with success messages
success() {
    printf "\r\033[2K  [ \033[00;32mOK\033[0m ] $1\n"
}

# for replacing previous input prompts with warnings
warn() {
    printf "\r\033[2K  [\033[0;33mWARN\033[0m] $1\n"
}

# for replacing previous prompts with errors
error() {
    printf "\r\033[2K  [\033[0;31mFAIL\033[0m] $1\n"
}

# Replacement for clone_repo() function using ka-clone tool for local config
# If run on an existing repository, will *update* and do --repair
# Arguments:
#   $1: url of the repository to clone
#   $2: directory to put repo
#   $3 onwards: any arguments to pass along to kaclone
kaclone_repo() {
    local src="$1"
    shift
    local dst="$1"
    shift

    (
        mkdir -p "$dst"
        cd "$dst"
        dirname=$(basename "$src")
        if [ ! -d "$dirname" ]; then
            "$KACLONE_BIN" "$src" "$dirname" "$@"
            cd "$dirname"
            git submodule update --init --recursive
        else
            cd "$dirname"
            # This 'ka-clone --repair' installs any new settings
            "$KACLONE_BIN" --repair --quiet "$@"
        fi
    )
}

# Print update in blue.
# $1: update message
update() {
    printf "\e[0;34m$1\e[0m\n"
}

# Print error in red and exit.
# $1: error message
# TODO(hannah): Factor out message-printing functions from mac-setup.sh.
err_and_exit() {
    printf "\e[0;31m$1\e[0m\n"
    exit 1
}

# Get yes or no input from the user. Return default value if the user does no
# enter a valid value (y, yes, n, or no with any captialization).
# $1: prompt
# $2: default value
get_yn_input() {
    if [ "$2" = "y" ]; then
        prompt="${1} [Y/n]: "
    elif [ "$2" = "n" ]; then
        prompt="${1} [y/N]: "
    else
        echo "Error: bad default value given to get_yn_input()" >&2
        exit $bad_usage_get_yn_input
    fi

    read -r -p "$prompt" input
    case "$input" in
        [yY][eE][sS] | [yY])
            echo "y"
            ;;
        [nN][oO] | [nN])
            echo "n"
            ;;
        *)
            echo $2
            ;;
    esac
}

# Exit with an error if the script is not being run on a Mac. (iOS development
# can only be done on Macs.)
ensure_mac_os() {
    if [ "`uname -s`" != "Darwin" ]; then
        err_and_exit "This script can only be run on Mac OS."
    fi
}

# $1: the package to install
brew_install() {
    if ! command -v brew >/dev/null 2>&1; then
        echo "Homebrew is not installed."
        exit 1
    fi
    if ! brew ls "$@" >/dev/null 2>&1; then
        echo "$@ is not installed, installing $@"
        brew install "$@" || echo "Failed to install $@, perhaps it is already installed."
    else
        echo "$@ already installed"
    fi
}

# $1: the text to add
add_to_dotfile() {
    grep -F -q "$1" "$HOME/.profile-generated.khan" || echo "$1" >> "$HOME/.profile-generated.khan" || exit 1
}

# Mac-specific function to install Java JDK
install_mac_java() {
    # It's surprisingly difficult to tell what java versions are
    # already installed -- there are different java providers -- so we
    # just always try to install the one we want.  For more info, see
    #   https://github.com/Khan/khan-dotfiles/pull/61/files#r964917242
    echo "Installing openjdk 21..."

    brew_install openjdk@21

    # Symlink openjdk for the system Java wrappers.  This supports
    # both M1 and x86_64 macs.
    if [ -d /opt/homebrew/opt/openjdk@21 ]; then
        brew_loc=/opt/homebrew/opt/openjdk@21
    elif [ -d /usr/local/Cellar/openjdk@21 ]; then
        # Different versions are installed here, we'll take the latest.
        brew_loc=$(ls -td /usr/local/Cellar/openjdk@21/21.* | head -n1)
    else
        error "Could not find the location of java 21, not installing it"
    fi
    sudo ln -sfn "$brew_loc"/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk-21.jdk

    # Ensure JAVA_HOME is set in ~/.profile.khan
    # TODO (jwiesebron): Update other parts of dotfiles to use this convention
    add_to_dotfile 'export JAVA_HOME="$(/usr/libexec/java_home)"'
    add_to_dotfile 'export PATH="'"$brew_loc"/bin':$PATH"'
}

DESIRED_GO_MAJOR_VERISON=1
DESIRED_GO_MINOR_VERISON=25
DESIRED_GO_VERSION="$DESIRED_GO_MAJOR_VERISON.$DESIRED_GO_MINOR_VERISON"

# Evaluates to truthy if go is installed and
# >=$DESIRED_GO_VERSION.  Evaluates to falsey else.
has_recent_go() {
    which go >/dev/null || return 1
    go_version=`go version`
    go_major_version=`expr "$go_version" : '.*go\([0-9]*\)'`
    go_minor_version=`expr "$go_version" : '.*go[0-9]*\.\([0-9]*\)'`
    [ "$go_major_version" -gt "$DESIRED_GO_MAJOR_VERISON" \
        -o "$go_minor_version" -ge "$DESIRED_GO_MINOR_VERISON" ]
}

# pip-install something globally.  Recent pythons don't let you do
# that (https://peps.python.org/pep-0668/), but we do it anyway.
# $@: the arguments to `pip install`.
pip3_install() {
    # If brew is installed, use its pip3 instead of the system pip3.
    if which brew >/dev/null 2>&1 && [ -e "$(brew --prefix)/bin/pip3" ]; then
        PIP3=$(brew --prefix)/bin/pip3
    else
        PIP3=pip3
    fi
    "$PIP3" install --break-system-packages "$@" >/dev/null 2>&1 \
        || "$PIP3" install "$@"
}

maybe_generate_ssh_keys() {
  # Create a public key if need be.
  info "Checking for ssh keys"
  mkdir -p ~/.ssh
  if [ -s ~/.ssh/id_rsa ] || [ -s ~/.ssh/id_ecdsa ]; then
    # TODO(ebrown): Verify these key(s) have passphrases on them
    success "Found existing ssh keys"
  else
    echo
    echo "Creating your ssh key pair for this machine"
    echo "Please DO NOT use an empty passphrase"
    APPLE_SSH_ADD_BEHAVIOR=macos ssh-keygen -t ecdsa -f ~/.ssh/id_ecdsa
    # Old: ssh-keygen -q -N "" -t rsa -f ~/.ssh/id_rsa
    success "Generated an rsa ssh key at ~/.ssh/id_ecdsa"
    echo "Your ssh public key is:"
    cat ~/.ssh/id_ecdsa.pub
    echo "Please manually copy this public key to https://github.com/settings/keys."
    read -p "Press enter when you've done this..."
  fi

  # Add the keys to the keychain if needed
  if [ -z "`ssh-add -l 2>/dev/null`" ]; then
      ssh-add >/dev/null || {
          # ssh-agent isn't running, let's fix that
          eval $(ssh-agent -s)
          ssh-add
      }
      success "Added key to your keychain"
  fi

  return 0
}

# If we exit unexpectedly, log this warning.
# Scripts should call "trap exit_warning EXIT" near the top to enable,
# then "trap - EXIT" just before exiting on success.
exit_warning() {
    echo "***           FATAL ERROR: khan-dotfiles crashed!             ***"
    echo "***                                                           ***"
    echo "***    Please check the dev setup docs for common errors, or     ***"
    echo "***  send the output above to @dev-support in the #1s-and-0s     ***"
    echo "***  channel. Once you've resolved the problem, re-run 'make'.   ***"
    echo "***                                                           ***"
    echo "***        Khan dev tools WILL NOT WORK until you do!         ***"
    echo "***                                                           ***"
}

setup_mise() {
    # Check for and remove 'mise activate ...' commands from shell config files.
    # These conflict with the shims-based approach we use.
    local _config_files=(
        "$HOME/.profile"
        "$HOME/.bash_profile"
        "$HOME/.bashrc"
        "$HOME/.zprofile"
        "$HOME/.zshrc"
        "$HOME/.config/fish/config.fish"
    )
    local _answer _tmp _config_file _removed_activate=false
    for _config_file in "${_config_files[@]}"; do
        if [ -f "$_config_file" ] && grep -q 'mise activate' "$_config_file"; then
            notice "Found 'mise activate ...' in $_config_file."
            notice "This is not needed when using mise shims and should be removed."
            _answer=$(get_yn_input "Remove it from $_config_file?" "y")
            if [ "$_answer" = "y" ]; then
                _tmp=$(mktemp)
                grep -v 'mise activate' "$_config_file" > "$_tmp" && mv "$_tmp" "$_config_file"
                success "Removed mise activate command from $_config_file"
                _removed_activate=true
            else
                warn "Skipped removing from $_config_file"
            fi
        fi
    done

    # Symlink the mise global config.
    mkdir -p ~/.config/mise

    local _mise_config="$HOME/.config/mise/config.toml"
    if [ -f "$_mise_config" ] && [ ! -L "$_mise_config" ]; then
        notice "Found existing $_mise_config that is not a symlink."
        notice "Moving it to $_mise_config.bak before creating symlink."
        mv "$_mise_config" "$_mise_config.bak"
        success "Moved $_mise_config to $_mise_config.bak"
    fi

    ln -sfn "$DEVTOOLS_DIR"/khan-dotfiles/mise_config.toml "$_mise_config"

    # .profile.khan and .zprofile.khan handle mise activate for bash and zsh.
    # Since we don't manage equivalent files for Fish in this repo, we need to
    # add the activation to the appropriate Fish config.
    if [[ ! -f ~/.config/fish/conf.d/mise.fish ]] || ! grep "mise activate" ~/.config/fish/conf.d/mise.fish; then
        echo "mise activate --shims fish | source" >> ~/.config/fish/conf.d/mise.fish
    fi

    # Uninstall any existing node installations which may not have been configured
    # to with `postinstall = "corepack enable"`.
    rm -rf "$HOME/.local/share/mise/installs/node"
    rm -rf "$HOME/.local/share/mise/installs/pnpm"

    # Installs tools defined in ~/.config/mise/config.toml globally.
    mise install

    # For the Fish shell we can't do the extra verification as _this_ script is
    # not running in Fish. So we simply exit and leave it to the user to verify.
    if [ "$(basename "$SHELL")" = "fish" ]; then
        echo
        success "Mise installed and activated for the Fish shell."
        notice "Please open a new shell session for changes to take effect (you can verify everything is correct by running 'which node' and 'which pnpm' in a new Fish shell. They should both point to the mise shims folder."
        return
    fi

    local mise_shims="$HOME/.local/share/mise/shims"

    if [ "$(which node)" != "$mise_shims/node" ]; then
        error "node is not resolving to the mise shim (got $(which node))\n"
        return 1
    fi
    if [ "$(which pnpm)" != "$mise_shims/pnpm" ]; then
        error "pnpm is not resolving to the mise shim (got $(which pnpm))\n"
        return 1
    fi

    node_version=$(node -v)
    pnpm_version=$(pnpm -v)

    success "Node.js $node_version and pnpm $pnpm_version installed successfully\n"

    if $_removed_activate; then
        notice "Shell config files were modified. Please open a new shell for the changes to take effect."
    fi
}
