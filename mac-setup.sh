#!/usr/bin/env sh

echo "Running Khan Installation Script 1.0"
echo "Warning: This is only tested on Mac OS 10.7 (Lion)"
echo "  After each statement, either something will open for you to"
echo "    interact with, or a script will run for you to use"
echo "  Press enter when a download/install is completed to go to"
echo "    the next step (including this one)"

read

# get user's name/email
read -p "Enter your full name: " name
read -p "Enter your github email: " gh_email
read -p "Enter your kiln email: " hg_email

if [ -z "$name" -o -z "$gh_email" -o -z "$hg_email" ]; then
	echo "You must enter names and emails"
	exit 1
fi

echo "Have you installed the XCode Command Line Tools package,"
read -p "  or do you have a working version of gcc? y/n [n] " clt_installed

if [ "$clt_installed" != "y" ]; then
	echo "Downloading Command Line Tools (log in to start the download)"
	# download the command line tools
	open "https://developer.apple.com/downloads/download.action?path=Developer_Tools/command_line_tools_for_xcode__june_2012/command_line_tools_for_xcode_june_2012.dmg"

	read

	echo "Running Command Line Tools Installer"

	# attach the disk image
	hdiutil attach ~/Downloads/command_line_tools_for_xcode_june_2012.dmg > /dev/null
	echo "Type your password to install:"
	# install the command line tools
	sudo installer -package /Volumes/Command\ Line\ Tools/Command\ Line\ Tools.mpkg -target /
	# detach the disk image
	hdiutil detach /Volumes/Command\ Line\ Tools/ > /dev/null
fi

echo "Opening Hipchat website (log in and click download to install)"
# open the hipchat page
open "http://www.hipchat.com/"

read

echo "Installing Homebrew"
# if homebrew is already installed, don't do it again
if [ ! -d /usr/local/.git ]; then
	/usr/bin/ruby -e "$(/usr/bin/curl -fsSL https://raw.github.com/mxcl/homebrew/master/Library/Contributions/install_homebrew.rb)"
fi
# update brew
brew update > /dev/null

# make the cellar
mkdir -p /usr/local/Cellar
# export some useful directories
export PATH=/usr/local/bin:/usr/local/sbin:$PATH
# put these in .bash_profile too
echo "export PATH=/usr/local/sbin:/usr/local/bin:$$PATH" >> ~/.bash_profile

# brew doctor
brew doctor

# setup git name/email
git config --global user.name "$name"
git config --global user.email "$gh_email"

echo "Installing virtualenv"
# install pip
sudo easy_install --quiet pip
# install virtualenv
sudo pip install virtualenv -q

echo "Setting up virtualenv"

# make a virtualenv
virtualenv -q --python=/usr/bin/python2.7 ~/.virtualenv/khan27
echo "source ~/.virtualenv/khan27/bin/activate" >> ~/.bash_profile

# our function to activate virtualenv
virtenv() {
	source ~/.virtualenv/khan27/bin/activate
}

echo "Installing mercurial in virtualenv"
virtenv
# install mercurial in virtualenv
pip -q install Mercurial
deactivate

echo "Making khan directory"
# start building our directory
mkdir -p ~/khan/
cd ~/khan/

echo "Cloning stable"
# get the stable branch
hg clone -q https://khanacademy.kilnhg.com/Code/Website/Group/stable stable 2>/dev/null || (cd stable; hg pull -q -u)

echo "Setting up your .hgrc.local"
# make the dummy certificate
yes "" | openssl req -new -x509 -extensions v3_ca -keyout /dev/null -out dummycert.pem -days 3650 -passout pass:pass 2> /dev/null
sudo cp dummycert.pem /etc/hg-dummy-cert.pem
rm dummycert.pem
# setup the .hgrc
echo "[ui]
username = $name <$hg_email>

[web]
cacerts = /etc/hg-dummy-cert.pem" > ~/.hgrc.local

echo "%include ~/.hgrc.local" >> ~/.hgrc

echo "Installing requirements"
virtenv
# install requirements into the virtualenv
pip -q install -r stable/requirements.txt
deactivate

echo "Setting up ssh keys"

# if there is no ssh key, make one
if [ ! -e ~/.ssh/id_*sa ]; then
	ssh-keygen -t rsa -C "$gh_email" -f ~/.ssh/id_rsa
fi

# copy the public key
cat ~/.ssh/id_rsa.pub | pbcopy

echo "Opening github ssh keys"
echo "Click 'Add SSH Key', paste into the box, and hit 'Add key'"
# go to the github ssh keys site
open "https://github.com/settings/ssh"

read

echo "Getting development tools"
# download a bunch of developer tools
mkdir -p devtools 
cd devtools
git clone -q https://github.com/Khan/kiln-review 2>/dev/null || (cd kiln-review; git pull -q)
hg clone -q https://bitbucket.org/brendan/mercurial-extensions-rdiff 2>/dev/null || (cd mercurial-extensions-rdiff; hg -q pull -u)
git clone -q https://github.com/Khan/khan-linter 2>/dev/null || (cd khan-linter; git pull -q)
git clone -q https://github.com/Khan/arcanist 2>/dev/null || (cd arcanist; git pull -q)
git clone -q https://github.com/Khan/libphutil.git 2>/dev/null || (cd libphutil; git pull -q)
curl -s https://khanacademy.kilnhg.com/Tools/Downloads/Extensions > /tmp/extensions.zip && unzip -qo /tmp/extensions.zip kiln_extensions/kilnauth.py

cd ~/khan

echo "Installing nginx"
# install nginx
brew install nginx

echo "Backing up nginx.conf to nginx.conf.old"
# make a backup of nginx config
sudo cp /usr/local/etc/nginx/nginx.conf /usr/local/etc/nginx/nginx.conf.old

echo "Setting up nginx"
# setup the nginx configuration file
cat nginx.conf | sed "s/%USER/$USER/" > /usr/local/etc/nginx/nginx.conf

# if not done before, add the new hosts to /etc/hosts
if ! grep -q "ka.local" /etc/hosts; then
	echo "# KA local servers
127.0.0.1       exercises.ka.local
::1             exercises.ka.local
127.0.0.1       stable.ka.local
::1             stable.ka.local" | sudo tee -a /etc/hosts >/dev/null
fi

# copy the launch plist
sudo cp /usr/local/Cellar/nginx/*/homebrew.mxcl.nginx.plist /Library/LaunchDaemons
# delete the username key so it is run as root
sudo /usr/libexec/PlistBuddy -c "Delete :UserName" /Library/LaunchDaemons/homebrew.mxcl.nginx.plist 2>/dev/null
# load it
sudo launchctl load -w /Library/LaunchDaemons/homebrew.mxcl.nginx.plist

echo "Setting up App Engine Launcher"
curl -s http://googleappengine.googlecode.com/files/GoogleAppEngineLauncher-1.6.6.dmg > ~/Downloads/GoogleAppEngineLauncher-1.6.6.dmg
hdiutil attach ~/Downloads/GoogleAppEngineLauncher-1.6.6.dmg
cp -r /Volumes/GoogleAppEngineLauncher-*/GoogleAppEngineLauncher.app /Applications/
hdiutil detach /Volumes/GoogleAppEngineLauncher-*

echo "Set up the Google App Engine Launcher according to the website."
open "https://sites.google.com/a/khanacademy.org/forge/for-khan-employees/-new-employees-onboard-doc/developer-setup/launching-your-test-site"
open -a GoogleAppEngineLauncher

read

echo "You might be done!"
