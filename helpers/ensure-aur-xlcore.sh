. helpers/prompt.sh
. helpers/error.sh

CHECK_FOR_FLATPAK() {
    if command -v flatpak &>/dev/null; then
        # dev.goats.xivlauncher is the current flatpak name for XLCore on flathub. Change this if that name changes for some reason.
        if flatpak list --app | grep "dev.goats.xivlauncher"; then
            error "Detected the flatpak version of XLCore. ACT cannot run in a flatpak environment. Please back up and delete your .xlcore directory, uninstall the flatpak, install the AUR/MPR build of XIVLauncher-git, and re-run this script."
            echo ""
            exit 1
        else
            success "Flatpak installation not present, checking for AUR/MPR build now..."
            CONTROL_FORK_DISTRO
        fi
    else
        warn "Flatpak is not installed. Continuing under the assumption that you cannot install a flatpak without it."
        CONTROL_FORK_DISTRO
    fi
}

CONTROL_FORK_DISTRO() {
    if command -v pacman &>/dev/null; then
        CHECK_FOR_AUR
    elif command -v apt &>/dev/null; then
        CHECK_FOR_MPR
    else
        warn "Your distro isn't in the list of tested distros. Proceed at your own risk, and ensure that you've installed XIVLauncher Core from source."
        PROMPT_CONTINUE;
    fi
}

CHECK_FOR_AUR() {
    if pacman -Q | grep "xivlauncher" &>/dev/null; then
        success "Found AUR XLCore."
        echo "If you haven't run the game at least once, do so now and rerun setup.sh"
        PLATFORM="AUR"
        PROMPT_CONTINUE
    else
        warn "xivlauncher-git not found. please install it."
        echo "Then launch the game, close it, and rerun setup.sh"
        echo "xivlauncher-git can be found at https://aur.archlinux.org/packages/xivlauncher-git"
        exit 1
    fi
}

CHECK_FOR_MPR() {
    if apt list --installed | grep "xivlauncher" &>/dev/null; then
        success "Found MPR XLCore."
        echo "If you haven't run the game at least once, do so now and rerun setup.sh"
        PLATFORM="MPR"
        PROMPT_CONTINUE
    else 
        warn "xivlauncher-git not found. please install it using makedeb."
        echo "xivlauncher-git can be found at https://mpr.makedeb.org/packages/xivlauncher-git"
        echo "Then launch the game, close it, and rerun setup.sh"
        exit 1
    fi
}
