#!/bin/bash

if [ "$OS" == "Windows_NT" ]; then
    cd windows && pwd
    ./init.sh
    cd - && pwd
fi

bash_files=(
    ".bashrc"
    ".bash_completion"
    ".bash_cmpl"
)

zsh_files=(
    ".zshrc"
    ".zprofile"
    `find .oh-my-zsh/custom/plugins -maxdepth 1 -mindepth 1 -type d ! -name example`
)

shell=$(basename $SHELL)
shell_files=$(eval echo \${${shell}_files[*]})

files=(
    ".gitconfig"
    ".gdbinit"
    ".inputrc"
    ".profile"
    ".tmux.conf"
    ".tmate.conf"
    ".vimrc"
    ".vim"
    ".condarc"
    ".xmodmap"
)
files=(${files[@]} ${shell_files[@]})

for file in ${files[@]}; do
    if [ ! -L $HOME/$file ] ; then
        origin_dir="$HOME/dotfile/origin"
        if [ -e $HOME/$file ] && [ ! -e $origin_dir/$file ] ; then
            target_dir=$origin_dir/$(dirname $file)

            echo "mkdir -p $target_dir"
            mkdir -p $target_dir

            echo "mv $HOME/$file $origin_dir/$file"
            mv $HOME/$file $origin_dir/$file
        fi
        
        echo "ln -s $HOME/dotfile/$file $HOME/$file"
        ln -s $HOME/dotfile/$file $HOME/$file
    fi
done

# submodule including vim plugins, zsh plugins
git submodule update --init --recursive
