bad_usage_get_yn_input=100

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

    # Symlink openjdk for the system Java wrappers
    sudo ln -sfn /opt/homebrew/opt/openjdk@11/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk-11.jdk

    # Ensure JAVA_HOME is set in ~/.profile.khan
    # TODO (jwiesebron): Update other parts of dotfiles to use this convention
    add_to_dotfile 'export JAVA_HOME=/Library/Java/JavaVirtualMachines/openjdk-11.jdk'
    add_to_dotfile 'export PATH="/opt/homebrew/opt/openjdk@11/bin:$PATH"'
}

install_protoc_common() {
    # Platform independent installation of protoc.
    # usage: install_protoc_common <zip_url>

    # The URL of the protoc zip file is passed as the first argument to this
    # function. This file is platform dependent.
    zip_url=$1

    # We use protocol buffers in webapp's event log stream infrastructure. This
    # installs the protocol buffer compiler (which generates python & java code
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

# Install the version of python2 virtualenv that we want
install_python2_virtualenv() {
    # Install virtualenv.
    # https://docs.google.com/document/d/1zrmm6byPImfbt7wDyS8PpULwnEckSxna2jhSl38cWt8
    # Must do --force-reinstall or it will NOT automatically overwrite
    # python3 version of virtualenv if it accidentally gets installed.
    python2 -m pip install virtualenv==20.0.23 --force-reinstall
}

# Creates a webapp virtualenv in $1, if none exists, then activates it.
#
# Assumes pip and virtualenv are already installed.
#
# Arguments:
#   $1: directory in which to put the virtualenv, typically ~/.virtualenv/khan27.
create_and_activate_virtualenv() {
    # On a arm64 mac, we MUST use the python2 version of virtualenv
    VIRTUALENV=$(which virtualenv)
    if [[ -n ${IS_MAC_ARM} ]]; then
        VIRTUALENV=/usr/local/bin/virtualenv
        if [[ -z "${VIRTUALENV}" ]]; then
            /usr/local/bin/python2 -m pip install virtualenv
        fi
    fi

    if [ ! -d "$1" ]; then
        ${VIRTUALENV} -q --python="$(which python2)" --always-copy "$1"
    fi

    # Activate the virtualenv.
    . "$1/bin/activate"

    # pip may get broken by virtualenv for some reason. We're better off 
    # calling `python -m pip` so we'll just swap in a script that does 
    # that for us.
    if ! pip --version 2>/dev/null ; then
        cp bin/pip `which pip`
        cp bin/pip2 `which pip2`
    fi

    # pip20+ stopped supporting python2.7, so we need to make sure
    # we are using an older pip.
    if ! pip --version | grep -q "pip 1[0-9]"; then
        pip install -U "pip<20" setuptools
    fi
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

# install keeper
# $1: path to python3 (including python3 binary)
install_keeper() {
    python=$1
    # NOTE(miguel): we have had issues in our deploy system and with devs
    # in their local environment with keeper throttling requests since
    # we have upgraded from 16.5.18. So we are moving keeper back to version
    # 16.5.18. The last version we had issues with was 16.8.24.
    # Version 16.5.18 is what we use in jenkins so we want to match that
    # https://github.com/Khan/aws-config/commit/fd89852562ca3719f8936c04c847ad73d4ba82f8
    version=16.5.18
    ${python} -m pip install -q keepercommander==${version}
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
