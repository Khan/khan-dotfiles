#!/bin/sh

# Stop or remove anything specific to Khan Academy

# TODO(ericbrown): Do we want to disable redis & postgresql too? others?

HOME=/home/vagrant
chown -R vagrant.vagrant ${HOME}/.[a-z]*
