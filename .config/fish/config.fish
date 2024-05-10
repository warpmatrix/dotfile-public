if status is-interactive
    # Commands to run in interactive sessions can go here
    if not set -q TMUX
        set -g TMUX tmux new-session -d -s home
        eval $TMUX
        tmux attach-session -d -t home
    end
    if command -v pyenv &> /dev/null
        pyenv init - | source
     end
end
