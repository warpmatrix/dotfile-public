if status is-interactive
    # Commands to run in interactive sessions can go here
    if command -v pyenv &> /dev/null
        pyenv init - | source
     end
end
