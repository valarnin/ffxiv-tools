Guide to get FFXIV and ACT working in wine/proton on Linux. Last updated 2019-09-18.

# Table of Contents

   * [Preamble](#preamble)
   * [Support](#support)
   * [Getting FFXIV itself working](#getting-ffxiv-itself-working)
      * [Steam](#steam)
      * [Standalone](#standalone)
   * [Setting up the FFXIV Environment](#setting-up-the-ffxiv-environment)
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

Note that all instructions below are written for `Proton 4.15-ge` or higher. Versions prior to this have various issues.

`Proton 4.15-ge` still has two remaining bugs:

1. The new launcher may or may not work for you. If it does not work for you, open the file at `drive_c/users/steamuser/My Documents/My Games/FINAL FANTASY XIV - A Realm Reborn/FFXIV_BOOT.cfg` and change `Browser` to `1`.
2. You must disable the new character opening cutscene. You can watch this cutscene from the menu without issues, but for some reason when it autoplays it crashes.

Additionally, please note that as of patch 5.08 released on 2019-08-29, you must use the Steam client if you bought the game through Steam, and you must use the standalone client if you bought the game through the Mog Station.

A final note that if your windowing manager does not render windows on other workspaces actively (i3 is our test case here) you will have issues with ACT working properly. See the Troubleshooting section for more information.

Tested as working on the following setups, though any Linux capable of getting FFXIV itself working should work properly:

1. `gentoo amd64/17.0, kernel 5.2.2, Gnome 3`
2. `gentoo amd64/17.1, kernel 5.2.2, Gnome 3`
3. `Arch Linux, 5.4.5-arch1-1, Mutter`
4. `Linux Mint 19.2 Cinnamon, kernel 4.15.0-62-generic, Cinnamon`
5. `Manjaro Linux, kernel 5.2.14-arch1-1-fsync, Gnome 3`
6. `Manjaro Linux, kernel 4.19.89-1-MANJARO, Gnome 3`

# Support

Note that EQAditu, creator of ACT itself, and Ravahn, creator of the FFXIV ACT Plugin, cannot help diagnose linux-specific issues. For support, please use the #ffxiv-linux-discussion text channel on the ACT FFXIV discord, which can be found [here](https://github.com/ravahn/FFXIV_ACT_Plugin).

We can upstream fixes for linux issues if needed, but the only case of a code change being required to support linux was for the socket listener, done via these pull requests:

https://github.com/ravahn/machina/pull/8 (initial)

https://github.com/ravahn/machina/pull/9 (fix false positives in linux detection)

# Getting FFXIV itself working

## Steam

1. In Steam, under `Settings` > `Steam Play`, make sure that the `Enable Steam Play for all titles` option is enabled.
2. Install FFXIV in Steam.
3. Follow the install instructions for Proton 4.15-ge from https://github.com/GloriousEggroll/proton-ge-custom.
4. Right click FFXIV in your Steam library, and in `Properties` > `General`, at the bottom, check the `Force the use of a specific Steam Play compatability tool`. In the dropdown select the option starting with `Proton-4.15-ge`.
5. Launch FFXIV. Log in with your account and allow the game to patch. Do not launch yet. Close the patcher.
6. Navigate to your FFXIV prefix directory. By default this should be at `~/.local/share/Steam/steamapps/compatdata/39210/pfx`
7. In `drive_c/users/steamuser/My Documents/My Games/FINAL FANTASY XIV - A Realm Reborn`, edit `FFXIV.cfg`. Find `CutsceneMovieOpening` and change the `0` to `1`
8. Open FFXIV, you should be able to log in/create character/etc. If you want to watch the opening cutscene, there's an option in the main menu for it.

## Standalone

1. Use the `lutris` installer at `https://lutris.net/games/final-fantasy-xiv-a-realm-reborn/`
2. Install the `Standalone - DXVK version`. This will handle installing the game client and setting up the config file changes required
3. Switch the proton version to 4.15-ge or higher. You may need to follow the install instructions here: https://github.com/GloriousEggroll/proton-ge-custom
4. Log in, make sure everything works.
5. If all else fails, you can set up a new 64-bit wine prefix directly in lutris configured to use proton 4.15-ge and install FFXIV in it with the installer download at <http://gdl.square-enix.com/ffxiv/inst/ffxivsetup.exe>.

# Setting up the FFXIV Environment

This entire process has been scripted out for you.

1. Download or clone this repo
2. Run `./setup.sh`
3. The setup script will guide you through the rest of the process

Throughout the remainder of this guide, I will refer to the `FFXIV environment`. This can be accessed by running `~/bin/ffxiv-env.sh`.

# The moment of truth

Finally, we're ready. Run FFXIV, log in to your character.

1. Within the `FFXIV environment`, run ACT. In ACT, go to the Plugins tab, click the `FFXIV Settings` tab.
2. The settings in the top-left area should be `Automatic`, `Network`, `All (Default)`, and unchecked box.
3. Check `(DEBUG) Enable Debug Options` at the bottom of the screen
4. Close ACT and re-open it. Go to the `FFXIV Settings` tab again, and you should see in the log at the bottom a line that reads `RawSocket: Did not detect Idle process, using TCP socket instead of IP socket for wine compatability.`
5. Click the `Test Game Connection` button roughly top-center. It should say `Succeeded: All FFXIV memory signatures detected successfully, and Network data is available.`
6. Go beat up a training dummy, see if the combat is logged in ACT
7. If all is good, uncheck `(DEBUG) Enable Debug Options`, you don't need it any more

## Troubleshooting

If you use i3 or some other windowing manager that does not render windows that are not on the active workspace, ACT will be very unstable. For i3, reports are that putting ACT in `scratch` and the overlay on the correct workspace should work as expected, but your mileage may vary.

If your overlay won’t appear when the game has focus. A possible solution is to set the game’s focus priority to “below all others”. On KDE Plasma, this can be done by right-clicking the activity on the menubar, hover on “More Actions”, and enable “Keep Below Others”. This also makes it possible to see the overlay in-game when running it in borderless windowed.

# Extras

## Text To Speach

TTS won't work on Linux, the MS Speech API won't install properly. We've created an ACT plugin to work around this issue, avialable here: <https://github.com/Minizbot2012/LinuxTTSPlugin/>.

The plugin's default configuration should use `espeak`, which is barebones and functional. You can reconfigure the plugin however you want to use something else without needing to recompile it, the config settings are pretty open.

## Transparency and wine/proton

Any plugins that have a transparent background (overlay plugins etc) will cause serious performance problems due to the way the rendering of the transparency works (it has to be rendered entirely on the CPU). We're currently investigating potential linux-specific fixes for this using web sockets (check out my fork of [hudkit](https://github.com/valarnin/hudkit)), for now be aware that having an overlay displayed may cause framerate hitches randomly, especially when the overlay changes in a significant fashion.

## OverlayPlugin/cactbot

`cactbot`, which is a raid helper overlay, now requires the ngld version of the overlayplugin, avialable here: <https://github.com/ngld/OverlayPlugin>

`cactbot` itself is available here: <https://github.com/quisquous/cactbot>

## FFLogs Uploader

FFLogs uploader is an electron app and should work normally as long as it's installed to the same wine prefix as FFXIV and ACT. If you want a native solution, [ngld](https://github.com/ngld) has created a script to repackage the uploader as a native app. Requires `node`, `yarn`, and `7z`, available in this repo as `fflogs-wrapper.sh`.

## Upgrading Proton

If you want to upgrade proton, you will need to:

1. Update proton as normal
2. Re-run `setup.sh`

## I use Steam and my ACT suddenly stopped working

Steam probably updated Proton as a minor version update (e.g. `4.11-2 to 4.11-3`). These updates overwrite the old files instead of creating a new proton installation. Re-run `setup.sh`
