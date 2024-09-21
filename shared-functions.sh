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

install_protoc_common() {
    # Platform independent installation of protoc.
    # usage: install_protoc_common <zip_url>

    # The URL of the protoc zip file is passed as the first argument to this
    # function. This file is platform dependent.
    zip_url=$1

    # We use protocol buffers in webapp's event log stream infrastructure. This
    # installs the protocol buffer compiler (which generates go & java code
    # from the protocol buffer definitions), as well as a go-based compiler
    # plugin that allows us to generate bigquery schemas as well.

    if ! which protoc >/dev/null || ! protoc --version | grep -q 3.4.0; then
        echo "Installing protoc"
        mkdir -p /tmp/protoc
        wget -O /tmp/protoc/protoc-3.4.0.zip "$zip_url"
        # Change directories within a subshell so that we don't have to worry
        # about changing back to the current directory when done.
        (
            cd /tmp/protoc
            # This puts the compiler itself into ./bin/protoc and several
            # definitions into ./include/google/protobuf we move them both
            # into /usr/local.
            unzip -q protoc-3.4.0.zip
            # Move the protoc binary to the final location and set the
            # permissions as needed.
            sudo install -m755 ./bin/protoc /usr/local/bin
            # Remove old versions of the includes, if they exist
            sudo rm -rf /usr/local/include/google/protobuf
            sudo mkdir -p /usr/local/include/google
            # Move the protoc include files to the final location and set the
            # permissions as needed.
            sudo mv ./include/google/protobuf /usr/local/include/google/
            sudo chmod -R a+rX /usr/local/include/google/protobuf
        )
        rm -rf /tmp/protoc
    else
        echo "protoc already installed"
    fi
}

DESIRED_GO_MAJOR_VERISON=1
DESIRED_GO_MINOR_VERISON=21
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

# Creates keeper config for command line access
# This is interactive
create_default_keeper_config() {
    config_file=${HOME}/.keeper-config.json
    if [ -e "${config_file}" ]; then
        if [ "$(get_yn_input "Keeper config exists, do you want to recreate it now?" "n")" = "y" ]; then
            rm -f ${config_file}
        fi
    fi

    if [ ! -e "${config_file}" ]; then
        gitemail=$(git config kaclone.email)
        echo "Keeper Command Line setup"
        echo "-------------------------"
        read -p "Enter your KA email (or blank if ${gitemail} is correct): " email
        email=${email:-$gitemail}

        echo
        echo "Keeper Master Password"
        echo "----------------------"
        echo "If you've setup keeper, enter your master password."
        echo
        echo "If you have not setup keeper, use your browser to set it up"
        echo "at https://khanacademy.org/r/keeper"
        echo "If you want to do this later (not recommended), just hit enter"
        echo "and run mac-setup-keeper.sh script later."
        echo

        read -s -p "Keeper Master Password: " master_password

        echo
        cat << EOF > ${config_file}
{
"server": "https://keepersecurity.com/api/v2/",
"user": "${email}",
"password": "${master_password}",
"sso_master_password": true,
"mfa_duration": "12_hours",
"mfa_token": "",
"mfa_type": "",
"debug": false,
"login_v3": false,
"plugins": [],
"commands": []
}
EOF
    fi
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

install_keeper() {
    # NOTE(miguel): we have had issues in our deploy system and with devs
    # in their local environment with keeper throttling requests since
    # we have upgraded from 16.5.18. So we are moving keeper back to version
    # 16.5.18. The last version we had issues with was 16.8.24.
    # Version 16.5.18 is what we use in jenkins so we want to match that
    # https://github.com/Khan/aws-config/commit/fd89852562ca3719f8936c04c847ad73d4ba82f8
    version=16.5.18
    pip3_install -q keepercommander==${version}
    # Show the keeper version (and warning if out of date)
    keeper version
    echo "(Any warning above about the latest version can probably be ignored)"
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
