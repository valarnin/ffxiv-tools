. ./prompt.sh
. ./error.sh

CHECK_FOR_FLATPAK() {
    if command -v flatpak &>/dev/null; then
        # dev.goats.xivlauncher is the current flatpak name for XLCore on flathub. Change this if that name changes for some reason.
        if flatpak list --app | grep "dev.goats.xivlauncher"; then
            error "Detected the flatpak version of XLCore. ACT cannot run in a flatpak environment. Please back up and delete your .xlcore directory, uninstall the flatpak, install the AUR/MPR build of XIVLauncher-git, and re-run this script."
            echo ""
            exit 1
        else
            success "Flatpak installation not present, checking for AUR build now..."
            return CONTROL_FORK_DISTRO
        fi
    else
        warn "Flatpak is not installed. Continuing under the assumption that you cannot install a flatpak without it."
        return CONTROL_FORK_DISTRO
    fi
}

CONTROL_FORK_DISTRO() {
    if command -v pacman &>/dev/null; then
        CHECK_FOR_AUR
    elif command -v apt &>/dev/null; then
        CHECK_FOR_MPR
    else
        error "Your distribution isn't supported by these setup scripts. This script only supports"
        echo "Arch-based and Debian-based distros, such as Arch Linux/Manjaro and Debian/Ubuntu/Linux Mint"
    fi
}

CHECK_FOR_AUR() {
    if pacman -Q | grep "xivlauncher" &>/dev/null; then
        success "Found AUR XLCore. Please ensure that the following setting is set in your XIVLauncher UI:"
        echo "Settings -> Wine -> Installation Type should be \"Managed by XIVLauncher\""
        echo "This is generally the correct setting regardless of whether you wish to use ACT. You should not use system WINE to run ff14."
        return 0
    else
        warn "XLCore not found. Would you like to install it now?"
        PROMPT_CONTINUE
        ARCH_INSTALL_XLCORE
    fi
}

CHECK_FOR_MPR() {
    if apt list --installed | grep "xivlauncher" &>/dev/null; then
        success "Found MPR XLCore. please ensure that the following setting is set in your XIVLauncher UI:"
        echo "Settings -> Wine -> Installation Type should be \"Managed by XIVLauncher\""
        echo "This is generally the correct setting regardless of whether you wish to use ACT. You should not use system WINE to run ff14."
        echo "If you haven't run the game at least once, do so now and rerun setup.sh"
        PROMPT_CONTINUE
        return 0
    else 
        warn "xivlauncher-git not found. please install it using makedeb or an MPR helper such as una."
        echo "Then launch the game, close it, and rerun setup.sh"
        exit 1
    fi
}

ARCH_INSTALL_XLCORE() {
    if ! command -v git &>/dev/null; then
        error "git must be installed in order to automate the installation of xlcore"
        exit 1
    else
        echo "Cloning XIVLauncher-git into /tmp/ffxiv-tools..."
        cd /tmp
        mkdir ffxiv-tools
        cd ffxiv-tools
        git clone https://aur.archlinux.org/xivlauncher-git.git &>/dev/null
        cd xivlauncher-git
        warn "Making the package. this will install a number of make dependencies onto your system."
        warn "The full list of make dependencies can be found at https://aur.archlinux.org/packages/xivlauncher-git"
        warn "You may be asked for your password. makepkg uses pacman to install dependencies, an operation that requires root."
        PROMPT_CONTINUE
        makepkg -s &>/dev/null
        PACKAGE_BALL=(*.pkg.tar.zst)
        warn "The next command requires root permissions. You will be asked for your password."
        warn "The command to be run is the following:"
        warn "sudo pacman --upgrade $PACKAGE_BALL"
        sudo pacman --upgrade $PACKAGE_BALL
        echo "You must now start XIVLauncher.core and run the game for the first time in order to populate the directories that are required for the next steps."
        echo "You may then run setup.sh again."
        exit 0
    fi
}
