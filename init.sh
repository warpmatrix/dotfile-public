#!/bin/bash
files=(
    ".bashrc"
    ".gitconfig"
    ".gdbinit"
    ".profile"
    ".tmux.conf"
    ".vimrc"
    ".vim"
)

for file in ${files[*]}; do
    if [ ! -L $HOME/$file ] ; then
        origindir="$HOME/dotfile/origin"
        if [ -r $HOME/$file ] && [ ! -r $origindir/$file ] ; then
            mkdir -p $HOME/dotfile/origin
            echo "mv $HOME/$file $origindir/$file"
            mv $HOME/$file $origindir/$file
        fi
        ln -s $HOME/dotfile/$file $HOME/$file
    fi
done

# some vim plugins, which impl scp $HOME/.vim/* remote:$HOME/.vim/
git submodule init && git submodule update
