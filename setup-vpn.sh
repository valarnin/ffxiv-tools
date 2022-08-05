#!/bin/bash

. helpers/error.sh
. helpers/prompt.sh
. helpers/vpn.sh
. setup-vpn-providers.sh

SCRIPT_DIR="$(dirname "$0")"

# FIXME: I lack the skills to update the VPN code to work with xlcore, so I am leaving things unchanged. -Arkevorkhat

echo "This script will configure a VPN for use with FFXIV."
echo

echo "Checking prerequisites..."

HAS_OPENVPN="$(which openvpn 2> /dev/null)"

if [[ "$HAS_OPENVPN" == "" ]]; then
    warn "You do not have the OpenVPN client installed."
else
    success "OpenVPN client fould at $HAS_OPENVPN."
fi

if [ ! -e /proc/self/ns/net ]; then
    error "Network namespace support not detected."
    error "Please install a kernel with network namespace support (CONFIG_NET_NS) and try again."
else
    success "Network namespace kernel support detected"
fi

HAS_TUNTAP="$(dmesg | grep -Poi "Universal TUN/TAP device driver, [0-9.]+")"

if [[ "$HAS_TUNTAP" == "" ]]; then
    error "TUN/TAP support not detected."
    error "Please install a kernel with TUN/TAP support (CONFIG_TUN) and try again."
else
    success "Found TUN/TAP driver \"$HAS_TUNTAP\""
fi

warn "Currently can't detect if Virtual Ethernet Device support is enabled.
If you know a way to detect veth support without the kernel config,
please let me know."

if [ ! -e /proc/net/ip_tables_names ]; then
    error "iptables support not detected."
    error "Please install a kernel with iptables support (CONFIG_IP_NF_IPTABLES) and try again."
else
    success "iptables support detected"
fi

HAS_SYSTEMD=""
HAS_SYSTEMCTL="$(which systemctl)"

echo
echo

success "$SUCCESSES successful checks"
warn "$WARNINGS warnings"
error "$ERRORS errors"

echo

if [ $ERRORS -gt 0 ]; then
    success "No errors detected. Proceeding with configuration"
else
    warn "Errors detected. Please correct the errors above and try again."
    exit 1
fi

echo
echo

PROMPT_IN_ARRAY "VPN_NAMES" "VPN_SELECTION" "VPN provider? " "Please select a VPN provider from the list below" 

echo "$VPN_SELECTION"

eval "${VPN_CONFIGS[VPN_SELECTION]}"