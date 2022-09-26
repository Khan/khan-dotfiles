alias ls="ls -G --color=auto"
alias l='ls -AF --color=auto'
alias ll='ls -alh --color=auto'
alias tree='tree -FC'
alias md='mkdir -p'
alias digs='dig +short'
alias testipport='nc -z -w1 -v'
alias h='history'
alias c='clear'
alias pst='export TZ=America/Los_Angeles'
alias ssh_nokey='ssh -o PubkeyAuthentication=no'
alias sdr='screen -dR'
alias sdrz='screen -dR -e^Z^Z'
alias sx='screen -x'
alias sxz='screen -x -e^Z^Z'
alias grep='grep --color=auto -n'
alias git_test='ssh -T git@github.com'
alias gt=git_test

alias g=gcloud
alias gc='gcloud compute'
alias gi='gcloud beta compute instances'

# Kill all background jobs (i.e. capture tasks)
alias killbg='sudo kill $(jobs -p)'
# Make tcpflow output easier to read
alias tflow='sudo tcpflow -cg "-T%T %A:%a-%B:%b--%C"'
# Listen on all ports with tcpflow (should specify a filter as an arg and maybe a -w <file> to read)
alias tflowany='tflow -i any'

# Show children
ptree() { if pids=$(pgrep $1); then for pid in $pids; do pstree -pa $pid; done; fi }

# Just colorize the words that match (pass all args but last to grep - last one is pattern)
cgrep() { grep -E --color ${@:1:$(($#-1))} "${@: -1}"'|$'; }

shopt -s histappend cmdhist cdspell nocaseglob
export ORIG_PATH=${PATH}
export PATH=~/bin:/usr/local/sbin:/usr/local/bin:${PATH}:/usr/sbin:/sbin
export HISTSIZE=10000
export HISTFILESIZE=20000
if [ -d "/data" ]; then
    # We get here in some cases if we are using a persistent volume
    export HISTFILE=/data/.bash_history${WINDOW:+.screen_$WINDOW}
else
    export HISTFILE=~/.bash_history${WINDOW:+.screen_$WINDOW}
fi
export HISTFILE=~/.bash_history${WINDOW:+.screen_$WINDOW}
export HISTCONTROL=erasedups
export HISTTIMEFORMAT="%F %T  "
if [ -z "$PROMPT_COMMAND" ]; then
  PROMPT_COMMAND='history -a'
else
  PROMPT_COMMAND="$PROMPT_COMMAND; history -a"
fi
export PROMPT_DIRTRIM=3
export EDITOR='code -w'
export GCC_COLORS=1
export GLOBIGNORE=".git:.svn:CVS:.DS_Store"  # glob ignore
export FIGNORE=".git:.svn:CVS:.DS_Store"     # pathname completion ignore
export LESS="-R -# 32 -X -b50 -i -w"
LESS+=" -P?f%f:stdin. ?m(%i of %m) .?ltlines %lt-%lb?L/%L. :byte %bB?s/%s. .?ccolumn %c .?e(END) ?x- Next\\: %x.:?pB%pB\\%..%t"

if [ -s ~/.bashrc.khan ]; then
    source ~/.bashrc.khan
fi

if [ -e ~/.ssh/id_rsa ]; then
    # Startup ssh-agent as it is probably desired
    # If running via docker, start with -v ~/.ssh/id_rsa:/home/kbuild/.ssk/id_rsa
    eval "$(ssh-agent -s)" >/dev/null
fi
