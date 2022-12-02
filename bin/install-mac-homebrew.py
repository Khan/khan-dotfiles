#!/usr/bin/env python3
"""Install or Fix homebrew."""

# This script will prompt for user's password if sudo access is needed
# TODO(ericbrown): Can we check, install & upgrade apps we know we need/want?

import platform
import subprocess

HOMEBREW_INSTALLER = \
    'https://raw.githubusercontent.com/Homebrew/install/master/install.sh'

print('Checking for mac homebrew')

install_brew = False
which = subprocess.run(['which', 'brew'], capture_output=True)
if which.returncode != 0:
    print('Brew not found, Installing!')
    install_brew = True
else:
    result = subprocess.run(['brew', '--help'], capture_output=True)
    if result.returncode != 0:
        print('Brew broken, Re-installing')
        install_brew = True

if install_brew:
    # Download installer
    installer = subprocess.run(['curl', '-fsSL', HOMEBREW_INSTALLER],
                               stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT,
                               check=True)

    # Validate that we have sudo access (as installer script checks)
    print("This setup script needs your password to install things as root.")
    subprocess.run(['sudo', 'sh', '-c', 'echo You have sudo'], check=True)

    # Run downloaded installer
    result = subprocess.run(['/bin/bash'], input=installer.stdout, check=True)
    if platform.uname().machine == 'arm64':
        # install brew86 for M1 architecture
        result = subprocess.run(['arch -x86_64 /bin/bash'],
                                input=installer.stdout, check=True)


print('Updating (but not upgrading) Homebrew')
subprocess.run(['brew', 'update'], capture_output=True, check=True)

# Install homebrew-cask, so we can use it manage installing binary/GUI apps
# brew tap caskroom/cask

# Likely need an alternate versions of Casks in order to install chrome-canary
# Required to install chrome-canary
# (Moved to mac-install-apps.sh, but might be needed elsewhere unbeknownst!)
# subprocess.run(['brew', 'tap', 'brew/cask-versions'], check=True)

# This is where we store our own formula, including a python@2 backport
subprocess.run(['brew', 'tap', 'khan/repo'], check=True)
