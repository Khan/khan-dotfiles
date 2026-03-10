#!/usr/bin/env python3
"""Install or Fix homebrew."""

# This script will prompt for user's password if sudo access is needed
# TODO(ericbrown): Can we check, install & upgrade apps we know we need/want?

import platform
import subprocess


class HomebrewInstaller:
    HOMEBREW_INSTALLER = (
        "https://raw.githubusercontent.com/Homebrew/install/master/install.sh"
    )
    HOMEBREW_UNINSTALLER = (
        "https://raw.githubusercontent.com/Homebrew/install/master/install.sh"
    )

    def __init__(self):
        self.__install_script = None
        self.__uninstall_script = None

    @property
    def _install_script(self):
        if not self.__install_script:
            self.__install_script = self._pull_script(self.HOMEBREW_INSTALLER)
        return self.__install_script

    @property
    def _uninstall_script(self):
        if not self.__install_script:
            self.__install_script = self._pull_script(self.HOMEBREW_INSTALLER)
        return self.__install_script

    @staticmethod
    def _pull_script(script_url):
        return subprocess.run(
            ["curl", "-fsSL", script_url],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=True,
        ).stdout

    @staticmethod
    def _install_or_uninstall_homebrew(brew_script):
        # Validate that we have sudo access (as installer script checks)
        print(
            "This setup script needs your password to install things as root."
        )
        subprocess.run(["sudo", "sh", "-c", "echo You have sudo"], check=True)

        # Run installer
        subprocess.run(["/bin/bash"], input=brew_script, check=True)

    def install_homebrew(self):
        self._install_or_uninstall_homebrew(brew_script=self._install_script)

    def uninstall_homebrew(self):
        self._install_or_uninstall_homebrew(brew_script=self._uninstall_script)

    def validate_and_install_homebrew(self):
        if platform.uname().machine == "arm64":
            brew_runner = ["/opt/homebrew/bin/brew"]
        else:
            brew_runner = ["/usr/local/bin/brew"]

        brew_bin_exists = (
            subprocess.run(
                ["which", "brew"], capture_output=True
            ).returncode
            == 0
        )
        if not brew_bin_exists:
            print("Brew not found, Installing!")
            self.install_homebrew()
        else:
            result = subprocess.run(
                brew_runner + ["--help"], capture_output=True
            )
            if result.returncode != 0:
                print("Brew broken, Re-installing")
                self.uninstall_homebrew()
                self.install_homebrew()

        print("Updating (but not upgrading) Homebrew")
        subprocess.run(
            brew_runner + ["update"], capture_output=True, check=True
        )

        # Install homebrew-cask, so we can use it manage installing binary/GUI
        # apps brew tap caskroom/cask

        # Likely need an alternate versions of Casks in order to install
        # chrome-canary
        # Required to install chrome-canary
        # (Moved to mac-install-apps.sh, but might be needed elsewhere
        # unbeknownst!)
        # subprocess.run(['brew', 'tap', 'brew/cask-versions'], check=True)

        # This is where we store our own formulas.
        subprocess.run(brew_runner + ["tap", "khan/repo"], check=True)


if __name__ == "__main__":
    print("Checking for mac homebrew")
    HomebrewInstaller().validate_and_install_homebrew()
