#!/bin/bash

# This script gets no elevated permissions. Do NOT run sudo or anything that
# expects sudo access.

# Bail on any errors
set -e

if [[ $(uname -m) = "arm64" ]]; then
    # Add homebrew to path on M1 macs
    export PATH=/opt/homebrew/bin:$PATH
fi

# This will call down to brew UNLESS the machine is an ARM architecture
# Mac (ie M1), in which case this will use rosetta to interact with the x86
# version of brew.
brew86() {
    if [[ $(uname -m) = "arm64" ]]; then
        arch -x86_64 /usr/local/bin/brew $@
    else
        brew $@
    fi
}

tty_bold=`tput bold`
tty_normal=`tput sgr0`

# The directory to which all repositories will be cloned.
ROOT=${1-$HOME}
REPOS_DIR="$ROOT/khan"

# Derived path location constants
DEVTOOLS_DIR="$REPOS_DIR/devtools"

# Load shared setup functions.
. "$DEVTOOLS_DIR"/khan-dotfiles/shared-functions.sh

trap exit_warning EXIT   # from shared-functions.sh


update_path() {
    # We need /opt/homebrew/bin (/usr/local/bin on x86) to come before /usr/bin
    # on the path, to pick up brew files we install.  To do this, we just source
    # .profile.khan, which does this for us (and the new user). (This assumes
    # you're running mac-setup.sh from the khan-dotfiles directory.)
    . .profile.khan
}

copy_ssh_key () {
  if [ -e ~/.ssh/id_ecdsa ]
  then
    pbcopy < ~/.ssh/id_ecdsa.pub
  elif [ -e ~/.ssh/id_rsa ]
  then
    pbcopy < ~/.ssh/id_rsa.pub
  elif [ -e ~/.ssh/id_dsa ]
  then
    pbcopy < ~/.ssh/id_dsa.pub
  else
    error "no ssh public keys found"
    exit
  fi
}

register_ssh_keys() {
    success "Registering your ssh keys with github\n"
    verify_ssh_auth
}

# checks to see that ssh keys are registered with github
# $1: "true"|"false" to end the auth cycle
verify_ssh_auth () {
    ssh_host="git@github.com"
    webpage_url="https://github.com/settings/ssh"
    instruction="Click 'Add SSH Key', paste into the box, and hit 'Add key'"
    info "Checking for GitHub ssh auth"
    # ssh returns 1 if auth succeeds, 255 if it fails (and 130 if passphrase is wrong)
    if [ $(ssh -T $ssh_host >/dev/null; echo $?) -ne 1 ]; then
        if [ "$2" == "false" ]  # error if auth fails twice in a row
        then
            error "Still no luck with GitHub ssh auth. Ask a dev!"
            ssh_auth_loop $webpage_url "false"
        else
            # otherwise prompt to upload keys
            success "GitHub's ssh auth didn't seem to work\n"
            notice "Let's add your public key to GitHub"
            info "${tty_bold}${instruction}${tty_normal}\n"
            ssh_auth_loop $webpage_url "true"
        fi
    else
        success "GitHub ssh auth succeeded!"
    fi
}

ssh_auth_loop() {
    # a convenience function which lets you copy your public key to your clipboard
    # open the webpage for the site you're pasting the key into or just bailing
    # $1 = ssh key registration url
    service_url=$1
    first_run=$2
    if [ "$first_run" == "true" ]
    then
        notice "1. hit ${tty_bold}o${tty_normal} to open GitHub on the web"
        notice "2. hit ${tty_bold}c${tty_normal} to copy your public key to your clipboard"
        notice "3. hit ${tty_bold}t${tty_normal} to test ssh auth for GitHub"
        notice "☢. hit ${tty_bold}s${tty_normal} to skip ssh setup for GitHub"
        ssh_auth_loop $1 "false"
    else
        user "o|c|t|s) "
        read -n1 ssh_option
        case $ssh_option in
            o|O )
                success "opening GitHub's webpage to register your key!"
                open $service_url
                ssh_auth_loop $service_url "false"
                ;;
            c|C )
                success "copying your ssh key to your clipboard"
                copy_ssh_key
                ssh_auth_loop $service_url "false"
                ;;
            t|T )
                printf "\r"
                verify_ssh_auth "false"
                ;;
            s|S )
                warn "skipping GitHub ssh registration"
                ;;
        esac
    fi
}

update_git() {
    if ! git --version | grep -q -e 'version 2\.[2-9][0-9]\.'; then
        echo "Installing an updated version of git using Homebrew"
        echo "Current version is `git --version`"

        if brew ls git >/dev/null 2>&1; then
            # If git is already installed via brew, update it
            brew upgrade git || true
        else
            # Otherwise, install via brew
            brew install git || true
        fi

        # Check git version again
        if ! git --version | grep -q -e 'version 2\.[2-9][0-9]\.'; then
            if ! brew ls --versions git | grep -q -e 'git 2\.[2-9][0-9]\.' ; then
                echo "Error installing git via brew; download and install manually via http://git-scm.com/download/mac. "
                read -p "Press enter to continue..."
            else
                echo "Git has been updated correctly, but will require restarting your terminal to take effect."
            fi
        fi
    fi
}

# install_or_upgrade_brew_formula ensures the latest version of the passed
# formula is installed as the homebrew team only tests the latest versions of
# every formula together.
install_or_upgrade_brew_formula() {
    formulaName=$1

    if brew ls --versions "$formulaName" >/dev/null ; then
        info "Upgrading brew formula $formulaName\n"
        brew upgrade "$formulaName"
    else
        info "Installing brew formula $formulaName\n"
        brew install "$formulaName"
    fi
}

install_node() {
    # We need to uninstall the deprecated node@16 homebrew formula if it is
    # installed so its dependencies don't conflict with the dependencies of the
    # latest postgresql@14 homebrew formula.
    if brew ls --versions node@16 >/dev/null ; then
        brew uninstall node@16
    fi

    # Upgrade brew-installed node@20 if it is already installed.
    if brew ls --versions node@20 >/dev/null ; then
        install_or_upgrade_brew_formula node@20
    fi

    # Install node@20 homebrew formula if no node binary is found in $PATH.
    if ! which node >/dev/null 2>&1; then
        # Install node 20: It's LTS and the latest version supported on
        # appengine standard.
        install_or_upgrade_brew_formula node@20

        # We need this because brew doesn't link /opt/homebrew/bin/node
        # (/usr/local/bin/node on x86) by default when installing non-latest
        # node.
        brew link --force --overwrite node@20
    fi

    # At this point, users should have a node binary, whether it's from homebrew
    # (preferred), NVM or standard install.

    # We don't want to force usage of node v20, but we want to make clear we
    # don't support anything else.
    if ! node --version | grep "v20" >/dev/null ; then
        notice "Your version of node is $(node --version). We currently only support v20."
        if brew ls --versions node@20 >/dev/null ; then
            notice "You do however have node 20 installed via brew."
            notice "Consider running:"
        else
            notice "Consider running:"
            notice "\t${tty_bold}brew install node@20${tty_normal}"
        fi
        notice "\t${tty_bold}brew link --force --overwrite node@20${tty_normal}"
        read -p "Press enter to continue..."
    fi
}

install_go() {
    if ! has_recent_go; then   # has_recent_go is from shared-functions.sh
        info "Installing go\n"
        if brew ls go >/dev/null 2>&1; then
            brew upgrade "go@$DESIRED_GO_VERSION"
        else
            brew install "go@$DESIRED_GO_VERSION"
        fi

        # Brew doesn't link non-latest versions of go on install. This command
        # fixes that, telling the system that this is the go executable to use
        brew link --force --overwrite "go@$DESIRED_GO_VERSION"
    else
        success "go already installed"
    fi
}

install_redis() {
    info "Checking for redis\n"
    if ! type redis-cli >/dev/null 2>&1; then
        info "Installing redis\n"
        brew install redis
    else
        success "redis already installed"
    fi

    if ! brew services list | grep redis | grep -q started; then
        info "Starting redis service\n"
        brew services start redis 2>&1
    else
        success "redis service already started"
    fi
}

install_image_utils() {
    info "Checking for imagemagick\n"
    if ! brew ls imagemagick >/dev/null 2>&1; then
        info "Installing imagemagick\n"
        brew install imagemagick
    else
        success "imagemagick already installed"
    fi
}

install_helpful_tools() {
    # This installs gtimeout, among a ton of other tools, which we use
    # some in our deploy pipeline.
    if ! brew ls coreutils >/dev/null 2>&1; then
        info "Installing coreutils\n"
        brew install coreutils
    else
        success "coreutils already installed"
    fi
}

install_wget() {
    info "Checking for wget\n"
    if ! which wget  >/dev/null 2>&1; then
        info "Installing wget\n"
        brew install wget
    else
        success "wget already installed"
    fi
}

install_openssl() {
    info "Checking for openssl\n"
    if ! which openssl  >/dev/null 2>&1; then
        info "Installing openssl\n"
        brew install openssl
    else
        success "openssl already installed"
    fi
    for source in $(brew --prefix openssl)/lib/*.dylib ; do
        dest="$(brew --prefix)/lib/$(basename $source)"
        # if dest is already a symlink pointing to the correct source, skip it
        if [ -h "$dest" -a "$(readlink "$dest")" = "$source" ]; then
            :
        # else if dest already exists, warn user and skip dotfile
        elif [ -e "$dest" ]; then
            warn "Not symlinking to $dest because it already exists."
        # otherwise, verbosely symlink the file (with --force)
        else
            info "Symlinking $(basename $source) "
            ln -sfvn "$source" "$dest"
        fi
    done
}

install_jq() {
    info "Checking for jq\n"
    if ! which jq  >/dev/null 2>&1; then
        info "Installing jq\n"
        brew install jq
    else
        success "jq already installed"
    fi
}

install_python_tools() {
    # Python3 is needed to run the python services (e.g. ai-guide-core).
    if ! which python3.11 >/dev/null 2>&1; then
        info "Installing python 3.11\n"
        brew install python@3.11
    fi
    # The python3 formula does not install `python` as a symlink, so we do.
    if ! [ -e /usr/local/bin/python ]; then
        ln -snf python3 /usr/local/bin/python
    fi

    # We use various python versions (e.g. internal-service)
    # and use Pyenv, pipenv as environment manager
    if ! brew ls pyenv >/dev/null 2>&1; then
        info "Installing pyenv\n"
        brew install pyenv
    else
        success "pyenv already installed"
    fi
}

install_watchman() {
    if ! which watchman >/dev/null 2>&1; then
        update "Installing watchman..."
        brew install watchman
    fi
}

install_fastly() {
    if ! which fastly >/dev/null 2>&1; then
        update "Installing fastly..."
        brew install fastly/tap/fastly
    fi
}

install_docker() {
    # TODO(csilvers): we should really be installing a docker UI here
    # (docker desktop or docker rancher), which will install the
    # docker CLI as part of it.  Once we decide on a UI we can replace
    # these install instructions with the install for the UI instead.
    if ! which docker >/dev/null 2>&1; then
        update "Installing docker..."
        brew install --cask docker
    fi
}

echo
success "Running Khan mac-setup-normal.sh\n"

update_path
maybe_generate_ssh_keys
register_ssh_keys
install_wget
install_openssl
install_jq
update_git

install_node
install_go

"$DEVTOOLS_DIR"/khan-dotfiles/bin/install-mac-rust.py
"$DEVTOOLS_DIR"/khan-dotfiles/bin/mac-setup-postgres.py

install_redis
install_image_utils
install_helpful_tools
install_watchman
install_python_tools
install_fastly
install_docker

trap - EXIT
