#!/bin/bash

prompt_continue()
{
    CONTINUE=""

    while [[ "$CONTINUE" != "Y" && "$CONTINUE" != "N" ]]; do
        read -p "Continue? [Y/N] " CONTINUE
    done

    if [[ "$CONTINUE" == "N" ]]; then
        echo "Aborting process"
        exit 1
    fi
}

echo 'Setting up the Proton environment to run ACT with network capture'
echo 'This script will set up your wine prefix and proton executables to run ACT, as well as set up a default ACT install for you'
echo 'If this process is aborted at any Continue prompt, it will resume from that point the next time it is run'
echo 'Please make sure nothing is running in the wine prefix for FFXIV before continuing'
echo
echo "Making sure wine isn't running anything"

wine64 wineboot -s &>/dev/null

if [ ! -f "$HOME/bin/ffxiv-env-setup.sh" ]; then
    echo "The FFXIV environment hasn't been configured yet. Please run the stage1 setup first!"
    exit 1
fi

echo 'Making sure you have winetricks'

WINETRICKS="$(which winetricks 2>/dev/null)"

if [[ "$WINETRICKS" == "" ]]; then
    WINETRICKS="$HOME/bin/winetricks"
    if [ ! -f "$HOME/bin/winetricks" ]; then
        echo "winetricks not found on your system. Downloading latest release from the winetricks github repo and storing it at $HOME/bin/winetricks"
        wget -O "$HOME/bin/winetricks" "https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks" &>/dev/null
        chmod +x "$HOME/bin/winetricks"
    fi
fi

echo 'Sourcing the FFXIV environment'
. $HOME/bin/ffxiv-env-setup.sh

echo 'Note that this process is destructive, meaning that if something goes wrong it can break your wine prefix and/or your proton runner installation'
echo 'Please make backups of both!'
echo "wine prefix: $WINEPREFIX"
echo "Proton distribution: $PROTON_DIST_PATH"

prompt_continue

echo 'Getting a list of installed packages in wine prefix'
WINE_INSTALLED_PACKAGES="$(wine64 uninstaller --list 2>/dev/null)"

echo 'Checking for WINE Mono'

if [[ "$(echo "$WINE_INSTALLED_PACKAGES" | grep '{EA50D369-6B67-43BC-8153-C3553B40ABEB} - 1033')" != "" ]]; then
    echo 'WINE Mono was found in the wine prefix and must be uninstalled'
    prompt_continue
    wine64 uninstaller --remove '{EA50D369-6B67-43BC-8153-C3553B40ABEB}'
fi

echo 'Checking for .NET Framework'

# TODO: Check for each version in order and start installation where it left off?

if [[ "$(echo "$WINE_INSTALLED_PACKAGES" | grep '{92FB6C44-E685-45AD-9B20-CADF4CABA132} - 1033')" == "" ]]; then
    echo 'Could not find .NET Framework 4.7.2, running winetricks installer for each version in order'
    prompt_continue
    echo 'Please continue through the install prompts for each .NET Framework installer'
    echo 'If prompted to restart by the installer, please choose Yes. This will only restart the wine server and is required for the .NET Framework to install properly'
    "$WINETRICKS" dotnet40
    "$WINETRICKS" dotnet45
    "$WINETRICKS" dotnet452
    "$WINETRICKS" dotnet46
    "$WINETRICKS" dotnet461
    "$WINETRICKS" dotnet462
    "$WINETRICKS" dotnet471
    "$WINETRICKS" dotnet472
fi

echo 'Checking for ACT install'
ACT_LOCATION="$WINEPREFIX/drive_c/ACT"

if [ -f "$WINEPREFIX/.ACT_Location" ]; then
    ACT_LOCATION="$(cat "$WINEPREFIX/.ACT_Location")"
else
    echo "Setup hasn't been run on this wine prefix before"
    echo "Searching for the ACT install may take some time if this prefix has been highly customized."
    prompt_continue

    TEMP_ACT_LOCATION="$(find $WINEPREFIX -name 'Advanced Combat Tracker.exe')"

    if [[ "$TEMP_ACT_LOCATION" == "" ]]; then
        echo 'Could not find ACT install, downloading and installing latest version'
        if [[ "$(which unzip 2>/dev/null)" == "" ]]; then
            echo "ACT install requires the unzip tool. Please install it from your distro's package manager and try again."
            exit 1
        fi
        prompt_continue
        wget -O "/tmp/ACT.zip" "https://advancedcombattracker.com/includes/page-download.php?id=57" &>/dev/null
        mkdir -p "$ACT_LOCATION" &> /dev/null
        unzip -qq "/tmp/ACT.zip" -d "$ACT_LOCATION"
    else
        ACT_LOCATION="$(dirname "$TEMP_ACT_LOCATION")"
    fi
    echo "Found ACT location at $ACT_LOCATION"
    echo "Saving this path to $WINEPREFIX/.ACT_Location for future use"
    echo "$ACT_LOCATION" > "$WINEPREFIX/.ACT_Location"
fi

echo "Making sure wine isn't running anything"
wine64 wineboot -s &>/dev/null

echo 'Checking for patchelf'

PATCHELF="$(which patchelf 2>/dev/null)"

if [[ "$PATCHELF" == "" ]]; then
    echo "patchelf binary was not found. Please install from your distro's package manager if available"
    echo "If patchelf is not available, then please download and compile it yourself from https://github.com/NixOS/patchelf/releases"
    exit 1
fi

echo 'Checking to see if wine binaries and libraries need to be patched'

if [[ "$(patchelf --print-rpath "$(which wine)" | grep '$ORIGIN')" != "" ]]; then
    echo 'Patching the rpath of wine executables and libraries'
    prompt_continue
    RPATH="${PROTON_DIST_PATH}/lib64:${PROTON_DIST_PATH}/lib"
    if [[ "$IS_STEAM" == "1" ]]; then
        RPATH="$RPATH:$HOME/.local/share/Steam/ubuntu12_64:$HOME/.local/share/Steam/ubuntu12_32"
    fi
    patchelf --set-rpath "$RPATH" "$(which wine)"
    patchelf --set-rpath "$RPATH" "$(which wine64)"
    patchelf --set-rpath "$RPATH" "$(which wineserver)"
    find "${PROTON_DIST_PATH}/lib64" -type f | xargs -I{} patchelf --set-rpath "$RPATH" {} &> /dev/null
    find "${PROTON_DIST_PATH}/lib" -type f | xargs -I{} patchelf --set-rpath "$RPATH" {} &> /dev/null
fi

echo 'Checking to see if wine binaries need their capabilities set'

if [[ "$(getcap "$(which wine)")" == "" ]]; then
    cat << EOF
Setting capabilities on wine executables
This process must be run as root, so you will be prompted for your password
The commands to be run are as follows:

sudo setcap cap_net_raw,cap_net_admin,cap_sys_ptrace=eip "$(which wine)"
sudo setcap cap_net_raw,cap_net_admin,cap_sys_ptrace=eip "$(which wine64)"
sudo setcap cap_net_raw,cap_net_admin,cap_sys_ptrace=eip "$(which wineserver)"
EOF
    prompt_continue
    sudo setcap cap_net_raw,cap_net_admin,cap_sys_ptrace=eip "$(which wine)"
    sudo setcap cap_net_raw,cap_net_admin,cap_sys_ptrace=eip "$(which wine64)"
    sudo setcap cap_net_raw,cap_net_admin,cap_sys_ptrace=eip "$(which wineserver)"
fi
