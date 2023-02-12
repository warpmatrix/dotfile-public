. ~/dotfile/utils.sh

cfg_mirror() {
    local mirror_exts=( "mingw32" "mingw64" "ucrt64" "clang64" "msys" )

    for ext in ${mirror_exts[@]}; do
        local file="/etc/pacman.d/mirrorlist.$ext"
        if ! pat_in_file "tsinghua" "$file"; then
            case $ext in
                mingw32)
                    local postfix="mingw/i686"
                    ;;
                mingw64)
                    local postfix="mingw/x86_64"
                    ;;
                msys)
                    local postfix='msys/$arch'
                    ;;
                *)
                    local postfix="mingw/$ext"
                    ;;
            esac
            sed -i "1 i Server = https://mirrors.tuna.tsinghua.edu.cn/msys2/$postfix" $file
        fi
    done
}

cfg_shell() {
    local platforms=( "msys2" "mingw32" "mingw64" )
    for platform in ${platforms[@]}; do
        if ! pat_in_file "SHELL" "/$platform.ini"; then
            echo "SHELL=/usr/bin/zsh" >> "$platform.ini"
        fi
    done
    sed -i 's/^set "LOGINSHELL=bash"/set "LOGINSHELL=zsh"/g' /msys2_shell.cmd
}

cfg_msys() {
    local exp_lnk='export MSYS="winsymlinks:lnk"'
    if ! pat_in_file "${exp_lnk}" /etc/profile; then
        echo "${exp_lnk}" >> /etc/profile
    fi

    if [ ! -L /home/$USERNAME ]; then
        ln -s /c/Users/$USERNAME /home/$USERNAME
    fi

    cfg_mirror
    cfg_shell
}

cfg_msys

if ! $(has_cmd zsh); then
    pacman -S zsh
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
fi

if [ ! -f "./VSCodeSetup-x64.exe" ]; then
    curl -sSL -o VSCodeSetup-x64.exe "https://code.visualstudio.com/sha/download?build=stable&os=win32-x64"
fi

if [ ! -f "./ahk-install.exe" ] ; then 
    curl -sSOL https://www.autohotkey.com/download/ahk-install.exe
    cp ./keymap.ahk "/C/Users/$USERNAME/AppData/Roaming/Microsoft/Windows/Start Menu/Programs/Startup/keymap.ahk"
fi
if [ ! -f "./im-select.exe" ] ; then 
    curl -sSOL https://github.com/daipeihust/im-select/raw/master/im-select-win/out/x64/im-select.exe
    cp ./im-select.exe /usr/bin/im-select.exe
fi
if [ ! -f "./DeskPins-1.32-setup.exe" ] ; then 
    curl -sSOL https://efotinis.neocities.org/downloads/DeskPins-1.32-setup.exe
fi
