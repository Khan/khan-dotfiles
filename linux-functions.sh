#!/bin/sh
# This is largely a copy of linux-setup.sh
# TODO(ericbrown): Reduce code redundancy by refactoring to share code

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

# NOTE: if you add a package here, check if you should also add it
# to webapp's Dockerfile.
install_packages() {
    updated_apt_repo=""

    # This is needed to get the add-apt-repository command.
    # apt-transport-https may not be strictly necessary, but can help
    # for future updates.
    sudo apt-get install -y software-properties-common apt-transport-https

    # To get the most recent nodejs, later.
    if ls /etc/apt/sources.list.d/ 2>&1 | grep -q chris-lea-node_js; then
        # We used to use the (obsolete) chris-lea repo, remove that if needed
        sudo add-apt-repository -y -r ppa:chris-lea/node.js
        sudo rm -f /etc/apt/sources.list.d/chris-lea-node_js*
        updated_apt_repo=yes
    fi
    if ! ls /etc/apt/sources.list.d/ 2>&1 | grep -q nodesource || \
       ! grep -q node_12.x /etc/apt/sources.list.d/nodesource.list; then
        # This is a simplified version of https://deb.nodesource.com/setup_12.x
        wget -O- https://deb.nodesource.com/gpgkey/nodesource.gpg.key | sudo apt-key add -
        cat <<EOF | sudo tee /etc/apt/sources.list.d/nodesource.list
deb https://deb.nodesource.com/node_12.x `lsb_release -c -s` main
deb-src https://deb.nodesource.com/node_12.x `lsb_release -c -s` main
EOF
        sudo chmod a+rX /etc/apt/sources.list.d/nodesource.list

        # Pin nodejs to 12.x, otherwise apt will update newer Ubuntu versions
        cat <<EOF | sudo tee /etc/apt/preferences.d/nodejs
Package: nodejs
Pin: version 12.*
Pin-Priority: 999
EOF
        updated_apt_repo=yes
    fi

    # To get the most recent git, later.
    if ! ls /etc/apt/sources.list.d/ 2>&1 | grep -q git-core-ppa; then
        sudo add-apt-repository -y ppa:git-core/ppa
        updated_apt_repo=yes
    fi

    # To get chrome, later.
    if [ ! -s /etc/apt/sources.list.d/google-chrome.list ]; then
        echo "deb http://dl.google.com/linux/chrome/deb/ stable main" \
            | sudo tee /etc/apt/sources.list.d/google-chrome.list
        wget -O- https://dl-ssl.google.com/linux/linux_signing_key.pub \
            | sudo apt-key add -
        updated_apt_repo=yes
    fi

    # Register all that stuff we just did.
    if [ -n "$updated_apt_repo" ]; then
        sudo apt-get update -qq -y || true
    fi

    # This is needed for ubuntu >=20, but not prior ones.
    sudo apt-get install -y python-is-python2 || true

    # Install pip manually.
    curl https://bootstrap.pypa.io/get-pip.py --output get-pip.py
    sudo python2 get-pip.py
    # Delete get-pip.py after we're finish running it.
    rm -f get-pip.py
    # Match webapp's version version.
    sudo pip install pip==20.1.1

    # Install virtualenv and pychecker manually; ubuntu
    # dropped support for them in ubuntu >=20 (since they're python2)
    sudo pip install virtualenv==20.0.23

    # We do not have pychecker on the mac (in /usr/local or virtualenv)
    # Current install creates a broken /usr/local/bin/pychecker
    #sudo pip install http://sourceforge.net/projects/pychecker/files/pychecker/0.8.19/pychecker-0.8.19.tar.gz/download

    # Needed to develop at Khan: git, python, node (js).
    # php is needed for phabricator
    # lib{freetype6{,-dev},{png,jpeg}-dev} are needed for PIL
    # imagemagick is needed for image resizing and other operations
    # lib{xml2,xslt}-dev are needed for lxml
    # libyaml-dev is needed for pyyaml
    # libncurses-dev and libreadline-dev are needed for readline
    # nginx is used as a devserver proxy that serves static files
    # nodejs is used for various frontendy stuff in webapp, as well as our js
    #   services. We standardize on version 12 (the latest version suppported
    #   on appengine standard).
    # redis is needed to run memorystore on dev
    # unzip is needed for other scripts
    # tree sysdig docker iftop tcpflow are for diagnostics
    # cargo is for rust / fastly
    # python-dev supplies Python.h for things built by setup.sh (but why?)
    # libncurses-dev is needed to build the readline we want
    # python3-pip pipenv is required
    # yarnpkg is the new node pkg mgr
    # TODO(benkraft): Pull the version we want from webapp somehow.
    # curl for various scripts (including setup.sh)
    sudo apt-get install -y git \
        python-dev \
        python-mode python-setuptools \
        libfreetype6 libfreetype6-dev libpng-dev libjpeg-dev \
        imagemagick \
        libxslt1-dev \
        libyaml-dev \
        libncurses-dev libreadline-dev \
        nodejs=12* \
        nginx \
        redis-server \
        curl \
        jq \
        unzip tree sysdig docker iftop tcpflow \
        cargo cargo-doc \
        python-dev \
        gcc \
        python3-pip pipenv

    # There are two different php packages, depending on if you're on Ubuntu
    # 14.04 LTS or 16.04 LTS, and neither version has both.  So we just try
    # both of them.  In 16.04+, php-xml is also a separate package, which we
    # need too.
    sudo apt install -y php-cli php-curl php-xml || sudo apt-get install -y php5-cli php5-curl

    # We need npm 6 or greater to support node12.  That's the default
    # for nodejs, but we may have overridden it before in a way that
    # makes it impossible to upgrade, so we reinstall nodejs if our
    # npm version is 5.x.x.
    if expr "`npm --version`" : 5 >/dev/null 2>&1; then
        sudo apt-get purge -y nodejs
        sudo apt-get install -y "nodejs=12*"
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
    # We need npm 6 or greater to support node12. This is a particular npm6
    # version known to work.
    sudo npm install -g npm@6.14.4
    sudo npm install -g yarn

    # Not technically needed to develop at Khan, but we assume you have it.
    sudo apt-get install -y unrar virtualbox ack-grep

    # Not needed for Khan, but useful things to have.
    sudo apt-get install -y ntp abiword curl diffstat expect gimp \
        mplayer netcat netpbm screen w3m vim emacs google-chrome-stable

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
}

install_slack() {
    # Get the latest slack deb file and install it.
    if ! which slack >/dev/null 2>&1 ; then
        case `uname -m` in
            *86) arch=i386;;
            x86_64) arch=amd64;;
            *) echo "WARNING: Cannot install slack: no client for `uname -m`";;
        esac
        if [ -n "$arch" ]; then
            sudo apt-get install -y gconf2 gconf-service libgtk2.0-0 libappindicator1
            rm -rf /tmp/slack.deb
            deb_url="$(wget -O- https://slack.com/downloads/instructions/ubuntu | grep -o 'https.*\.deb' | head -n1)"
            if [ -n "$deb_url" ]; then
                wget -O/tmp/slack.deb "$deb_url" || echo "WARNING: Cannot install slack: couldn't download $deb_url"
                sudo dpkg -i /tmp/slack.deb
            else
                echo "WARNING: Cannot install slack: couldn't find .deb URL"
            fi
        fi
    fi
}

install_protoc() {
    # The linux and mac installation process is the same aside from the
    # platform-dependent zip archive.
    install_protoc_common https://github.com/google/protobuf/releases/download/v3.4.0/protoc-3.4.0-linux-x86_64.zip
}

install_watchman() {
    if ! which watchman ; then
        update "Installing watchman..."
        builddir="$DEVTOOLS_DIR/watchman/"
        if [ ! -d "$builddir" ]; then
            mkdir -p "$builddir"
            git clone https://github.com/facebook/watchman.git "$builddir"
        fi

        (
            # Adapted from https://medium.com/@saurabh.friday/install-watchman-on-ubuntu-18-04-ba23c56eb23a
            cd "$builddir"
            sudo apt-get install -y autoconf automake build-essential python-dev libtool libssl-dev
            git checkout tags/v4.9.0
            ./autogen.sh
            # --enable-lenient is required for newer versions of GCC, which is
            # stricter with certain constructs.
            ./configure --enable-lenient
            make
            sudo make install
        )
    fi
}

install_postgresql() {
    # postgresql-12 (not 11) is in normal repos for 20.04
    # TODO(ericbrown): We do WANT postgresql-11 - INFRA-5679

    #sudo apt-get remove postgresql-11 postgresql-13 postgresql-client-11 postgresql-client-12 postgresql-client-13
    #sudo apt-get remove postgresql-client-common postgresql-common

    # Instructions taken from
    # https://pgdash.io/blog/postgres-11-getting-started.html
    # Postgres 11 is not available in 18.04, so we need to add the pg apt repository.
    #curl -s https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
    #sudo add-apt-repository -y "deb http://apt.postgresql.org/pub/repos/apt/ `lsb_release -c -s`-pgdg main"
    #sudo apt-get update

    POSTGRESQL_VERSION=12
    echo "Installing postgresql-${POSTGRESQL_VERSION}"
    sudo apt-get install -y postgresql-${POSTGRESQL_VERSION} postgresql-contrib libpq-dev

    # Set up authentication to allow connections from the postgres user with no
    # password. This matches the authentication setup that homebrew installs on
    # a mac. Unlike a mac, we do not need to create a postgres user manually.
    # We are doing this with a here-document because paths are different when
    # this is called from packer scripts.
    sudo cp "/etc/postgresql/${POSTGRESQL_VERSION}/main/pg_hba.conf" \
            "/etc/postgresql/${POSTGRESQL_VERSION}/main/pg_hba.conf.bak"
    sudo tee /etc/postgresql/${POSTGRESQL_VERSION}/main/pg_hba.conf >/dev/null <<EOF
# We allow any connection by the postgres user to local addresses, without a
# password.

# TYPE  DATABASE        USER            ADDRESS                 METHOD
# "local" is for Unix domain socket connections only
local   all             postgres                              trust
local   all             vagrant                               trust

# IPv4 local connections:
host    all             postgres      127.0.0.1/32            trust
# IPv6 local connections:
host    all             postgres      ::1/128                 trust
EOF

    sudo chown postgres.postgres "/etc/postgresql/${POSTGRESQL_VERSION}/main/pg_hba.conf"
    sudo service postgresql restart
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
