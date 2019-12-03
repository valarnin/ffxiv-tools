Guide to get FFXIV and ACT working in wine/proton on Linux. Last updated 2019-09-18.

# Table of Contents

   * [Preamble](#preamble)
   * [Support](#support)
   * [Getting FFXIV itself working](#getting-ffxiv-itself-working)
      * [Steam](#steam)
      * [Standalone](#standalone)
   * [Setting up the FFXIV Environment](#setting-up-the-ffxiv-environment)
      * [For Steam](#for-steam)
      * [For Lutris](#for-lutris)
   * [Getting ACT itself working](#getting-act-itself-working)
      * [Preparation](#preparation)
   * [Getting the FFXIV ACT plugin working](#getting-the-ffxiv-act-plugin-working)
      * [Preparing ld.so.conf.d library loading](#preparing-ldsoconfd-library-loading)
      * [Setting capabilities on executables](#setting-capabilities-on-executables)
   * [The moment of truth](#the-moment-of-truth)
      * [Troubleshooting](#troubleshooting)
   * [Extras](#extras)
      * [Text To Speach](#text-to-speach)
      * [Transparency and wine/proton](#transparency-and-wineproton)
      * [OverlayPlugin/cactbot](#overlayplugincactbot)
      * [FFLogs Uploader](#fflogs-uploader)
      * [Upgrading Proton](#upgrading-proton)
      * [I use Steam and my ACT suddenly stopped working](#i-use-steam-and-my-act-suddenly-stopped-working)

# Preamble

Note that all instructions below are written for `Proton 4.11.2` or higher. Versions prior to this have various issues.

`Proton 4.11.2` still has two remaining bugs:

1. When logging in to the launcher, you must press `Enter` on your keyboard after entering your password(s), not click the actual login button. Clicking the Play button afterwards works without issue.
2. You must disable the new character opening cutscene. You can watch this cutscene from the menu without issues, but for some reason when it autoplays it crashes.

Additionally, please note that as of patch 5.08 released on 2019-08-29, you must use the Steam client if you bought the game through Steam, and you must use the standalone client if you bought the game through the Mog Station.

A final note that if your windowing manager does not render windows on other workspaces actively (i3 is our test case here) you will have issues with ACT working properly. See the Troubleshooting section for more information.

Tested as working on the following setups:

1. `gentoo amd64/17.0, kernel 5.2.2, Gnome 3`
2. `gentoo amd64/17.1, kernel 5.2.2, Gnome 3`
3. `arch linux, more info needed`
4. `Linux Mint 19.2 Cinnamon, kernel 4.15.0-62-generic, Cinnamon`
5. `Manjaro Linux, kernel 5.2.14-arch1-1-fsync, Gnome 3`

# Support

Note that EQAditu, creator of ACT itself, and Ravahn, creator of the FFXIV ACT Plugin, cannot help diagnose linux-specific issues. For support, please use the #ffxiv-linux-discussion text channel on the ACT FFXIV discord, which can be found [here](https://github.com/ravahn/FFXIV_ACT_Plugin).

We can upstream fixes for linux issues if needed, but the only case of a code change being required to support linux was for the socket listener, done via these pull requests:

https://github.com/ravahn/machina/pull/8 (initial)

https://github.com/ravahn/machina/pull/9 (fix false positives in linux detection)

# Getting FFXIV itself working

## Steam

1. In Steam, under `Settings` > `Steam Play`, make sure that the `Enable Steam Play for all titles` option is enabled.
2. Install FFXIV in Steam.
3. In `Library` > `Tools`, install `Proton 4.11`.
4. Right click FFXIV in your Steam library, and in `Properties` > `General`, at the bottom, check the `Force the use of a specific Steam Play compatability tool`. In the dropdown select the option starting with `Proton 4.11`.
5. Launch FFXIV. Log in with your account and allow the game to patch. Do not launch yet. Close the patcher.
6. Navigate to your FFXIV prefix directory. By default this should be at `~/.local/share/Steam/steamapps/compatdata/39210/pfx`
7. In `drive_c/users/steamuser/My Documents/My Games/FINAL FANTASY XIV - A Realm Reborn`, edit `FFXIV.cfg`. Find `CutsceneMovieOpening` and change the `0` to `1`
8. Open FFXIV, you should be able to log in/create character/etc. If you want to watch the opening cutscene, there's an option in the main menu for it.

## Standalone

1. Use the `lutris` installer at `https://lutris.net/games/final-fantasy-xiv-a-realm-reborn/`
2. Install the `Standalone - DXVK version`. This will handle installing the game client and setting up the config file changes required
3. Log in, make sure everything works. If not, you may try changing the `Wine version` to a 4.11.2 or higher proton version
4. If all else fails, you can set up a new 64-bit wine prefix directly in lutris configured to use proton 4.11.2 and install FFXIV in it with the installer download at <http://gdl.square-enix.com/ffxiv/inst/ffxivsetup.exe>.

# Setting up the FFXIV Environment

Through the rest of this guide I will refer to the "FFXIV Environment". This is a terminal with environment variables configured to run commands in the same context and prefix with the same wine/proton runner that your FFXIV runs under. To get this environment running, I have created shell scripts for Steam and for Lutris which you call with the FFXIV process ID, and they will output a shell script which can be used to replicate the FFXIV environment. **Any command that involves the `wine` or `wine64` binaries from here out should be run in the FFXIV environment. If you run a command in the wrong environment, you may mess up your system wine!**

Usage: `./prep_env.sh <FFXIV Launcher PID> > ~/bin/ffxiv_env.sh`

## For Steam

```bash
#!/bin/bash

FFXIVPID=$1

echo '#!/bin/bash'
echo

# Get running process's environment variables, pull out only the ones we need, and format them as export lines
cat /proc/$FFXIVPID/environ | xargs -0 bash -c 'printf "export %q\n" "$@"' | grep -P '(LD_LIBRARY_PATH|SteamUser|ENABLE_VK_LAYER_VALVE_steam_overlay_1|SteamGameId|STEAM_RUNTIME_LIBRARY_PATH|STEAM_CLIENT_CONFIG_FILE|SteamAppId|SDL_GAMECONTROLLERCONFIG|SteamStreamingHardwareEncodingNVIDIA|SDL_GAMECONTROLLER_ALLOW_STEAM_VIRTUAL_GAMEPAD|STEAM_ZENITY|STEAM_RUNTIME|SteamClientLaunch|SteamStreamingHardwareEncodingIntel|STEAM_COMPAT_CLIENT_INSTALL_PATH|STEAM_COMPAT_DATA_PATH|EnableConfiguratorSupport|SteamAppUser|SDL_VIDEO_X11_DGAMOUSE|SteamStreamingHardwareEncodingAMD|SDL_GAMECONTROLLER_IGNORE_DEVICES|STEAMSCRIPT_VERSION|DXVK_LOG_LEVEL|WINEDEBUG|WINEDLLPATH|WINEPREFIX|WINE_MONO_OVERRIDES|WINEESYNC|PROTON_VR_RUNTIME|WINEDLLOVERRIDES|WINELOADERNOEXEC|WINEPRELOADRESERVE)'

# Build a custom PATH based on the running pid's path vars
steampath=`cat /proc/$FFXIVPID/environ | xargs -0 bash -c 'printf "export %q\n" "$@"' | grep 'export PATH' | tr ':' $'\n' | grep -i steam | tr $'\n' ':' | sed -e 's/:$//g'`

echo
echo '# Note that if you switch Proton runners in steam, you will need to fix the path here as well as the LD_LIBRARY_PATH above'
echo "export ${steampath}:\$PATH"

echo
echo 'cd $WINEPREFIX/drive_c'
echo
echo '/bin/bash'
```

## For Lutris

```bash
#!/bin/bash

FFXIVPID=$1

echo '#!/bin/bash'
echo

# Get running process's environment variables, pull out only the ones we need, and format them as export lines
cat /proc/$FFXIVPID/environ | xargs -0 bash -c 'printf "export %q\n" "$@"' | grep -P '(DRI_PRIME|LD_LIBRARY_PATH|PYTHONPATH|SDL_VIDEO_FULLSCREEN_DISPLAY|STEAM_RUNTIME|WINEDEBUG|WINEDLLPATH|WINEPREFIX|WINE_MONO_OVERRIDES|WINEESYNC|PROTON_VR_RUNTIME|WINEDLLOVERRIDES|WINELOADERNOEXEC|WINEPRELOADRESERVE|DXVK|export WINE=)'

echo 'export TERM=xterm'

# Build a custom PATH based on the running pid's path vars
lutrispath=`dirname "$(cat /proc/$FFXIVPID/environ | xargs -0 bash -c 'printf "export %q\n" "$@"' | grep 'export WINE=' | cut -d'=' -f2)"`

echo
echo '# Note that if you switch Proton/wine runners in lutris, you will need to fix the path here as well as the LD_LIBRARY_PATH and WINE variables above'
echo export PATH=${lutrispath}:\$PATH

echo
echo 'cd $WINEPREFIX/drive_c'
echo
echo '/bin/bash'
```

# Getting ACT itself working

## Preparation

ACT requires that you use the native .net firmware, it will not work with `mono`. All of the following commands/steps should be done from within the `FFXIV environment`. This is a good time to make a backup of your prefix so that if you have issues you can restore!

1. Ensure that you do not have `Wine Mono` installed in your wine prefix. Most `wine`/`proton` builds have it by default, so it will need to be uninstalled. *Be sure to uninstall this first, as it may break the .net firmware installation if you don't!* To uninstall, run `wine64 uninstaller` and then uninstall from the GUI.
2. Install the .net framework, starting with 4.0 and working your way up to 4.7.2 in order. If the .net installer prompts you to reboot, always select `Yes`. This will just close the wine prefix, but failing to do this can cause issues. If you don't have `winetricks` available as a command-line tool, you can get it from <https://github.com/Winetricks/winetricks>. The versions to install, in order, are: `dotnet40`, `dotnet45`, `dotnet452`, `dotnet46`, `dotnet461`, `dotnet462`, `dotnet471`, `dotnet472`. If you have issues here, you will likely need to restart from scratch because the .net installer can leave the prefix in an unusable state, so *be careful*!
3. Ensure that the wine prefix is configured for Windows 7 in `wine64 winecfg` at the bottom of the `Applications` tab.
4. Download the latest (setup) version of ACT from <https://advancedcombattracker.com/download.php>
5. Run the installer via `wine <path to ACTv3-Setup.exe>`, install with default settings
6. Run ACT if it doesn't auto-run via `wine64 "Program Files (x86)/Advanced Combat Tracker/Advanced Combat Tracker.exe"`
7. Follow the first-time instructions and select the FFXIV plugin, note that the plugin itself won't work properly yet
8. Close ACT and make sure FFXIV still runs for you as expected

# Getting the FFXIV ACT plugin working

The FFXIV ACT plugin consists of two troublesome components which we need to address to get it working in Linux.

1. The plugin reads the game's memory to determine current zone and some other basic info
2. The plugin intercepts network packets inbound to the game to determine events such as `<player> hit <enemy> with <skill> for <damage>`

To address these issues, we will need to set the capabilities extended to the wine/proton executables to allow this. However, doing so will cause issues with library loading due to the security models applied to executables running within a `setcap` scope. As such, we'll need to modify the global shared library path to load the required libraries. However, we can't just indiscriminately load libraries, as that might clobber functionaltiy of other processes on your system.

## Preparing ld.so.conf.d library loading

TODO: There has to be a better way to do this...

We need to figure out what libraries the FFXIV process is using. If you use a controller, this is especially important to get correct, as otherwise controllers won't work.

Again, all commands ran here are from within the `FFXIV environment`.

1. Open FFXIV, get in-game, make sure your controller is working if you use one
2. In a terminal with the game still running, execute this command to determine which libraries are in use (aside from the standard wine/proton libraries): `for i in $(sudo awk '/\.so/{print $6}' /proc/<FFXIV Game PID>/maps | sort -u); do found=false; for j in $(ldconfig -p | grep -Poi ' => .*?$' | cut -d' ' -f3-); do if [ "$i" == "$j" ]; then found=true; fi; done; if [ "$found" == "false" ]; then echo $i; fi; done | grep -Pvi '^(/lib|/usr/lib)' | grep -Pvi "$(dirname -- "$(dirname -- "$(which wine)")")"`. An example of the libraries that might be returned include `libpng12.so.0.46.0`, `libSDL2-2.0.so.0.9.0`, and `libudev.so.0.13.0`. You'll want to check the directory these libraries reside in and copy both the libraries themselves as well as any symlinks to them (e.g. `libpng12.so.0 > libpng12.so.0.46.0`) out to a separate directory. I will refer to this as $EXTRALIBS64 in step 5. Save this list somewhere, as you may need to refer to it again later to resolve further issues.
3. Repeat the step above with the launcher running. Note that the launcher is a 32-bit application, whereas the game itself is a 64-bit application, so you may need an $EXTRALIBS32.
4. Run `echo $(dirname -- "$(dirname -- "$(which wine)")")` to get the base path to the proton/wine runner, I will refer to this as $PROTONPATH in step 4.
5. Create a new file, `/etc/ld.so.conf.d/ffxiv.conf`. This file should have two to four lines ($EXTRALIBS64 and $EXTRALIBS32 only if needed):
```
$PROTONPATH/lib64
$PROTONPATH/lib
$EXTRALIBS64
$EXTRALIBS32
```
6. Run `sudo ldconfig` to regenerate the ld cache
7. If for some reason you need to revert this change, you can remove the `/etc/ld.so.conf.d/ffxiv.conf` and re-run `sudo ldconfig` (or delete `/etc/ld.so.cache` and reboot)

## Setting capabilities on executables

Now we need to do the actual capabilities changes to the executables for proton/wine.

Close ACT and FFXIV, ensure that there are no processes running on the wine prefix (check `ps aux | grep -i \\.exe`).

Within the `FFXIV environment`, run the following:

```
sudo setcap cap_net_raw,cap_net_admin,cap_sys_ptrace=eip "`which wine-preloader`"
sudo setcap cap_net_raw,cap_net_admin,cap_sys_ptrace=eip "`which wine64-preloader`"
sudo setcap cap_net_raw,cap_net_admin,cap_sys_ptrace=eip "`which wine64`"
sudo setcap cap_net_raw,cap_net_admin,cap_sys_ptrace=eip "`which wine`"
sudo setcap cap_net_raw,cap_net_admin,cap_sys_ptrace=eip "`which wineserver`"
```

If for some reason you need to revert this change later, you can do the following:

```
sudo setcap -r "`which wineserver`"
sudo setcap -r "`which wine`"
sudo setcap -r "`which wine64`"
sudo setcap -r "`which wine64-preloader`"
sudo setcap -r "`which wine-preloader`"
```

# The moment of truth

Finally, we're ready. Run FFXIV, log in to your character.

1. Within the `FFXIV environment`, run ACT. In ACT, go to the Plugins tab, click the `FFXIV Settings` tab.
2. The settings in the top-left area should be `Automatic`, `Network`, `All (Default)`, and unchecked box.
3. Check `(DEBUG) Show debug messages` at the bottom of the screen
4. Close ACT and re-open it. Go to the `FFXIV Settings` tab again, and you should see in the log at the bottom a line that reads `RawSocket: Did not detect Idle process, using TCP socket instead of IP socket for wine compatability.`
5. Click the `Test Game Connection` button roughly top-center. It should say `Succeeded: All FFXIV memory signatures detected successfully, and Network data is available.`
6. Go beat up a training dummy, see if the combat is logged in ACT.

## Troubleshooting

If you have issues opening FFXIV after running the `setcap` commands, you have likely missed some libraries. Review the list of libraries and verify that you have them installed in your base system. If you don't, install their corresponding package from your package manager or copy them out to the $EXTRALIBS32 (for the launcher) or $EXTRALIBS64 (for the game) directories, and re-run `sudo ldconfig` to regenerate the cache again. Other examples of libraries include 32-bit `libfontconfig.so.1.4.4` on systems with only 64-bit installed, and both 32-bit and 64-bit `libvulkan.so.1.1.73` on systems that do not have the vulkan loader installed.

If you use i3 or some other windowing manager that does not render windows that are not on the active workspace, ACT will be very unstable. For i3, reports are that putting ACT in `scratch` and the overlay on the correct workspace should work as expected, but your mileage may vary.

# Extras

## Text To Speach

TTS won't work on Linux, the MS Speech API won't install properly. We've created an ACT plugin to work around this issue, avialable here: <https://github.com/Minizbot2012/LinuxTTSPlugin/>.

The plugin's default configuration should use `espeak`, which is barebones and functional. You can reconfigure the plugin however you want to use something else without needing to recompile it, the config settings are pretty open.

## Transparency and wine/proton

Any plugins that have a transparent background (overlay plugins etc) will cause serious performance problems due to the way the rendering of the transparency works (it has to be rendered entirely on the CPU). We're currently investigating potential linux-specific fixes for this using web sockets, for now be aware that having an overlay displayed may cause framerate hitches randomly, especially when the overlay changes in a significant fashion.

## OverlayPlugin/cactbot

`cactbot`, which is a raid helper overlay, only currently works with the hibayasleep fork of `OverlayPlugin`, avialable here: <https://github.com/hibiyasleep/OverlayPlugin>

`cactbot` itself is available here: <https://github.com/quisquous/cactbot>

There is an open PR to get `cactbot` working in ngld's fork of OverlayPlugin, which has more features, you can follow the progress on that here: <https://github.com/quisquous/cactbot/pull/577>

## FFLogs Uploader

FFLogs uploader is an electron app and should work normally as long as it's installed to the same wine prefix as FFXIV and ACT. If you want a native solution, [ngld](https://github.com/ngld) has created a script to repackage the uploader as a native app. Requires `node`, `yarn`, and `7z`:

```bash
#!/bin/bash

set -e

echo "==> Downloading FFLogs uploader..."

curl -O https://ddosa82diq6o3.cloudfront.net/FFLogsUploader.exe

echo "==> Extracting installer..."

7z x -otmp FFLogsUploader.exe
if [ -f 'tmp/$PLUGINSDIR/app-64.7z' ]; then
  7z x -otmp 'tmp/$PLUGINSDIR/app-64.7z'
fi

echo "==> Downloading asar..."
yarn add asar

echo "==> Unpacking application..."
yarn run asar e tmp/resources/app.asar app

cd app
echo "==> Downloading electron tools..."
yarn add -D electron electron-builder

echo "==> Building linux build..."
yarn run electron-builder -l
cd dist

echo "==> Done! Files are in $(pwd)"
```

## Upgrading Proton

If you want to upgrade proton, you will need to:

1. Update the `~/bin/ffxiv_env.sh` script to reflect the new Proton path (`PATH`, `LD_LIBRARY_PATH`, and lutris-only `WINE`)
2. Re-do the steps from [Preparing ld.so.conf.d library loading](#preparing-ldsoconfd-library-loading) and [Setting capabilities on executables](#setting-capabilities-on-executables)

## I use Steam and my ACT suddenly stopped working

Steam probably updated Proton as a minor version update (e.g. `4.11-2 to 4.11-3`). These updates overwrite the old files instead of creating a new proton installation. You can verify this by running `getcap "$(which wine)"` within the FFXIV environment. If that command returns nothing, try re-doing the [Setting capabilities on executables](#setting-capabilities-on-executables) section. If you get library load errors, remove the capabilities per the instructions in [Setting capabilities on executables](#setting-capabilities-on-executables) and then follow the upgrade instructions in [Upgrading Proton](#upgrading-proton).