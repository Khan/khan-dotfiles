#!/usr/bin/env python3
"""Install or Fix homebrew."""

# This script will prompt for user's password if sudo access is needed
# TODO(ericbrown): Can we check, install & upgrade apps we know we need/want?

import os
import platform
import subprocess


class HomebrewInstaller:
    HOMEBREW_INSTALLER = (
        "https://raw.githubusercontent.com/Homebrew/install/master/install.sh"
    )
    HOMEBREW_UNINSTALLER = (
        "https://raw.githubusercontent.com/Homebrew/install/master/install.sh"
    )
    ARM64_BREW_DIR = "/opt/homebrew/bin"
    X86_BREW_DIR = "/usr/local/bin"

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
    def _install_or_uninstall_homebrew(brew_script, force_x86=False):
        # Validate that we have sudo access (as installer script checks)
        print(
            "This setup script needs your password to install things as root."
        )
        subprocess.run(["sudo", "sh", "-c", "echo You have sudo"], check=True)

        # Run installer
        installer_runner = (
            ["arch", "-x86_64", "/bin/bash"] if force_x86 else ["/bin/bash"]
        )
        subprocess.run(installer_runner, input=brew_script, check=True)

    def install_homebrew(self, force_x86=False):
        self._install_or_uninstall_homebrew(
            brew_script=self._install_script, force_x86=force_x86
        )

    def uninstall_homebrew(self, force_x86=False):
        if force_x86:
            os.environ["PATH"] = self.X86_BREW_DIR + os.environ["PATH"]
        self._install_or_uninstall_homebrew(brew_script=self._uninstall_script)
        if force_x86:
            os.environ["PATH"] = self.ARM64_BREW_DIR + os.environ["PATH"]

    def _validate_and_install_homebrew(self, force_x86=False):
        if platform.uname().machine == "arm64":
            if force_x86:
                brew_runner = ["arch", "-x86_64", "/usr/local/bin/brew"]
            else:
                brew_runner = ["/opt/homebrew/bin/brew"]
        else:
            brew_runner = ["/usr/local/bin/brew"]

        if force_x86:
            brew_bin_exists = os.path.exists("/usr/local/bin/brew")
        else:
            brew_bin_exists = (
                subprocess.run(
                    ["which", "brew"], capture_output=True
                ).returncode
                == 0
            )
        if not brew_bin_exists:
            print("Brew not found, Installing!")
            self.install_homebrew(force_x86=force_x86)
        else:
            result = subprocess.run(
                brew_runner + ["--help"], capture_output=True
            )
            if result.returncode != 0:
                print("Brew broken, Re-installing")
                self.uninstall_homebrew(force_x86=force_x86)
                self.install_homebrew(force_x86=force_x86)
        update_msg = "Updating (but not upgrading) Homebrew"
        if force_x86:
            update_msg += " x86"
        print(update_msg)
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

    def validate_and_install_homebrew(self):
        self._validate_and_install_homebrew()

        if platform.uname().machine == "arm64":
            # Ensure arm64 brew bin is used by default over x86
            path_msg = (
                self.ARM64_BREW_DIR
                + "must come before "
                + self.X86_BREW_DIR
                + " in PATH"
            )
            env_path = os.environ["PATH"]
            assert self.ARM64_BREW_DIR in env_path, path_msg
            opt_homebrew_idx = env_path.index(self.ARM64_BREW_DIR)
            usr_local_bin_idx = env_path.index(self.X86_BREW_DIR)
            assert opt_homebrew_idx < usr_local_bin_idx, path_msg
            # Install x86 brew for M1 architecture to be run with rosetta
            self._validate_and_install_homebrew(force_x86=True)


if __name__ == "__main__":
    print("Checking for mac homebrew")
    HomebrewInstaller().validate_and_install_homebrew()
