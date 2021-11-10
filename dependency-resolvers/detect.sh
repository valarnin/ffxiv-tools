#!/bin/bash

# Default resolver, distro-specific solutions should override this
RESOLVE_DEPS() {
    echo
    error "No dependency resolver was found for your distro."
    error "Please install the libraries and/or tools listed above as missing before continuing."
    echo
    exit 1
}

if [[ -e "/etc/gentoo-release" ]]; then
    . "$(dirname "${BASH_SOURCE[0]}")/gentoo.sh"
    return
fi

if [[ -e "/etc/arch-release" ]]; then
    . "$(dirname "${BASH_SOURCE[0]}")/arch.sh"
    return
fi
