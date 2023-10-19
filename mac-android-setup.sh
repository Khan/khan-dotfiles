#!/bin/bash
set -e -o pipefail

# This script sets up developers to work on the Android app and/or test using an
# Android emulator. As of now, this script can only be run on Mac OSs. (While
# there is support for Android dev on Linux, none of the mobile developers on
# the team have tried it.)

# Install in $HOME by default, or an alternate destination specified via $1.
ROOT=${1-$HOME}
mkdir -p "$ROOT"

# The directory to which all repositories will be cloned.
REPOS_DIR="$ROOT/khan"

# Derived path location constants
DEVTOOLS_DIR="$REPOS_DIR/devtools"
KACLONE_BIN="$DEVTOOLS_DIR/ka-clone/bin/ka-clone"

ANDROID_HOME="$HOME/Library/Android"
ANDROID_STUDIO_APP_PATH="/Applications/Android Studio.app"

# Load shared setup functions.
. "$DEVTOOLS_DIR"/khan-dotfiles/shared-functions.sh
. "$DEVTOOLS_DIR"/khan-dotfiles/mobile-functions.sh

# Ensure Android Studio is installed (or that the user does not want to install it).
install_android_studio() {
    if [ ! -e "$ANDROID_STUDIO_APP_PATH" ]; then
        # If Android Studio is not installed, ask the user before installing it.
        if [ "$(get_yn_input "Install Android Studio?" "y")" = "y" ]; then
            update "Installing or updating Android Studio..."
            brew install android-studio
        fi
    else
        update "Android Studio already installed"
    fi
}

# Create a symbolic link to the KA codestyle files so that they can be used by
# Android Studio.
configure_codestyle() {
    if [ ! -e "$ANDROID_STUDIO_APP_PATH" ]; then
        echo "Android Studio not found. The Khan Academy codestyle will not be installed."
        echo "Rerun this script after installing Android Studio to install it."
        return
    fi

    ANDROID_STUDIO_VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" /Applications/Android\ Studio.app/Contents/Info.plist)
    ANDROID_STUDIO_CODESTYLES_PATH="$HOME/Library/Preferences/AndroidStudio${ANDROID_STUDIO_VERSION}/codestyles"
    CODESTYLE_SOURCE="$REPOS_DIR"/mobile/android/third-party/style-guide/configs/KhanAcademyAndroid.xml

    mkdir -p "$ANDROID_STUDIO_CODESTYLES_PATH"

	# Ensure submodules are up to date. Otherwise Android Studio can't see the 
	# style file. This should be done by `kaclone_repo` but for some reason it
	# doesn't always seem to happen!
	# Example: https://khanacademy.slack.com/archives/C02NPE076/p1597853211320400?thread_ts=1597853074.320200&cid=C02NPE076
    if [ ! -e "$CODESTYLE_SOURCE" ]; then
        pushd "$REPOS_DIR/mobile"
        git submodule update --recursive --init
    fi

    if [ ! -e "$ANDROID_STUDIO_CODESTYLES_PATH"/KhanAcademyAndroid.xml ]; then
        update "Linking Khan Academy codestyle files..."
        ln -s -f "$CODESTYLE_SOURCE" "$ANDROID_STUDIO_CODESTYLES_PATH"
    fi
}

# Make a symbolic link from the default Homebrew location to $ANDROID_HOME.
link_sdk() {
    # We only do this if Android Studio _isn't_ installed.
    # If it is, we use Android Studio to manage the Android SDK
    if [ ! -d "$ANDROID_HOME"/sdk/ ]; then
        # Create the directory to store the Andrid SDK.
        mkdir -p "$ANDROID_HOME"/sdk

        # Get the directory where Homebrew installed the Android SDK.
        version_dir=`ls /usr/local/Caskroom/android-sdk/ | head -n1`

        ln -s /usr/local/Caskroom/android-sdk/"$version_dir"/* "$ANDROID_HOME"/sdk/
    fi
}

# Ensure the Android SDK is installed.
install_android_sdk() {
    if [ -d "$ANDROID_STUDIO_APP_PATH" ]; then
        update "Android Studio is installed. Android SDK should be installed using Android Studio."
    else
        if [ ! -d "$ANDROID_HOME"/sdk/tools ]; then
            update "Android Studio not found. Installing Android SDK..."

            brew cask install android-sdk
            link_sdk
        fi

        # Update or install SDK components.
        # Install platform-tools to get adb.
        "$ANDROID_HOME"/sdk/tools/bin/sdkmanager "tools" "platform-tools"
        # Install Build Tools (25.0.2 is necessary to build using gradle).
        "$ANDROID_HOME"/sdk/tools/bin/sdkmanager "build-tools;25.0.2"
        # Install Google Play Services.
        "$ANDROID_HOME"/sdk/tools/bin/sdkmanager "extras;google;google_play_services"

        # Accept all license agreements.
        # TODO(hannah): There doesn't seem to be a great way to accept all of the
        # licenses programmatically, but make this more robust.
        # TODO(Kai): For some reason, this way to accept all licenses doesn't work and exits unexpectedly,
        # so temporarily diable it.
        # while sleep 1; do echo "y"; done |
        # "$ANDROID_HOME"/sdk/tools/bin/sdkmanager --licenses
    fi
}

ensure_mac_os  # Function defined in shared-functions.sh.

brew update # Make sure the Homebrew package DB is up to date

# TODO(hannah): Ensure setup.sh has already been run.
install_mac_java
clone_mobile_repo

install_android_studio
configure_codestyle

# This occurs _after_ installing Android Studio. If this is a developer setting
# up an environment, they will install the SDK via Android Studio.
install_android_sdk

install_homebrew_libraries

install_react_native_dependencies

update "Done! Complete setup instructions at \
https://khanacademy.atlassian.net/wiki/spaces/MG/pages/49317506/Android+Environment+Setup"
