<!-- omit in toc -->
# log

<!-- omit in toc -->
## Table of Contents

- [bashrc](#bashrc)
- [vimrc](#vimrc)
- [profile](#profile)
- [tmux.config](#tmuxconfig)

## bashrc

auto completion script of k8s in ~/.bashec:

```.bashrc
source <(kubectl completion bash)
```

set bash input mode vim:

```.bashrc
set -o vi
```

## vimrc

set tab size = 4:

```vim
// 一个 tab 对应空格
set tabstop=4
// 缩进对应的空格
set shiftwidth=4
// 使用空格填充缩进
set expandtab
// 保持和上一行相同的缩进数
set autoindent
// 自动填充缩进的空格数
set smarttab
```

show line number and set the line number relative:

```vim
set relativenumber
set number
```

key remapping:

```vim
noremap H ^
noremap L $
```

增加 [imselect](git@github.com:brglng/vim-im-select.git) 脚本，自动更换输入法。

引入 tpope 大神的插件：commentary, repeat, surround

## profile

modify ~/.profile to add pyenv feat: virtualenv disable prompt:

```profile
export PYENV_VIRTUALENV_DISABLE_PROMPT=1
```

modify ~/.profile to add texlive path:

```profile
export PATH=$PATH:/usr/local/texlive/2020/bin/x86_64-linux
```

## tmux.config

display color

```tmux
set -g default-terminal "screen-256color"
```

Remap prefix from 'C-b' to 'C-a'

```tmux
unbind C-b
set-option -g prefix C-a
bind-key C-a send-prefix
```

Use vim keybindings in copy mode

```tmux
setw -g mode-keys vi
```
