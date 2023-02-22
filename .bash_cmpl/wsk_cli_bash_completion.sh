# bash completion for wsk                                  -*- shell-script -*-

__wsk_debug()
{
    if [[ -n ${BASH_COMP_DEBUG_FILE} ]]; then
        echo "$*" >> "${BASH_COMP_DEBUG_FILE}"
    fi
}

# Homebrew on Macs have version 1.3 of bash-completion which doesn't include
# _init_completion. This is a very minimal version of that function.
__wsk_init_completion()
{
    COMPREPLY=()
    _get_comp_words_by_ref "$@" cur prev words cword
}

__wsk_index_of_word()
{
    local w word=$1
    shift
    index=0
    for w in "$@"; do
        [[ $w = "$word" ]] && return
        index=$((index+1))
    done
    index=-1
}

__wsk_contains_word()
{
    local w word=$1; shift
    for w in "$@"; do
        [[ $w = "$word" ]] && return
    done
    return 1
}

__wsk_handle_go_custom_completion()
{
    __wsk_debug "${FUNCNAME[0]}: cur is ${cur}, words[*] is ${words[*]}, #words[@] is ${#words[@]}"

    local shellCompDirectiveError=1
    local shellCompDirectiveNoSpace=2
    local shellCompDirectiveNoFileComp=4
    local shellCompDirectiveFilterFileExt=8
    local shellCompDirectiveFilterDirs=16

    local out requestComp lastParam lastChar comp directive args

    # Prepare the command to request completions for the program.
    # Calling ${words[0]} instead of directly wsk allows to handle aliases
    args=("${words[@]:1}")
    requestComp="${words[0]} __completeNoDesc ${args[*]}"

    lastParam=${words[$((${#words[@]}-1))]}
    lastChar=${lastParam:$((${#lastParam}-1)):1}
    __wsk_debug "${FUNCNAME[0]}: lastParam ${lastParam}, lastChar ${lastChar}"

    if [ -z "${cur}" ] && [ "${lastChar}" != "=" ]; then
        # If the last parameter is complete (there is a space following it)
        # We add an extra empty parameter so we can indicate this to the go method.
        __wsk_debug "${FUNCNAME[0]}: Adding extra empty parameter"
        requestComp="${requestComp} \"\""
    fi

    __wsk_debug "${FUNCNAME[0]}: calling ${requestComp}"
    # Use eval to handle any environment variables and such
    out=$(eval "${requestComp}" 2>/dev/null)

    # Extract the directive integer at the very end of the output following a colon (:)
    directive=${out##*:}
    # Remove the directive
    out=${out%:*}
    if [ "${directive}" = "${out}" ]; then
        # There is not directive specified
        directive=0
    fi
    __wsk_debug "${FUNCNAME[0]}: the completion directive is: ${directive}"
    __wsk_debug "${FUNCNAME[0]}: the completions are: ${out[*]}"

    if [ $((directive & shellCompDirectiveError)) -ne 0 ]; then
        # Error code.  No completion.
        __wsk_debug "${FUNCNAME[0]}: received error from custom completion go code"
        return
    else
        if [ $((directive & shellCompDirectiveNoSpace)) -ne 0 ]; then
            if [[ $(type -t compopt) = "builtin" ]]; then
                __wsk_debug "${FUNCNAME[0]}: activating no space"
                compopt -o nospace
            fi
        fi
        if [ $((directive & shellCompDirectiveNoFileComp)) -ne 0 ]; then
            if [[ $(type -t compopt) = "builtin" ]]; then
                __wsk_debug "${FUNCNAME[0]}: activating no file completion"
                compopt +o default
            fi
        fi
    fi

    if [ $((directive & shellCompDirectiveFilterFileExt)) -ne 0 ]; then
        # File extension filtering
        local fullFilter filter filteringCmd
        # Do not use quotes around the $out variable or else newline
        # characters will be kept.
        for filter in ${out[*]}; do
            fullFilter+="$filter|"
        done

        filteringCmd="_filedir $fullFilter"
        __wsk_debug "File filtering command: $filteringCmd"
        $filteringCmd
    elif [ $((directive & shellCompDirectiveFilterDirs)) -ne 0 ]; then
        # File completion for directories only
        local subDir
        # Use printf to strip any trailing newline
        subdir=$(printf "%s" "${out[0]}")
        if [ -n "$subdir" ]; then
            __wsk_debug "Listing directories in $subdir"
            __wsk_handle_subdirs_in_dir_flag "$subdir"
        else
            __wsk_debug "Listing directories in ."
            _filedir -d
        fi
    else
        while IFS='' read -r comp; do
            COMPREPLY+=("$comp")
        done < <(compgen -W "${out[*]}" -- "$cur")
    fi
}

__wsk_handle_reply()
{
    __wsk_debug "${FUNCNAME[0]}"
    local comp
    case $cur in
        -*)
            if [[ $(type -t compopt) = "builtin" ]]; then
                compopt -o nospace
            fi
            local allflags
            if [ ${#must_have_one_flag[@]} -ne 0 ]; then
                allflags=("${must_have_one_flag[@]}")
            else
                allflags=("${flags[*]} ${two_word_flags[*]}")
            fi
            while IFS='' read -r comp; do
                COMPREPLY+=("$comp")
            done < <(compgen -W "${allflags[*]}" -- "$cur")
            if [[ $(type -t compopt) = "builtin" ]]; then
                [[ "${COMPREPLY[0]}" == *= ]] || compopt +o nospace
            fi

            # complete after --flag=abc
            if [[ $cur == *=* ]]; then
                if [[ $(type -t compopt) = "builtin" ]]; then
                    compopt +o nospace
                fi

                local index flag
                flag="${cur%=*}"
                __wsk_index_of_word "${flag}" "${flags_with_completion[@]}"
                COMPREPLY=()
                if [[ ${index} -ge 0 ]]; then
                    PREFIX=""
                    cur="${cur#*=}"
                    ${flags_completion[${index}]}
                    if [ -n "${ZSH_VERSION}" ]; then
                        # zsh completion needs --flag= prefix
                        eval "COMPREPLY=( \"\${COMPREPLY[@]/#/${flag}=}\" )"
                    fi
                fi
            fi
            return 0;
            ;;
    esac

    # check if we are handling a flag with special work handling
    local index
    __wsk_index_of_word "${prev}" "${flags_with_completion[@]}"
    if [[ ${index} -ge 0 ]]; then
        ${flags_completion[${index}]}
        return
    fi

    # we are parsing a flag and don't have a special handler, no completion
    if [[ ${cur} != "${words[cword]}" ]]; then
        return
    fi

    local completions
    completions=("${commands[@]}")
    if [[ ${#must_have_one_noun[@]} -ne 0 ]]; then
        completions+=("${must_have_one_noun[@]}")
    elif [[ -n "${has_completion_function}" ]]; then
        # if a go completion function is provided, defer to that function
        __wsk_handle_go_custom_completion
    fi
    if [[ ${#must_have_one_flag[@]} -ne 0 ]]; then
        completions+=("${must_have_one_flag[@]}")
    fi
    while IFS='' read -r comp; do
        COMPREPLY+=("$comp")
    done < <(compgen -W "${completions[*]}" -- "$cur")

    if [[ ${#COMPREPLY[@]} -eq 0 && ${#noun_aliases[@]} -gt 0 && ${#must_have_one_noun[@]} -ne 0 ]]; then
        while IFS='' read -r comp; do
            COMPREPLY+=("$comp")
        done < <(compgen -W "${noun_aliases[*]}" -- "$cur")
    fi

    if [[ ${#COMPREPLY[@]} -eq 0 ]]; then
		if declare -F __wsk_custom_func >/dev/null; then
			# try command name qualified custom func
			__wsk_custom_func
		else
			# otherwise fall back to unqualified for compatibility
			declare -F __custom_func >/dev/null && __custom_func
		fi
    fi

    # available in bash-completion >= 2, not always present on macOS
    if declare -F __ltrim_colon_completions >/dev/null; then
        __ltrim_colon_completions "$cur"
    fi

    # If there is only 1 completion and it is a flag with an = it will be completed
    # but we don't want a space after the =
    if [[ "${#COMPREPLY[@]}" -eq "1" ]] && [[ $(type -t compopt) = "builtin" ]] && [[ "${COMPREPLY[0]}" == --*= ]]; then
       compopt -o nospace
    fi
}

# The arguments should be in the form "ext1|ext2|extn"
__wsk_handle_filename_extension_flag()
{
    local ext="$1"
    _filedir "@(${ext})"
}

__wsk_handle_subdirs_in_dir_flag()
{
    local dir="$1"
    pushd "${dir}" >/dev/null 2>&1 && _filedir -d && popd >/dev/null 2>&1 || return
}

__wsk_handle_flag()
{
    __wsk_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

    # if a command required a flag, and we found it, unset must_have_one_flag()
    local flagname=${words[c]}
    local flagvalue
    # if the word contained an =
    if [[ ${words[c]} == *"="* ]]; then
        flagvalue=${flagname#*=} # take in as flagvalue after the =
        flagname=${flagname%=*} # strip everything after the =
        flagname="${flagname}=" # but put the = back
    fi
    __wsk_debug "${FUNCNAME[0]}: looking for ${flagname}"
    if __wsk_contains_word "${flagname}" "${must_have_one_flag[@]}"; then
        must_have_one_flag=()
    fi

    # if you set a flag which only applies to this command, don't show subcommands
    if __wsk_contains_word "${flagname}" "${local_nonpersistent_flags[@]}"; then
      commands=()
    fi

    # keep flag value with flagname as flaghash
    # flaghash variable is an associative array which is only supported in bash > 3.
    if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
        if [ -n "${flagvalue}" ] ; then
            flaghash[${flagname}]=${flagvalue}
        elif [ -n "${words[ $((c+1)) ]}" ] ; then
            flaghash[${flagname}]=${words[ $((c+1)) ]}
        else
            flaghash[${flagname}]="true" # pad "true" for bool flag
        fi
    fi

    # skip the argument to a two word flag
    if [[ ${words[c]} != *"="* ]] && __wsk_contains_word "${words[c]}" "${two_word_flags[@]}"; then
			  __wsk_debug "${FUNCNAME[0]}: found a flag ${words[c]}, skip the next argument"
        c=$((c+1))
        # if we are looking for a flags value, don't show commands
        if [[ $c -eq $cword ]]; then
            commands=()
        fi
    fi

    c=$((c+1))

}

__wsk_handle_noun()
{
    __wsk_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

    if __wsk_contains_word "${words[c]}" "${must_have_one_noun[@]}"; then
        must_have_one_noun=()
    elif __wsk_contains_word "${words[c]}" "${noun_aliases[@]}"; then
        must_have_one_noun=()
    fi

    nouns+=("${words[c]}")
    c=$((c+1))
}

__wsk_handle_command()
{
    __wsk_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

    local next_command
    if [[ -n ${last_command} ]]; then
        next_command="_${last_command}_${words[c]//:/__}"
    else
        if [[ $c -eq 0 ]]; then
            next_command="_wsk_root_command"
        else
            next_command="_${words[c]//:/__}"
        fi
    fi
    c=$((c+1))
    __wsk_debug "${FUNCNAME[0]}: looking for ${next_command}"
    declare -F "$next_command" >/dev/null && $next_command
}

__wsk_handle_word()
{
    if [[ $c -ge $cword ]]; then
        __wsk_handle_reply
        return
    fi
    __wsk_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"
    if [[ "${words[c]}" == -* ]]; then
        __wsk_handle_flag
    elif __wsk_contains_word "${words[c]}" "${commands[@]}"; then
        __wsk_handle_command
    elif [[ $c -eq 0 ]]; then
        __wsk_handle_command
    elif __wsk_contains_word "${words[c]}" "${command_aliases[@]}"; then
        # aliashash variable is an associative array which is only supported in bash > 3.
        if [[ -z "${BASH_VERSION}" || "${BASH_VERSINFO[0]}" -gt 3 ]]; then
            words[c]=${aliashash[${words[c]}]}
            __wsk_handle_command
        else
            __wsk_handle_noun
        fi
    else
        __wsk_handle_noun
    fi
    __wsk_handle_word
}

_wsk_action_create()
{
    last_command="wsk_action_create"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--annotation=")
    two_word_flags+=("--annotation")
    two_word_flags+=("-a")
    local_nonpersistent_flags+=("--annotation")
    local_nonpersistent_flags+=("--annotation=")
    local_nonpersistent_flags+=("-a")
    flags+=("--annotation-file=")
    two_word_flags+=("--annotation-file")
    two_word_flags+=("-A")
    local_nonpersistent_flags+=("--annotation-file")
    local_nonpersistent_flags+=("--annotation-file=")
    local_nonpersistent_flags+=("-A")
    flags+=("--concurrency=")
    two_word_flags+=("--concurrency")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--concurrency")
    local_nonpersistent_flags+=("--concurrency=")
    local_nonpersistent_flags+=("-c")
    flags+=("--copy")
    local_nonpersistent_flags+=("--copy")
    flags+=("--docker=")
    two_word_flags+=("--docker")
    local_nonpersistent_flags+=("--docker")
    local_nonpersistent_flags+=("--docker=")
    flags+=("--kind=")
    two_word_flags+=("--kind")
    local_nonpersistent_flags+=("--kind")
    local_nonpersistent_flags+=("--kind=")
    flags+=("--logsize=")
    two_word_flags+=("--logsize")
    two_word_flags+=("-l")
    local_nonpersistent_flags+=("--logsize")
    local_nonpersistent_flags+=("--logsize=")
    local_nonpersistent_flags+=("-l")
    flags+=("--main=")
    two_word_flags+=("--main")
    local_nonpersistent_flags+=("--main")
    local_nonpersistent_flags+=("--main=")
    flags+=("--memory=")
    two_word_flags+=("--memory")
    two_word_flags+=("-m")
    local_nonpersistent_flags+=("--memory")
    local_nonpersistent_flags+=("--memory=")
    local_nonpersistent_flags+=("-m")
    flags+=("--native")
    local_nonpersistent_flags+=("--native")
    flags+=("--param=")
    two_word_flags+=("--param")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--param")
    local_nonpersistent_flags+=("--param=")
    local_nonpersistent_flags+=("-p")
    flags+=("--param-file=")
    two_word_flags+=("--param-file")
    two_word_flags+=("-P")
    local_nonpersistent_flags+=("--param-file")
    local_nonpersistent_flags+=("--param-file=")
    local_nonpersistent_flags+=("-P")
    flags+=("--sequence")
    local_nonpersistent_flags+=("--sequence")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    two_word_flags+=("-t")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    local_nonpersistent_flags+=("-t")
    flags+=("--web=")
    two_word_flags+=("--web")
    local_nonpersistent_flags+=("--web")
    local_nonpersistent_flags+=("--web=")
    flags+=("--web-secure=")
    two_word_flags+=("--web-secure")
    local_nonpersistent_flags+=("--web-secure")
    local_nonpersistent_flags+=("--web-secure=")
    flags+=("--apihost=")
    two_word_flags+=("--apihost")
    flags+=("--apiversion=")
    two_word_flags+=("--apiversion")
    flags+=("--auth=")
    two_word_flags+=("--auth")
    two_word_flags+=("-u")
    flags+=("--cert=")
    two_word_flags+=("--cert")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--insecure")
    flags+=("-i")
    flags+=("--key=")
    two_word_flags+=("--key")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_wsk_action_delete()
{
    last_command="wsk_action_delete"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--apihost=")
    two_word_flags+=("--apihost")
    flags+=("--apiversion=")
    two_word_flags+=("--apiversion")
    flags+=("--auth=")
    two_word_flags+=("--auth")
    two_word_flags+=("-u")
    flags+=("--cert=")
    two_word_flags+=("--cert")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--insecure")
    flags+=("-i")
    flags+=("--key=")
    two_word_flags+=("--key")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_wsk_action_get()
{
    last_command="wsk_action_get"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--save")
    local_nonpersistent_flags+=("--save")
    flags+=("--save-as=")
    two_word_flags+=("--save-as")
    local_nonpersistent_flags+=("--save-as")
    local_nonpersistent_flags+=("--save-as=")
    flags+=("--summary")
    flags+=("-s")
    local_nonpersistent_flags+=("--summary")
    local_nonpersistent_flags+=("-s")
    flags+=("--url")
    flags+=("-r")
    local_nonpersistent_flags+=("--url")
    local_nonpersistent_flags+=("-r")
    flags+=("--apihost=")
    two_word_flags+=("--apihost")
    flags+=("--apiversion=")
    two_word_flags+=("--apiversion")
    flags+=("--auth=")
    two_word_flags+=("--auth")
    two_word_flags+=("-u")
    flags+=("--cert=")
    two_word_flags+=("--cert")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--insecure")
    flags+=("-i")
    flags+=("--key=")
    two_word_flags+=("--key")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_wsk_action_invoke()
{
    last_command="wsk_action_invoke"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--blocking")
    flags+=("-b")
    local_nonpersistent_flags+=("--blocking")
    local_nonpersistent_flags+=("-b")
    flags+=("--param=")
    two_word_flags+=("--param")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--param")
    local_nonpersistent_flags+=("--param=")
    local_nonpersistent_flags+=("-p")
    flags+=("--param-file=")
    two_word_flags+=("--param-file")
    two_word_flags+=("-P")
    local_nonpersistent_flags+=("--param-file")
    local_nonpersistent_flags+=("--param-file=")
    local_nonpersistent_flags+=("-P")
    flags+=("--result")
    flags+=("-r")
    local_nonpersistent_flags+=("--result")
    local_nonpersistent_flags+=("-r")
    flags+=("--apihost=")
    two_word_flags+=("--apihost")
    flags+=("--apiversion=")
    two_word_flags+=("--apiversion")
    flags+=("--auth=")
    two_word_flags+=("--auth")
    two_word_flags+=("-u")
    flags+=("--cert=")
    two_word_flags+=("--cert")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--insecure")
    flags+=("-i")
    flags+=("--key=")
    two_word_flags+=("--key")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_wsk_action_list()
{
    last_command="wsk_action_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--limit=")
    two_word_flags+=("--limit")
    two_word_flags+=("-l")
    local_nonpersistent_flags+=("--limit")
    local_nonpersistent_flags+=("--limit=")
    local_nonpersistent_flags+=("-l")
    flags+=("--name-sort")
    flags+=("-n")
    local_nonpersistent_flags+=("--name-sort")
    local_nonpersistent_flags+=("-n")
    flags+=("--skip=")
    two_word_flags+=("--skip")
    two_word_flags+=("-s")
    local_nonpersistent_flags+=("--skip")
    local_nonpersistent_flags+=("--skip=")
    local_nonpersistent_flags+=("-s")
    flags+=("--apihost=")
    two_word_flags+=("--apihost")
    flags+=("--apiversion=")
    two_word_flags+=("--apiversion")
    flags+=("--auth=")
    two_word_flags+=("--auth")
    two_word_flags+=("-u")
    flags+=("--cert=")
    two_word_flags+=("--cert")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--insecure")
    flags+=("-i")
    flags+=("--key=")
    two_word_flags+=("--key")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_wsk_action_update()
{
    last_command="wsk_action_update"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--annotation=")
    two_word_flags+=("--annotation")
    two_word_flags+=("-a")
    local_nonpersistent_flags+=("--annotation")
    local_nonpersistent_flags+=("--annotation=")
    local_nonpersistent_flags+=("-a")
    flags+=("--annotation-file=")
    two_word_flags+=("--annotation-file")
    two_word_flags+=("-A")
    local_nonpersistent_flags+=("--annotation-file")
    local_nonpersistent_flags+=("--annotation-file=")
    local_nonpersistent_flags+=("-A")
    flags+=("--concurrency=")
    two_word_flags+=("--concurrency")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--concurrency")
    local_nonpersistent_flags+=("--concurrency=")
    local_nonpersistent_flags+=("-c")
    flags+=("--copy")
    local_nonpersistent_flags+=("--copy")
    flags+=("--del-annotation=")
    two_word_flags+=("--del-annotation")
    local_nonpersistent_flags+=("--del-annotation")
    local_nonpersistent_flags+=("--del-annotation=")
    flags+=("--docker=")
    two_word_flags+=("--docker")
    local_nonpersistent_flags+=("--docker")
    local_nonpersistent_flags+=("--docker=")
    flags+=("--kind=")
    two_word_flags+=("--kind")
    local_nonpersistent_flags+=("--kind")
    local_nonpersistent_flags+=("--kind=")
    flags+=("--logsize=")
    two_word_flags+=("--logsize")
    two_word_flags+=("-l")
    local_nonpersistent_flags+=("--logsize")
    local_nonpersistent_flags+=("--logsize=")
    local_nonpersistent_flags+=("-l")
    flags+=("--main=")
    two_word_flags+=("--main")
    local_nonpersistent_flags+=("--main")
    local_nonpersistent_flags+=("--main=")
    flags+=("--memory=")
    two_word_flags+=("--memory")
    two_word_flags+=("-m")
    local_nonpersistent_flags+=("--memory")
    local_nonpersistent_flags+=("--memory=")
    local_nonpersistent_flags+=("-m")
    flags+=("--native")
    local_nonpersistent_flags+=("--native")
    flags+=("--param=")
    two_word_flags+=("--param")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--param")
    local_nonpersistent_flags+=("--param=")
    local_nonpersistent_flags+=("-p")
    flags+=("--param-file=")
    two_word_flags+=("--param-file")
    two_word_flags+=("-P")
    local_nonpersistent_flags+=("--param-file")
    local_nonpersistent_flags+=("--param-file=")
    local_nonpersistent_flags+=("-P")
    flags+=("--sequence")
    local_nonpersistent_flags+=("--sequence")
    flags+=("--timeout=")
    two_word_flags+=("--timeout")
    two_word_flags+=("-t")
    local_nonpersistent_flags+=("--timeout")
    local_nonpersistent_flags+=("--timeout=")
    local_nonpersistent_flags+=("-t")
    flags+=("--web=")
    two_word_flags+=("--web")
    local_nonpersistent_flags+=("--web")
    local_nonpersistent_flags+=("--web=")
    flags+=("--web-secure=")
    two_word_flags+=("--web-secure")
    local_nonpersistent_flags+=("--web-secure")
    local_nonpersistent_flags+=("--web-secure=")
    flags+=("--apihost=")
    two_word_flags+=("--apihost")
    flags+=("--apiversion=")
    two_word_flags+=("--apiversion")
    flags+=("--auth=")
    two_word_flags+=("--auth")
    two_word_flags+=("-u")
    flags+=("--cert=")
    two_word_flags+=("--cert")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--insecure")
    flags+=("-i")
    flags+=("--key=")
    two_word_flags+=("--key")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_wsk_action()
{
    last_command="wsk_action"

    command_aliases=()

    commands=()
    commands+=("create")
    commands+=("delete")
    commands+=("get")
    commands+=("invoke")
    commands+=("list")
    commands+=("update")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--apihost=")
    two_word_flags+=("--apihost")
    flags+=("--apiversion=")
    two_word_flags+=("--apiversion")
    flags+=("--auth=")
    two_word_flags+=("--auth")
    two_word_flags+=("-u")
    flags+=("--cert=")
    two_word_flags+=("--cert")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--insecure")
    flags+=("-i")
    flags+=("--key=")
    two_word_flags+=("--key")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_wsk_activation_get()
{
    last_command="wsk_activation_get"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--last")
    flags+=("-l")
    local_nonpersistent_flags+=("--last")
    local_nonpersistent_flags+=("-l")
    flags+=("--logs")
    flags+=("-g")
    local_nonpersistent_flags+=("--logs")
    local_nonpersistent_flags+=("-g")
    flags+=("--summary")
    flags+=("-s")
    local_nonpersistent_flags+=("--summary")
    local_nonpersistent_flags+=("-s")
    flags+=("--apihost=")
    two_word_flags+=("--apihost")
    flags+=("--apiversion=")
    two_word_flags+=("--apiversion")
    flags+=("--auth=")
    two_word_flags+=("--auth")
    two_word_flags+=("-u")
    flags+=("--cert=")
    two_word_flags+=("--cert")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--insecure")
    flags+=("-i")
    flags+=("--key=")
    two_word_flags+=("--key")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_wsk_activation_list()
{
    last_command="wsk_activation_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--full")
    flags+=("-f")
    local_nonpersistent_flags+=("--full")
    local_nonpersistent_flags+=("-f")
    flags+=("--limit=")
    two_word_flags+=("--limit")
    two_word_flags+=("-l")
    local_nonpersistent_flags+=("--limit")
    local_nonpersistent_flags+=("--limit=")
    local_nonpersistent_flags+=("-l")
    flags+=("--since=")
    two_word_flags+=("--since")
    local_nonpersistent_flags+=("--since")
    local_nonpersistent_flags+=("--since=")
    flags+=("--skip=")
    two_word_flags+=("--skip")
    two_word_flags+=("-s")
    local_nonpersistent_flags+=("--skip")
    local_nonpersistent_flags+=("--skip=")
    local_nonpersistent_flags+=("-s")
    flags+=("--upto=")
    two_word_flags+=("--upto")
    local_nonpersistent_flags+=("--upto")
    local_nonpersistent_flags+=("--upto=")
    flags+=("--apihost=")
    two_word_flags+=("--apihost")
    flags+=("--apiversion=")
    two_word_flags+=("--apiversion")
    flags+=("--auth=")
    two_word_flags+=("--auth")
    two_word_flags+=("-u")
    flags+=("--cert=")
    two_word_flags+=("--cert")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--insecure")
    flags+=("-i")
    flags+=("--key=")
    two_word_flags+=("--key")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_wsk_activation_logs()
{
    last_command="wsk_activation_logs"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--last")
    flags+=("-l")
    local_nonpersistent_flags+=("--last")
    local_nonpersistent_flags+=("-l")
    flags+=("--strip")
    flags+=("-r")
    local_nonpersistent_flags+=("--strip")
    local_nonpersistent_flags+=("-r")
    flags+=("--apihost=")
    two_word_flags+=("--apihost")
    flags+=("--apiversion=")
    two_word_flags+=("--apiversion")
    flags+=("--auth=")
    two_word_flags+=("--auth")
    two_word_flags+=("-u")
    flags+=("--cert=")
    two_word_flags+=("--cert")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--insecure")
    flags+=("-i")
    flags+=("--key=")
    two_word_flags+=("--key")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_wsk_activation_poll()
{
    last_command="wsk_activation_poll"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--exit=")
    two_word_flags+=("--exit")
    two_word_flags+=("-e")
    local_nonpersistent_flags+=("--exit")
    local_nonpersistent_flags+=("--exit=")
    local_nonpersistent_flags+=("-e")
    flags+=("--since-days=")
    two_word_flags+=("--since-days")
    local_nonpersistent_flags+=("--since-days")
    local_nonpersistent_flags+=("--since-days=")
    flags+=("--since-hours=")
    two_word_flags+=("--since-hours")
    local_nonpersistent_flags+=("--since-hours")
    local_nonpersistent_flags+=("--since-hours=")
    flags+=("--since-minutes=")
    two_word_flags+=("--since-minutes")
    local_nonpersistent_flags+=("--since-minutes")
    local_nonpersistent_flags+=("--since-minutes=")
    flags+=("--since-seconds=")
    two_word_flags+=("--since-seconds")
    local_nonpersistent_flags+=("--since-seconds")
    local_nonpersistent_flags+=("--since-seconds=")
    flags+=("--apihost=")
    two_word_flags+=("--apihost")
    flags+=("--apiversion=")
    two_word_flags+=("--apiversion")
    flags+=("--auth=")
    two_word_flags+=("--auth")
    two_word_flags+=("-u")
    flags+=("--cert=")
    two_word_flags+=("--cert")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--insecure")
    flags+=("-i")
    flags+=("--key=")
    two_word_flags+=("--key")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_wsk_activation_result()
{
    last_command="wsk_activation_result"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--last")
    flags+=("-l")
    local_nonpersistent_flags+=("--last")
    local_nonpersistent_flags+=("-l")
    flags+=("--apihost=")
    two_word_flags+=("--apihost")
    flags+=("--apiversion=")
    two_word_flags+=("--apiversion")
    flags+=("--auth=")
    two_word_flags+=("--auth")
    two_word_flags+=("-u")
    flags+=("--cert=")
    two_word_flags+=("--cert")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--insecure")
    flags+=("-i")
    flags+=("--key=")
    two_word_flags+=("--key")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_wsk_activation()
{
    last_command="wsk_activation"

    command_aliases=()

    commands=()
    commands+=("get")
    commands+=("list")
    commands+=("logs")
    commands+=("poll")
    commands+=("result")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--apihost=")
    two_word_flags+=("--apihost")
    flags+=("--apiversion=")
    two_word_flags+=("--apiversion")
    flags+=("--auth=")
    two_word_flags+=("--auth")
    two_word_flags+=("-u")
    flags+=("--cert=")
    two_word_flags+=("--cert")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--insecure")
    flags+=("-i")
    flags+=("--key=")
    two_word_flags+=("--key")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_wsk_api_create()
{
    last_command="wsk_api_create"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--apiname=")
    two_word_flags+=("--apiname")
    two_word_flags+=("-n")
    local_nonpersistent_flags+=("--apiname")
    local_nonpersistent_flags+=("--apiname=")
    local_nonpersistent_flags+=("-n")
    flags+=("--config-file=")
    two_word_flags+=("--config-file")
    two_word_flags+=("-c")
    local_nonpersistent_flags+=("--config-file")
    local_nonpersistent_flags+=("--config-file=")
    local_nonpersistent_flags+=("-c")
    flags+=("--response-type=")
    two_word_flags+=("--response-type")
    local_nonpersistent_flags+=("--response-type")
    local_nonpersistent_flags+=("--response-type=")
    flags+=("--apihost=")
    two_word_flags+=("--apihost")
    flags+=("--apiversion=")
    two_word_flags+=("--apiversion")
    flags+=("--auth=")
    two_word_flags+=("--auth")
    two_word_flags+=("-u")
    flags+=("--cert=")
    two_word_flags+=("--cert")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--insecure")
    flags+=("-i")
    flags+=("--key=")
    two_word_flags+=("--key")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_wsk_api_delete()
{
    last_command="wsk_api_delete"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--apihost=")
    two_word_flags+=("--apihost")
    flags+=("--apiversion=")
    two_word_flags+=("--apiversion")
    flags+=("--auth=")
    two_word_flags+=("--auth")
    two_word_flags+=("-u")
    flags+=("--cert=")
    two_word_flags+=("--cert")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--insecure")
    flags+=("-i")
    flags+=("--key=")
    two_word_flags+=("--key")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_wsk_api_get()
{
    last_command="wsk_api_get"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--format=")
    two_word_flags+=("--format")
    local_nonpersistent_flags+=("--format")
    local_nonpersistent_flags+=("--format=")
    flags+=("--full")
    flags+=("-f")
    local_nonpersistent_flags+=("--full")
    local_nonpersistent_flags+=("-f")
    flags+=("--apihost=")
    two_word_flags+=("--apihost")
    flags+=("--apiversion=")
    two_word_flags+=("--apiversion")
    flags+=("--auth=")
    two_word_flags+=("--auth")
    two_word_flags+=("-u")
    flags+=("--cert=")
    two_word_flags+=("--cert")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--insecure")
    flags+=("-i")
    flags+=("--key=")
    two_word_flags+=("--key")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_wsk_api_list()
{
    last_command="wsk_api_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--full")
    flags+=("-f")
    local_nonpersistent_flags+=("--full")
    local_nonpersistent_flags+=("-f")
    flags+=("--limit=")
    two_word_flags+=("--limit")
    two_word_flags+=("-l")
    local_nonpersistent_flags+=("--limit")
    local_nonpersistent_flags+=("--limit=")
    local_nonpersistent_flags+=("-l")
    flags+=("--name-sort")
    flags+=("-n")
    local_nonpersistent_flags+=("--name-sort")
    local_nonpersistent_flags+=("-n")
    flags+=("--skip=")
    two_word_flags+=("--skip")
    two_word_flags+=("-s")
    local_nonpersistent_flags+=("--skip")
    local_nonpersistent_flags+=("--skip=")
    local_nonpersistent_flags+=("-s")
    flags+=("--apihost=")
    two_word_flags+=("--apihost")
    flags+=("--apiversion=")
    two_word_flags+=("--apiversion")
    flags+=("--auth=")
    two_word_flags+=("--auth")
    two_word_flags+=("-u")
    flags+=("--cert=")
    two_word_flags+=("--cert")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--insecure")
    flags+=("-i")
    flags+=("--key=")
    two_word_flags+=("--key")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_wsk_api()
{
    last_command="wsk_api"

    command_aliases=()

    commands=()
    commands+=("create")
    commands+=("delete")
    commands+=("get")
    commands+=("list")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--apihost=")
    two_word_flags+=("--apihost")
    flags+=("--apiversion=")
    two_word_flags+=("--apiversion")
    flags+=("--auth=")
    two_word_flags+=("--auth")
    two_word_flags+=("-u")
    flags+=("--cert=")
    two_word_flags+=("--cert")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--insecure")
    flags+=("-i")
    flags+=("--key=")
    two_word_flags+=("--key")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_wsk_help()
{
    last_command="wsk_help"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--apihost=")
    two_word_flags+=("--apihost")
    flags+=("--apiversion=")
    two_word_flags+=("--apiversion")
    flags+=("--auth=")
    two_word_flags+=("--auth")
    two_word_flags+=("-u")
    flags+=("--cert=")
    two_word_flags+=("--cert")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--insecure")
    flags+=("-i")
    flags+=("--key=")
    two_word_flags+=("--key")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_wsk_list()
{
    last_command="wsk_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--name-sort")
    flags+=("-n")
    local_nonpersistent_flags+=("--name-sort")
    local_nonpersistent_flags+=("-n")
    flags+=("--apihost=")
    two_word_flags+=("--apihost")
    flags+=("--apiversion=")
    two_word_flags+=("--apiversion")
    flags+=("--auth=")
    two_word_flags+=("--auth")
    two_word_flags+=("-u")
    flags+=("--cert=")
    two_word_flags+=("--cert")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--insecure")
    flags+=("-i")
    flags+=("--key=")
    two_word_flags+=("--key")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_wsk_namespace_get()
{
    last_command="wsk_namespace_get"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--name-sort")
    flags+=("-n")
    local_nonpersistent_flags+=("--name-sort")
    local_nonpersistent_flags+=("-n")
    flags+=("--apihost=")
    two_word_flags+=("--apihost")
    flags+=("--apiversion=")
    two_word_flags+=("--apiversion")
    flags+=("--auth=")
    two_word_flags+=("--auth")
    two_word_flags+=("-u")
    flags+=("--cert=")
    two_word_flags+=("--cert")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--insecure")
    flags+=("-i")
    flags+=("--key=")
    two_word_flags+=("--key")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_wsk_namespace_list()
{
    last_command="wsk_namespace_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--apihost=")
    two_word_flags+=("--apihost")
    flags+=("--apiversion=")
    two_word_flags+=("--apiversion")
    flags+=("--auth=")
    two_word_flags+=("--auth")
    two_word_flags+=("-u")
    flags+=("--cert=")
    two_word_flags+=("--cert")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--insecure")
    flags+=("-i")
    flags+=("--key=")
    two_word_flags+=("--key")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_wsk_namespace()
{
    last_command="wsk_namespace"

    command_aliases=()

    commands=()
    commands+=("get")
    commands+=("list")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--apihost=")
    two_word_flags+=("--apihost")
    flags+=("--apiversion=")
    two_word_flags+=("--apiversion")
    flags+=("--auth=")
    two_word_flags+=("--auth")
    two_word_flags+=("-u")
    flags+=("--cert=")
    two_word_flags+=("--cert")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--insecure")
    flags+=("-i")
    flags+=("--key=")
    two_word_flags+=("--key")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_wsk_package_bind()
{
    last_command="wsk_package_bind"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--annotation=")
    two_word_flags+=("--annotation")
    two_word_flags+=("-a")
    local_nonpersistent_flags+=("--annotation")
    local_nonpersistent_flags+=("--annotation=")
    local_nonpersistent_flags+=("-a")
    flags+=("--annotation-file=")
    two_word_flags+=("--annotation-file")
    two_word_flags+=("-A")
    local_nonpersistent_flags+=("--annotation-file")
    local_nonpersistent_flags+=("--annotation-file=")
    local_nonpersistent_flags+=("-A")
    flags+=("--overwrite")
    flags+=("-o")
    local_nonpersistent_flags+=("--overwrite")
    local_nonpersistent_flags+=("-o")
    flags+=("--param=")
    two_word_flags+=("--param")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--param")
    local_nonpersistent_flags+=("--param=")
    local_nonpersistent_flags+=("-p")
    flags+=("--param-file=")
    two_word_flags+=("--param-file")
    two_word_flags+=("-P")
    local_nonpersistent_flags+=("--param-file")
    local_nonpersistent_flags+=("--param-file=")
    local_nonpersistent_flags+=("-P")
    flags+=("--apihost=")
    two_word_flags+=("--apihost")
    flags+=("--apiversion=")
    two_word_flags+=("--apiversion")
    flags+=("--auth=")
    two_word_flags+=("--auth")
    two_word_flags+=("-u")
    flags+=("--cert=")
    two_word_flags+=("--cert")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--insecure")
    flags+=("-i")
    flags+=("--key=")
    two_word_flags+=("--key")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_wsk_package_create()
{
    last_command="wsk_package_create"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--annotation=")
    two_word_flags+=("--annotation")
    two_word_flags+=("-a")
    local_nonpersistent_flags+=("--annotation")
    local_nonpersistent_flags+=("--annotation=")
    local_nonpersistent_flags+=("-a")
    flags+=("--annotation-file=")
    two_word_flags+=("--annotation-file")
    two_word_flags+=("-A")
    local_nonpersistent_flags+=("--annotation-file")
    local_nonpersistent_flags+=("--annotation-file=")
    local_nonpersistent_flags+=("-A")
    flags+=("--param=")
    two_word_flags+=("--param")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--param")
    local_nonpersistent_flags+=("--param=")
    local_nonpersistent_flags+=("-p")
    flags+=("--param-file=")
    two_word_flags+=("--param-file")
    two_word_flags+=("-P")
    local_nonpersistent_flags+=("--param-file")
    local_nonpersistent_flags+=("--param-file=")
    local_nonpersistent_flags+=("-P")
    flags+=("--shared=")
    two_word_flags+=("--shared")
    local_nonpersistent_flags+=("--shared")
    local_nonpersistent_flags+=("--shared=")
    flags+=("--apihost=")
    two_word_flags+=("--apihost")
    flags+=("--apiversion=")
    two_word_flags+=("--apiversion")
    flags+=("--auth=")
    two_word_flags+=("--auth")
    two_word_flags+=("-u")
    flags+=("--cert=")
    two_word_flags+=("--cert")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--insecure")
    flags+=("-i")
    flags+=("--key=")
    two_word_flags+=("--key")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_wsk_package_delete()
{
    last_command="wsk_package_delete"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--apihost=")
    two_word_flags+=("--apihost")
    flags+=("--apiversion=")
    two_word_flags+=("--apiversion")
    flags+=("--auth=")
    two_word_flags+=("--auth")
    two_word_flags+=("-u")
    flags+=("--cert=")
    two_word_flags+=("--cert")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--insecure")
    flags+=("-i")
    flags+=("--key=")
    two_word_flags+=("--key")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_wsk_package_get()
{
    last_command="wsk_package_get"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--summary")
    flags+=("-s")
    local_nonpersistent_flags+=("--summary")
    local_nonpersistent_flags+=("-s")
    flags+=("--apihost=")
    two_word_flags+=("--apihost")
    flags+=("--apiversion=")
    two_word_flags+=("--apiversion")
    flags+=("--auth=")
    two_word_flags+=("--auth")
    two_word_flags+=("-u")
    flags+=("--cert=")
    two_word_flags+=("--cert")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--insecure")
    flags+=("-i")
    flags+=("--key=")
    two_word_flags+=("--key")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_wsk_package_list()
{
    last_command="wsk_package_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--limit=")
    two_word_flags+=("--limit")
    two_word_flags+=("-l")
    local_nonpersistent_flags+=("--limit")
    local_nonpersistent_flags+=("--limit=")
    local_nonpersistent_flags+=("-l")
    flags+=("--name-sort")
    flags+=("-n")
    local_nonpersistent_flags+=("--name-sort")
    local_nonpersistent_flags+=("-n")
    flags+=("--skip=")
    two_word_flags+=("--skip")
    two_word_flags+=("-s")
    local_nonpersistent_flags+=("--skip")
    local_nonpersistent_flags+=("--skip=")
    local_nonpersistent_flags+=("-s")
    flags+=("--apihost=")
    two_word_flags+=("--apihost")
    flags+=("--apiversion=")
    two_word_flags+=("--apiversion")
    flags+=("--auth=")
    two_word_flags+=("--auth")
    two_word_flags+=("-u")
    flags+=("--cert=")
    two_word_flags+=("--cert")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--insecure")
    flags+=("-i")
    flags+=("--key=")
    two_word_flags+=("--key")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_wsk_package_refresh()
{
    last_command="wsk_package_refresh"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--apihost=")
    two_word_flags+=("--apihost")
    flags+=("--apiversion=")
    two_word_flags+=("--apiversion")
    flags+=("--auth=")
    two_word_flags+=("--auth")
    two_word_flags+=("-u")
    flags+=("--cert=")
    two_word_flags+=("--cert")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--insecure")
    flags+=("-i")
    flags+=("--key=")
    two_word_flags+=("--key")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_wsk_package_update()
{
    last_command="wsk_package_update"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--annotation=")
    two_word_flags+=("--annotation")
    two_word_flags+=("-a")
    local_nonpersistent_flags+=("--annotation")
    local_nonpersistent_flags+=("--annotation=")
    local_nonpersistent_flags+=("-a")
    flags+=("--annotation-file=")
    two_word_flags+=("--annotation-file")
    two_word_flags+=("-A")
    local_nonpersistent_flags+=("--annotation-file")
    local_nonpersistent_flags+=("--annotation-file=")
    local_nonpersistent_flags+=("-A")
    flags+=("--param=")
    two_word_flags+=("--param")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--param")
    local_nonpersistent_flags+=("--param=")
    local_nonpersistent_flags+=("-p")
    flags+=("--param-file=")
    two_word_flags+=("--param-file")
    two_word_flags+=("-P")
    local_nonpersistent_flags+=("--param-file")
    local_nonpersistent_flags+=("--param-file=")
    local_nonpersistent_flags+=("-P")
    flags+=("--shared=")
    two_word_flags+=("--shared")
    local_nonpersistent_flags+=("--shared")
    local_nonpersistent_flags+=("--shared=")
    flags+=("--apihost=")
    two_word_flags+=("--apihost")
    flags+=("--apiversion=")
    two_word_flags+=("--apiversion")
    flags+=("--auth=")
    two_word_flags+=("--auth")
    two_word_flags+=("-u")
    flags+=("--cert=")
    two_word_flags+=("--cert")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--insecure")
    flags+=("-i")
    flags+=("--key=")
    two_word_flags+=("--key")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_wsk_package()
{
    last_command="wsk_package"

    command_aliases=()

    commands=()
    commands+=("bind")
    commands+=("create")
    commands+=("delete")
    commands+=("get")
    commands+=("list")
    commands+=("refresh")
    commands+=("update")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--apihost=")
    two_word_flags+=("--apihost")
    flags+=("--apiversion=")
    two_word_flags+=("--apiversion")
    flags+=("--auth=")
    two_word_flags+=("--auth")
    two_word_flags+=("-u")
    flags+=("--cert=")
    two_word_flags+=("--cert")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--insecure")
    flags+=("-i")
    flags+=("--key=")
    two_word_flags+=("--key")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_wsk_project_deploy()
{
    last_command="wsk_project_deploy"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--apihost=")
    two_word_flags+=("--apihost")
    flags+=("--apiversion=")
    two_word_flags+=("--apiversion")
    flags+=("--auth=")
    two_word_flags+=("--auth")
    two_word_flags+=("-u")
    flags+=("--cert=")
    two_word_flags+=("--cert")
    two_word_flags+=("-c")
    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--deployment=")
    two_word_flags+=("--deployment")
    flags+=("--insecure")
    flags+=("-i")
    flags+=("--key=")
    two_word_flags+=("--key")
    two_word_flags+=("-k")
    flags+=("--manifest=")
    two_word_flags+=("--manifest")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    two_word_flags+=("-n")
    flags+=("--param=")
    two_word_flags+=("--param")
    flags+=("--param-file=")
    two_word_flags+=("--param-file")
    flags+=("--preview")
    flags+=("--project=")
    two_word_flags+=("--project")
    flags+=("--projectname=")
    two_word_flags+=("--projectname")
    flags+=("--strict")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_wsk_project_export()
{
    last_command="wsk_project_export"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--apihost=")
    two_word_flags+=("--apihost")
    flags+=("--apiversion=")
    two_word_flags+=("--apiversion")
    flags+=("--auth=")
    two_word_flags+=("--auth")
    two_word_flags+=("-u")
    flags+=("--cert=")
    two_word_flags+=("--cert")
    two_word_flags+=("-c")
    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--deployment=")
    two_word_flags+=("--deployment")
    flags+=("--insecure")
    flags+=("-i")
    flags+=("--key=")
    two_word_flags+=("--key")
    two_word_flags+=("-k")
    flags+=("--manifest=")
    two_word_flags+=("--manifest")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    two_word_flags+=("-n")
    flags+=("--param=")
    two_word_flags+=("--param")
    flags+=("--param-file=")
    two_word_flags+=("--param-file")
    flags+=("--preview")
    flags+=("--project=")
    two_word_flags+=("--project")
    flags+=("--projectname=")
    two_word_flags+=("--projectname")
    flags+=("--strict")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_wsk_project_sync()
{
    last_command="wsk_project_sync"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--apihost=")
    two_word_flags+=("--apihost")
    flags+=("--apiversion=")
    two_word_flags+=("--apiversion")
    flags+=("--auth=")
    two_word_flags+=("--auth")
    two_word_flags+=("-u")
    flags+=("--cert=")
    two_word_flags+=("--cert")
    two_word_flags+=("-c")
    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--deployment=")
    two_word_flags+=("--deployment")
    flags+=("--insecure")
    flags+=("-i")
    flags+=("--key=")
    two_word_flags+=("--key")
    two_word_flags+=("-k")
    flags+=("--manifest=")
    two_word_flags+=("--manifest")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    two_word_flags+=("-n")
    flags+=("--param=")
    two_word_flags+=("--param")
    flags+=("--param-file=")
    two_word_flags+=("--param-file")
    flags+=("--preview")
    flags+=("--project=")
    two_word_flags+=("--project")
    flags+=("--projectname=")
    two_word_flags+=("--projectname")
    flags+=("--strict")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_wsk_project_undeploy()
{
    last_command="wsk_project_undeploy"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--apihost=")
    two_word_flags+=("--apihost")
    flags+=("--apiversion=")
    two_word_flags+=("--apiversion")
    flags+=("--auth=")
    two_word_flags+=("--auth")
    two_word_flags+=("-u")
    flags+=("--cert=")
    two_word_flags+=("--cert")
    two_word_flags+=("-c")
    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--deployment=")
    two_word_flags+=("--deployment")
    flags+=("--insecure")
    flags+=("-i")
    flags+=("--key=")
    two_word_flags+=("--key")
    two_word_flags+=("-k")
    flags+=("--manifest=")
    two_word_flags+=("--manifest")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    two_word_flags+=("-n")
    flags+=("--param=")
    two_word_flags+=("--param")
    flags+=("--param-file=")
    two_word_flags+=("--param-file")
    flags+=("--preview")
    flags+=("--project=")
    two_word_flags+=("--project")
    flags+=("--projectname=")
    two_word_flags+=("--projectname")
    flags+=("--strict")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_wsk_project()
{
    last_command="wsk_project"

    command_aliases=()

    commands=()
    commands+=("deploy")
    commands+=("export")
    commands+=("sync")
    commands+=("undeploy")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--config=")
    two_word_flags+=("--config")
    flags+=("--deployment=")
    two_word_flags+=("--deployment")
    flags+=("--manifest=")
    two_word_flags+=("--manifest")
    flags+=("--namespace=")
    two_word_flags+=("--namespace")
    two_word_flags+=("-n")
    flags+=("--param=")
    two_word_flags+=("--param")
    flags+=("--param-file=")
    two_word_flags+=("--param-file")
    flags+=("--preview")
    flags+=("--project=")
    two_word_flags+=("--project")
    flags+=("--projectname=")
    two_word_flags+=("--projectname")
    flags+=("--strict")
    flags+=("--apihost=")
    two_word_flags+=("--apihost")
    flags+=("--apiversion=")
    two_word_flags+=("--apiversion")
    flags+=("--auth=")
    two_word_flags+=("--auth")
    two_word_flags+=("-u")
    flags+=("--cert=")
    two_word_flags+=("--cert")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--insecure")
    flags+=("-i")
    flags+=("--key=")
    two_word_flags+=("--key")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_wsk_property_get()
{
    last_command="wsk_property_get"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--all")
    local_nonpersistent_flags+=("--all")
    flags+=("--apibuild")
    local_nonpersistent_flags+=("--apibuild")
    flags+=("--apibuildno")
    local_nonpersistent_flags+=("--apibuildno")
    flags+=("--cliversion")
    local_nonpersistent_flags+=("--cliversion")
    flags+=("--namespace")
    local_nonpersistent_flags+=("--namespace")
    flags+=("--output=")
    two_word_flags+=("--output")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--output")
    local_nonpersistent_flags+=("--output=")
    local_nonpersistent_flags+=("-o")
    flags+=("--apihost=")
    two_word_flags+=("--apihost")
    flags+=("--apiversion=")
    two_word_flags+=("--apiversion")
    flags+=("--auth=")
    two_word_flags+=("--auth")
    two_word_flags+=("-u")
    flags+=("--cert=")
    two_word_flags+=("--cert")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--insecure")
    flags+=("-i")
    flags+=("--key=")
    two_word_flags+=("--key")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_wsk_property_set()
{
    last_command="wsk_property_set"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--apihost=")
    two_word_flags+=("--apihost")
    flags+=("--apiversion=")
    two_word_flags+=("--apiversion")
    flags+=("--auth=")
    two_word_flags+=("--auth")
    two_word_flags+=("-u")
    flags+=("--cert=")
    two_word_flags+=("--cert")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--insecure")
    flags+=("-i")
    flags+=("--key=")
    two_word_flags+=("--key")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_wsk_property_unset()
{
    last_command="wsk_property_unset"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--apihost=")
    two_word_flags+=("--apihost")
    flags+=("--apiversion=")
    two_word_flags+=("--apiversion")
    flags+=("--auth=")
    two_word_flags+=("--auth")
    two_word_flags+=("-u")
    flags+=("--cert=")
    two_word_flags+=("--cert")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--insecure")
    flags+=("-i")
    flags+=("--key=")
    two_word_flags+=("--key")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_wsk_property()
{
    last_command="wsk_property"

    command_aliases=()

    commands=()
    commands+=("get")
    commands+=("set")
    commands+=("unset")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--apihost=")
    two_word_flags+=("--apihost")
    flags+=("--apiversion=")
    two_word_flags+=("--apiversion")
    flags+=("--auth=")
    two_word_flags+=("--auth")
    two_word_flags+=("-u")
    flags+=("--cert=")
    two_word_flags+=("--cert")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--insecure")
    flags+=("-i")
    flags+=("--key=")
    two_word_flags+=("--key")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_wsk_rule_create()
{
    last_command="wsk_rule_create"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--apihost=")
    two_word_flags+=("--apihost")
    flags+=("--apiversion=")
    two_word_flags+=("--apiversion")
    flags+=("--auth=")
    two_word_flags+=("--auth")
    two_word_flags+=("-u")
    flags+=("--cert=")
    two_word_flags+=("--cert")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--insecure")
    flags+=("-i")
    flags+=("--key=")
    two_word_flags+=("--key")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_wsk_rule_delete()
{
    last_command="wsk_rule_delete"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--disable")
    local_nonpersistent_flags+=("--disable")
    flags+=("--apihost=")
    two_word_flags+=("--apihost")
    flags+=("--apiversion=")
    two_word_flags+=("--apiversion")
    flags+=("--auth=")
    two_word_flags+=("--auth")
    two_word_flags+=("-u")
    flags+=("--cert=")
    two_word_flags+=("--cert")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--insecure")
    flags+=("-i")
    flags+=("--key=")
    two_word_flags+=("--key")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_wsk_rule_disable()
{
    last_command="wsk_rule_disable"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--apihost=")
    two_word_flags+=("--apihost")
    flags+=("--apiversion=")
    two_word_flags+=("--apiversion")
    flags+=("--auth=")
    two_word_flags+=("--auth")
    two_word_flags+=("-u")
    flags+=("--cert=")
    two_word_flags+=("--cert")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--insecure")
    flags+=("-i")
    flags+=("--key=")
    two_word_flags+=("--key")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_wsk_rule_enable()
{
    last_command="wsk_rule_enable"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--apihost=")
    two_word_flags+=("--apihost")
    flags+=("--apiversion=")
    two_word_flags+=("--apiversion")
    flags+=("--auth=")
    two_word_flags+=("--auth")
    two_word_flags+=("-u")
    flags+=("--cert=")
    two_word_flags+=("--cert")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--insecure")
    flags+=("-i")
    flags+=("--key=")
    two_word_flags+=("--key")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_wsk_rule_get()
{
    last_command="wsk_rule_get"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--summary")
    flags+=("-s")
    local_nonpersistent_flags+=("--summary")
    local_nonpersistent_flags+=("-s")
    flags+=("--apihost=")
    two_word_flags+=("--apihost")
    flags+=("--apiversion=")
    two_word_flags+=("--apiversion")
    flags+=("--auth=")
    two_word_flags+=("--auth")
    two_word_flags+=("-u")
    flags+=("--cert=")
    two_word_flags+=("--cert")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--insecure")
    flags+=("-i")
    flags+=("--key=")
    two_word_flags+=("--key")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_wsk_rule_list()
{
    last_command="wsk_rule_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--limit=")
    two_word_flags+=("--limit")
    two_word_flags+=("-l")
    local_nonpersistent_flags+=("--limit")
    local_nonpersistent_flags+=("--limit=")
    local_nonpersistent_flags+=("-l")
    flags+=("--name-sort")
    flags+=("-n")
    local_nonpersistent_flags+=("--name-sort")
    local_nonpersistent_flags+=("-n")
    flags+=("--skip=")
    two_word_flags+=("--skip")
    two_word_flags+=("-s")
    local_nonpersistent_flags+=("--skip")
    local_nonpersistent_flags+=("--skip=")
    local_nonpersistent_flags+=("-s")
    flags+=("--apihost=")
    two_word_flags+=("--apihost")
    flags+=("--apiversion=")
    two_word_flags+=("--apiversion")
    flags+=("--auth=")
    two_word_flags+=("--auth")
    two_word_flags+=("-u")
    flags+=("--cert=")
    two_word_flags+=("--cert")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--insecure")
    flags+=("-i")
    flags+=("--key=")
    two_word_flags+=("--key")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_wsk_rule_status()
{
    last_command="wsk_rule_status"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--apihost=")
    two_word_flags+=("--apihost")
    flags+=("--apiversion=")
    two_word_flags+=("--apiversion")
    flags+=("--auth=")
    two_word_flags+=("--auth")
    two_word_flags+=("-u")
    flags+=("--cert=")
    two_word_flags+=("--cert")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--insecure")
    flags+=("-i")
    flags+=("--key=")
    two_word_flags+=("--key")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_wsk_rule_update()
{
    last_command="wsk_rule_update"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--apihost=")
    two_word_flags+=("--apihost")
    flags+=("--apiversion=")
    two_word_flags+=("--apiversion")
    flags+=("--auth=")
    two_word_flags+=("--auth")
    two_word_flags+=("-u")
    flags+=("--cert=")
    two_word_flags+=("--cert")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--insecure")
    flags+=("-i")
    flags+=("--key=")
    two_word_flags+=("--key")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_wsk_rule()
{
    last_command="wsk_rule"

    command_aliases=()

    commands=()
    commands+=("create")
    commands+=("delete")
    commands+=("disable")
    commands+=("enable")
    commands+=("get")
    commands+=("list")
    commands+=("status")
    commands+=("update")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--apihost=")
    two_word_flags+=("--apihost")
    flags+=("--apiversion=")
    two_word_flags+=("--apiversion")
    flags+=("--auth=")
    two_word_flags+=("--auth")
    two_word_flags+=("-u")
    flags+=("--cert=")
    two_word_flags+=("--cert")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--insecure")
    flags+=("-i")
    flags+=("--key=")
    two_word_flags+=("--key")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_wsk_sdk_install()
{
    last_command="wsk_sdk_install"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--help")
    flags+=("-h")
    local_nonpersistent_flags+=("--help")
    local_nonpersistent_flags+=("-h")
    flags+=("--stdout")
    flags+=("-s")
    local_nonpersistent_flags+=("--stdout")
    local_nonpersistent_flags+=("-s")
    flags+=("--apihost=")
    two_word_flags+=("--apihost")
    flags+=("--apiversion=")
    two_word_flags+=("--apiversion")
    flags+=("--auth=")
    two_word_flags+=("--auth")
    two_word_flags+=("-u")
    flags+=("--cert=")
    two_word_flags+=("--cert")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--insecure")
    flags+=("-i")
    flags+=("--key=")
    two_word_flags+=("--key")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_wsk_sdk()
{
    last_command="wsk_sdk"

    command_aliases=()

    commands=()
    commands+=("install")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--apihost=")
    two_word_flags+=("--apihost")
    flags+=("--apiversion=")
    two_word_flags+=("--apiversion")
    flags+=("--auth=")
    two_word_flags+=("--auth")
    two_word_flags+=("-u")
    flags+=("--cert=")
    two_word_flags+=("--cert")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--insecure")
    flags+=("-i")
    flags+=("--key=")
    two_word_flags+=("--key")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_wsk_trigger_create()
{
    last_command="wsk_trigger_create"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--annotation=")
    two_word_flags+=("--annotation")
    two_word_flags+=("-a")
    local_nonpersistent_flags+=("--annotation")
    local_nonpersistent_flags+=("--annotation=")
    local_nonpersistent_flags+=("-a")
    flags+=("--annotation-file=")
    two_word_flags+=("--annotation-file")
    two_word_flags+=("-A")
    local_nonpersistent_flags+=("--annotation-file")
    local_nonpersistent_flags+=("--annotation-file=")
    local_nonpersistent_flags+=("-A")
    flags+=("--feed=")
    two_word_flags+=("--feed")
    two_word_flags+=("-f")
    local_nonpersistent_flags+=("--feed")
    local_nonpersistent_flags+=("--feed=")
    local_nonpersistent_flags+=("-f")
    flags+=("--feed-param=")
    two_word_flags+=("--feed-param")
    two_word_flags+=("-F")
    local_nonpersistent_flags+=("--feed-param")
    local_nonpersistent_flags+=("--feed-param=")
    local_nonpersistent_flags+=("-F")
    flags+=("--param=")
    two_word_flags+=("--param")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--param")
    local_nonpersistent_flags+=("--param=")
    local_nonpersistent_flags+=("-p")
    flags+=("--param-file=")
    two_word_flags+=("--param-file")
    two_word_flags+=("-P")
    local_nonpersistent_flags+=("--param-file")
    local_nonpersistent_flags+=("--param-file=")
    local_nonpersistent_flags+=("-P")
    flags+=("--trigger-param=")
    two_word_flags+=("--trigger-param")
    two_word_flags+=("-T")
    local_nonpersistent_flags+=("--trigger-param")
    local_nonpersistent_flags+=("--trigger-param=")
    local_nonpersistent_flags+=("-T")
    flags+=("--apihost=")
    two_word_flags+=("--apihost")
    flags+=("--apiversion=")
    two_word_flags+=("--apiversion")
    flags+=("--auth=")
    two_word_flags+=("--auth")
    two_word_flags+=("-u")
    flags+=("--cert=")
    two_word_flags+=("--cert")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--insecure")
    flags+=("-i")
    flags+=("--key=")
    two_word_flags+=("--key")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_wsk_trigger_delete()
{
    last_command="wsk_trigger_delete"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--apihost=")
    two_word_flags+=("--apihost")
    flags+=("--apiversion=")
    two_word_flags+=("--apiversion")
    flags+=("--auth=")
    two_word_flags+=("--auth")
    two_word_flags+=("-u")
    flags+=("--cert=")
    two_word_flags+=("--cert")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--insecure")
    flags+=("-i")
    flags+=("--key=")
    two_word_flags+=("--key")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_wsk_trigger_fire()
{
    last_command="wsk_trigger_fire"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--param=")
    two_word_flags+=("--param")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--param")
    local_nonpersistent_flags+=("--param=")
    local_nonpersistent_flags+=("-p")
    flags+=("--param-file=")
    two_word_flags+=("--param-file")
    two_word_flags+=("-P")
    local_nonpersistent_flags+=("--param-file")
    local_nonpersistent_flags+=("--param-file=")
    local_nonpersistent_flags+=("-P")
    flags+=("--apihost=")
    two_word_flags+=("--apihost")
    flags+=("--apiversion=")
    two_word_flags+=("--apiversion")
    flags+=("--auth=")
    two_word_flags+=("--auth")
    two_word_flags+=("-u")
    flags+=("--cert=")
    two_word_flags+=("--cert")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--insecure")
    flags+=("-i")
    flags+=("--key=")
    two_word_flags+=("--key")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_wsk_trigger_get()
{
    last_command="wsk_trigger_get"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--summary")
    flags+=("-s")
    local_nonpersistent_flags+=("--summary")
    local_nonpersistent_flags+=("-s")
    flags+=("--apihost=")
    two_word_flags+=("--apihost")
    flags+=("--apiversion=")
    two_word_flags+=("--apiversion")
    flags+=("--auth=")
    two_word_flags+=("--auth")
    two_word_flags+=("-u")
    flags+=("--cert=")
    two_word_flags+=("--cert")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--insecure")
    flags+=("-i")
    flags+=("--key=")
    two_word_flags+=("--key")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_wsk_trigger_list()
{
    last_command="wsk_trigger_list"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--limit=")
    two_word_flags+=("--limit")
    two_word_flags+=("-l")
    local_nonpersistent_flags+=("--limit")
    local_nonpersistent_flags+=("--limit=")
    local_nonpersistent_flags+=("-l")
    flags+=("--name-sort")
    flags+=("-n")
    local_nonpersistent_flags+=("--name-sort")
    local_nonpersistent_flags+=("-n")
    flags+=("--skip=")
    two_word_flags+=("--skip")
    two_word_flags+=("-s")
    local_nonpersistent_flags+=("--skip")
    local_nonpersistent_flags+=("--skip=")
    local_nonpersistent_flags+=("-s")
    flags+=("--apihost=")
    two_word_flags+=("--apihost")
    flags+=("--apiversion=")
    two_word_flags+=("--apiversion")
    flags+=("--auth=")
    two_word_flags+=("--auth")
    two_word_flags+=("-u")
    flags+=("--cert=")
    two_word_flags+=("--cert")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--insecure")
    flags+=("-i")
    flags+=("--key=")
    two_word_flags+=("--key")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_wsk_trigger_update()
{
    last_command="wsk_trigger_update"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--annotation=")
    two_word_flags+=("--annotation")
    two_word_flags+=("-a")
    local_nonpersistent_flags+=("--annotation")
    local_nonpersistent_flags+=("--annotation=")
    local_nonpersistent_flags+=("-a")
    flags+=("--annotation-file=")
    two_word_flags+=("--annotation-file")
    two_word_flags+=("-A")
    local_nonpersistent_flags+=("--annotation-file")
    local_nonpersistent_flags+=("--annotation-file=")
    local_nonpersistent_flags+=("-A")
    flags+=("--feed-param=")
    two_word_flags+=("--feed-param")
    two_word_flags+=("-F")
    local_nonpersistent_flags+=("--feed-param")
    local_nonpersistent_flags+=("--feed-param=")
    local_nonpersistent_flags+=("-F")
    flags+=("--param=")
    two_word_flags+=("--param")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--param")
    local_nonpersistent_flags+=("--param=")
    local_nonpersistent_flags+=("-p")
    flags+=("--param-file=")
    two_word_flags+=("--param-file")
    two_word_flags+=("-P")
    local_nonpersistent_flags+=("--param-file")
    local_nonpersistent_flags+=("--param-file=")
    local_nonpersistent_flags+=("-P")
    flags+=("--trigger-param=")
    two_word_flags+=("--trigger-param")
    two_word_flags+=("-T")
    local_nonpersistent_flags+=("--trigger-param")
    local_nonpersistent_flags+=("--trigger-param=")
    local_nonpersistent_flags+=("-T")
    flags+=("--apihost=")
    two_word_flags+=("--apihost")
    flags+=("--apiversion=")
    two_word_flags+=("--apiversion")
    flags+=("--auth=")
    two_word_flags+=("--auth")
    two_word_flags+=("-u")
    flags+=("--cert=")
    two_word_flags+=("--cert")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--insecure")
    flags+=("-i")
    flags+=("--key=")
    two_word_flags+=("--key")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_wsk_trigger()
{
    last_command="wsk_trigger"

    command_aliases=()

    commands=()
    commands+=("create")
    commands+=("delete")
    commands+=("fire")
    commands+=("get")
    commands+=("list")
    commands+=("update")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--apihost=")
    two_word_flags+=("--apihost")
    flags+=("--apiversion=")
    two_word_flags+=("--apiversion")
    flags+=("--auth=")
    two_word_flags+=("--auth")
    two_word_flags+=("-u")
    flags+=("--cert=")
    two_word_flags+=("--cert")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--insecure")
    flags+=("-i")
    flags+=("--key=")
    two_word_flags+=("--key")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_wsk_root_command()
{
    last_command="wsk"

    command_aliases=()

    commands=()
    commands+=("action")
    commands+=("activation")
    commands+=("api")
    commands+=("help")
    commands+=("list")
    commands+=("namespace")
    commands+=("package")
    commands+=("project")
    commands+=("property")
    commands+=("rule")
    commands+=("sdk")
    commands+=("trigger")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--apihost=")
    two_word_flags+=("--apihost")
    flags+=("--apiversion=")
    two_word_flags+=("--apiversion")
    flags+=("--auth=")
    two_word_flags+=("--auth")
    two_word_flags+=("-u")
    flags+=("--cert=")
    two_word_flags+=("--cert")
    flags+=("--debug")
    flags+=("-d")
    flags+=("--insecure")
    flags+=("-i")
    flags+=("--key=")
    two_word_flags+=("--key")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

__start_wsk()
{
    local cur prev words cword
    declare -A flaghash 2>/dev/null || :
    declare -A aliashash 2>/dev/null || :
    if declare -F _init_completion >/dev/null 2>&1; then
        _init_completion -s || return
    else
        __wsk_init_completion -n "=" || return
    fi

    local c=0
    local flags=()
    local two_word_flags=()
    local local_nonpersistent_flags=()
    local flags_with_completion=()
    local flags_completion=()
    local commands=("wsk")
    local must_have_one_flag=()
    local must_have_one_noun=()
    local has_completion_function
    local last_command
    local nouns=()

    __wsk_handle_word
}

if [[ $(type -t compopt) = "builtin" ]]; then
    complete -o default -F __start_wsk wsk
else
    complete -o default -o nospace -F __start_wsk wsk
fi

# ex: ts=4 sw=4 et filetype=sh
