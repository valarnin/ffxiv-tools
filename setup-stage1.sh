#!/bin/bash

. helpers/error.sh
. helpers/prompt.sh
. helpers/funcs.sh
. helpers/ensure-aur-xlcore.sh

# Determine where the user wants to install the tools
. config/ffxiv-tools-location.sh

echo "Checking installation..."
CHECK_FOR_FLATPAK

echo
echo "Detected environment: $PLATFORM"
echo

echo "Setting up the FFXIV Environment scripts."
echo
echo "This script will require you to launch the game from XIVLauncher Core."
echo

while true; do
    GET_NEWEST_PID "FFXIV_PID" '[A-Z]:\\.*\\ffxiv_dx11.exe(?: --steamticket=[^\s]+)?'; PID_SUCCESS=$?
    [[ "$PID_SUCCESS" -eq 0 ]] && break
    [[ -z "$XIVLAUNCHER_WARN" ]] && { warn "Please open the game. looking for process \"ffxiv_dx11.exe\""; XIVLAUNCHER_WARN="Y"; }
    sleep 1
done

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
    # CORE ENVIRONMENT by Lutris (Updated: 2022-Jan-09, Wine: "lutris-6.21-6-x86_64")
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

    # GAMEPAD ENVIRONMENT (used when player has configured
    # a gamepad in Lutris, not visible in env otherwise).
    "SDL_GAMECONTROLLERCONFIG"
    "SDL_GAMECONTROLLER_ALLOW_STEAM_VIRTUAL_GAMEPAD"
    "SDL_GAMECONTROLLER_IGNORE_DEVICES"

    # Extras added by us just in case (they won't be included
    # in our output if they're missing from the environment).
    "SDL_VIDEO_X11_DGAMOUSE"
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
FFXIV_PATH=$(grep 'GamePath' $HOME/.xlcore/launcher.ini | sed 's/GamePath=\(.*\)/\1/')
printf -v FFXIV_ENVIRON_FINAL '%s\nexport FFXIV_PATH=%q' "$FFXIV_ENVIRON_FINAL" "$FFXIV_PATH" 

# XLCore uses a static installation location.
XIVLAUNCHER_PATH="/opt/XIVLauncher/XIVLauncher.Core"
printf -v FFXIV_ENVIRON_FINAL '%s\nexport XIVLAUNCHER_PATH=%q' "$FFXIV_ENVIRON_FINAL" "$XIVLAUNCHER_PATH" 

MANAGED_WINE=$(grep 'WineStartupType' $HOME/.xlcore/launcher.ini | sed 's/WineStartupType=\(.*\)/\1/')
if [[ $MANAGED_WINE == *"Managed"* ]]; then
    # Find the actual wine version name inside the XLCore directory.
    XLCORE_WINE_VERSION=$(ls -1trd $HOME/.xlcore/compatibilitytool/beta | tail -n1)
    # This is hard-coded in XLCore, and is vanishingly unlikely to ever change.
    PROTON_PATH="$HOME/.xlcore/compatibilitytool/beta/$XLCORE_WINE_VERSION/bin/wine"
else
    # Customized wine doesn't actually require us to find the version, since the full path is stored in the ini file.
    XLCORE_WINE_VERSION="Customized"
    PROTON_PATH=$(grep 'WineBinaryPath' $HOME/.xlcore/launcher.ini | sed 's/WineBinaryPath=\(.*\)/\1/')
fi
PROTON_DIST_PATH="$(dirname "$(dirname "$PROTON_PATH")")"

# Extract the wineprefix value too.
# IMPORTANT: This is also fully escaped already, so we unescape it with "eval" too.
# Works perfectly based on the lutris script, so has been left unchanged. -Arkevorkhat
WINEPREFIX="$(echo "$FFXIV_ENVIRON_FINAL" | grep 'export WINEPREFIX=' | cut -d'=' -f2-)"
eval WINEPREFIX=$WINEPREFIX

# Add the final variables to the environment we'll be exporting.
printf -v FFXIV_ENVIRON_FINAL '%s\nexport PROTON_PATH=%q' "$FFXIV_ENVIRON_FINAL" "$PROTON_PATH" 
printf -v FFXIV_ENVIRON_FINAL '%s\nexport PROTON_DIST_PATH=%q' "$FFXIV_ENVIRON_FINAL" "$PROTON_DIST_PATH" 
printf -v FFXIV_ENVIRON_FINAL '%s\nexport PATH=%q:$PATH' "$FFXIV_ENVIRON_FINAL" "$PROTON_DIST_PATH/bin" 

echo
success "Detected the following information about your setup. If any of this looks incorrect, please abort and report a bug to the Github repo..."
echo "Runtime Environment: $PLATFORM XIVLauncher.Core"
echo "FFXIV Game Location: $FFXIV_PATH"
echo "wine Executable Location: $PROTON_PATH"
echo "wine Distribution Path: $PROTON_DIST_PATH"
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
cat << EOF > "$HOME/$FFXIV_TOOLS_LOCATION/ffxiv-env-setup.sh"
#!/bin/bash
$FFXIV_ENVIRON_FINAL
export WINEDEBUG=-all
EOF

chmod +x "$HOME/$FFXIV_TOOLS_LOCATION/ffxiv-env-setup.sh"

echo "Creating environment wrapper at $HOME/$FFXIV_TOOLS_LOCATION/ffxiv-env.sh"

cat << EOF > "$HOME/$FFXIV_TOOLS_LOCATION/ffxiv-env.sh"
#!/bin/bash
. "$HOME/$FFXIV_TOOLS_LOCATION/ffxiv-env-setup.sh"
cd "\$WINEPREFIX"
/bin/bash
EOF

chmod +x "$HOME/$FFXIV_TOOLS_LOCATION/ffxiv-env.sh"
