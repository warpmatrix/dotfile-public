# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# see /usr/share/doc/bash/examples/startup-files for examples.
# the files are located in the bash-doc package.

# the default umask is set in /etc/profile; for setting the umask
# for ssh logins, install and configure the libpam-umask package.
#umask 022

# if running bash
if [ -n "$BASH_VERSION" ]; then
    # include .bashrc if it exists
    if [ -f "$HOME/.bashrc" ]; then
	. "$HOME/.bashrc"
    fi
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/bin" ] ; then
    PATH="$HOME/bin:$PATH"
fi

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/.local/bin" ] ; then
    PATH="$HOME/.local/bin:$PATH"
fi

# customized settings
# for go
export PATH="$PATH:/usr/local/go/bin"

# for embedded OS
# export PATH=/opt/FriendlyARM/toolchain/4.9.3/bin:$PATH
# export GCC_COLORS=auto

# for pyenv
export PYENV_VIRTUALENV_DISABLE_PROMPT=1

# for texlive
export PATH=/usr/local/texlive/2020/bin/x86_64-linux:$PATH
