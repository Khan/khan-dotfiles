#!/bin/sh

# This installs binaries that you need to develop at Khan Academy.
# The OS-independent setup.sh assumes all this stuff has been
# installed.

# Bail on any errors
set -e

# Install in $HOME by default, but can set an alternate destination via $1.
ROOT=${1-$HOME}
mkdir -p "$ROOT"

# the directory all repositories will be cloned to
REPOS_DIR="$ROOT/khan"

# derived path location constants
DEVTOOLS_DIR="$REPOS_DIR/devtools"

# Load shared setup functions.
. "$DEVTOOLS_DIR"/khan-dotfiles/shared-functions.sh

trap exit_warning EXIT   # from shared-functions.sh

install_java() {
    sudo apt-get install -y openjdk-11-jdk
    # We ask you to select a java version (interactively) in case you have more
    # than one installed.  If there's only one, it'll just select that version
    # by default.
    sudo update-alternatives --config java
    sudo update-alternatives --config javac
}

install_go() {
    if ! has_recent_go; then   # has_recent_go is from shared-functions.sh
        # This PPA is needed for ubuntus <20 but not >=20
        # (and it doesn't install for them anyway)
        sudo add-apt-repository -y ppa:longsleep/golang-backports && sudo apt-get update -qq -y || sudo add-apt-repository -y -r ppa:longsleep/golang-backports
        sudo apt-get install -y "golang-$DESIRED_GO_VERSION"
        # The ppa installs go into /usr/lib/go-<version>/bin/go
        # Let's link that to somewhere likely to be on $PATH
        sudo cp -sf /usr/lib/"go-$DESIRED_GO_VERSION"/bin/* /usr/local/bin/
    else
        echo "golang already installed"
    fi
}

# Builds and installs `mkcert` which is used by the following things in
# webapp:
# - https://khanacademy.dev
# - the "Vitejs Directly" option in the dev support bar
#
# NOTE: This depends on `go` being installed.
install_mkcert() {
    if ! which mkcert >/dev/null; then
        update "Installing mkcert..."
        builddir=$(mktemp -d -t mkcert.XXXXX)
        git clone https://github.com/FiloSottile/mkcert "$builddir"

        (
            cd "$builddir"
            go mod download
            go build -ldflags "-X main.Version=$(git describe --tags)"
            sudo install -m 755 mkcert /usr/local/bin
        )

        # cleanup temporary build directory
        rm -rf "$builddir"

        mkcert -install

        echo "You have installed mkcert (used to make khanacademy.dev and "
        echo "'Vitejs Directly' on localhost:8088 work)."
        echo ""
        echo "A CA has been added to your system and browser certificate "
        echo "trust stores."
        echo ""
        echo "You must RESTART your browser in order for it to recognize "
        echo "the new CA and in some situations you may need REBOOT your "
        echo "machine."
    else
        echo "mkcert already installed"
    fi
}

# NOTE: if you add a package here, check if you should also add it
# to webapp's Dockerfile.
install_packages() {
    updated_apt_repo=""

    # This is needed to get the add-apt-repository command.
    # apt-transport-https may not be strictly necessary, but can help
    # for future updates.
    sudo apt-get install -y software-properties-common apt-transport-https \
         wget gnupg

    # To get the most recent nodejs, later.
    if ls /etc/apt/sources.list.d/ 2>&1 | grep -q chris-lea-node_js; then
        # We used to use the (obsolete) chris-lea repo, remove that if needed
        sudo add-apt-repository -y -r ppa:chris-lea/node.js
        sudo rm -f /etc/apt/sources.list.d/chris-lea-node_js*
        updated_apt_repo=yes
    fi
    if ! ls /etc/apt/sources.list.d/ 2>&1 | grep -q nodesource || \
       ! grep -q node_20.x /etc/apt/sources.list.d/nodesource.list; then
        # This is a simplified version of https://deb.nodesource.com/setup_20.x
        sudo mkdir -p /usr/share/keyrings
        sudo rm -f /usr/share/keyrings/nodesource.gpg
        sudo rm -f /etc/apt/sources.list.d/nodesource.list
        curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /usr/share/keyrings/nodesource.gpg
        cat <<EOF | sudo tee /etc/apt/sources.list.d/nodesource.list
deb [signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main
EOF
        sudo chmod a+rX /etc/apt/sources.list.d/nodesource.list

        # Pin nodejs to the version-specific nodesource repo, otherwise apt might update
        # it in newer Ubuntu versions
        cat <<EOF | sudo tee /etc/apt/preferences.d/nodejs
Package: nodejs
Pin: origin deb.nodesource.com
Pin-Priority: 999
EOF
        updated_apt_repo=yes
    fi

    # To get the most recent git, later.
    if ! ls /etc/apt/sources.list.d/ 2>&1 | grep -q git-core-ppa; then
        sudo add-apt-repository -y ppa:git-core/ppa
        updated_apt_repo=yes
    fi

    # To get the most recent python, later.
    if ! ls /etc/apt/sources.list.d/ 2>&1 | grep -q deadsnakes; then
        sudo add-apt-repository -y ppa:deadsnakes/ppa
        updated_apt_repo=yes
    fi

    # To get chrome, later.
    if [ ! -s /etc/apt/sources.list.d/google-chrome.list ]; then
        wget -O- https://dl-ssl.google.com/linux/linux_signing_key.pub \
            | sudo gpg --no-default-keyring --keyring /etc/apt/keyrings/google-chrome.gpg --import
        echo 'deb [signed-by=/etc/apt/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main' \
            | sudo tee /etc/apt/sources.list.d/google-chrome.list
        updated_apt_repo=yes
    fi


    # Register all that stuff we just did.
    if [ -n "$updated_apt_repo" ]; then
        sudo apt-get update -qq -y || true
    fi

    # Python3 is needed to run the python services (e.g. ai-guide-core).
    # We are on python3.11 now
    sudo apt-get install -y python3.11 python3.11-venv

    # Install curl for setup script usage
    sudo apt-get install -y curl

    # Needed to develop at Khan: git, node (js).
    # lib{freetype6{,-dev},{png,jpeg}-dev} are needed for PIL
    # imagemagick is needed for image resizing and other operations
    # lib{xml2,xslt}-dev are needed for lxml
    # libyaml-dev is needed for pyyaml
    # libncurses-dev and libreadline-dev are needed for readline
    # nodejs is used for various frontendy stuff in webapp, as well as our js
    #   services. We standardize on version 16.
    # redis is needed to run memorystore on dev
    # libnss3-tools is a pre-req for mkcert, see install_mkcert for details.
    # python3-venv is needed for the deploy virtualenv
    # cargo is needed to run fastly-khancademy-dev
    # docker is needed to run dev/server, lsof and uuid-runtime to run hotel
    # TODO(benkraft): Pull the version we want from webapp somehow.
    sudo apt-get install -y git \
        libfreetype6 libfreetype6-dev libpng-dev libjpeg-dev \
        imagemagick \
        libxslt1-dev \
        libyaml-dev \
        libncurses-dev libreadline-dev \
        nodejs \
        redis-server \
        unzip \
        jq \
        libnss3-tools \
        python3-dev python3-setuptools python3-pip python3-venv \
        python-is-python3 \
        cargo cargo-doc \
        docker lsof uuid-runtime

    # We need npm 8 or greater to support node16.  That's the default
    # for nodejs, but we may have overridden it before in a way that
    # makes it impossible to upgrade, so we reinstall nodejs if our
    # npm version is 5.x.x, 6.x.x, or 7.x.x.
    if expr "`npm --version`" : '5\|6\|7' >/dev/null 2>&1; then
        sudo apt-get purge -y nodejs
        sudo apt-get install -y "nodejs"
    fi

    # Ubuntu installs as /usr/bin/nodejs but the rest of the world expects
    # it to be `node`.
    if ! [ -f /usr/bin/node ] && [ -f /usr/bin/nodejs ]; then
        sudo ln -s /usr/bin/nodejs /usr/bin/node
    fi

    # Ubuntu's nodejs doesn't install npm, but if you get it from the PPA,
    # it does (and conflicts with the separate npm package).  So install it
    # if and only if it hasn't been installed already.
    if ! which npm >/dev/null 2>&1 ; then
        sudo apt-get install -y npm
    fi
    # Make sure we have the preferred version of npm
    # TODO(benkraft): Pull this version number from webapp somehow.
    # We need npm 8 or greater to support node16. This is a particular npm8
    # version known to work.
    sudo npm install -g npm@8.11.0

    # Not technically needed to develop at Khan, but we assume you have it.
    sudo apt-get install -y unrar ack-grep

    # Not needed for Khan, but useful things to have.
    sudo apt-get install -y ntp abiword diffstat expect gimp \
         mplayer netcat iftop tcpflow netpbm screen w3m \
         vim emacs google-chrome-stable

    # If you don't have the other ack installed, ack is shorter than ack-grep
    # This might fail if you already have ack installed, so let it fail silently.
    sudo dpkg-divert --local --divert /usr/bin/ack --rename --add \
        /usr/bin/ack-grep || echo "Using installed ack"

    # Needed to install printer drivers, and to use the printer scanner
    sudo apt-get install -y apparmor-utils xsane

    # We use java for our google cloud dataflow jobs that live in webapp
    # (as well as in khan-linter for linting those jobs)
    install_java

    # We use go for our code, going forward
    install_go

    # Used to create and install security certificates, see the docstring
    # for this function for more details.
    install_mkcert
}

install_watchman() {
    if ! which watchman ; then
        update "Installing watchman..."

        # First try installing via apt package, which exists in the repositories
        # as of Ubuntu 20.04.
        sudo apt-get install -y watchman || true
    fi

    if ! which watchman ; then
        # If installing the package didn't work, then install from source.
        builddir=$(mktemp -d -t watchman.XXXXX)
        git clone https://github.com/facebook/watchman.git "$builddir"

        (
            # Adapted from https://medium.com/@saurabh.friday/install-watchman-on-ubuntu-18-04-ba23c56eb23a
            cd "$builddir"
            sudo apt-get install -y autoconf automake build-essential libtool libssl-dev
            git checkout tags/v4.9.0
            ./autogen.sh
            # --enable-lenient is required for newer versions of GCC, which is
            # stricter with certain constructs.
            ./configure --enable-lenient
            make
            sudo make install
        )

        # cleanup temporary build directory
        sudo rm -rf "$builddir"
    fi
}

install_postgresql() {
    # Instructions taken from
    # https://pgdash.io/blog/postgres-11-getting-started.html
    # and
    # https://wiki.postgresql.org/wiki/Apt
    # Postgres 11 is not available in 18.04, so we need to add the pg apt repository.
    curl https://www.postgresql.org/media/keys/ACCC4CF8.asc \
        | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/apt.postgresql.org.gpg >/dev/null

    sudo add-apt-repository -y "deb http://apt.postgresql.org/pub/repos/apt/ `lsb_release -c -s`-pgdg main"
    sudo apt-get update
    sudo apt-get install -y postgresql-14

    # Set up authentication to allow connections from the postgres user with no
    # password. This matches the authentication setup that homebrew installs on
    # a mac. Unlike a mac, we do not need to create a postgres user manually.
    sudo cp -av postgresql/pg_hba.conf "/etc/postgresql/14/main/pg_hba.conf"
    sudo chown postgres.postgres "/etc/postgresql/14/main/pg_hba.conf"
    sudo service postgresql restart
}

install_fastly() {
    builddir=$(mktemp -d -t fastly.XXXXX)

    (
        cd "$builddir"
        # There's no need to update the version regularly, fastly self updates
        curl -LO https://github.com/fastly/cli/releases/download/v3.3.0/fastly_3.3.0_linux_amd64.deb
        sudo apt install ./fastly_3.3.0_linux_amd64.deb
    )

    # cleanup temporary build directory
    sudo rm -rf "$builddir"
}

setup_clock() {
    # This shouldn't be necessary, but it seems it is.
    if ! grep -q 3.ubuntu.pool.ntp.org /etc/ntp.conf; then
        sudo service ntp stop
        sudo ntpdate 0.ubuntu.pool.ntp.org 1.ubuntu.pool.ntp.org \
            2.ubuntu.pool.ntp.org 3.ubuntu.pool.ntp.org
        sudo service ntp start
    fi
}

config_inotify() {
    # webpack gets sad on webapp if it can only watch 8192 files (which is the
    # ubuntu default).
    echo fs.inotify.max_user_watches=524288 | sudo tee -a /etc/sysctl.conf && sudo sysctl -p
}

echo
echo "Running Khan Installation Script 1.1"
echo
# We grep -i to have a good chance of catching flavors like Xubuntu.
if ! lsb_release -is 2>/dev/null | grep -iq ubuntu ; then
    echo "This script is mostly tested on Ubuntu;"
    echo "other distributions may or may not work."
fi

if ! echo "$SHELL" | grep -q '/bash$' ; then
    echo
    echo "It looks like you're using a shell other than bash!"
    echo "Other shells are not officially supported.  Most things"
    echo "should work, but dev-support help is not guaranteed."
fi

# Run sudo once at the beginning to get the necessary permissions.
echo "This setup script needs your password to install things as root."
sudo sh -c 'echo Thanks'

install_packages
install_watchman
setup_clock
config_inotify
install_postgresql
install_fastly
# TODO (boris): Setup pyenv (see mac_setup:install_python_tools)
# https://opencafe.readthedocs.io/en/latest/getting_started/pyenv/

"$DEVTOOLS_DIR"/khan-dotfiles/bin/edit-system-config.sh

trap - EXIT
