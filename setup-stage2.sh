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

echo
warn 'Note that the next step is destructive, meaning that if something goes wrong it can break your wine prefix and/or your proton runner installation.'
echo 'Please make backups of both!'
echo "Wine prefix: $WINEPREFIX"
echo "Proton distribution: $PROTON_DIST_PATH"

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
