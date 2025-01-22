# This is meant to be a base image for building (and possibly running) webapp.
# It implements most of linux-setup.sh.

# Warning: We're using a number of "deprecated" packages and moving past 22.04
# is likely non-trivial.
FROM ubuntu:22.04

# TODO: Use linux-setup.sh for everything.
# Warning: I hit a number of snags trying to use linux-setup.sh directly.

RUN apt-get update && apt-get install -y \
    curl \
    git \
    jq \
    make \
    curl \
    unzip \
    net-tools \
    telnet \
    wget \
    screen \
    tree \
    netcat \
    strace \
    tcpdump \
    tcpflow \
    sudo \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg

# We're in a container. We aren't root just to avoid stupid mistakes.
# But we want to be root easily if needed.
RUN echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# TODO: Lock down google-sdk version as we do elsewhere.

# Install google-sdk repo
RUN curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
RUN echo "deb https://packages.cloud.google.com/apt cloud-sdk main" >> /etc/apt/sources.list.d/google-cloud-sdk.list
# Install golang repo
RUN add-apt-repository -y ppa:longsleep/golang-backports
RUN add-apt-repository -y -r ppa:chris-lea/node.js
RUN add-apt-repository -y ppa:git-core/ppa

RUN wget -O- https://deb.nodesource.com/gpgkey/nodesource.gpg.key | sudo apt-key add -
RUN echo deb https://deb.nodesource.com/node_16.x `lsb_release -c -s` main >> /etc/apt/sources.list.d/nodesource.list
RUN echo deb-src https://deb.nodesource.com/node_16.x `lsb_release -c -s` main >> /etc/apt/sources.list.d/nodesource.list
RUN chmod a+rX /etc/apt/sources.list.d/nodesource.list
RUN echo "Package: nodejs" >> /etc/apt/preferences.d/nodejs
RUN echo "Pin: version 16.*" >> /etc/apt/preferences.d/nodejs
RUN echo "Pin-Priority: 999" >> /etc/apt/preferences.d/nodejs

# Update indexes
RUN apt-get update

# Install google cloud sdk
RUN apt-get install -y \
    google-cloud-sdk \
    openjdk-11-jdk \
    nodejs \
    watchman

# TODO: Get version from common location
# WARNING: We REALLY WANT to avoid requring make and/or break standalone skaffold.
ENV DESIRED_GO_VERSION=1.21
RUN apt-get install -y golang-${DESIRED_GO_VERSION}
RUN cp -sf /usr/lib/go-${DESIRED_GO_VERSION}/bin/* /usr/local/bin/

RUN apt-get install -y \
        libfreetype6 libfreetype6-dev libpng-dev libjpeg-dev \
        imagemagick \
        libxslt1-dev \
        libyaml-dev \
        libncurses-dev libreadline-dev \
        redis-server \
        libnss3-tools \
        python3-pip

RUN pip3 install -q pipenv
RUN npm install -g yarn
# Install pnpm, following:
# https://pnpm.io/installation
RUN wget -qO- https://get.pnpm.io/install.sh | ENV="$HOME/.bashrc" SHELL="$(which bash)" bash -

# protoc
RUN mkdir -p /tmp/protoc
RUN wget -O /tmp/protoc/protoc-3.4.0.zip https://github.com/google/protobuf/releases/download/v3.4.0/protoc-3.4.0-linux-x86_64.zip
WORKDIR /tmp/protoc
RUN unzip -q protoc-3.4.0.zip
RUN install -m755 ./bin/protoc /usr/local/bin
RUN rm -rf /usr/local/include/google/protobuf
RUN mkdir -p /usr/local/include/google
RUN mv ./include/google/protobuf /usr/local/include/google/
RUN chmod -R a+rX /usr/local/include/google/protobuf
WORKDIR /root
RUN rm -rf /tmp/protoc

WORKDIR /root

ENV GROUP_NAME=khandev
ENV USER_NAME=khandev
RUN addgroup --gid 1001 ${GROUP_NAME}
# To set password to "kabuild", add -p padco2M.JnJHY
RUN useradd -ms /bin/bash --uid 1001 --gid 1001 -G sudo ${USER_NAME}

RUN mkdir /tmp/fastly
RUN cd /tmp/fastly && \
    curl -LO https://github.com/fastly/cli/releases/download/v3.3.0/fastly_3.3.0_linux_amd64.deb && \
    apt install ./fastly_3.3.0_linux_amd64.deb
RUN rm -rf /tmp/fastly

USER ${USER_NAME}:${GROUP_NAME}
WORKDIR /home/${USER_NAME}

RUN mkdir -m 700 .ssh
RUN mkdir khan
RUN ssh-keyscan github.com >> ~/.ssh/known_hosts
COPY --chown=${USER_NAME}:${GROUP_NAME} .profile.khan .profile.khan
COPY --chown=${USER_NAME}:${GROUP_NAME} .bash_profile.khan .bash_profile.khan
COPY --chown=${USER_NAME}:${GROUP_NAME} .bashrc.khan .bashrc.khan
COPY --chown=${USER_NAME}:${GROUP_NAME} bash_profile.default .bash_profile
COPY --chown=${USER_NAME}:${GROUP_NAME} profile.default .profile
COPY --chown=${USER_NAME}:${GROUP_NAME} git-completion.bash git-completion.bash
COPY --chown=${USER_NAME}:${GROUP_NAME} .gitconfig.khan .gitconfig
COPY --chown=${USER_NAME}:${GROUP_NAME} . /home/${USER_NAME}/khan/devtools/khan-dotfiles/

COPY --chown=${USER_NAME}:${GROUP_NAME} bashrc.default bashrc.default
RUN cat bashrc.default .bashrc > .bashrc.new
RUN mv .bashrc.new .bashrc
RUN rm -f bashrc.default

CMD tail -f /dev/null
