#!/bin/bash

. helpers/error.sh
. helpers/prompt.sh

echo "Setting up the FFXIV Environment scripts."
echo
echo "This script will require you to open the FFXIV launcher from Lutris or Steam as if you were going to play the game normally"
echo

FFXIV_PID="$(ps axo pid,cmd | grep -Pi 'ffxivlauncher(|64).exe' | grep -vi grep | sed -e 's/^[[:space:]]*//' | cut -d' ' -f1)"

if [[ "$FFXIV_PID" == "" ]]; then
    warn "Please open the FFXIV Launcher. Checking for process \"ffxivlauncher.exe\" or \"ffxivlauncher64.exe\"..."
    while [[ "$FFXIV_PID" == "" ]]; do
        sleep 1
        FFXIV_PID="$(ps axo pid,cmd | grep -Pi 'ffxivlauncher(|64).exe' | grep -vi grep | sed -e 's/^[[:space:]]*//' | cut -d' ' -f1)"
    done
fi

success "FFXIV Launcher PID found! ($FFXIV_PID)"
echo "Building environment information based on FFXIV Launcher env..."

FFXIV_ENVIRON="$(cat /proc/$FFXIV_PID/environ | xargs -0 bash -c 'printf "export %q\n" "$@"')"

IS_STEAM=0
REQ_ENV_VARS_REGEX="(DRI_PRIME|LD_LIBRARY_PATH|PYTHONPATH|SDL_VIDEO_FULLSCREEN_DISPLAY|STEAM_RUNTIME|WINEDLLPATH|WINEPREFIX|WINE_MONO_OVERRIDES|WINEESYNC|PROTON_VR_RUNTIME|WINEDLLOVERRIDES|WINELOADERNOEXEC|WINEPRELOADRESERVE|DXVK|export WINE=)"

if [[ "$(echo "$FFXIV_ENVIRON" | grep SteamGameId)" != "" ]]; then
    warn "Looks like you're using Steam, configuring for Steam runtime"
    IS_STEAM=1
    REQ_ENV_VARS_REGEX="(LD_LIBRARY_PATH|SteamUser|ENABLE_VK_LAYER_VALVE_steam_overlay_1|SteamGameId|STEAM_RUNTIME_LIBRARY_PATH|STEAM_CLIENT_CONFIG_FILE|SteamAppId|SDL_GAMECONTROLLERCONFIG|SteamStreamingHardwareEncodingNVIDIA|SDL_GAMECONTROLLER_ALLOW_STEAM_VIRTUAL_GAMEPAD|STEAM_ZENITY|STEAM_RUNTIME|SteamClientLaunch|SteamStreamingHardwareEncodingIntel|STEAM_COMPAT_CLIENT_INSTALL_PATH|STEAM_COMPAT_DATA_PATH|EnableConfiguratorSupport|SteamAppUser|SDL_VIDEO_X11_DGAMOUSE|SteamStreamingHardwareEncodingAMD|SDL_GAMECONTROLLER_IGNORE_DEVICES|STEAMSCRIPT_VERSION|DXVK_LOG_LEVEL|WINEDLLPATH|WINEPREFIX|WINE_MONO_OVERRIDES|WINEESYNC|PROTON_VR_RUNTIME|WINEDLLOVERRIDES|WINELOADERNOEXEC|WINEPRELOADRESERVE|export WINE=|export PATH=)"
fi

FFXIV_ENVIRON_FINAL="$(echo "$FFXIV_ENVIRON" | grep -P "$REQ_ENV_VARS_REGEX")"

if [[ "$IS_STEAM" == "1" ]]; then
    # Add WINE= env var for Steam setup
    FFXIV_ENVIRON_FINAL="$FFXIV_ENVIRON_FINAL"$'\n'"export WINE=$(echo "$FFXIV_ENVIRON_FINAL" | grep 'export PATH' | cut -d'=' -f2 | tr ':' $'\n' | grep -i '/dist/')wine"

    # Remove PATH= from Environment now that we have the Proton path
    FFXIV_ENVIRON_FINAL="$(echo "$FFXIV_ENVIRON_FINAL" | grep -v 'export PATH=')"
fi

# Add FFXIV game path to environment for use in stage3 scripts
FFXIV_PATH=$(readlink -f /proc/$FFXIV_PID/cwd)
FFXIV_ENVIRON_FINAL="$FFXIV_ENVIRON_FINAL"$'\n'"export FFXIV_PATH=\"$FFXIV_PATH\""

PROTON_PATH="$(echo "$FFXIV_ENVIRON_FINAL" | grep 'export WINE=' | cut -d'=' -f2)"
PROTON_DIST_PATH="$(dirname "$(dirname "$PROTON_PATH")")"

WINEPREFIX="$(echo "$FFXIV_ENVIRON_FINAL" | grep 'export WINEPREFIX=' | cut -d'=' -f2)"

if [[ "$(echo "$PROTON_PATH" | grep '\\ ')" != "" ]] || [[ "$(echo "$WINEPREFIX" | grep '\\ ')" != "" ]]; then
    error "There is a space in your Proton or Wine Prefix path."
    error "There's a known issue with spaces causing issues with the setup."
    error "Please remove spaces from the path(s) and try again."
    exit 1
fi

# Check for wine already being setcap'd, fail if so
if [[ "$(getcap "$PROTON_PATH")" != "" ]]; then
    error "Detected that you're running this against an already configured Proton (the binary at path \"$PROTON_PATH\" has capabilities set already)"
    error "You must run this script against a fresh proton install, or else the LD_LIBRARY_PATH environment variable configured by your runtime cannot be detected"
    exit 1
fi

if [[ "$(echo "$FFXIV_ENVIRON_FINAL" | grep 'export LD_LIBRARY_PATH=')" == "" ]]; then
    error "Unable to determine runtime LD_LIBRARY_PATH."
    error "This may indicate something strange with your setup."
    error "Please submit a new issue to the github repo or contact me via Discord."
    exit 1
fi

echo
success "Detected the following information about your setup. If any of this looks incorrect, please abort and report a bug to the Github repo..."
if [[ "$IS_STEAM" == "1" ]]; then
    echo "Runtime Environment: Steam"
else
    echo "Runtime Environment: Lutris"
fi
echo "wine Executable Location: $PROTON_PATH"
echo "Proton Distribution Path: $PROTON_DIST_PATH"
echo "Wine Prefix: $WINEPREFIX"
echo

PROMPT_CONTINUE

echo "Creating destination directory at $HOME/bin if it doesn't exist"

mkdir -p "$HOME/bin"

echo "Creating source-able environment script at $HOME/bin/ffxiv-env-setup.sh"

cat << EOF > $HOME/bin/ffxiv-env-setup.sh
#!/bin/bash
$FFXIV_ENVIRON_FINAL
export WINEDEBUG=-all
export PROTON_PATH="$PROTON_PATH"
export PROTON_DIST_PATH="$PROTON_DIST_PATH"
export WINEPREFIX="$WINEPREFIX"
export IS_STEAM="$IS_STEAM"
export PATH="$PROTON_DIST_PATH/bin:\$PATH"
EOF

chmod +x $HOME/bin/ffxiv-env-setup.sh

echo "Creating environment wrapper at $HOME/bin/ffxiv-env.sh"

cat << EOF > $HOME/bin/ffxiv-env.sh
#!/bin/bash
. $HOME/bin/ffxiv-env-setup.sh
cd \$WINEPREFIX
/bin/bash
EOF

chmod +x $HOME/bin/ffxiv-env.sh