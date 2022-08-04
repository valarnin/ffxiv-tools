. ./funcs.sh
. ./error.sh

CHECK_FOR_FLATPAK() {
    if command -v flatpak &>/dev/null; then
        # dev.goats.xivlauncher is the current flatpak name for XLCore on flathub. Change this if that name changes for some reason.
        if flatpak list --app | grep "dev.goats.xivlauncher"; then
            error "Detected the flatpak version of XLCore. ACT cannot run in a flatpak environment. Please install XLCore from the AUR instead."
            return 1
        else
            success "XLCore flatpak not detected... Checking for AUR build now..."
            return CHECK_FOR_AUR
        fi
    else
        warn "Flatpak is not installed. Continuing under the assumption that you cannot install a flatpak without it."
        return CHECK_FOR_AUR
    fi
}

CHECK_FOR_AUR() {
    if command -v pacman &>/dev/null; then
        if pacman -Q | grep "xivlauncher" &>/dev/null; then
            success "Found AUR XLCore. Please ensure that the following setting is set in your XIVLauncher UI:"
            echo "Settings -> Wine -> Installation Type should be \"Managed by XIVLauncher\""
            echo "This is generally the correct setting regardless of whether you wish to use ACT. You should not use system WINE to run ff14."
            return 0
        fi
    fi
}

CHECK_FOR_FLATPAK
