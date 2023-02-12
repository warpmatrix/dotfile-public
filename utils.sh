has_cmd() {
    [ -n "$(command -v $1)" ]
}

pat_in_file() {
    local pattern=$1
    local file=$2
    ! [ -z "$(cat "$file" | grep "$pattern")" ]
}
