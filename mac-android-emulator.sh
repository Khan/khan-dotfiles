#!/bin/bash
set -e -o pipefail

# This script helps developers create and run Android emulators as well as build
# and install the KA APK. As of now, this script can only be run on Mac OSs.
# (While there is support for Android dev on Linux, none of the mobile
# developers on the team have tried it.)
#
# This script must be run after mac-android-setup.sh, which installs the JDKs
# and SDKs and clones the repo necessary to create and run emulators with the KA
# app. This script can be run whenever you want to create and/or run an Android
# emulator with the KA app.

ANDROID_REPO="$HOME"/khan/mobile/app/android
ANDROID_HOME=~/Library/Android/sdk

# Load shared setup functions.
. "$HOME"/khan/devtools/khan-dotfiles/shared-functions.sh

# Gets input from the user. Return default value if the user gives empty input.
# $1: prompt
# $2: default value
get_input() {
    read -p "$1" input
    if [ -z "$input" ]; then
        echo "$2"
    else
        echo "$input"
    fi
}

# Ensure $ANDROID_HOME exists; prompt user to run mac-android-setup.sh if not.
ensure_android_home() {
    if [ ! -d "$ANDROID_HOME" ]; then
        err_and_exit "Run ./mac-android-setup.sh, then re-run this script."
    fi
    export ANDROID_SDK_ROOT="$ANDROID_HOME"
}

main() {
    ensure_android_home

    # Determine if we should build the APK. (Do this before launch_emulator so
    # that the output doesn't interfere with user input.)
    should_build_apk=$( get_should_build_apk )
    if [ "$should_build_apk" = "true" ]; then
        build_apk
    fi

    launch_emulator

    install_apk
}

# Return "true" if there is no available debug APK or if the user chooses to
# rebuild it and "false" otherwise.
get_should_build_apk() {
    should_build="true"
    if [ -e "$ANDROID_REPO"/app/build/outputs/apk/app-debug.apk ]; then
        # If there is a debug APK available, give the user the choice to rebuild
        # it.
        input=$( get_yn_input "Would you like to rebuild the APK?" "y" )
        if [ "$input" = "n" ]; then
            should_build="false"
        fi
    fi
    echo "$should_build"
}

# Build debug APK using gradle.
build_apk() {
    # TODO(hannah): Display the HEAD hash.
    update "Building APK..."
    (
        cd "$ANDROID_REPO"
        ./gradlew clean :app:assembleDebug --daemon
    )
}

# Launches an existing emulator or creates an emulator and launches it.
launch_emulator() {
    if [ -z "$($ANDROID_HOME/emulator/emulator -list-avds)" ]; then
        echo "There are no existing emulators."
    else
        echo "Here are existing emulators:"
        "$ANDROID_HOME/emulator/emulator" -list-avds
    fi

    name=$( get_input "Enter the name of the emulator you would like to use, or hit enter to create a new emulator: " "")

    # Create an emulator if the user hits enter.
    if [ -z "$name" ]; then
        update "Creating emulator..."

        # Get name, API, and ABI from user.
        echo "The name of your emulator gives you a way to reference it. You might want to name them with the convention device_API_[api]_[abi]."
        name=$( get_input "Emulator name [test-device]: " "test-device" )
        echo "API 23 is the oldest API level the KA app supports and API 31 is the newest API."
        api=$( get_input "API [31]: " "31" )
        echo "See https://developer.android.com/ndk/guides/abis.html for more information on Android ABIs."
        abi=$( get_input "ABI (x86_64 if Intel, arm64-v8a if M1/M2) [arm64-v8a]: " "arm64-v8a" )

        ensure_platform_and_abi "$api" "$abi"

        # Say "no" to "Do you wish to create a custom hardware profile".
        # TODO(hannah): Allow the user to specify the AVD's hardware.
        echo "no" | "$ANDROID_HOME/tools/bin/avdmanager" create avd \
            --name "$name" \
            --abi google_apis/"$abi" \
            --package "system-images;android-$api;google_apis;$abi"
    else
        check_emulator_exists "$name"
    fi

    # Ensure no emulators are already running.
    # TODO(hannah): Just use running emulator if available.
    if [ "$(is_device_ready)" = "true" ]; then
        err_and_exit "Please close any open emulators."
    fi

    update "Launching emulator $name..."
    # Launch emulator with given name and GPU on (see
    # https://code.google.com/p/android/issues/detail?id=189040).
    "$ANDROID_HOME/emulator/emulator" -avd "$name" -gpu on &
}

# Exit if there is not an emulator with the given name.
# $1: name of emulator
check_emulator_exists() {
    if [ -z "$1" ] || ! "$ANDROID_HOME/emulator/emulator" -list-avds | grep -w -q "$1" ; then
        err_and_exit "The emulator $name does not exist. Run 'emulator -list-avds' to see the list of emulators."
    fi
}

# Return "true" if the emulator has finished booting up, "false" otherwise. Do
# not print anything to stdout.
is_device_ready() {
    {
        if [ "`adb shell getprop sys.boot_completed | tr -d '\r' `" = "1" ]; then
            ready="true"
        else
            ready="false"
        fi
    } 2> /dev/null
    echo "$ready"
}

# Install given platform and ABI if necessary.
# $1: API
# $2: ABI
ensure_platform_and_abi() {
    if [ ! -d "$ANDROID_HOME/platforms/android-$1" ] ; then
        update "Installing platform..."
        "$ANDROID_HOME/tools/bin/sdkmanager" "platforms;android-$1"
    fi

    if [ ! -d "$ANDROID_HOME/system-images/android-$1/google_apis/$2" ] ; then
        update "Installing ABI..."
        "$ANDROID_HOME/tools/bin/sdkmanager" "system-images;android-$1;google_apis;$2"
    fi

    # Ensure the system-images directory is properly linked.
    if [ ! -d "$ANDROID_HOME/system-images" ] ; then
        # Get the directory where Homebrew installed the Android SDK.
        version_dir=`ls /usr/local/Caskroom/android-sdk/ | head -n1`

        ln -s /usr/local/Caskroom/android-sdk/"$version_dir"/system-images "$ANDROID_HOME"/
    fi
}

# Install debug APK on the open emulator.
install_apk() {
    # Wait for the emulator to finish booting up.
    while [ "$(is_device_ready)" = "false" ]; do
        sleep 0.5
    done

    # If the APK is already installed, ask the user if they want to reinstall.
    if adb shell pm list packages | grep -w -q "org.khanacademy.android.debug" ; then
        should_install=$( get_yn_input "Would you like to reinstall the APK?" "y" )
    else
        should_install="y"
    fi

    if [ "$should_install" = "y" ]; then
        update "Installing APK..."
        # Include -r so we re-install if necessary.
        adb install -r "$ANDROID_REPO"/app/build/outputs/apk/debug/app-debug.apk

        # Disables the annoying error when you launch for the first time
        # where it asks if the app can draw over other apps!
        adb shell 'appops set org.khanacademy.android.debug SYSTEM_ALERT_WINDOW allow'
    fi
}

ensure_mac_os  # Function defined in shared-functions.sh.
main
