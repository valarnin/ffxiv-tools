#!/bin/bash

ARCH_DEP_TO_PACKAGE() {
    case "$DEP" in
        "unzip")
            DEP='extra/unzip'
            ;;
        "patchelf")
            DEP='community/patchelf'
            ;;
        "libgcrypt.so")
            DEP='core/libgcrypt'
            ;;
        *)
            error "Could not resolve dependency for $DEP"
            exit 1
            ;;
    esac
}

ARCH_MISC() {
    case "$DEP" in
        "ulimit")
            echo "Please refer to the Arch wiki page here:"
            echo "https://wiki.archlinux.org/title/Limits.conf"
            echo
            echo "The values that need to be set are as follows:"
            echo "* hard nofile 65535"
            echo "* soft nofile 65535"
            echo
            echo "You must reboot after applying these settings."
            exit 1
            ;;
        *)
        "wine_deps")
            echo "Please refer to the lutris documentation here:"
            echo "https://github.com/lutris/docs/blob/master/WineDependencies.md"
            exit 1
            ;;
        *)
            error "Could not find logic for misc dep $DEP"
            exit 1
            ;;
    esac
}

RESOLVE_DEPS() {
    MISSING_UNIQUE=(  )
    for DEP in "${MISSING_HARD_32[@]}"; do
        ARCH_DEP_TO_PACKAGE
        MISSING_UNIQUE+=("$DEP")
    done
    for DEP in "${MISSING_HARD_64[@]}"; do
        ARCH_DEP_TO_PACKAGE
        MISSING_UNIQUE+=("$DEP")
    done
    for DEP in "${MISSING_SOFT_32[@]}"; do
        ARCH_DEP_TO_PACKAGE
        MISSING_UNIQUE+=("$DEP")
    done
    for DEP in "${MISSING_SOFT_64[@]}"; do
        ARCH_DEP_TO_PACKAGE
        MISSING_UNIQUE+=("$DEP")
    done
    for DEP in "${MISSING_HARD_TOOLS[@]}"; do
        ARCH_DEP_TO_PACKAGE
        MISSING_UNIQUE+=("$DEP")
    done
    for DEP in "${MISSING_SOFT_TOOLS[@]}"; do
        ARCH_DEP_TO_PACKAGE
        MISSING_UNIQUE+=("$DEP")
    done
    for DEP in "${MISSING_SOFT_MISC[@]}"; do
        ARCH_MISC
    done
    for DEP in "${MISSING_HARD_MISC[@]}"; do
        ARCH_MISC
    done
    MISSING_UNIQUE=($(echo "${MISSING_UNIQUE[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
    echo
    warn "Installing the following dependencies:"
    echo 
    echo "${MISSING_UNIQUE[@]}"
    echo
    PROMPT_CONTINUE
    sudo pacman -Syu ${MISSING_UNIQUE[@]}
    if [[ "$?" -ne 0 ]]; then
        exit 1
    fi
}
