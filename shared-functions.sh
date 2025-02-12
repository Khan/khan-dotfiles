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
    echo "Installing openjdk 11..."

    brew_install openjdk@11

    # Symlink openjdk for the system Java wrappers.  This supports
    # both M1 and x86_64 macs.
    if [ -d /opt/homebrew/opt/openjdk@11 ]; then
        brew_loc=/opt/homebrew/opt/openjdk@11
    elif [ -d /usr/local/Cellar/openjdk@11 ]; then
        # Different versions are installed here, we'll take the latest.
        brew_loc=$(ls -td /usr/local/Cellar/openjdk@11/11.* | head -n1)
    else
        error "Could not find the location of java 11, not installing it"
    fi
    sudo ln -sfn "$brew_loc"/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk-11.jdk

    # Ensure JAVA_HOME is set in ~/.profile.khan
    # TODO (jwiesebron): Update other parts of dotfiles to use this convention
    add_to_dotfile 'export JAVA_HOME="$(/usr/libexec/java_home)"'
    add_to_dotfile 'export PATH="'"$brew_loc"/bin':$PATH"'
}

DESIRED_GO_MAJOR_VERISON=1
DESIRED_GO_MINOR_VERISON=22
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
    echo "***        FATAL ERROR: khan-dotfiles crashed!         ***"
    echo "***     Please check the dev setup docs for common     ***"
    echo "***  errors, or send the output above to @dev-support. ***"
    echo "***  Once you've resolved the problem, re-run 'make'.  ***"
    echo "***     Khan dev tools WILL NOT WORK until you do!     ***"
}
