. ./funcs.sh
. ./error.sh

CHECK_FOR_FLATPAK() 
{
    if command -v flatpak &>/dev/null; then
        if flatpak list --app | grep "dev.goats.xivlauncher"; then
            error "Detected the flatpak version of XLCore. ACT cannot run in a flatpak environment. Please install XLCore from the AUR instead."
        else 
            success "XLCore flatpak not detected... Checking for AUR build now..."
            if command -v pacman &>/dev/null; then 
                if pacman -Q | grep "xivlauncher" &>/dev/null; then 
                    success "Found AUR XLCore. Please ensure that the following setting is set in your XIVLauncher UI:"
                    echo "Settings -> Wine -> Installation Type should be \"Managed by XIVLauncher\""
                    echo "This is generally the correct setting regardless of whether you wish to use ACT. You should not use system WINE to run ff14."
                fi
            fi
        fi

    else
        echo "flatpak not installed"
    fi
}

CHECK_FOR_FLATPAK;