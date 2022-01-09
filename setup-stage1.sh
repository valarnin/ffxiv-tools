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
FFXIV_PATH="$(readlink -f /proc/$FFXIV_PID/cwd)"
FFXIV_ENVIRON_FINAL="$(printf '%s\nexport FFXIV_PATH=%q\n' "$FFXIV_ENVIRON_FINAL" "$FFXIV_PATH")"

# Add XIVLauncher path to environment for use in stage3 scripts
# Note that if we detect a specific version path, we automatically replace
# the versioned subdirectory with the generic XIVLauncher executable (which
# auto-runs/downloads the latest XIVLauncher version). We thereby avoid
# having to reinstall our scripts every time the user upgrades XIVLauncher.
# Raw Example:
# C:\users\foo\AppData\Local\XIVLauncher\app-6.1.15\XIVLauncher.exe
# Corrected Example:
# C:\users\foo\AppData\Local\XIVLauncher\XIVLauncher.exe
XIVLAUNCHER_PATH="$(grep -zPo '.*XIVLauncher.exe' /proc/$FFXIV_PID/cmdline | head -z -n 1 | sed -z 's/[/\\]app-[^/\\]*\([/\\]\)/\1/g' | tr -d '\0')"
FFXIV_ENVIRON_FINAL="$(printf '%s\nexport XIVLAUNCHER_PATH=%q\n' "$FFXIV_ENVIRON_FINAL" "$XIVLAUNCHER_PATH")"

# Generate Proton environment variables based on the Wine runner's location.
# IMPORTANT: The PROTON_PATH is already fully escaped (by printf during extraction),
# so DON'T wrap it in quotes if using in scripts or function calls. However,
# the PROTON_DIST_PATH is generated here and WILL NEED quoting.
# VERY IMPORTANT: These issues regarding already-quoted variables only applies
# to setup-stage1.sh. The other setup scripts read the finished environment file
# into memory which automatically unescapes everything, so other files actually
# have to do the opposite (must always quote/escape properly), for ALL variables.
PROTON_PATH="$(echo "$FFXIV_ENVIRON_FINAL" | grep 'export WINE=' | cut -d'=' -f2)"
PROTON_DIST_PATH="$(dirname "$(dirname $PROTON_PATH)")"

# Extract the wineprefix value too.
# IMPORTANT: This is also fully escaped already. Same caveats apply as above.
WINEPREFIX="$(echo "$FFXIV_ENVIRON_FINAL" | grep 'export WINEPREFIX=' | cut -d'=' -f2)"

# Add the final variables to the environment we'll be exporting.
# IMPORTANT: We DON'T escape the already-escaped Proton variables! We MUST use %s instead of %q for those!
FFXIV_ENVIRON_FINAL="$(printf '%s\nexport PROTON_PATH=%s\n' "$FFXIV_ENVIRON_FINAL" "$PROTON_PATH")"
FFXIV_ENVIRON_FINAL="$(printf '%s\nexport PROTON_DIST_PATH=%q\n' "$FFXIV_ENVIRON_FINAL" "$PROTON_DIST_PATH")"
FFXIV_ENVIRON_FINAL="$(printf '%s\nexport PATH=%q:\$PATH\n' "$FFXIV_ENVIRON_FINAL" "$PROTON_DIST_PATH/bin")"

# Check for wine already being setcap'd, and fail if so.
if [[ "$(getcap $PROTON_PATH)" != "" ]]; then
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

# NOTE: We forcibly disable all wine debug output in our environment,
# to ensure that it's running without logging slowdowns. However, we'll
# get two WINEDEBUG lines in the output environment. This last one takes
# precedence, and the user can manually edit their script if they prefer
# whatever value was retrieved from their Lutris environment instead.
cat << EOF > $HOME/$FFXIV_TOOLS_LOCATION/ffxiv-env-setup.sh
#!/bin/bash
$FFXIV_ENVIRON_FINAL
export WINEDEBUG=-all
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
