#!/usr/bin/env python3
"""Install mkcert and setup a CA.

This very simple script exists because we want it to be called along with all
the other scripts that require elevated permissions (sudo) and because it
requires a reboot after completion.
"""

import subprocess

result = subprocess.run(['which', 'mkcert'], capture_output=True)
if result.returncode != 0:
    subprocess.run(['brew', 'install', 'mkcert'], check=True)
    # The following will ask for your password
    subprocess.run(['mkcert', '-install'], check=True)

    print("""
You have installed mkcert (used to make khanacademy.dev work)
A CA has been added to your system and browser certificate trust stores.

You must REBOOT your machine for browsers to recognize new CA.
""")
