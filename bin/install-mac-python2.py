#!/usr/bin/env python3
"""Install Khan's python2."""

import argparse
import re
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument("--force", help="Force install of Khan's python2",
                    action="store_true")
args = parser.parse_args()

which = subprocess.run(['which', 'python2'], capture_output=True, text=True)
is_installed = (which.returncode == 0
                and which.stdout.strip() != "/usr/bin/python2")
if is_installed:
    print("Already running a non-system python2.")

if args.force or not is_installed:
    action = "reinstall" if is_installed else "install"
    print("Installing python2 from khan/repo. This may take a few minutes.")
    subprocess.run(['brew', action, 'khan/repo/python@2'], check=True)

# Get version of pip2
pip2_version = ""
pip2_version_str = subprocess.run(['pip2', '--version'],
                                  capture_output=True, text=True)
if pip2_version_str:
    match = re.match(r'\w+ (\d+)', pip2_version_str.stdout)
    if match:
        pip2_version = match.group(1)

if pip2_version and pip2_version > "19":
    print("Reverting pip2 from version: " + pip2_version_str.stdout.strip())
    subprocess.run(['pip2', 'install', 'pip<20', '-U'], check=True)

# Simple diagnostics
subprocess.run(['pip2', '--version'])
print("which python2: " + which.stdout.strip())
