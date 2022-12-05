#!/usr/bin/env python3
"""Install or Fix homebrew."""

# This script will prompt for user's password if sudo access is needed
# TODO(ericbrown): Can we check, install & upgrade apps we know we need/want?

import os
import platform
import subprocess


class HomebrewInstaller:
    HOMEBREW_INSTALLER = \
        'https://raw.githubusercontent.com/Homebrew/install/master/install.sh'
    HOMEBREW_UNINSTALLER = \
        'https://raw.githubusercontent.com/Homebrew/install/master/install.sh'

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
        return subprocess.run(['curl', '-fsSL', script_url],
                              stdout=subprocess.PIPE,
                              stderr=subprocess.STDOUT,
                              check=True).stdout

    @staticmethod
    def _install_or_uninstall_homebrew(script: bytes, force_x86: bool = False) -> None:
        # Validate that we have sudo access (as installer script checks)
        print("This setup script needs your password to install things as root.")
        subprocess.run(['sudo', 'sh', '-c', 'echo You have sudo'], check=True)

        # Run installer
        installer_runner = 'arch -x86_64 /bin/bash' if force_x86 else '/bin/bash'
        subprocess.run([installer_runner], input=script, check=True)

    def install_homebrew(self, force_x86: bool = False) -> None:
        self._install_or_uninstall_homebrew(script=self._install_script, force_x86=force_x86)

    def uninstall_homebrew(self) -> None:
        self._install_or_uninstall_homebrew(script=self._uninstall_script)

    def _validate_and_install_homebrew(self, force_x86: bool = False) -> None:
        brew_cmd = 'brew86' if force_x86 else 'brew'
        if force_x86:
            brew_bin_exists = os.path.exists('/usr/local/bin/brew')
        else:
            brew_bin_exists = subprocess.run(['which', 'brew'], capture_output=True) == 0
        if not brew_bin_exists:
            print('Brew not found, Installing!')
            self.install_homebrew(force_x86=force_x86)
        else:
            result = subprocess.run([brew_cmd, '--help'], capture_output=True)
            if result.returncode != 0:
                print('Brew broken, Re-installing')
                self.uninstall_homebrew()
                self.install_homebrew(force_x86=force_x86)
        print('Updating (but not upgrading) Homebrew')
        subprocess.run([brew_cmd, 'update'], capture_output=True, check=True)

        # Install homebrew-cask, so we can use it manage installing binary/GUI apps
        # brew tap caskroom/cask

        # Likely need an alternate versions of Casks in order to install chrome-canary
        # Required to install chrome-canary
        # (Moved to mac-install-apps.sh, but might be needed elsewhere unbeknownst!)
        # subprocess.run(['brew', 'tap', 'brew/cask-versions'], check=True)

        # This is where we store our own formula, including a python@2 backport
        subprocess.run([brew_cmd, 'tap', 'khan/repo'], check=True)

    def validate_and_install_homebrew(self) -> None:
        self._validate_and_install_homebrew()

        if platform.uname().machine == 'arm64':
            # Ensure arm64 brew bin is used by default over x86
            arm64_brew_dir = '/opt/homebrew/bin'
            x86_brew_dir = '/usr/local/bin'
            path_msg = f'{arm64_brew_dir} must come before {x86_brew_dir} in PATH'
            env_path = os.environ['PATH']
            assert arm64_brew_dir in env_path, path_msg
            opt_homebrew_idx = env_path.index(arm64_brew_dir)
            usr_local_bin_idx = env_path.index(x86_brew_dir)
            assert opt_homebrew_idx < usr_local_bin_idx, path_msg
            # Install x86 brew for M1 architecture to be run with rosetta
            self._validate_and_install_homebrew(force_x86=True)


if __name__ == "__main__":
    print('Checking for mac homebrew')
    HomebrewInstaller().validate_and_install_homebrew()
