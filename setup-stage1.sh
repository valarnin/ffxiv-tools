#!/bin/bash

echo "Setting up the FFXIV Environment scripts."
echo
echo "This script will require you to open the FFXIV launcher from Lutris or Steam as if you were going to play the game normally"
echo

FFXIV_PID="$(ps axo pid,cmd | grep -i ffxivlauncher.exe | grep -vi grep | sed -e 's/^[[:space:]]*//' | cut -d' ' -f1)"

if [[ "$FFXIV_PID" == "" ]]; then
    echo "Please open the FFXIV Launcher. Checking for process \"ffxivlauncher.exe\"..."
    while [[ "$FFXIV_PID" == "" ]]; do
        sleep 1
        FFXIV_PID="$(ps axo pid,cmd | grep -i ffxivlauncher.exe | grep -vi grep | sed -e 's/^[[:space:]]*//' | cut -d' ' -f1)"
    done
fi

echo "FFXIV Launcher PID found! ($FFXIV_PID)"
echo "Building environment information based on FFXIV Launcher env..."

FFXIV_ENVIRON="$(cat /proc/$FFXIV_PID/environ | xargs -0 bash -c 'printf "export %q\n" "$@"')"

IS_STEAM=0
REQ_ENV_VARS_REGEX="(DRI_PRIME|LD_LIBRARY_PATH|PYTHONPATH|SDL_VIDEO_FULLSCREEN_DISPLAY|STEAM_RUNTIME|WINEDEBUG|WINEDLLPATH|WINEPREFIX|WINE_MONO_OVERRIDES|WINEESYNC|PROTON_VR_RUNTIME|WINEDLLOVERRIDES|WINELOADERNOEXEC|WINEPRELOADRESERVE|DXVK|export WINE=)"

if [[ "$(echo "$FFXIV_ENVIRON" | grep SteamGameId)" != "" ]]; then
    echo "Looks like you're using Steam, configuring for Steam runtime"
    IS_STEAM=1
    REQ_ENV_VARS_REGEX="(LD_LIBRARY_PATH|SteamUser|ENABLE_VK_LAYER_VALVE_steam_overlay_1|SteamGameId|STEAM_RUNTIME_LIBRARY_PATH|STEAM_CLIENT_CONFIG_FILE|SteamAppId|SDL_GAMECONTROLLERCONFIG|SteamStreamingHardwareEncodingNVIDIA|SDL_GAMECONTROLLER_ALLOW_STEAM_VIRTUAL_GAMEPAD|STEAM_ZENITY|STEAM_RUNTIME|SteamClientLaunch|SteamStreamingHardwareEncodingIntel|STEAM_COMPAT_CLIENT_INSTALL_PATH|STEAM_COMPAT_DATA_PATH|EnableConfiguratorSupport|SteamAppUser|SDL_VIDEO_X11_DGAMOUSE|SteamStreamingHardwareEncodingAMD|SDL_GAMECONTROLLER_IGNORE_DEVICES|STEAMSCRIPT_VERSION|DXVK_LOG_LEVEL|WINEDEBUG|WINEDLLPATH|WINEPREFIX|WINE_MONO_OVERRIDES|WINEESYNC|PROTON_VR_RUNTIME|WINEDLLOVERRIDES|WINELOADERNOEXEC|WINEPRELOADRESERVE|export WINE=|export PATH=)"
fi

FFXIV_ENVIRON_FINAL="$(echo "$FFXIV_ENVIRON" | grep -P "$REQ_ENV_VARS_REGEX")"

if [ $IS_STEAM ]; then
    # Add WINE= env var for Steam setup
    FFXIV_ENVIRON_FINAL="$FFXIV_ENVIRON_FINAL"$'\n'"export WINE=$(echo "$FFXIV_ENVIRON_FINAL" | grep 'export PATH' | cut -d'=' -f2 | tr ':' $'\n' | grep -i '/dist/')wine"

    # Remove PATH= from Environment now that we have the Proton path
    FFXIV_ENVIRON_FINAL="$(echo "$FFXIV_ENVIRON_FINAL" | grep -v 'export PATH=')"
fi

PROTON_PATH="$(echo "$FFXIV_ENVIRON_FINAL" | grep 'export WINE=' | cut -d'=' -f2)"
PROTON_DIST_PATH="$(dirname "$(dirname "$PROTON_PATH")")"

WINEPREFIX="$(echo "$FFXIV_ENVIRON_FINAL" | grep 'export WINEPREFIX=' | cut -d'=' -f2)"

echo
echo "Detected the following information about your setup. If any of this looks incorrect, please abort and report a bug to the Github repo..."
echo "Runtime Environment: $([ $IS_STEAM ] && echo "Steam" || echo "Proton")"
echo "wine Executable Location: $PROTON_PATH"
echo "Proton Distribution Path: $PROTON_DIST_PATH"
echo "Wine Prefix: $WINEPREFIX"
echo

CONTINUE=""

while [[ "$CONTINUE" != "Y" && "$CONTINUE" != "N" ]]; do
    read -p "Continue? [Y/N] " CONTINUE
done

if [[ "$CONTINUE" == "N" ]]; then
    echo "Aborting process"
    exit 1
fi

echo "Creating source-able environment script at $HOME/bin/ffxiv-env-setup.sh"

cat << EOF > $HOME/bin/ffxiv-env-setup.sh
#!/bin/bash
$FFXIV_ENVIRON_FINAL
PROTON_PATH="$PROTON_PATH"
PROTON_DIST_PATH="$PROTON_DIST_PATH"
WINEPREFIX="$WINEPREFIX"
IS_STEAM="$IS_STEAM"
PATH="$PROTON_DIST_PATH/bin:\$PATH"
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