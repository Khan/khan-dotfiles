#!/bin/sh

# Bail on any errors
set -e

tty_bold=`tput bold`
tty_normal=`tput sgr0`

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
  if [ -e ~/.ssh/id_[rd]sa ]
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

install_gcc() {
    info "\nChecking for apple command line developer tools..."
    if ! gcc --version >/dev/null 2>&1 || [ ! -s /usr/include/stdio.h ]; then
        if sw_vers -productVersion | grep -e '10\.[0-8]$' -e '10\.[0-8]\.'; then
            warn "Command line tools are *probably available* for your Mac's OS, but..."
            info "Kayla or Kamens or your mentor will gladly upgrade your OS right now\n"
            info "Otherwise, you can always visit developer.apple.com and grab 'em there.\n"
            exit 1
        else
            success "Installing command line developer tools"
            # Also, how did you get this dotfiles repo in 10.9 without
            # git auto-triggering the command line tools install process??
            xcode-select --install
            warn "The dotfile setup is stopping now."
            warn "When the install finishes, rerun ${tty_bold}make${tty_normal} to continue. (sorry)"
            exit 1
        fi
        # If this doesn't work for you, you can find the most recent
        # version here: https://developer.apple.com/downloads
    else
        success "Great, found gcc! (assuming we also have other recent devtools)"
    fi
}

install_hipchat() {
    info "Checking for HipChat..."
    if ! open -R -g -a HipChat > /dev/null; then
        success "Didn't find HipChat."
        info "Installing HipChat to ~/Applications and opening\n"
        mkdir -p ~/Applications
        hipchat_app_url="http://downloads.hipchat.com.s3.amazonaws.com/osx/HipChat-2.5.6-87.zip"
        curl -o ~/Downloads/HipChat-2.5.6-87.zip $hipchat_app_url
        unzip ~/Downloads/HipChat-2.5.6-87.zip -d ~/Applications > /dev/null
        open -a ~/Applications/HipChat.app
    else
        success "Great! HipChat already installed!"
    fi
}

install_homebrew() {
    info "Checking for mac homebrew"
    # If homebrew is already installed, don't do it again.
    if ! brew --help >/dev/null 2>&1; then
        success "Brew not found. Installing!"
        ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
    else
        success "Great! Mac homebrew already installed!"
    fi
    success "Updating (but not upgrading) Homebrew"
    brew update > /dev/null

    # Make the cellar.
    mkdir -p /usr/local/Cellar

    # TODO(marcos) check for other versions of osx perhaps and do some
    # sanity checking and other goodness here. SO VERY SORRY EVERYONE.
    brew tap homebrew/dupes
    brew install apple-gcc42

    # We need a particular version of phantomjs to run the end-to-end tests.
    # This command will let us access those.
    brew tap homebrew/versions

    # Make sure everything is ok.  We don't care if we're using an
    # obsolete gcc, so instead of looking at the exit code for 'brew
    # doctor', we look at its output.  The last 'grep', combined with
    # the ! at the beginning of this command, causes the overall
    # command to fail -- and thus the script to exit -- if brew doctor
    # has any errors or warnings after we grep out the stuff we don't
    # care about.
    ## Commented out for now: too many legit setups have warnings (cf chris).
    ## ! brew doctor 2>&1 \
    ##     | grep -v -e 'A newer Command Line Tools' \
    ##     | grep -v -e 'Your Homebrew is not installed to /usr/local' \
    ##     | grep -C1000 -e ^Error -e ^Warning
}

update_git() {
    if ! git --version | grep -q -e 'version 1.[89]' \
                                 -e 'version 2'; then
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
        if ! git --version | grep -q -e 'version 1.[89]' \
                                     -e 'version 2'; then
            echo "Error installing git via brew; download and install manually via http://git-scm.com/download/mac. "
            read -p "Press enter to continue..."
        fi
    fi
}

install_node() {
    if ! brew ls node >/dev/null 2>&1; then
        brew install node 2>&1
    fi
    if ! npm --version >/dev/null; then
        curl -L https://npmjs.org/install.sh | sh
    fi
}

install_phantomjs() {
    info "Installing phantomjs 1.9.8..."
    brew uninstall --force phantomjs
    brew install phantomjs198
}

install_helpful_tools() {
    # This is useful for profiling
    # cf. http://www.khanacademy.org/r/fun-with-miniprofiler
    info "Would you like to install qcachegrind to profile performance woes?"
    notice "c.f. ${tty_bold}http://www.khanacademy.org/r/fun-with-miniprofiler${tty_normal}"
    user "y | N) "
    read -n1 yepnope
    case $yepnope in
        y|Y )
            success "Great, installing qcachegrind!"
            if ! brew ls qcachegrind >/dev/null 2>&1; then
                brew install qcachegrind 2>&1
            else
                info "qcachegrind already installed!\n"
            fi
            ;;
        * )
            success "Not installing qcachegrind (you can always do it later!)"
        ;;
    esac
}


echo "\n"
success "Running Khan Installation Script 1.1\n"
warn "Warning: This is only tested on Mac OS 10.9 (Mavericks)\nand Mac OS 10.10 (Yosemite)\n"
notice "After each statement, either something will open for you to"
notice "interact with, or a script will run for you to use\n"
notice "Press enter when a download/install is completed to go to"
notice "the next step (including this one)"

read -p "Press enter to continue..."

# Run sudo once at the beginning to get the necessary permissions.
notice "This setup script needs your password to install things as root."
sudo sh -c 'echo Thanks'

update_path
maybe_generate_ssh_keys
register_ssh_keys
install_gcc
install_hipchat
install_homebrew
update_git
install_node
install_phantomjs
install_helpful_tools

notice "You might be done! \n\n \
You should open a new shell to pick up any changes."
