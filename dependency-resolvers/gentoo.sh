#!/bin/bash

GENTOO_DEP_TO_PACKAGE() {
    case "$DEP" in
        "unzip")
            DEP='app-arch/unzip'
            ;;
        "patchelf")
            DEP='dev-util/patchelf'
            ;;
        "winetricks")
            DEP='app-emulation/winetricks'
            ;;
        "libpng12.so.0")
            DEP='=media-libs/libpng-1.2*'
            ;;
        "libgcrypt.so")
            DEP='dev-libs/libgcrypt'
            ;;
        *)
            error "Could not resolve dependency for $DEP"
            exit 1
            ;;
    esac
}

GENTOO_MISC() {
    case "$DEP" in
        "ulimit")
            echo "Please refer to the Gentoo wiki page here:"
            echo "https://wiki.gentoo.org/wiki/Security_Handbook/User_and_group_limitations"
            echo
            echo "The values that need to be set are as follows:"
            echo "* hard nofile 65535"
            echo "* soft nofile 65535"
            echo
            echo "You must reboot after applying these settings."
            exit 1
            ;;
        *)
            error "Could not find logic for misc dep $DEP"
            exit 1
            ;;
}

RESOLVE_DEPS() {
    MISSING_UNIQUE=(  )
    for DEP in "${MISSING_HARD_32[@]}"; do
        GENTOO_DEP_TO_PACKAGE
        MISSING_UNIQUE+=("$DEP")
    done
    for DEP in "${MISSING_HARD_64[@]}"; do
        GENTOO_DEP_TO_PACKAGE
        MISSING_UNIQUE+=("$DEP")
    done
    for DEP in "${MISSING_SOFT_32[@]}"; do
        GENTOO_DEP_TO_PACKAGE
        MISSING_UNIQUE+=("$DEP")
    done
    for DEP in "${MISSING_SOFT_64[@]}"; do
        GENTOO_DEP_TO_PACKAGE
        MISSING_UNIQUE+=("$DEP")
    done
    for DEP in "${MISSING_HARD_TOOLS[@]}"; do
        GENTOO_DEP_TO_PACKAGE
        MISSING_UNIQUE+=("$DEP")
    done
    for DEP in "${MISSING_SOFT_TOOLS[@]}"; do
        GENTOO_DEP_TO_PACKAGE
        MISSING_UNIQUE+=("$DEP")
    done
    for DEP in "${MISSING_SOFT_MISC[@]}"; do
        GENTOO_MISC
    done
    for DEP in "${MISSING_HARD_MISC[@]}"; do
        GENTOO_MISC
    done
    MISSING_UNIQUE=($(echo "${MISSING_UNIQUE[@]} | tr ' ' '\n' | sort -u | tr '\n' ' '"))
    echo
    warn "Installing the following dependencies:"
    echo 
    echo "${MISSING_UNIQUE[@]}"
    echo
    PROMPT_CONTINUE
    sudo emerge -av ${MISSING_UNIQUE[@]}
    if [[ "$?" -ne 0 ]]; then
        exit 1
    fi
}
