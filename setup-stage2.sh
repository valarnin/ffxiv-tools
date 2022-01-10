#!/bin/bash

. helpers/error.sh
. helpers/prompt.sh
. helpers/funcs.sh

# Determine where the user wants to install the tools
. config/ffxiv-tools-location.sh

echo 'Setting up the Proton environment to run ACT with network capture'
echo 'This script will set up your wine prefix and proton executables to run ACT, as well as set up a default ACT install for you'
echo 'If this process is aborted at any Continue prompt, it will resume from that point the next time it is run'
echo 'Please make sure nothing is running in the wine prefix for FFXIV before continuing'

if [ ! -f "$HOME/$FFXIV_TOOLS_LOCATION/ffxiv-env-setup.sh" ]; then
    error "The FFXIV environment hasn't been configured yet. Please run the stage1 setup first!"
    exit 1
fi

echo 'Sourcing the FFXIV environment'
. "$HOME/$FFXIV_TOOLS_LOCATION/ffxiv-env-setup.sh"

echo
echo "Making sure that Wine isn't running anything..."

# Close all Wine ".exe" processes.
# NOTE: Since we scan for the newest PID each time, we'll properly close
# the programs in the reverse order of how they were started!
# TODO/FIXME: This is harmful if there are other Wine runtimes on the system
# that are actively used, since it will forcibly close their programs.
# This regex needs rewriting someday to only close .exe files belonging
# to the exact FFXIV Wine runner we are targeting. Or perhaps just targeting
# XIVLauncher, FFXIV's own launcher, FFXIV's main process, and ACT?
# Or another alternative may be to find a way to signal our specific wine
# runner (the FFXIV container's) to itself terminate all running programs?
while true; do
    GET_NEWEST_PID "WINE_EXE_PID" '[A-Z]:\\.*\.exe$'; PID_SUCCESS=$?
    [[ "$PID_SUCCESS" -ne 0 ]] && break
    warn "Detected Wine process ($WINE_EXE_PID). Forcing it to exit..."
    kill -9 "$WINE_EXE_PID"
    sleep 0.5
done

wine64 wineboot -fs &>/dev/null

PROTON_VERSION_FULL=""

if [[ -f "$PROTON_DIST_PATH/version" ]]; then
    PROTON_VERSION_FULL="$(cat "$PROTON_DIST_PATH/version" | cut -d' ' -f2 | cut -d'-' -f1)"
fi

if [[ "$PROTON_VERSION_FULL" == "" ]]; then
    PROTON_VERSION_FULL="$(echo "$PROTON_DIST_PATH" | grep -Po '\d\.\d+')"
fi

PROTON_VERSION_MAJOR="$(echo "$PROTON_VERSION_FULL" | cut -d'.' -f1)"
PROTON_VERSION_MINOR="$(echo "$PROTON_VERSION_FULL" | cut -d'.' -f2)"

if [[ "$PROTON_VERSION_FULL" == "" || "$PROTON_VERSION_MAJOR" == "" || "$PROTON_VERSION_MINOR" == "" ]]; then
    error "Could not detect Proton version. Please request help in the #ffxiv-linux-discussion channel of the discord."
    exit 1
fi

echo
warn 'Note that the next step is destructive, meaning that if something goes wrong it can break your wine prefix and/or your proton runner installation.'
echo 'Please make backups of both!'
echo "Wine prefix: $WINEPREFIX"
echo "Proton distribution: $PROTON_DIST_PATH"
echo "Proton version: ${PROTON_VERSION_MAJOR}.${PROTON_VERSION_MINOR}"

PROMPT_BACKUP

echo
echo "Would you like to continue installation?"
echo

PROMPT_CONTINUE

echo 'Checking for ACT install'
ACT_LOCATION="$WINEPREFIX/drive_c/ACT"

if [ -f "$WINEPREFIX/.ACT_Location" ]; then
    ACT_LOCATION="$(cat "$WINEPREFIX/.ACT_Location")"
else
    warn "Setup hasn't been run on this wine prefix before"
    echo "This script will need to scan your wine prefix to locate ACT if it's already installed."
    PROMPT_CONTINUE

    TEMP_ACT_LOCATION="$(find "$WINEPREFIX" -name 'Advanced Combat Tracker.exe')"

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
    echo "Saving this path to \"$WINEPREFIX/.ACT_Location\" for future use"
    echo "$ACT_LOCATION" > "$WINEPREFIX/.ACT_Location"
fi

echo "Making sure wine isn't running anything"
wine64 wineboot -s &>/dev/null

echo 'Checking to see if wine binaries and libraries need to be patched'

if [[ "$(patchelf --print-rpath "$(which wine)" | grep '$ORIGIN')" != "" || "$(patchelf --print-rpath "$(which wine)")" == "" ]]; then
    # IMPORTANT: We don't quote/escape the RPATH, since we only give it
    # to the patchelf executable, and it seems to only want unquoted paths.
    # If there are ever any issues with RPATH patching with paths containing
    # spaces or weird characters, then this chunk of code will need changing!

    # Add the core libraries to RPATH.
    RPATH="${PROTON_DIST_PATH}/lib64:${PROTON_DIST_PATH}/lib"

    # Lutris requires additional RPATH from its runtime install path.
    # TODO/FIXME: This method of extracting the path is risky, since it blindly
    # replaces all ":" symbols with newlines, without considering that some
    # of the ":" symbols can be escaped "\:" and legitimately be part of the
    # directory path. We need a new solution which understands escaped colons,
    # to avoid the risk of extracting corrupted/fragmented paths.
    RPATH="$RPATH:$(echo $LD_LIBRARY_PATH | tr ':' $'\n' | grep '/lutris/runtime/' | tr $'\n' ':')"

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
    warn 'Setting network capture capabilities for ACT on your wine executables'
    warn 'This process must be run as root, so you will be prompted for your password'
    warn 'The commands to be run are as follows:'
    echo
    warn 'sudo setcap cap_net_raw,cap_net_admin,cap_sys_ptrace=eip "$(which wine)"'
    warn 'sudo setcap cap_net_raw,cap_net_admin,cap_sys_ptrace=eip "$(which wine64)"'
    warn 'sudo setcap cap_net_raw,cap_net_admin,cap_sys_ptrace=eip "$(which wineserver)"'
    PROMPT_CONTINUE
    sudo setcap cap_net_raw,cap_net_admin,cap_sys_ptrace=eip "$(which wine)"
    sudo setcap cap_net_raw,cap_net_admin,cap_sys_ptrace=eip "$(which wine64)"
    sudo setcap cap_net_raw,cap_net_admin,cap_sys_ptrace=eip "$(which wineserver)"
fi
