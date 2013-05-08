#!/bin/sh

# This has files that are used by Khan Academy developers.  This setup
# script is OS-agnostic; it installs things like dotfiles, python
# libraries, etc that are the same on Linux, OS X, maybe even cygwin.
# It is intended to be idempotent; you can safely run it multiple
# times.  It should be run from the root of the khan-dotfiles directory.


# Bail on any errors
set -e

# Install in $HOME by default, but can set an alternate destination via $1.
ROOT=${1-$HOME}
mkdir -p "$ROOT"


warnings=""

add_warning() {
    echo "WARNING: $*"
    warnings="$warnings\nWARNING: $*"
}

check_dependencies() {
    echo "Checking system dependencies"
    # We need git >=1.7.11 for '[push] default=simple'.
    if ! git --version | grep -q -e 'version 1.7.1[1-9]' \
                                 -e 'version 1.[89]' \
                                 -e 'version 2'; then
        echo "Must have git >= 1.8.  See http://git-scm.com/downloads"
        exit 1
    fi

    # You need to have run the setup to install binaries: node, npm/etc.
    if ! npm --version >/dev/null; then
        echo "You must install binaries before running $0.  See"
        echo "   https://sites.google.com/a/khanacademy.org/forge/for-khan-employees/-new-employees-onboard-doc/developer-setup"
        exit 1
    fi
}

install_dotfiles() {
    echo "Installing and updating dotfiles (.bashrc, etc)"
    # Most dotfiles are installed as symlinks.
    # (But we ignore .git which is actually part of the khan-dotfiles repo!)
    for file in `find .[!.]* -name .git -prune -o -type f -print`; do
        mkdir -p "$ROOT"/`dirname "$file"`
        source=`pwd`/"$file"
        dest="$ROOT/$file"
        if [ -h "$dest" -a "`readlink $dest`" = "$source" ]; then
            :
        elif [ -e "$dest" ]; then
            add_warning "Not symlinking to $dest because it already exists."
        else
            ln -sfvn "$source" "$dest"
        fi
    done

    # A few dotfiles are copied so the user can change them.  They all
    # have names like bashrc.default, which is installed as .bashrc.
    # They all have the property they 'include' khan-specific code.
    for file in *.default; do
        dest="$ROOT/.`echo "$file" | sed s/.default$//`"  # foo.default -> .foo
        ka_version=.`echo "$file" | sed s/default/khan/`  # .bashrc.khan
        if [ ! -e "$dest" ]; then
            cp -f "$file" "$dest"
        elif ! fgrep -q "$ka_version" "$dest"; then
            add_warning "$dest does not include $ka_version; see `pwd`/$file"
        fi
    done

}

edit_system_config() {
    echo "Modifying system configs: /etc/hosts, etc"
    # This will let you visit the khan academy homepage by just typing
    # www (or www/) into your browser's address bar, rather than
    # having to type www.khanacademy.org.
    if ! grep -q "search khanacademy.org" /etc/resolv.conf; then
        sudo sh -c 'echo "search khanacademy.org" >> /etc/resolv.conf'
    fi

    # This will let you use a url like exercises.ka.local
    if ! grep -q "ka.local" /etc/hosts; then
        # This 'sudo tee' trick is the way to redirect stdin within sudo.
        sudo tee -a /etc/hosts >/dev/null <<EOF 

# KA local servers
127.0.0.1       exercises.ka.local
::1             exercises.ka.local
127.0.0.1       stable.ka.local
::1             stable.ka.local
EOF
    fi

    # This command avoids the spew when you deploy the Khan Academy
    # appengine app:
    #   Cannot guess mime-type for XXX.  Using application/octet-stream
    line="application/octet-stream  less eot ttf woff otf as fla sjs flash tmpl"
    if [ -s /usr/local/etc/mime.types ]; then
        # Replace any existing line with 'less' and 'eot' with the new line.
        grep -v 'less eot' /usr/local/etc/mime.types | \
            sudo sh -c "cat; echo '$line' > /usr/local/etc/mime.types"
    else
        sudo sh -c 'echo "$line" > /usr/local/etc/mime.types' 
    fi

    # If there is no ssh key, make one.
    mkdir -p "$ROOT/.ssh"
    if [ ! -e "$ROOT/.ssh/id_rsa" -a ! -e "$ROOT/.ssh/id_dsa" ]; then
        ssh-keygen -q -N "" -t rsa -f "$ROOT/.ssh/id_rsa"
    fi
}

# $1: url of the repository to clone.  $2: directory to put repo, under $ROOT
clone_repo() {
    (
        mkdir -p "$ROOT/$2"
        cd "$ROOT/$2"
        dirname=`basename "$1"`
        if [ ! -d "$dirname" ]; then
            git clone "$1"
            cd `basename $1`
            git submodule update --init --recursive
        else
            cd `basename $1`
            # This 'git init' installs any new hooks we may have created.
            git init -q
        fi
    )
}

clone_repos() {
    echo "Cloning repositories, including the main 'webapp' repo"
    clone_repo ssh://khanacademy@khanacademy.kilnhg.com/Website/Group/webapp \
        khan/
    clone_repo git://github.com/Khan/kiln-review khan/devtools/
    clone_repo git://github.com/Khan/khan-linter khan/devtools/
    clone_repo git://github.com/Khan/libphutil khan/devtools/
    clone_repo git://github.com/Khan/arcanist khan/devtools/
    # For hg users
    (
        cd "$ROOT/khan/devtools"
        hg clone https://bitbucket.org/brendan/mercurial-extensions-rdiff || true

        mkdir -p kiln_extensions
        if [ ! -e kiln_extensions/kilnauth.py ]; then
            curl -s https://khanacademy.kilnhg.com/Tools/Downloads/Extensions \
                > /tmp/extensions.zip \
                && unzip -qo /tmp/extensions.zip kiln_extensions/kilnauth.py
        fi
    )
}

# Depends on khan-linter having been pulled first.
install_git_hooks() {
    echo "Installing git hooks"
    mkdir -p "$ROOT/.git_template/hooks"
    ln -snfv "$ROOT/khan/devtools/khan-linter/githook.py" \
             "$ROOT/.git_template/hooks/commit-msg"
}

install_mercurial_hooks() {
    echo "Installing mercurial hooks"
    # Create a dummy certificate to quiet mercurial and kiln
    mkdir -p "$ROOT/khan/devtools"
    if [ ! -s "$ROOT/khan/devtools/hg-dummy-cert.pem" ]; then
        yes "" | openssl req -new -x509 -extensions v3_ca -keyout /dev/null \
            -out "$ROOT/khan/devtools/hg-dummy-cert.pem" -days 3650 \
            -passout pass:pass >/dev/null 2>&1
    fi
}

# Must have cloned the repos first.
install_python_and_npm() {
    echo "Installing python and npm (javascript/node) libraries"
    # pip is a nicer installer/package manager than easy-install.
    sudo easy_install --quiet pip

    # Install non-khan-specific modules.
    sudo pip install -q Mercurial

    # Install virtualenv.
    # https://sites.google.com/a/khanacademy.org/forge/for-khan-employees/-new-employees-onboard-doc/developer-setup/using-virtualenv
    sudo pip install -q virtualenv
    if [ ! -d "$ROOT/.virtualenv/khan27" ]; then
        virtualenv -q --python="`which python2.7`" --no-site-packages \
            "$ROOT/.virtualenv/khan27"
    fi
    # Activate the virtualenv
    . ~/.virtualenv/khan27/bin/activate

    # Install all the requirements for khan, khan-exercises, and khan-linter.
    # This also installs npm deps.
    ( cd "$ROOT/khan/webapp" && make install_deps )
    ( cd "$ROOT/khan/webapp/khan-exercises" && pip install -r requirements.txt )
    ( cd "$ROOT/khan/devtools/khan-linter" && pip install -r requirements.txt )
}

install_ruby() {
    echo "Installing ruby libraries"
    # These are used by khan-exercises to pack exercises.
    # --conservative keeps gem from re-installing things that are
    # already installed, but the older gem that defaults on OS X
    # doesn't support it, so we do it manually.
    for package in json nokogiri uglifier therubyracer; do
        if ! gem list | grep -q "^$package"; then
            sudo gem install -q "$package"
        fi
    done
}

update_credentials() {
    echo "Updating information in your git and hg configs"
    # sed -i means 'replace in-place'
    if grep -q '%NAME_FIRST_LAST%' "$ROOT/.gitconfig" "$ROOT/.hgrc"; then
        read -p "Enter your full name (First Last): " name
        perl -pli -e "s/%NAME_FIRST_LAST%/$name/g" "$ROOT/.gitconfig" "$ROOT/.hgrc"
    fi

    if grep -q '%EMAIL%' "$ROOT/.gitconfig" "$ROOT/.hgrc"; then
        read -p "Enter your KA email, without the @khanacademy.org (e.g. $USER): " email
        perl -pli -e "s/%EMAIL%/$email/g" "$ROOT/.gitconfig" "$ROOT/.hgrc"
    fi
}


check_dependencies

# Run sudo once at the beginning to get the necessary permissions.
echo "This setup script needs your password to install things as root."
sudo sh -c 'echo Thanks'

install_dotfiles
edit_system_config
clone_repos
# These need the repos to exist (e.g. khan-linter), so come after that.
install_git_hooks
install_mercurial_hooks
install_python_and_npm
install_ruby
update_credentials


echo
echo "---------------------------------------------------------------------"

if [ -n "$warnings" ]; then
    echo "-- WARNINGS:"
    # echo is very inconsistent about whether it supports -e. :-( 
    echo "$warnings" | sed 's/\\n/\n/g'
else
    echo "DONE!"
fi

echo
echo "To finish your setup, go to"
echo "   https://sites.google.com/a/khanacademy.org/forge/for-khan-employees/-new-employees-onboard-doc/developer-setup"
