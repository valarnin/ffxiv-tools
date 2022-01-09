#!/bin/bash

. helpers/error.sh
. helpers/prompt.sh

# Determine where the user wants to install the tools
. config/ffxiv-tools-location.sh

echo "Setting up the FFXIV Environment scripts."
echo
echo "This script will require you to open the FFXIV launcher from Lutris as if you were going to play the game normally"
echo

FFXIV_PID="$(ps axo pid,cmd | grep -P '^\s*\d+\s+[A-Z]:\\.*\\XIVLauncher.exe$' | grep -vi grep | tail -n 1 | sed -e 's/^[[:space:]]*//' | cut -d' ' -f1)"

if [[ "$FFXIV_PID" == "" ]]; then
    warn "Please open the XIVLauncher Launcher. Checking for process \"XIVLauncher.exe\"..."
    while [[ "$FFXIV_PID" == "" ]]; do
        sleep 1
        FFXIV_PID="$(ps axo pid,cmd | grep -P '^\s*\d+\s+[A-Z]:\\.*\\XIVLauncher\.exe$'| grep -vi grep | sed -e 's/^[[:space:]]*//' | cut -d' ' -f1)"
    done
fi

success "FFXIV Launcher PID found! ($FFXIV_PID)"
echo "Building environment information based on FFXIV Launcher env..."

# IMPORTANT: This array is extremely important and must be updated
# whenever Lutris or its FFXIV wine runtime introduces new environment
# variables, otherwise there will be plenty of bugs with the launched
# game (such as delayed sound, glitches), or it may not launch at all.

# To find the exact list of environment variables that Lutris itself
# is INTENTIONALLY setting when the game is launched, just open
# a terminal and run the following:
#
# "lutris -d"
#
# Then start XIVLauncher inside Lutris GUI. There will be lots of
# debugging information in the terminal. All of the required variables
# will be listed there, in the following format:
#
# "DEBUG    2022-01-09 09:00:23,918 [command.start:139]:DXVK_NVAPIHACK="0""
#
# Simply copy the variable names from each line, such as "DXVK_NVAPIHACK",
# and update the array below.
#
# But the easiest and most reliable way to produce the list of variables
# is by copying all of the "command.start" lines into a text document,
# and then running the following regex replacement on it:
#
# - Search: `^DEBUG    .+? \[command.start:139\]:(.+?)=.+?$`
# - Replace: `    "\1"`
#
# (Don't include the surrounding backticks: `.)
#
# That regex will automatically create perfectly formatted lines for you.
#
# NOTE: The environment may still contain a few other variables which
# aren't listed in Lutris debug, but those probably aren't set by Lutris
# and most likely comes from Wine and the OS itself, so technically
# we probably don't need to include anything other than what Lutris sets.
#
# ALSO NOTE: Unfortunately, we'll only capture the user's CURRENT values,
# but won't react if they later change some of the game settings in Lutris.
# However, since most people play the game with default Lutris settings,
# this risk won't affect most people.
#
declare -a FFXIV_ENVIRON_REQUIRED=(
    # Set by Lutris (Updated: 2022-Jan-09, Wine: "lutris-6.21-6-x86_64")
    "DISABLE_LAYER_AMD_SWITCHABLE_GRAPHICS_1"
    "SDL_VIDEO_FULLSCREEN_DISPLAY"
    "PULSE_LATENCY_MSEC"
    "LD_LIBRARY_PATH"
    "DSSENH"
    "XL_WINEONLINUX"
    "__GL_SHADER_DISK_CACHE"
    "__GL_SHADER_DISK_CACHE_PATH"
    "WINEDEBUG"
    "WINEARCH"
    "WINE"
    "GST_PLUGIN_SYSTEM_PATH_1_0"
    "WINEPREFIX"
    "WINEESYNC"
    "WINEFSYNC"
    "DXVK_NVAPIHACK"
    "WINEDLLOVERRIDES"
    "WINE_LARGE_ADDRESS_AWARE"
    "game_name"
    "PYTHONPATH"
    "LUTRIS_GAME_UUID"

    # Extras added by us just in case (they won't be included
    # in our output if they're missing from the environment).
    "DRI_PRIME"
    "WINEDLLPATH"
    "WINE_MONO_OVERRIDES"
    "PROTON_VR_RUNTIME"
    "WINELOADERNOEXEC"
    "WINEPRELOADRESERVE"
)

# Generate a safe, accurately-matching regex from the array above.
# NOTE: We use `|` as separator.
IFS=\| eval 'FFXIV_ENVIRON_REQ_RGX="^export (${FFXIV_ENVIRON_REQUIRED[*]})="'

# Extract the currently running Lutris environment as properly quoted, newline-separated values.
FFXIV_ENVIRON="$(cat /proc/$FFXIV_PID/environ | xargs -0 bash -c 'printf "export %q\n" "$@"' --)"

# Grab only the exact environment variables that we want.
FFXIV_ENVIRON_FINAL="$(echo "$FFXIV_ENVIRON" | grep -P "$FFXIV_ENVIRON_REQ_RGX")"

# Add FFXIV game path to environment for use in stage3 scripts
FFXIV_PATH=$(readlink -f /proc/$FFXIV_PID/cwd)
FFXIV_ENVIRON_FINAL="$FFXIV_ENVIRON_FINAL"$'\n'"export FFXIV_PATH=\"$FFXIV_PATH\""

# Add XIVLauncher path to environment for use in stage3 scripts
# Note that if we detect a specific version path, we automatically replace
# the versioned subdirectory with the generic XIVLauncher executable (which
# auto-runs/downloads the latest XIVLauncher version). We thereby avoid
# having to reinstall our scripts every time the user upgrades XIVLauncher.
# Raw Example:
# C:\users\foo\AppData\Local\XIVLauncher\app-6.1.15\XIVLauncher.exe
# Corrected Example:
# C:\users\foo\AppData\Local\XIVLauncher\XIVLauncher.exe
XIVLAUNCHER_PATH="$(cat /proc/$FFXIV_PID/cmdline | grep -aPo '.*XIVLauncher.exe' | sed 's/[/\\]app-[^/\\]*\([/\\]\)/\1/g')"
FFXIV_ENVIRON_FINAL="$FFXIV_ENVIRON_FINAL"$'\n'"export XIVLAUNCHER_PATH=\"$XIVLAUNCHER_PATH\""

PROTON_PATH="$(echo "$FFXIV_ENVIRON_FINAL" | grep 'export WINE=' | cut -d'=' -f2)"
PROTON_DIST_PATH="$(dirname "$(dirname "$PROTON_PATH")")"

WINEPREFIX="$(echo "$FFXIV_ENVIRON_FINAL" | grep 'export WINEPREFIX=' | cut -d'=' -f2)"

if [[ "$(echo "$PROTON_PATH" | grep '\\ ')" != "" ]] || [[ "$(echo "$WINEPREFIX" | grep '\\ ')" != "" ]]; then
    error "There is a space in your Proton or Wine Prefix path."
    error "There's a known issue with spaces causing issues with the setup."
    error "Please remove spaces from the path(s) and try again."
    error "Proton distribution path detected: $PROTON_DIST_PATH"
    error "Proton path detected: $PROTON_PATH"
    error "Prefix path detected: $WINEPREFIX"
    error "Full environment detected:"
    error "$FFXIV_ENVIRON_FINAL"
    exit 1
fi

# Check for wine already being setcap'd, fail if so
if [[ "$(getcap "$PROTON_PATH")" != "" ]]; then
    error "Detected that you're running this against an already configured Proton (the binary at path \"$PROTON_PATH\" has capabilities set already)"
    error "You must run this script against a fresh proton install, or else the LD_LIBRARY_PATH environment variable configured by your runtime cannot be detected"
    exit 1
fi

if [[ "$(echo "$FFXIV_ENVIRON_FINAL" | grep 'export LD_LIBRARY_PATH=')" == "" ]]; then
    warn "Unable to determine runtime LD_LIBRARY_PATH."
    warn "This may indicate something strange with your setup."
    warn "Continuing is not advised unless you know how to fix any issues that may come up related to missing libraries."
    exit 1
fi

echo
success "Detected the following information about your setup. If any of this looks incorrect, please abort and report a bug to the Github repo..."
echo "Runtime Environment: Lutris"
echo "wine Executable Location: $PROTON_PATH"
echo "Proton Distribution Path: $PROTON_DIST_PATH"
echo "Wine Prefix: $WINEPREFIX"
echo "XIVLauncher Windows Path: $XIVLAUNCHER_PATH"
echo

PROMPT_CONTINUE

echo "Creating destination directory at $HOME/$FFXIV_TOOLS_LOCATION/ if it doesn't exist"

mkdir -p "$HOME/$FFXIV_TOOLS_LOCATION"

echo "Creating source-able environment script at $HOME/$FFXIV_TOOLS_LOCATION/ffxiv-env-setup.sh"

cat << EOF > $HOME/$FFXIV_TOOLS_LOCATION/ffxiv-env-setup.sh
#!/bin/bash
$FFXIV_ENVIRON_FINAL
export WINEDEBUG=-all
export PROTON_PATH="$PROTON_PATH"
export PROTON_DIST_PATH="$PROTON_DIST_PATH"
export PATH="$PROTON_DIST_PATH/bin:\$PATH"
EOF

chmod +x $HOME/$FFXIV_TOOLS_LOCATION/ffxiv-env-setup.sh

echo "Creating environment wrapper at $HOME/$FFXIV_TOOLS_LOCATION/ffxiv-env.sh"

cat << EOF > $HOME/$FFXIV_TOOLS_LOCATION/ffxiv-env.sh
#!/bin/bash
. $HOME/$FFXIV_TOOLS_LOCATION/ffxiv-env-setup.sh
cd \$WINEPREFIX
/bin/bash
EOF

chmod +x $HOME/$FFXIV_TOOLS_LOCATION/ffxiv-env.sh
