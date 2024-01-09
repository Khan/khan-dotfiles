install:
	./git_sync.sh
	$(MAKE) dotfiles-install
	$(MAKE) os-install
	$(MAKE) common-install
	@echo "***  YOU MUST REBOOT **IF** this was   ***"
	@echo "***  the first time you've setup       ***"
	@echo "***  khan-dotfiles (i.e. if you are    ***"
	@echo "***  onboarding)                       ***"
	@echo "***  (Reboot is required for browser   ***"
	@echo "***  to pickup CA for khanacademy.dev) ***"
	@echo ""
	@echo "To finish your setup, head back to the"
	@echo "setup docs:"
	@echo "  https://khanacademy.atlassian.net/wiki/x/VgKiC"

dotfiles-install:
	./dotfiles-setup.sh

os-install:
	if [ `uname -s` = Linux ]; then \
		./linux-setup.sh; \
	fi
	if [ `uname -s` = Darwin ]; then \
		./mac-setup.sh; \
	fi

common-install:
	./setup.sh

virtualenv:
	./bin/rebuild_virtualenv.sh

