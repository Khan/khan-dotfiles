# kabuild-image

## Overview

This is an experimental image meant to replace the "base" image in webapp. 
It is purely ubuntu 22.04 with the goal to encapsulate all developer tooling
required to run webapp's "make deps". As tooling required to do that is
defined mostly in khan-dotfiles, this is where we are defining the image.

## Versioning

We are using semantic versioning starting with 1.0.0. Versions are created
by a developer manually creating a git-tag containing the semantic version.

## Why skaffold

skaffold is a framework for building and deployment that is a bit opionated.
When using defaults (which aren't necessarily exactly the way Khan typically
does things), it also simplifies aspects of build and deployment. Thus, we
are attempting to use skaffold instead of calling docker (or even make in
most cases).

The only skaffold command we're really using here is "skaffold build"

## Why NOT linux-setup.sh

linux-setup.sh & linux-functions.sh could possibly be used instead of
doing things explicity in the Dockerfile. But that was tried and there was
quite a bit to debug. And in the long term, DevOps anticipates that all
services are built with relatively simple containers instead of a mega
kabuild kitchen-sink container like this one. Thus, the effort to debug
scripts is minimal value. Others are welcome to put in the effort.

## Building

To build locally, run: skaffold build

To build remotely, run: skaffold build -p cloudbuild

## Tagging and building releases

Once pushed to master, a developer should tag that version of master
with an appropriate semantic version (i.e. 1.3.5), push the tag and 
then run "make build" locally. That will build the semantic version
and push it to the container repository.

## Other Usage

Please see "make help"

## Remote Use

TBD - i.e. Using "skaffold run" with an appropriate persistent
volume, claim and appropriate ssh-key mapping outght to make remote
development in kubernetes quite realistic. However, ideally this would
be bootstrapped with another container that has the most recent webapp
repo and run "make deps", etc. (This may be somewhat trivial with a
webhook or nightly task.)
