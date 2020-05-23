#!/bin/bash

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
        read -p "Would you like to make a backup of your Proton install and FFXIV prefix? [Y/N] " CONTINUE
    done

    if [[ "$CONTINUE" == "N" || "$CONTINUE" == "n" ]]; then
        echo "Skipping backup"
    else
        TIMESTAMP="$(date +%s)"

        PROTON_BACKUP_FILENAME="BACKUP_dist_$TIMESTAMP.tar.gz"
        echo "Creating Proton backup at $PROTON_BACKUP_DIR/$PROTON_BACKUP_FILENAME"
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
        echo "Desktop entries have already been created"
        CONTINUE="n"
    fi

    while [[ "$CONTINUE" != "Y" && "$CONTINUE" != "N" && "$CONTINUE" != "y" && "$CONTINUE" != "n" ]]; do
        read -p "Would you like to create desktop entries for FFXIV and ACT? [Y/N] " CONTINUE
    done

    if [[ "$CONTINUE" == "N" || "$CONTINUE" == "n" ]]; then
        echo "Skipping entry creation"
    else
        mkdir -p "$HOME/.local/share/icons/hicolor/200x200/apps" &> /dev/null
        mkdir -p "$HOME/.local/share/icons/hicolor/256x256/apps" &> /dev/null
        wget -O "$HOME/.local/share/icons/hicolor/200x200/apps/act.png" "https://forums.advancedcombattracker.com/uploads/userpics/821/pRS0T7AHQ1UUH.png" &> /dev/null
        wget -O "$HOME/.local/share/icons/hicolor/256x256/apps/act_ffxiv.png" "https://advancedcombattracker.com/act_data/act_ffxiv.png" &> /dev/null
        if [[ "$(find "$HOME/.local/share/icons/hicolor/128x128/apps" -maxdepth 1 -iname 'lutris_final-fantasy-xiv-a-realm-reborn.png' -print -quit 2> /dev/null | wc -l)" -gt 0 ]]; then
            FFXIV_ICON="$HOME/.local/share/icons/hicolor/128x128/apps/lutris_final-fantasy-xiv-a-realm-reborn.png"
        elif [[ "$(find "$HOME/.local/share/icons/hicolor/32x32/apps" -maxdepth 1 -iname 'steam_icon_39210.png' -print -quit 2> /dev/null | wc -l)" -gt 0 ]]; then
            FFXIV_ICON="$HOME/.local/share/icons/hicolor/32x32/apps/steam_icon_39210.png"
        else
            echo "Could not find FFXIV's icon. Downloading..."
            wget -O "$HOME/.local/share/icons/hicolor/200x200/apps/ffxiv_icon.png" "https://steamuserimages-a.akamaihd.net/ugc/862859572048700909/04B5C43E1CA6850F56EC76C9D45BFEC128C87A69/" &> /dev/null
            FFXIV_ICON="$HOME/.local/share/icons/hicolor/200x200/apps/ffxiv_icon.png"
        fi
        mkdir -p $HOME/.local/share/applications &> /dev/null
        printf '%s\n' \
        "[Desktop Entry]" \
        "Name=FFXIV & ACT" \
        "Exec=$HOME/bin/ffxiv-run-both.sh" \
        "Icon=$HOME/.local/share/icons/hicolor/256x256/apps/act_ffxiv.png" \
        "Type=Application" \
        "Terminal=False" \
        "Categories=Game;" > $HOME/.local/share/applications/ffxiv-run-both.desktop
        printf '%s\n' \
        "[Desktop Entry]" \
        "Name=Final Fantasy XIV" \
        "Exec=$HOME/bin/ffxiv-run-game.sh" \
        "Icon=$FFXIV_ICON" \
        "Type=Application" \
        "Terminal=False" \
        "Categories=Game;" > $HOME/.local/share/applications/ffxiv-run-game.desktop
        printf '%s\n' \
        "[Desktop Entry]" \
        "Name=Advanced Combat Tracker" \
        "Exec=$HOME/bin/ffxiv-run-act.sh" \
        "Icon=$HOME/.local/share/icons/hicolor/200x200/apps/act.png" \
        "Type=Application" \
        "Terminal=False" \
        "Categories=Game;" > $HOME/.local/share/applications/ffxiv-run-act.desktop
        echo "Desktop entries have been created at $HOME/.local/share/applications/"
    fi
}
