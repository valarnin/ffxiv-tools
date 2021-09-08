#!/bin/bash

. helpers/error.sh
. helpers/prompt.sh

echo 'Setting up the Proton environment to run ACT with network capture'
echo 'This script will set up your wine prefix and proton executables to run ACT, as well as set up a default ACT install for you'
echo 'If this process is aborted at any Continue prompt, it will resume from that point the next time it is run'
echo 'Please make sure nothing is running in the wine prefix for FFXIV before continuing'

if [ ! -f "$HOME/bin/ffxiv-env-setup.sh" ]; then
    error "The FFXIV environment hasn't been configured yet. Please run the stage1 setup first!"
    exit 1
fi

echo 'Sourcing the FFXIV environment'
. $HOME/bin/ffxiv-env-setup.sh

echo
echo "Making sure wine isn't running anything"

FFXIV_PID="$(ps axo pid,cmd | grep -Pi 'ffxivlauncher(|64).exe' | grep -vi grep | sed -e 's/^[[:space:]]*//' | cut -d' ' -f1)"

if [[ "$FFXIV_PID" != "" ]]; then
    warn "FFXIV launcher detected as running, forceably closing it"
    kill -9 "$FFXIV_PID"
fi

wine64 wineboot -fs &>/dev/null

PROTON_VERSION_FULL="$(cat "$PROTON_DIST_PATH/version" | cut -d' ' -f2 | cut -d'-' -f1)"
PROTON_VERSION_MAJOR="$(echo "$PROTON_VERSION_FULL" | cut -d'.' -f1)"
PROTON_VERSION_MINOR="$(echo "$PROTON_VERSION_FULL" | cut -d'.' -f2)"
PROTON_CUSTOM_LATEST_TAG=$(curl -sL https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest | jq -r ".tag_name")
PROTON_VERSION_CUSTOM_LATEST="$(cat "$HOME/.steam/steam/compatibilitytools.d/Proton-$PROTON_CUSTOM_LATEST_TAG/version" | cut -d' ' -f2 | cut -d'-' -f1)"

if [[ "$PROTON_VERSION_CUSTOM_LATEST" == "" ]]; then
    if [[ "$PROTON_VERSION_FULL" == "" || "$PROTON_VERSION_MAJOR" == "" || "$PROTON_VERSION_MINOR" == "" ]]; then
        error "Could not detect Proton version. Please request help in the #ffxiv-linux-discussion channel of the discord."
        exit 1
    fi
fi

warn 'Note that this process is destructive, meaning that if something goes wrong it can break your wine prefix and/or your proton runner installation'
echo 'Please make backups of both!'
echo "wine prefix: $WINEPREFIX"
echo "Proton distribution: $PROTON_DIST_PATH"
echo "Proton version: ${PROTON_VERSION_MAJOR}.${PROTON_VERSION_MINOR}"

PROMPT_BACKUP

echo
echo "Would you like to continue installation?"
echo

PROMPT_CONTINUE

echo 'Getting a list of installed packages in wine prefix'

# Need to remove carriage returns from this output

WINE_INSTALLED_PACKAGES="$(wine64 uninstaller --list | sed -e 's/\r//g' 2>/dev/null)"

echo 'Checking for WINE Mono'

WINE_MONO_GUID="$(echo "$WINE_INSTALLED_PACKAGES" | grep -i 'Wine Mono' | cut -d'|' -f1)"

if [[ "$WINE_MONO_GUID" != "" ]]; then
    warn 'WINE Mono was found in the wine prefix and must be uninstalled'
    PROMPT_CONTINUE
    wine64 uninstaller --remove "$WINE_MONO_GUID"
fi

echo 'Checking for .NET Framework'

# Version strings for .NET Framework detection

DOTNET_VS_40_C='Microsoft .NET Framework 4 Client Profile|||Microsoft .NET Framework 4 Client Profile'
DOTNET_VS_40_E='Microsoft .NET Framework 4 Extended|||Microsoft .NET Framework 4 Extended'
DOTNET_VS_452='{92FB6C44-E685-45AD-9B20-CADF4CABA132} - 1033|||Microsoft .NET Framework 4.5.2'
DOTNET_VS_46='{92FB6C44-E685-45AD-9B20-CADF4CABA132} - 1033|||Microsoft .NET Framework 4.6'
DOTNET_VS_461='{92FB6C44-E685-45AD-9B20-CADF4CABA132} - 1033|||Microsoft .NET Framework 4.6.1'
DOTNET_VS_462='{92FB6C44-E685-45AD-9B20-CADF4CABA132} - 1033|||Microsoft .NET Framework 4.6.2'
DOTNET_VS_471='{92FB6C44-E685-45AD-9B20-CADF4CABA132} - 1033|||Microsoft .NET Framework 4.7.1'
DOTNET_VS_472='{92FB6C44-E685-45AD-9B20-CADF4CABA132}.KB4087364|||Update for Microsoft .NET Framework 4.7.2 (KB4087364)'

if [[ "$(echo "$WINE_INSTALLED_PACKAGES" | grep "$DOTNET_VS_472")" == "$DOTNET_VS_472" ]]; then
    success 'Found .NET Framework 4.7.2 in wine prefix'
else
    warn 'Could not find .NET Framework 4.7.2, determining where we need to start the installation process'
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
    elif [[ "$(echo "$WINE_INSTALLED_PACKAGES" | grep "$DOTNET_VS_40_C")" == "$DOTNET_VS_40_C" && "$(echo "$WINE_INSTALLED_PACKAGES" | grep "$DOTNET_VS_40_E")" == "$DOTNET_VS_40_E" ]]; then
        echo 'Detected .NET Framework 4.0, starting install with 4.5.2'
        WINETRICKS_DOTNET_PACKAGES="dotnet452 dotnet46 dotnet461 dotnet462 dotnet471 dotnet472"
    fi
    if [[ "$WINETRICKS_DOTNET_PACKAGES" == "" ]]; then
        echo 'No .NET Framework packages detected, starting from 4.0'
        WINETRICKS_DOTNET_PACKAGES="dotnet40 dotnet452 dotnet46 dotnet461 dotnet462 dotnet471 dotnet472"
    fi
    echo 'Please continue through the install prompts for each .NET Framework installer'
    echo 'If prompted to restart by the installer, please choose Yes. This will only restart the wine server and is required for the .NET Framework to install properly'
    echo 'If the process hangs part way through while trying to install dotnet462, you need to kill the mscorsvw.exe process that has "-Comment NGen Worker Process" in the arguments'
    PROMPT_CONTINUE
    WINEDEBUG=-all winetricks $WINETRICKS_DOTNET_PACKAGES
fi

echo 'Checking for ACT install'
ACT_LOCATION="$WINEPREFIX/drive_c/ACT"

if [ -f "$WINEPREFIX/.ACT_Location" ]; then
    ACT_LOCATION="$(cat "$WINEPREFIX/.ACT_Location")"
else
    warn "Setup hasn't been run on this wine prefix before"
    echo "Searching for the ACT install may take some time if this prefix has been highly customized."
    PROMPT_CONTINUE

    TEMP_ACT_LOCATION="$(find $WINEPREFIX -name 'Advanced Combat Tracker.exe')"

    if [[ "$TEMP_ACT_LOCATION" == "" ]]; then
        warn 'Could not find ACT install, downloading and installing latest version'
        PROMPT_CONTINUE
        wget -O "/tmp/ACT.zip" "https://advancedcombattracker.com/includes/page-download.php?id=57" &>/dev/null
        mkdir -p "$ACT_LOCATION" &> /dev/null
        unzip -qq "/tmp/ACT.zip" -d "$ACT_LOCATION"
    else
        ACT_LOCATION="$(dirname "$TEMP_ACT_LOCATION")"
    fi
    success "Found ACT location at $ACT_LOCATION"
    echo "Saving this path to $WINEPREFIX/.ACT_Location for future use"
    echo "$ACT_LOCATION" > "$WINEPREFIX/.ACT_Location"
fi

echo "Making sure wine isn't running anything"
wine64 wineboot -s &>/dev/null

echo 'Checking to see if wine binaries and libraries need to be patched'

if [[ "$(patchelf --print-rpath "$(which wine)" | grep '$ORIGIN')" != "" ]]; then
    RPATH="${PROTON_DIST_PATH}/lib64:${PROTON_DIST_PATH}/lib"
    if [[ "$IS_STEAM" == "1" ]]; then
        # Steam requires ubuntu runtimes
        STEAM_ROOT_PATH="$(readlink -f $HOME/.steam/root)"
        RPATH="$RPATH:$STEAM_ROOT_PATH/ubuntu12_64:$STEAM_ROOT_PATH/ubuntu12_32:$STEAM_ROOT_PATH/ubuntu12_32/steam-runtime/lib/i386-linux-gnu:$STEAM_ROOT_PATH/ubuntu12_32/steam-runtime/lib/x86_64-linux-gnu"
    else
        # Lutris requires extra runtimes from its install path
        RPATH="$RPATH:$(echo $LD_LIBRARY_PATH | tr ':' $'\n' | grep '/lutris/runtime/' | tr $'\n' ':')"
    fi
    echo 'Patching the rpath of wine executables and libraries'
    echo 'New rpath for binaries:'
    echo
    echo "$RPATH"
    PROMPT_CONTINUE
    patchelf --set-rpath "$RPATH" "$(which wine)"
    patchelf --set-rpath "$RPATH" "$(which wine64)"
    patchelf --set-rpath "$RPATH" "$(which wineserver)"
    PATCH_LIB_RPATH="Yes"
    if [[ "$PROTON_VERSION_MAJOR" -ge "5" ]]; then
        warn 'Detected a Proton version greater than 4.X'
        echo 'There was a change in wine/proton somewhere after 4.21 which caused the libraries to not need their rpath patched'
        echo 'The lowest known version after 4.21 which does not require the rpath to be patched is 5.2'
        if [[ "$PROTON_VERSION_MAJOR" -gt "5" || "$PROTON_VERSION_MINOR" -ge "2" ]]; then
            success 'Detected proton version 5.2 or later, skipping patching the rpath'
            PATCH_LIB_RPATH="No"
        else
            PATCH_LIB_RPATH=""
            warn 'Please let us know what your proton version is and if patching the rpath was required, so that we can narrow the window for where this change was made.'
            while [[ "$PATCH_LIB_RPATH" != "Yes" && "$PATCH_LIB_RPATH" != "No" ]]; do
                read -p "Do you want to patch the rpath? [Yes/No] " PATCH_LIB_RPATH
            done
        fi
    fi
    if [[ "$PATCH_LIB_RPATH" == "Yes" ]]; then
        find "${PROTON_DIST_PATH}/lib64" -type f | xargs -I{} patchelf --set-rpath "$RPATH" {} &> /dev/null
        find "${PROTON_DIST_PATH}/lib" -type f | xargs -I{} patchelf --set-rpath "$RPATH" {} &> /dev/null
    fi
fi

echo 'Checking to see if wine binaries need their capabilities set'

if [[ "$(getcap "$(which wine)")" == "" ]]; then
    warn << EOF
Setting capabilities on wine executables
This process must be run as root, so you will be prompted for your password
The commands to be run are as follows:

sudo setcap cap_net_raw,cap_net_admin,cap_sys_ptrace=eip "$(which wine)"
sudo setcap cap_net_raw,cap_net_admin,cap_sys_ptrace=eip "$(which wine64)"
sudo setcap cap_net_raw,cap_net_admin,cap_sys_ptrace=eip "$(which wineserver)"
EOF
    PROMPT_CONTINUE
    sudo setcap cap_net_raw,cap_net_admin,cap_sys_ptrace=eip "$(which wine)"
    sudo setcap cap_net_raw,cap_net_admin,cap_sys_ptrace=eip "$(which wine64)"
    sudo setcap cap_net_raw,cap_net_admin,cap_sys_ptrace=eip "$(which wineserver)"
fi
