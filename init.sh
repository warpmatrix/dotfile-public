#!/bin/bash

bash_files=(
    ".bashrc"
    ".bash_completion"
    ".bash_cmpl"
)

zsh_files=(
    ".zshrc"
    ".oh-my-zsh/custom/plugins"
    ".zprofile"
)

shell=$(basename $SHELL)
shell_files=$(eval echo \${${shell}_files[*]})

files=(
    ".gitconfig"
    ".gdbinit"
    ".inputrc"
    ".profile"
    ".tmux.conf"
    ".vimrc"
    ".vim"
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

# tmux completion
curl https://raw.githubusercontent.com/imomaliev/tmux-bash-completion/master/completions/tmux > ./.bash_cmpl/tmux
