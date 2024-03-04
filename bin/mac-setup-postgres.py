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

# Ensure we are using the best "version" of brew
BREW86_PREFIX = "/usr/local/bin/"
BREW_PREFIX = "/opt/homebrew/bin/"
BREW_PREFIX = BREW_PREFIX if os.path.isdir(BREW_PREFIX) else BREW86_PREFIX
BREW = BREW_PREFIX + "brew"
PSQL = BREW_PREFIX + "psql"

SCRIPT = os.path.basename(__file__)
POSTGRES_FORMULA = 'postgresql@14'


def get_brewname():
    """Return the brew formula name currently installed or None."""
    result = subprocess.run([BREW, 'ls', POSTGRES_FORMULA],
                            capture_output=True)
    if result.returncode == 0:
        return POSTGRES_FORMULA

    # TODO(ericbrown): Remove when sure this is no longer needed
    # I believe this code is from when postgresql 11 was the current version
    result = subprocess.run([BREW, 'ls', 'postgres', '--versions'],
                            capture_output=True, text=True)
    if result.returncode == 0 and re.search(r'\s11\.\d', result.stdout):
        return "postgresql"

    # There is no postgresql installed
    return None


def link_postgres_if_needed(brewname, force=False):
    """Create symlinks in /usr/local/bin for postgresql (i.e. psql).

    Brew doesn't link non-latest versions on install. This command fixes that
    allowing postgresql and commands like psql to be found."""

    # TODO(ericbrown): If user has non-brew psql installed in PATH, WARN
    # TODO(ericbrown): Verify this psql is from brew's postgresql@14
    # If it is from postgresql@14 then we must either unlink or remove it
    result = subprocess.run(['which', PSQL], capture_output=True)
    if force or result.returncode != 0:
        print(f'{SCRIPT}: {BREW} link {brewname}')
        # We unlink first because 'brew link' returns non-0 if already linked
        subprocess.run([BREW, 'unlink', brewname],
                       stdout=subprocess.DEVNULL)
        subprocess.run([BREW,
                        'link', '--force', '--overwrite', '--quiet',
                        brewname],
                       check=True, stdout=subprocess.DEVNULL)


def install_postgres() -> None:
    # Install an older formula for postgres that is pinned to call icu4c 73.2 
    # as that is the latest node@16 supports.
    print('Downloading postgresql@14 with icu4c.rb 73.2 bindings')
    subprocess.run(['wget', '-O', '/tmp/postgresql@14.rb', 'https://raw.githubusercontent.com/Homebrew/homebrew-core/521c3b3f579cd4df16e0b85b26a49e47d2daf9c6/Formula/p/postgresql@14.rb'], check=True)
    print('Installing postgresql@14 with icu4c.rb 73.2 bindings')
    subprocess.run(['BREW', 'install', '/tmp/postgresql@14.rb'], check=True)
    link_postgres_if_needed('postgresql@14', force=True)
    # Reinstall icu4c 73.2 as it will have got updated to 74.2+ during the 
    # previous postgresql@14 install.
    print('Downloading icu4c.rb v73.2')
    subprocess.run(['wget', '-O', '/tmp/icu4c.rb', 'https://raw.githubusercontent.com/Homebrew/homebrew-core/74261226614d00a324f31e2936b88e7b73519942/Formula/i/icu4c.rb'], check=True)
    print('Reinstalling icu4c v73.2')
    my_env = os.environ.copy()
    # icu4c 73.2 formula wants to install latest postgres 14.11_1 but that wont
    # work and makes a circular dependency on installing icu4c so we skip the
    # check.
    my_env["HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK"] = "1"
    subprocess.run(['BREW', 'reinstall', '/tmp/icu4c.rb', '--force', '--skip-cask-deps'], check=True, env=my_env)


def is_postgres_running(brewname: str) -> bool:
    result = subprocess.run([BREW, 'services', 'list'],
                            capture_output=True, text=True)
    return (result.returncode == 0 and
            any(brewname in lst and 'started' in lst
                for lst in result.stdout.splitlines()))


def start_postgres(brewname: str) -> None:
    """Postgres must be running for us to create the postgres user."""
    print(f'{SCRIPT}: Starting postgresql service')
    subprocess.run([BREW, 'services', 'start', brewname], check=True)
    time.sleep(5)  # Give postgres a chance to start up before we connect


def does_postgres_user_exist() -> bool:
    """Return True if the 'postgres' user exists in postgres."""
    result = subprocess.run([PSQL,
                             '-tc', 'SELECT rolname from pg_catalog.pg_roles',
                             'postgres'],
                            capture_output=True, check=True, text=True)
    return 'postgres' in result.stdout


def create_postgres_user() -> None:
    print(f'{SCRIPT}: Creating postgres user')
    subprocess.run([PSQL, '--quiet', '-c',
                    'CREATE ROLE postgres LOGIN SUPERUSER;', 'postgres'],
                   check=True)


def setup_postgres() -> None:
    """Install verson of postgresql we want for mac development with homebrew
    on catalina and later."""

    print(f'{SCRIPT}: Ensuring postgres (usually 14) is installed and running')
    brewname = get_brewname()
    if not brewname:
        brewname = POSTGRES_FORMULA
        install_postgres()
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
