#!/bin/bash

# This script is normally called by mac-setup.sh (with relevant arguments)

# User may be prompted for password so brew can run sudo when installing
# - google-drive-file-stream (currently broken in homebrew 2/4/2021)
# - zoom

# Bail on any errors
set -e

SCRIPT=$(basename $0)

usage() {
  cat <<EOF
usage: $SCRIPT [options]
  -n, --none  Install none of the optional apps some Khan DEVs like
  -a, --all   Install all apps
EOF
}

# Process command line arguments
while [[ "$1" != "" ]]; do
  case $1 in
    -n | --none)
      # Install no apps (just exit)
      exit 0
      ;;
    -a | --all)
      input="a"
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 1
      ;;
  esac
  shift
done

# TODO(ericbrown): Remove by 6/1/2021 if no complaints (not needed anymore?)
# Likely need an alternate versions of Casks in order to install chrome-canary
# Required to install chrome-canary
#brew tap homebrew/cask-versions

# To install some useful mac apps.
install_mac_apps() {
  chosen_apps=() # When the user opts to install a package it will be added to this array.

  mac_apps=(
    # Browsers
    firefox firefox-developer-edition google-chrome google-chrome-canary
    # Tools
    dropbox google-drive-file-stream iterm2 zoomus
    # Text Editors
    macvim sublime-text textmate atom
    # Chat
    slack
  )

  mac_apps_str="${mac_apps[@]}"

  if [[ -z "$input" ]]; then
    echo "We recommend installing the following apps: ${mac_apps_str}."
    echo
    read -r -p "Would you like to install [a]ll, [n]one, or [s]ome of the apps? [a/n/s]: " input
  fi

  case "$input" in
      [aA][lL][lL] | [aA])
          chosen_apps=("${mac_apps[@]}")
          ;;
      [sS][oO][mM][eE] | [sS])
          for app in ${mac_apps[@]}; do
            if [ "$(get_yn_input "Would you like to install ${app}?" "y")" = "y" ]; then
              chosen_apps=("${chosen_apps[@]}" "${app}")
            fi
          done
          ;;
      [nN][oO][nN][eE] | [nN])
          ;;
      *)
          echo "Please choose [a]ll, [n]one, or [s]ome."
          exit 100
          ;;
  esac

  for app in ${chosen_apps[@]}; do
    if ! brew cask ls $app >/dev/null 2>&1; then
        echo "$app is not installed, installing $app"
        brew install --cask $app || echo "Failed to install $app, perhaps it is already installed."
    else
        echo "$app already installed"
    fi
  done
}

install_mac_apps
