# 💻 🍎 🐧 khan-dotfiles 🐧 🍎 💻

This repository contains configuration files and setup scripts for
the Khan Academy web developer environment.  This includes a
variety of things, some very Khan-specific, some not, including:
- the [Khan linter](https://github.com/Khan/khan-linter)
- various `git` aliases, including for working with submodules
- tools needed to run a dev server for the Khan webapp
- other useful and "useful" miscellany

This is meant to complement the
[developer setup documentation](https://khanacademy.atlassian.net/wiki/x/VgKiC)
in EngDocs.  If you run into any problems with this script, contact
the Infrastructure team, such as by pinging `@dev-support` on Slack.

## Setup

Run the following commands:

    mkdir -p ~/khan/devtools
    cd ~/khan/devtools
    git clone https://github.com/Khan/khan-dotfiles.git
    cd khan-dotfiles
    make

This will install your system: installing executables, python
libraries, dotfiles, etc.  It will not overwrite any of your existing
dotfiles but will emit a warning if it sees something it doesn't
understand.

If you later need to fix up your setup, or get updates to it,
you can do:

    cd ~/khan/devtools/khan-dotfiles
    git pull
    make

This script is idempotent, so it should be safe to run it multiple
times.  We support macOS and Ubuntu, using `bash`, but other flavors
of Linux and other shells may work too.

## Hacking on `khan-dotfiles`

Pull requests, whether to fix bugs, or add new goodies, are welcome!
A few notes to keep in mind:

- If you make nontrivial changes to the setup script, make sure to
  test them!  The best way is to run the script on a blank VM, and
  check that `make check MAX_TEST_SIZE=tiny` passes.  See
  [EngDocs](https://docs.google.com/document/d/1KU70sbXOltXeS21DjoW_NpMfiHbrm_aONyZidA921lE/edit)
  for instructions on VM setup.
- Make sure to keep the script idempotent!  Running it on a working
  dev setup should avoid breaking anything.  You can keep it that way
  by making sure to no-op if a package is already installed or setup,
  and so on.

Ask in `#infrastructure-devops` if you have any questions, and thanks
for the contributions!

## Testing `khan-dotfiles` on Linux

It is easy to test the Khan-dotfiles on linux using a Docker container.
Use a command like `docker run -it ubuntu:22.04` to create a new
linux instance.  Then run:
```
# apt-get update
# apt-get install git sudo
# adduser testuser      # and fill in some random values
# adduser testuser sudo
# su - testuser
$ mkdir -p khan/devtools
$ cd khan/devtools
$ git clone https://github.com/Khan/khan-dotfiles
$ cd khan-dotfiles
$ make
```

## Credits

The `khan-dotfiles` are now maintained by the DevOps group within the
Infrastructure Team; ping them (e.g. `@dev-support` in Slack) if you
have any questions or run into problems.  They were originally
extracted from [David's dotfiles](http://github.com/divad12/dotfiles),
with commits and lines here and there stolen from
[Jamie](http://github.com/phleet/dotfiles),
[Desmond](https://github.com/dmnd), and others.  Non-dotfile config
files, and the setup script, were originally written by Craig
Silverstein.  Pull requests are welcome!
