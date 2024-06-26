#!/usr/bin/env python3
"""Install mkcert and setup a CA.

This very simple script exists because we want it to be called along with all
the other scripts that require elevated permissions (sudo) and because it
requires a reboot after completion.
"""

import os
import subprocess

# Ensure we are using the best "version" of brew
BREW86_PREFIX = "/usr/local/bin/"
BREW_PREFIX = "/opt/homebrew/bin/"
BREW_PREFIX = BREW_PREFIX if os.path.isdir(BREW_PREFIX) else BREW86_PREFIX
BREW = BREW_PREFIX + "brew"

result = subprocess.run(['which', 'mkcert'], capture_output=True)
if result.returncode != 0:
    # nss is a library that's required to make mkcert work with Firefox
    subprocess.run([BREW, 'install', 'mkcert', 'nss'], check=True)
    # The following will ask for your password
    subprocess.run(['mkcert', '-install'], check=True)

    print("""
You have installed mkcert (used to make khanacademy.dev and "Vitejs Directly"
on localhost:8088 work).

A CA has been added to your system and browser certificate trust stores.

You must REBOOT your machine for browsers to recognize new CA.
""")
