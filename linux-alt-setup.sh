#!/usr/bin/env bash

set -e

# newestInstalledVersion returns the latest version for a given language from
# mise/asdf. It exists to avoid having to double write versions and maintain
# areas where the latest was always installed
newestInstalledVersion() {
    # TODO: verify versions are actually descending
    mise ls --json $1 | jq -r .[0].version
}

miseInstall() {
    lang=$1
    version=$2 # can be empty for latest
    mise install $lang@$version

    # Bridge logic, to help bridge between the older dotfiles approach and these
    # make all of the languages installed the global versions
    mise global $lang@$(newestInstalledVersion $lang)
}

# install_fastly ported from original
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

# config_inotify ported from original
config_inotify() {
    # webpack gets sad on webapp if it can only watch 8192 files (which is the
    # ubuntu default).
    sudo grep 'max_user_watches=524288' /etc/sysctl.conf
    if [ $? -eq 1 ]; then
        echo fs.inotify.max_user_watches=524288 | sudo tee -a /etc/sysctl.conf && sudo sysctl -p
    fi
}

install_protoc() {
    mise plugin add protoc https://github.com/paxosglobal/asdf-protoc.git
    mise install protoc
}

install_docker() {
    # From https://docs.docker.com/engine/installation/linux/debian/
    echo "===== Docker ====="
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources:
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
    sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo gpasswd -a ${USER} docker
}

# DIFF: Get mise which will manage our language and any supported tools
if ! [ -x "$(command -v mise)" ]; then
    curl https://mise.run | sh
    echo 'eval "$(~/.local/bin/mise activate)"' >> ~/.bashrc
fi

# initial apt
sudo apt-get install -y software-properties-common apt-transport-https \
    wget gnupg curl \
    git \
    libfreetype6 libfreetype6-dev libpng-dev libjpeg-dev \
    imagemagick \
    libxslt1-dev \
    libyaml-dev \
    libncurses-dev libreadline-dev \
    unzip \
    jq \
    libnss3-tools \
    lsof uuid-runtime

# Not needed for Khan, but useful things to have.
# DIFF: changed removed google-chrome (didn't wanna ppa), vim/emacs (left to users), netcat (package varied)
sudo apt-get install -y ntp abiword diffstat expect gimp \
     mplayer iftop tcpflow netpbm screen w3m

# Languages
miseInstall python 3.11
miseInstall rust
miseInstall nodejs
miseInstall java openjdk-11
miseInstall golang 1.22

# mkcert
if ! [ -x "$(command -v mkcert)" ]; then
    go install -ldflags "-X main.Version=$(go list -m filippo.io/mkcert@latest | awk '{print $2}')" filippo.io/mkcert@latest
    mkcert -install
fi

# SECTION END: by this point we've cover nearly all of what install_packages & install_rust covered
miseInstall protoc 3.4.0
sudo apt install -y watchman # removed fallback it exists in ubuntu and deb repos
config_inotify
install_fastly
install_docker

# DIFF: keeper wasn't install in the original, but seems no reason not to, and
# our pip is standardized as a non system version now so just install directly
pip install keepercommander==16.5.18
keeper version

# DIFF: I removed ack, so installing ripgrep (rg)
cargo install ripgrep

# TODO: deal with databases, postgres, redis, etc
