# https://eternallybored.org/misc/wget/
if [ ! -f "./ahk-install.exe" ] ; then 
    wget https://www.autohotkey.com/download/ahk-install.exe
    cp ./keymap.ahk "/C/Users/$USERNAME/AppData/Roaming/Microsoft/Windows/Start Menu/Programs/Startup/keymap.ahk"
fi
if [ ! -f "./im-select.exe" ] ; then 
    wget https://github.com/daipeihust/im-select/raw/master/im-select-win/out/x64/im-select.exe
    cp ./im-select.exe /usr/bin/im-select.exe
fi
if [ ! -f "./DeskPins-1.32-setup.exe" ] ; then 
    wget https://efotinis.neocities.org/downloads/DeskPins-1.32-setup.exe
fi
