#!/bin/bash

# Supported VPN connections
VPN_NAMES=(
    "Private Internet Access"
    "Custom (download)"
    "Custom (local config file)"
    "Non-OpenVPN (requires manual configuration)"
)
VPN_CONFIGS=(
    "VPN_CONFIG_PIA"
    "VPN_CONFIG_CUSTOM_DOWNLOAD"
    "VPN_CONFIG_CUSTOM_LOCAL"
    "VPN_CONFIG_CUSTOM_OTHER"
)

VPN_COUNT="${#VPN_NAMES[*]}"

VPN_CONFIG_PIA() {
    echo "Downloading PIA VPN configuration file..."
    wget -O/tmp/pia_vpn.zip 'https://www.privateinternetaccess.com/openvpn/openvpn.zip' &> /dev/null

    OIFS="$IFS"
    IFS=$'\n'
    PIA_FILES=( $(zipinfo -1 /tmp/pia_vpn.zip | grep -P '.*\.ovpn') )
    IFS="$OIFS"
    PROMPT_IN_ARRAY "PIA_FILES" "PIA_SELECTION" "Configuration? " "Downloaded. Select a VPN configuration from the list below."

    unzip -p /tmp/pia_vpn.zip "${PIA_FILES[PIA_SELECTION]}" > /tmp/vpn_config.conf

    ./setup-vpn-openvpn.sh "/tmp/vpn_config.conf"
}

VPN_CONFIG_CUSTOM_DOWNLOAD() {
    echo "Enter the URL of the OpenVPN configuration file to download."
    echo "Only supports direct download of config files."
    echo "If you need to extract or something, use the local file option instead."
    read -p "Download URL? " DL_URL

    wget -O/tmp/vpn_config.conf "$DL_URL" &> /dev/null

    if [ ! -e "/tmp/vpn_config.conf" ]; then
        error "Failed to download config file"
        exit 1
    else
        success "Downloaded config file to /tmp/vpn_config.conf, proceeding with install"
        ./setup-vpn-openvpn.sh "/tmp/vpn_config.conf"
    fi
}

VPN_CONFIG_CUSTOM_LOCAL() {
    echo "Please enter the path to the local config file that you wish to use."
    read -p "Local file? " LOCAL_FILE

    LOCAL_FILE="$(readlink -f "$LOCAL_FILE")"

    if [ ! -e "$LOCAL_FILE" ]; then
        error "The file specified does not exist"
        exit 1
    else
        success "Found file at $LOCAL_FILE, proceeding with install"
        ./setup-vpn-openvpn.sh "$LOCAL_FILE"
    fi
}

VPN_CONFIG_CUSTOM_OTHER() {
    ./setup-vpn-other.sh
}