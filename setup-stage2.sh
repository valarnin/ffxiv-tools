#!/bin/bash

prompt_continue()
{
    CONTINUE=""

    while [[ "$CONTINUE" != "Y" && "$CONTINUE" != "N" && "$CONTINUE" != "y" && "$CONTINUE" != "n" ]]; do
        read -p "Continue? [Y/N] " CONTINUE
    done

    if [[ "$CONTINUE" == "N" || "$CONTINUE" == "n" ]]; then
        echo "Aborting process"
        exit 1
    fi
}

echo 'Setting up the Proton environment to run ACT with network capture'
echo 'This script will set up your wine prefix and proton executables to run ACT, as well as set up a default ACT install for you'
echo 'If this process is aborted at any Continue prompt, it will resume from that point the next time it is run'
echo 'Please make sure nothing is running in the wine prefix for FFXIV before continuing'
echo
echo 'Checking for prerequisites'

UNZIP="$(which unzip 2>/dev/null)"

if [[ "$UNZIP" == "" ]]; then
    echo "ACT install requires the unzip tool. You can continue with the setup, but it will fail attempting to install ACT."
    prompt_continue
fi

PATCHELF="$(which patchelf 2>/dev/null)"

if [[ "$PATCHELF" == "" ]]; then
    echo "ACT install requires the patchelf tool. You can continue with the setup, but it will fail attempting to patch the wine binaries."
    prompt_continue
fi

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

# Need to remove carriage returns from this output

WINE_INSTALLED_PACKAGES="$(wine64 uninstaller --list | sed -e 's/\r//g' 2>/dev/null)"

echo 'Checking for WINE Mono'

if [[ "$(echo "$WINE_INSTALLED_PACKAGES" | grep '{EA50D369-6B67-43BC-8153-C3553B40ABEB} - 1033')" != "" ]]; then
    echo 'WINE Mono was found in the wine prefix and must be uninstalled'
    prompt_continue
    wine64 uninstaller --remove '{EA50D369-6B67-43BC-8153-C3553B40ABEB}'
fi

echo 'Checking for .NET Framework'

# Version strings for .NET Framework detection

DOTNET_VS_40_C="Microsoft .NET Framework 4 Client Profile|||Microsoft .NET Framework 4 Client Profile"
DOTNET_VS_40_E="Microsoft .NET Framework 4 Extended|||Microsoft .NET Framework 4 Extended"
DOTNET_VS_45="{92FB6C44-E685-45AD-9B20-CADF4CABA132} - 1033|||Microsoft .NET Framework 4.5"
DOTNET_VS_452="{92FB6C44-E685-45AD-9B20-CADF4CABA132} - 1033|||Microsoft .NET Framework 4.5.2"
DOTNET_VS_46="{92FB6C44-E685-45AD-9B20-CADF4CABA132} - 1033|||Microsoft .NET Framework 4.6"
DOTNET_VS_461="{92FB6C44-E685-45AD-9B20-CADF4CABA132} - 1033|||Microsoft .NET Framework 4.6.1"
DOTNET_VS_462="{92FB6C44-E685-45AD-9B20-CADF4CABA132} - 1033|||Microsoft .NET Framework 4.6.2"
DOTNET_VS_471="{92FB6C44-E685-45AD-9B20-CADF4CABA132} - 1033|||Microsoft .NET Framework 4.7.1"
DOTNET_VS_472="{92FB6C44-E685-45AD-9B20-CADF4CABA132}.KB4087364|||Update for Microsoft .NET Framework 4.7.2 (KB4087364)"

if [[ "$(echo "$WINE_INSTALLED_PACKAGES" | grep "$DOTNET_VS_472")" == "$DOTNET_VS_472" ]]; then
    echo 'Found .NET Framework 4.7.2 in wine prefix'
else
    echo 'Could not find .NET Framework 4.7.2, determining where we need to start the installation process'
    WINETRICKS_DOTNET_PACKAGES=""
    if [[ "$(echo "$WINE_INSTALLED_PACKAGES" | grep "$DOTNET_VS_471")" == "$DOTNET_VS_471" ]]; then
        echo 'Detected .NET Framework 4.7.1, only need to install 4.7.2'
        WINETRICKS_DOTNET_PACKAGES="dotnet472"
    elif [[ "$(echo "$WINE_INSTALLED_PACKAGES" | grep "$DOTNET_VS_462")" == "$DOTNET_VS_462" ]]; then
        echo 'Detected .NET Framework 4.6.2, starting install with 4.7.1'
        WINETRICKS_DOTNET_PACKAGES="dotnet471 dotnet472"
    elif [[ "$(echo "$WINE_INSTALLED_PACKAGES" | grep "$DOTNET_VS_461")" == "$DOTNET_VS_461" ]]; then
        echo 'Detected .NET Framework 4.6.1, starting install with 4.6.2'
        WINETRICKS_DOTNET_PACKAGES="dotnet462 dotnet471 dotnet472"
    elif [[ "$(echo "$WINE_INSTALLED_PACKAGES" | grep "$DOTNET_VS_46")" == "$DOTNET_VS_46" ]]; then
        echo 'Detected .NET Framework 4.6, starting install with 4.6.1'
        WINETRICKS_DOTNET_PACKAGES="dotnet461 dotnet462 dotnet471 dotnet472"
    elif [[ "$(echo "$WINE_INSTALLED_PACKAGES" | grep "$DOTNET_VS_452")" == "$DOTNET_VS_452" ]]; then
        echo 'Detected .NET Framework 4.5.2, starting install with 4.6'
        WINETRICKS_DOTNET_PACKAGES="dotnet46 dotnet461 dotnet462 dotnet471 dotnet472"
    elif [[ "$(echo "$WINE_INSTALLED_PACKAGES" | grep "$DOTNET_VS_45")" == "$DOTNET_VS_45" ]]; then
        echo 'Detected .NET Framework 4.5, starting install with 4.5.2'
        WINETRICKS_DOTNET_PACKAGES="dotnet452 dotnet46 dotnet461 dotnet462 dotnet471 dotnet472"
    elif [[ "$(echo "$WINE_INSTALLED_PACKAGES" | grep "$DOTNET_VS_40_C")" == "$DOTNET_VS_40_C" && "$(echo "$WINE_INSTALLED_PACKAGES" | grep "$DOTNET_VS_40_E")" == "$DOTNET_VS_40_E" ]]; then
        echo 'Detected .NET Framework 4.0, starting install with 4.5'
        WINETRICKS_DOTNET_PACKAGES="dotnet45 dotnet452 dotnet46 dotnet461 dotnet462 dotnet471 dotnet472"
    fi
    if [[ "$WINETRICKS_DOTNET_PACKAGES" == "" ]]; then
        echo 'No .NET Framework packages detected, starting from 4.0'
        WINETRICKS_DOTNET_PACKAGES="dotnet40 dotnet45 dotnet452 dotnet46 dotnet461 dotnet462 dotnet471 dotnet472"
    fi
    echo 'Please continue through the install prompts for each .NET Framework installer'
    echo 'If prompted to restart by the installer, please choose Yes. This will only restart the wine server and is required for the .NET Framework to install properly'
    echo 'If the process hangs part way through while trying to install dotnet462, you need to kill the mscorsvw.exe process that has "-Comment NGen Worker Process" in the arguments'
    prompt_continue
    WINEDEBUG=-all "$WINETRICKS" $WINETRICKS_DOTNET_PACKAGES
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
        if [[ "$UNZIP" == "" ]]; then
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

if [[ "$PATCHELF" == "" ]]; then
    echo "patchelf binary was not found. Please install from your distro's package manager if available"
    echo "If patchelf is not available, then please download and compile it yourself from https://github.com/NixOS/patchelf/releases"
    exit 1
fi

echo 'Checking to see if wine binaries and libraries need to be patched'

if [[ "$(patchelf --print-rpath "$(which wine)" | grep '$ORIGIN')" != "" ]]; then
    RPATH="${PROTON_DIST_PATH}/lib64:${PROTON_DIST_PATH}/lib"
    if [[ "$IS_STEAM" == "1" ]]; then
        # Steam requires ubuntu runtimes
        RPATH="$RPATH:$HOME/.local/share/Steam/ubuntu12_64:$HOME/.local/share/Steam/ubuntu12_32"
    else
        # Lutris requires extra runtimes from its install path
        RPATH="$RPATH:$(echo $LD_LIBRARY_PATH | grep 'export LD_LIBRARY_PATH' | cut -d'=' -f2- | tr ':' $'\n' | grep '/lutris/runtime/' | tr $'\n' ':')"
    fi
    echo 'Patching the rpath of wine executables and libraries'
    echo 'New rpath for binaries:'
    echo
    echo "$RPATH"
    prompt_continue
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
