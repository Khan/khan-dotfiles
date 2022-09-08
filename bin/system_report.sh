#!/bin/bash

# This file represents the entrypoint of a tool create a report of the local
# development environment, for the purpose of identifying potential problems.

# Make a temporary file to dump the report into
tmpfile="$(mktemp -u  /tmp/system-report.XXXXXX).txt"
: >"$tmpfile"
echo "Putting report into tempfile ${tmpfile}"

# logging functions
header() {
    printf "\n\t%s:\n" "$1" >> "${tmpfile}"
}

kv() {
    printf "%-20s %s\n" "$1:" "$2" >> "${tmpfile}"
}

kv_multiline() {
    printf "%s\n%s\n\n" "$1:" "$2" >> "${tmpfile}"
}

tool_version_warning() {
    version=$1
    warning="$(grep -v '^#' bin/bad_versions.txt | grep "${version}" | sed 's/.* | //g')"
    if ! [ -z "$warning" ] ; then
        printf "\n!!! WARNING!!!\n\t %s" "${warning}" >> "${tmpfile}"
    fi
}

tool_version() {
    tool=$1
    version_cmd=$2
    if loc="$(which "${tool}")" ; then
        # If it's a link, show where it links to
        if [[ -L "${loc}" ]] ; then
            loc="${loc} -> $(readlink "${loc}")"
        fi
        version="$("${tool}" "${version_cmd}" 2>&1)"
        kv "${tool}" "${version} (${loc})"
        tool_version_warning "${version}"
    else
        kv "${tool}" "Not present!"
    fi
}


# System level information
header "System"
uname_os="$(uname -s)"
kv "OS" "${uname_os}"
kv "Release" "$(uname -r)"
kv "Hardware" "$(uname -m)"
kv "Hostname" "$(uname -n)"
kv "Version" "$(uname -v)"

# OSX Version
if [ "${uname_os}" = "Darwin" ]; then
    header "OSX"
    # Should be 10.15.x or 11.x
    osx_version=$(sw_vers -productVersion)
    kv "Version" "${osx_version}"
    if echo "$osx_version" | grep -q -v -e '^12' -e '^11' ; then 
        kv "!!! WARNING!!!" "Please update to OSX 12(Monterey)!!!"

    fi
fi

# Environmental information
header "Environment"
kv "User" "$(whoami)"
kv "Shell" "$SHELL"
kv "PATH" "$PATH"


# XCode, a big pain point on Mac
if [ "${uname_os}" = "Darwin" ]; then
    header "OSX - XCode"
    # DEV-245 - Should be 11.x
    kv_multiline "Xcode Version" "$(xcodebuild -version 2>&1)"
    kv_multiline "Avaliable Versions" "$(system_profiler SPDeveloperToolsDataType)"
fi

# TODO(dbraley): (A) check profile

header "GCC"
kv "LDFLAGS" "$LDFLAGS"
kv "LD_LIBRARY_PATH" "$LD_LIBRARY_PATH"
kv "CPPFLAGS" "$CPPFLAGS"
kv "CFLAGS" "$CFLAGS"

# Brew, another pain point on Mac
header "Brew"
tool_version brew --version
if which brew >/dev/null ; then
        kv_multiline "Brew Installs" "$(brew list --formula -l)"
        kv_multiline "Brew Services"  "$(brew services list)"
        kv_multiline "Brew Doctor Output" "$(brew doctor 2>&1)"
    fi

# TODO(dbraley): (m) check wget

header "Node/JS"
tool_version node --version
tool_version npm --version
tool_version yarn --version

header "Go"
tool_version go version
kv_multiline "Go ENV" "$(go env)"

header "Rust"
tool_version cargo --version

# This is multi-line, but it's still pretty readable. Good enough for now.
header "Fastly"
tool_version fastly version

header "PostgreSQL"
tool_version postgres --version
tool_version psql --version

# TODO(dbraley): (A) check nginx
# TODO(dbraley): (A) check redis
# TODO(dbraley): (A) check image_utils

header "Java"
tool_version java -version

# TODO(dbraley): (A) check protoc
# TODO(dbraley): (A) check watchman
# TODO(dbraley): (A) check mac apps

# Python tooling
header "Python"
tool_version python --version
tool_version python2 --version
tool_version python3 --version
tool_version pip --version
kv "VIRTUAL_ENV" "$VIRTUAL_ENV"
kv "sys.path" "$(python2 -c 'import sys; print sys.path')"

# TODO(dbraley): (l) check software-properties-common
# TODO(dbraley): (l) check apt-trasport-https
# TODO(dbraley): (l) check libfreetype etc
# TODO(dbraley): (l) check libncurses-dev, libreadline-dev
# TODO(dbraley): (l) check clock
# TODO(dbraley): (l) check inotify
# TODO(dbraley): (l) check curl

# GCloud
header "GCloud"
tool_version gcloud --version

# TODO(dbraley): (A) check repos

# Make sure the user can access the things they need
header "File Access Rights"
# DEV-246 - This should be empty
if [ -d "${VIRTUAL_ENV}" ] ; then
    kv_multiline "Root Owned VEnv Files" "$(find "$VIRTUAL_ENV" -user root -ls)"
fi

# TODO(dbraley): (m) check readline validity (DEV-242,238)
# TODO(dbraley): (A) check secrets.py validity (DEV-241)

header "SSH Config"
kv "SSH_AUTH_SOCK" "${SSH_AUTH_SOCK}"
kv_multiline "Fingerprints" "$(ssh-add -l)"

header "Git Config"
tool_version git --version
# DEV-232
kv "user.email" "$(git config user.email)"
kv "ssh access" "$(ssh -o StrictHostKeyChecking=no -o LogLevel=ERROR -o UserKnownHostsFile=/dev/null -T git@github.com 2>&1)"

header "Arcanist"
tool_version arc version

header "Required Tools"
# DEV-229
tool_version jq --version

header "OpenSSL"
tool_version openssl version

header "Routing"
kv_multiline "Hosts File" "$(cat /etc/hosts)"

header "Webapp"
# Allow user to specifiy WEBAPP_ROOT
: "${WEBAPP_ROOT:=$HOME/khan/webapp}"
kv "WEBAPP_ROOT" "$WEBAPP_ROOT"
if [ -d "$WEBAPP_ROOT" ]; then
    kv_multiline "make check_setup" "$( (cd "$WEBAPP_ROOT" && make check_setup) )"
    kv "Current Branch Trails Master by" "$(git --git-dir "$WEBAPP_ROOT"/.git rev-list --left-only --count origin/master...HEAD) commits"
    kv "Diverged from master at" "$(git --git-dir "$WEBAPP_ROOT"/.git show --pretty='https://github.com/Khan/webapp/commit/%h %cs' -q "$(git --git-dir "$WEBAPP_ROOT"/.git merge-base HEAD origin/master)")"
else
    kv "!!! WARNING !!!" "$WEBAPP_ROOT could not be found!"
fi
