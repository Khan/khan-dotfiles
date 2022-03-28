#!/bin/bash

# This script gets no elevated permissions. Do NOT run sudo or anything that
# expects sudo access.

# Bail on any errors
set -e

if [[ $(uname -m) = "arm64" ]]; then
    # Add homebrew to path on M1 macs
    export PATH=/opt/homebrew/bin:$PATH
fi

tty_bold=`tput bold`
tty_normal=`tput sgr0`

# The directory to which all repositories will be cloned.
ROOT=${1-$HOME}
REPOS_DIR="$ROOT/khan"

# Derived path location constants
DEVTOOLS_DIR="$REPOS_DIR/devtools"

# Load shared setup functions.
. "$DEVTOOLS_DIR"/khan-dotfiles/shared-functions.sh

# for printing standard echoish messages
notice () {
    printf "         $1\n"
}

# for printing logging messages that *may* be replaced by
# a success/warn/error message
info () {
    printf "  [ \033[00;34m..\033[0m ] $1"
}

# for printing prompts that expect user input and will be
# replaced by a success/warn/error message
user () {
    printf "\r  [ \033[0;33m??\033[0m ] $1 "
}

# for replacing previous input prompts with success messages
success () {
    printf "\r\033[2K  [ \033[00;32mOK\033[0m ] $1\n"
}

# for replacing previous input prompts with warnings
warn () {
    printf "\r\033[2K  [\033[0;33mWARN\033[0m] $1\n"
}

# for replacing previous prompts with errors
error () {
    printf "\r\033[2K  [\033[0;31mFAIL\033[0m] $1\n"
}

trap exit_warning EXIT   # from shared-functions.sh


update_path() {
    # We need /usr/local/bin to come before /usr/bin on the path, to
    # pick up brew files we install.  To do this, we just source
    # .profile.khan, which does this for us (and the new user).
    # (This assumes you're running mac-setup.sh from the khan-dotfiles
    # directory.)
    . .profile.khan
}

maybe_generate_ssh_keys () {
  # Create a public key if need be.
  info "Checking for ssh keys"
  mkdir -p ~/.ssh
  if [ -s ~/.ssh/id_rsa ] || [ -s ~/.ssh/id_dsa ]
  then
    success "Found existing ssh keys"
  else
    ssh-keygen -q -N "" -t rsa -f ~/.ssh/id_rsa
    success "Generated an rsa ssh key at ~/.ssh/id_rsa"
  fi
  return 0
}

copy_ssh_key () {
  if [ -e ~/.ssh/id_rsa ]
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
    if ! ssh -T -v $ssh_host 2>&1 >/dev/null | grep \
        -q -e "Authentication succeeded (publickey)"
    then
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

install_python2() {
    # We only do this if python2 == /usr/bin/python2, which means it's system python
    if [ "$(which python2)" != "/usr/bin/python2" ]; then
      success "Already running a non-system python2."
      return
    fi

    info "Installing python2 from khan/repo. This may take a few minutes."
    brew install khan/repo/python@2
}

install_node() {
    BREW=brew
    [ `uname -m` = "arm64" ] && BREW="arch -x86_64 /usr/local/bin/brew"

    if ! which node >/dev/null 2>&1; then
        # Install node 16: It's LTS and the latest version supported on
        # appengine standard.
        $BREW install node@16

        # We need this because brew doesn't link /usr/local/bin/node
        # by default when installing non-latest node.
        $BREW link --force --overwrite node@16
    fi
    # We don't want to force usage of node v16, but we want to make clear we
    # don't support anything else.
    if ! node --version | grep "v16" >/dev/null ; then
        notice "Your version of node is $(node --version). We currently only support v16."
        if $BREW ls --versions node@16 >/dev/null ; then
            notice "You do however have node 16 installed."
            notice "Consider running:"
        else
            notice "Consider running:"
            notice "\t${tty_bold}brew install node@16${tty_normal}"
        fi
        notice "\t${tty_bold}brew link --force --overwrite node@16${tty_normal}"
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

install_nginx() {
    info "Checking for nginx\n"
    if ! type nginx >/dev/null 2>&1; then
        info "Installing nginx\n"
        brew install nginx
    else
        success "nginx already installed"
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
    # We use various python versions (e.g. internal-service)
    # and use Pyenv, pipenv as environment manager
    if ! brew ls pyenv >/dev/null 2>&1; then
        info "Installing pyenv\n"
        brew install pyenv
        # At the moment, we depend on MacOS coming with python 2.7. If that
        # stops, or we want to align the python versions with the linux
        # dotfiles more effectively, we could do it with pyenv:
        # `pyenv install 2.7.16 ; pyenv global 2.7.16`
        # Because the linux dotfiles do not yet install pyenv, holding off on
        # using pyenv to enforce python version until either that happens, or
        # MacOs stops including python 2.7 by default.
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

echo
success "Running Khan mac-setup-normal.sh\n"

update_path
maybe_generate_ssh_keys
register_ssh_keys
install_wget
install_openssl
install_jq
update_git

"$DEVTOOLS_DIR"/khan-dotfiles/bin/install-mac-python2.py

install_node
install_go

"$DEVTOOLS_DIR"/khan-dotfiles/bin/install-mac-rust.py
"$DEVTOOLS_DIR"/khan-dotfiles/bin/mac-setup-postgres.py

install_nginx
install_redis
install_image_utils
install_helpful_tools
install_watchman
install_python_tools

trap - EXIT
