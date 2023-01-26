#!/usr/bin/env python3
"""Ensure postgres is installed nicely on mac."""

# This is also a prototype to understand what writing scripts in python3
# instead of shell looks like. The goal is easier debugability, testability and
# potential future code reuse. And we do not want a major porting effort, just
# a mechanism to slowly transition.

# First pass: Don't like flow compared to shell script, but easier to debug
# and exceptions better than set -e

# Catalina has a python3 binary, but it prompts users to install "stuff". It
# may be useful to use homebrew to install python3 before running python3
# scripts.

# TODO(ericbrown): Why do we support anything other than postgresql@14 ?
# TODO(ericbrown): mac-setup.sh used to tweak icu4c - obsolete now?

import os
import re
import subprocess
import time

SCRIPT = os.path.basename(__file__)
POSTGRES_FORMULA = 'postgresql@14'


def get_brewname():
    """Return the brew formula name currently installed or None."""
    result = subprocess.run(['brew', 'ls', POSTGRES_FORMULA],
                            capture_output=True)
    if result.returncode == 0:
        return POSTGRES_FORMULA

    # TODO(ericbrown): Remove when sure this is no longer needed
    # I believe this code is from when postgresql 11 was the current version
    result = subprocess.run(['brew', 'ls', 'postgres', '--versions'],
                            capture_output=True, text=True)
    if result.returncode == 0 and re.search(r'\s11\.\d', result.stdout):
        return "postgresql"

    # There is no postgresql installed
    return None


def link_postgres_if_needed(brewname: str, force=False):
    """Create symlinks in /usr/local/bin for postgresql (i.e. psql).

    Brew doesn't link non-latest versions on install. This command fixes that
    allowing postgresql and commands like psql to be found."""

    # TODO(ericbrown): If user has non-brew psql installed in PATH, WARN
    # TODO(ericbrown): Verify this psql is from brew's postgresql@14
    # If it is from postgresql@14 then we must either unlink or remove it
    result = subprocess.run(['which', 'psql'], capture_output=True)
    if force or result.returncode != 0:
        print(f'{SCRIPT}: brew link {brewname}')
        # We unlink first because 'brew link' returns non-0 if already linked
        subprocess.run(['brew', 'unlink', brewname],
                       stdout=subprocess.DEVNULL)
        subprocess.run(['brew',
                        'link', '--force', '--overwrite', '--quiet',
                        brewname],
                       check=True, stdout=subprocess.DEVNULL)


def install_postgres(brewname: str) -> None:
    print(f'Installing {brewname}')
    subprocess.run(['brew', 'install', brewname], check=True)
    link_postgres_if_needed(brewname, force=True)


def is_postgres_running(brewname: str) -> bool:
    result = subprocess.run(['brew', 'services', 'list'],
                            capture_output=True, text=True)
    return (result.returncode == 0 and
            any(brewname in lst and 'started' in lst
                for lst in result.stdout.splitlines()))


def start_postgres(brewname: str) -> None:
    """Postgres must be running for us to create the postgres user."""
    print(f'{SCRIPT}: Starting postgresql service')
    subprocess.run(['brew', 'services', 'start', brewname], check=True)
    time.sleep(5)  # Give postgres a chance to start up before we connect


def does_postgres_user_exist() -> bool:
    """Return True if the 'postgres' user exists in postgres."""
    result = subprocess.run(['psql',
                             '-tc', 'SELECT rolname from pg_catalog.pg_roles',
                             'postgres'],
                            capture_output=True, check=True, text=True)
    return 'postgres' in result.stdout


def create_postgres_user() -> None:
    print(f'{SCRIPT}: Creating postgres user')
    subprocess.run(['psql', '--quiet', '-c',
                    'CREATE ROLE postgres LOGIN SUPERUSER;', 'postgres'],
                   check=True)


def setup_postgres() -> None:
    """Install verson of postgresql we want for mac development with homebrew
    on catalina and later."""

    print(f'{SCRIPT}: Ensuring postgres (usually 14) is installed and running')
    brewname = get_brewname()
    if not brewname:
        brewname = POSTGRES_FORMULA
        install_postgres(brewname)
    else:
        # Sometimes postgresql gets unlinked if dev is tweaking their env
        # Force in case user has another version of postgresql installed too
        link_postgres_if_needed(brewname, force=True)

    if not is_postgres_running(brewname):
        start_postgres(brewname)

    if not does_postgres_user_exist():
        create_postgres_user()

    print()
    print(f'{SCRIPT}: {brewname} installed and running')


if __name__ == '__main__':
    setup_postgres()
