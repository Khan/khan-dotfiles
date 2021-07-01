#!/usr/bin/env python3
"""Install rust & cargo on a mac."""

# TODO(ebrown): Make something that works on mac & linux
# TODO(ebrown): Install a specific version of rust/cargo
# TODO(ebrown): Tweak khan startup scripts instead of rustup-init doing it

import subprocess

# M1 requires we run under rosetta, thus /usr/local/bin/brew
# The same command works for both intel & M1 macs
subprocess.run(
    ['arch', '-x86_64', '/usr/local/bin/brew', 'install', 'rustup-init'],
    check=True)
subprocess.run(['rustup-init', '-y', '-t', 'wasm32-wasi', '--no-modify-path'],
               check=True)
