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
    CONTINUE=""

    while [[ "$CONTINUE" != "Y" && "$CONTINUE" != "N" && "$CONTINUE" != "y" && "$CONTINUE" != "n" ]]; do
        read -p "Would you like to make a backup of your Proton install and FFXIV prefix? [Y/N] " CONTINUE
    done

    if [[ "$CONTINUE" == "N" || "$CONTINUE" == "n" ]]; then
        echo "Skipping backup"
    else
        TIMESTAMP="$(date +%s)"

        PROTON_BACKUP_FILENAME="BACKUP_dist_$TIMESTAMP.tar.gz"
        PROTON_BACKUP_DIR="$(dirname "$PROTON_DIST_PATH")"
        echo "Creating Proton backup at $PROTON_BACKUP_DIR/$PROTON_BACKUP_FILENAME"
        tar -C "$PROTON_BACKUP_DIR" -czf "$PROTON_BACKUP_DIR/$PROTON_BACKUP_FILENAME" "$(basename "$PROTON_DIST_PATH")"
        echo "Backup created, size $(du -h "$PROTON_BACKUP_DIR/$PROTON_BACKUP_FILENAME" | cut -f1)"

        PREFIX_BACKUP_FILENAME="BACKUP_$(basename "$WINEPREFIX")_$TIMESTAMP.tar.gz"
        PREFIX_BACKUP_DIR="$(dirname "$WINEPREFIX")"
        echo "Creating Wine Prefix backup at $PREFIX_BACKUP_DIR/$PREFIX_BACKUP_FILENAME"
        tar -C "$PREFIX_BACKUP_DIR" -czf "$PREFIX_BACKUP_DIR/$PREFIX_BACKUP_FILENAME" --exclude="SquareEnix/FINAL FANTASY XIV - A Realm Reborn" "$(basename "$WINEPREFIX")"
        echo "Backup created, size $(du -h "$PREFIX_BACKUP_DIR/$PREFIX_BACKUP_FILENAME" | cut -f1)"
    fi
}
