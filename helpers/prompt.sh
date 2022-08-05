#!/bin/bash

# Determine where the user wants to install the tools
# NOTE: Because prompt.sh runs as a child of the main setup scripts,
# the working dir and $0 refers to the main folder, hence this path.
. config/ffxiv-tools-location.sh

if [[ "$HELPERS_PROMPT" == "Y" ]]; then
  return;
fi

HELPERS_PROMPT="Y"

PROMPT_IN_ARRAY() {
    eval "ARRAY"='( "${'$1'[@]}" )'
    ARRAY_COUNT="${#ARRAY[*]}"
    SELECTION=""
    while [[ "$SELECTION" == "" ]]; do
        if [[ "$4" != "" ]]; then
            echo "$4"
        fi
        for ((i=0;i<ARRAY_COUNT;++i)); do
            echo "$i) ${ARRAY[i]}"
        done
        read -p "$3" SELECTION
        if [[ ! "$SELECTION" =~ ^[0-9]+$ ]] || [ "$SELECTION" -lt 0 ] || [ "$SELECTION" -ge "$ARRAY_COUNT" ]; then
            echo "Invalid input"
            SELECTION=""
        fi
    done
    eval "$2"="$SELECTION"
}

PROMPT_CONTINUE()
{
    CONTINUE=""

    while [[ "$CONTINUE" != "Y" && "$CONTINUE" != "N" && "$CONTINUE" != "y" && "$CONTINUE" != "n" ]]; do
        read -p "Continue? [Y/N] " CONTINUE
    done

    if [[ "$CONTINUE" == "N" || "$CONTINUE" == "n" ]]; then
        echo "Aborting process"
        exit 1
    fi
}

PROMPT_BACKUP()
{
    PROTON_BACKUP_DIR="$(dirname "$PROTON_DIST_PATH")"
    PREFIX_BACKUP_DIR="$(dirname "$WINEPREFIX")"
    CONTINUE=""

    if [[ "$(find "$PROTON_BACKUP_DIR" -maxdepth 1 -iname 'BACKUP_dist_*.tar.gz' -print -quit | wc -l)" -gt 0 ]]; then
        echo "Backup already exists"
        CONTINUE="n"
    fi

    while [[ "$CONTINUE" != "Y" && "$CONTINUE" != "N" && "$CONTINUE" != "y" && "$CONTINUE" != "n" ]]; do
        read -p "Would you like to make a backup of your wine install and FFXIV prefix? [Y/N] " CONTINUE
    done

    if [[ "$CONTINUE" == "N" || "$CONTINUE" == "n" ]]; then
        echo "Skipping backup"
    else
        TIMESTAMP="$(date +%s)"

        PROTON_BACKUP_FILENAME="BACKUP_dist_$TIMESTAMP.tar.gz"
        echo "Creating wine backup at $PROTON_BACKUP_DIR/$PROTON_BACKUP_FILENAME"
        tar -C "$PROTON_BACKUP_DIR" -czf "$PROTON_BACKUP_DIR/$PROTON_BACKUP_FILENAME" "$(basename "$PROTON_DIST_PATH")"
        echo "Backup created, size $(du -h "$PROTON_BACKUP_DIR/$PROTON_BACKUP_FILENAME" | cut -f1)"

        PREFIX_BACKUP_FILENAME="BACKUP_$(basename "$WINEPREFIX")_$TIMESTAMP.tar.gz"
        echo "Creating Wine Prefix backup at $PREFIX_BACKUP_DIR/$PREFIX_BACKUP_FILENAME"
        tar -C "$PREFIX_BACKUP_DIR" -czf "$PREFIX_BACKUP_DIR/$PREFIX_BACKUP_FILENAME" --exclude="SquareEnix/FINAL FANTASY XIV - A Realm Reborn" "$(basename "$WINEPREFIX")"
        echo "Backup created, size $(du -h "$PREFIX_BACKUP_DIR/$PREFIX_BACKUP_FILENAME" | cut -f1)"
    fi
}

PROMPT_DESKTOP_ENTRIES()
{
    CONTINUE=""
    
    if [[ "$(find "$HOME/.local/share/applications" -maxdepth 1 -iname 'ffxiv-run-act.desktop' -print -quit 2> /dev/null | wc -l)" -gt 0 ]]; then
        echo "Desktop entries have already been created."
        CONTINUE="n"
    fi

    while [[ "$CONTINUE" != "Y" && "$CONTINUE" != "N" && "$CONTINUE" != "y" && "$CONTINUE" != "n" ]]; do
        read -p "Would you like to create desktop entries for FFXIV and ACT? [Y/N] " CONTINUE
    done

    if [[ "$CONTINUE" == "N" || "$CONTINUE" == "n" ]]; then
        echo "Skipping desktop entry creation."
    else
        mkdir -p "$HOME/.local/share/icons/hicolor/200x200/apps" &> /dev/null
        mkdir -p "$HOME/.local/share/icons/hicolor/256x256/apps" &> /dev/null

        # Download our custom icons.
        # NOTE: Our custom FFXIV icon (ffxiv_icon.png) was created as follows:
        #   wget -O FFXIV_logo.png "https://static.wikia.nocookie.net/finalfantasy/images/b/b3/FFXIV_logo.png"
        #   convert FFXIV_logo.png -background none -gravity east -extent 724x724 xivlogofull.png
        #   convert xivlogofull.png -resize 256x256 -unsharp 2x1.0+1.2 ffxiv_icon.png

        # TODO: Discuss with Valarnin the possibility of replacing the FFXIV logo with a Dalamud logo. -Arkevorkhat
        wget -O "$HOME/.local/share/icons/hicolor/200x200/apps/act.png" "https://forums.advancedcombattracker.com/uploads/userpics/821/pRS0T7AHQ1UUH.png" &> /dev/null
        wget -O "$HOME/.local/share/icons/hicolor/256x256/apps/act_ffxiv.png" "https://advancedcombattracker.com/act_data/act_ffxiv.png" &> /dev/null
        wget -O "$HOME/.local/share/icons/hicolor/256x256/apps/ffxiv_icon.png" "https://i.imgur.com/iFoGEUZ.png" &> /dev/null
        FFXIV_ICON="$HOME/.local/share/icons/hicolor/256x256/apps/ffxiv_icon.png"

        # Signal to the OS cache that there are new icons.
        touch "$HOME/.local/share/icons/hicolor/"
        mkdir -p "$HOME/.local/share/applications" &> /dev/null

        # Create the desktop files.
        # IMPORTANT: Desktop files are complicated. The Icon line must never
        # be escaped even if the path contains spaces. However, the Exec
        # line must instead ALWAYS be escaped. A common trick for running
        # programs with spaces is to execute `sh -c '"command here"'` which
        # then runs the space-containing path as a command in a sub-shell,
        # and that trick is also backwards-compatible with older desktops which
        # lacked support for double-quote escaping. That's what we'll do here!
        printf '%s\n' \
        "[Desktop Entry]" \
        "Name=FFXIV & ACT" \
        "Exec=sh -c '\"$HOME/$FFXIV_TOOLS_LOCATION/ffxiv-run-both.sh\"'" \
        "Icon=$HOME/.local/share/icons/hicolor/256x256/apps/act_ffxiv.png" \
        "Type=Application" \
        "Terminal=False" \
        "Categories=Game;" > "$HOME/.local/share/applications/ffxiv-run-both.desktop"
        printf '%s\n' \
        "[Desktop Entry]" \
        "Name=Final Fantasy XIV" \
        "Exec=sh -c '\"$HOME/$FFXIV_TOOLS_LOCATION/ffxiv-run-game.sh\"'" \
        "Icon=$FFXIV_ICON" \
        "Type=Application" \
        "Terminal=False" \
        "Categories=Game;" > "$HOME/.local/share/applications/ffxiv-run-game.desktop"
        printf '%s\n' \
        "[Desktop Entry]" \
        "Name=Advanced Combat Tracker" \
        "Exec=sh -c '\"$HOME/$FFXIV_TOOLS_LOCATION/ffxiv-run-act.sh\"'" \
        "Icon=$HOME/.local/share/icons/hicolor/200x200/apps/act.png" \
        "Type=Application" \
        "Terminal=False" \
        "Categories=Game;" > "$HOME/.local/share/applications/ffxiv-run-act.desktop"

        echo "Desktop entries have been created at $HOME/.local/share/applications/"
    fi
}
