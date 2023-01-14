#!/bin/bash

. helpers/error.sh
. helpers/prompt.sh
. helpers/vpn.sh

# Determine where the user wants to install the tools
. config/ffxiv-tools-location.sh

SCRIPT_HELPER_DEST="$HOME/$FFXIV_TOOLS_LOCATION/ffxiv-vpn-helper.sh"
SCRIPT_HELPER_CONFIG_DEST="$HOME/$FFXIV_TOOLS_LOCATION/ffxiv-vpn-helper-config.sh"
SCRIPT_RUN_ACT_DEST="$HOME/$FFXIV_TOOLS_LOCATION/ffxiv-vpn-run-act.sh"
SCRIPT_RUN_GAME_DEST="$HOME/$FFXIV_TOOLS_LOCATION/ffxiv-vpn-run-game.sh"
SCRIPT_RUN_BOTH_DEST="$HOME/$FFXIV_TOOLS_LOCATION/ffxiv-vpn-run-both.sh"
SCRIPT_RUN_OTHER_DEST="$HOME/$FFXIV_TOOLS_LOCATION/ffxiv-vpn-run-other.sh"
SCRIPT_RESET_VPN_DEST="$HOME/$FFXIV_TOOLS_LOCATION/ffxiv-vpn-reset-vpn.sh"

echo "This script will set up the required helper scripts but you will need to customize them to match your VPN setup."
echo "Please edit $SCRIPT_HELPER_DEST after the install is finished"
echo "and customize the RUN_VPN and CLOSE_VPN commands to actually take the actions required to connect"
echo "to your VPN setup."
echo

echo "Checking active local IP ranges to determine an unused range for the network namespace..."

IP_SUBNET="$(FIND_UNUSED_SUBNET)"

if [[ "$IP_SUBNET" == "1" ]]; then
    error "Could not find an unused subnet (somehow). Aborting install"
fi

OIFS="$IFS"
IFS=$'\n'
NETWORK_INTERFACES=( $(ip link | grep -Po '^\d+: [^:]+' | cut -d' ' -f2-) )
IFS="$OIFS"

PROMPT_IN_ARRAY "NETWORK_INTERFACES" "NETWORK_INTERFACES_ANSWER" "Network Interface? "\
 "Which network interface do you use to connect to the internet?
You can manually change this later by modifying $SCRIPT_HELPER_CONFIG_DEST"

IP_ADDR="$(ip addr show "${NETWORK_INTERFACES[NETWORK_INTERFACES_ANSWER]}" | grep -Po 'inet \d+\.\d+\.\d+\.\d+/\d+' | sed -e 's/inet //g')"

IP_ADDR_START="$(IP_TO_OCTETS "$(echo "$(GET_IP_RANGE "$IP_ADDR")" | cut -d' ' -f1)")"
IP_ADDR_MASK="$(ifconfig ${NETWORK_INTERFACES[NETWORK_INTERFACES_ANSWER]} | grep -Po 'netmask \d+\.\d+\.\d+\.\d+' | cut -d' ' -f2)"

SCRIPT_HELPER_CONFIG=$(cat << EOF
#!/bin/bash

TARGET_USER="$USER"
FFXIV_VPN_NAMESPACE="ffxiv"
FFXIV_VPN_SUBNET="$IP_SUBNET"
TARGET_INTERFACE="${NETWORK_INTERFACES[NETWORK_INTERFACES_ANSWER]}"

EOF
)

SCRIPT_HELPER=$(cat << EOF
#!/bin/bash

if [[ "\$(id -u)" != "0" ]]; then
    echo "This script must be run via sudo"
    exit 1
fi

. "$SCRIPT_HELPER_CONFIG_DEST"

RUN_NETWORK_NAMESPACE() {
    # Enable IPv4 traffic forwarding
    sysctl -q net.ipv4.ip_forward=1
    # Create the network namespace folder used for resolving IPs
    mkdir -p "/etc/netns/\${FFXIV_VPN_NAMESPACE}"
    # Set up DNS resolution to work through VPN by hardcoding to public DNS servers
    echo -e "nameserver 1.1.1.1\\nnameserver 1.0.0.1\\nnameserver 8.8.8.8\\nnameserver 8.8.4.4" > "/etc/netns/\${FFXIV_VPN_NAMESPACE}/resolv.conf"
    # Create network namespace
    ip netns add "\${FFXIV_VPN_NAMESPACE}"
    # Create Virtual Ethernet (VETH) pair, start them up
    ip link add "veth_a_\${FFXIV_VPN_NAMESPACE}" type veth peer name "veth_b_\${FFXIV_VPN_NAMESPACE}"
    ip link set "veth_a_\${FFXIV_VPN_NAMESPACE}" up
    # Create TAP adapter and bridge, bridge TAP with VETH A
    ip tuntap add "tap_\${FFXIV_VPN_NAMESPACE}" mode tap user root
    ip link set "tap_\${FFXIV_VPN_NAMESPACE}" up
    ip link add "br_\${FFXIV_VPN_NAMESPACE}" type bridge
    ip link set "tap_\${FFXIV_VPN_NAMESPACE}" master "br_\${FFXIV_VPN_NAMESPACE}"
    ip link set "veth_a_\${FFXIV_VPN_NAMESPACE}" master "br_\${FFXIV_VPN_NAMESPACE}"
    # Give bridge an IP address, start it up
    ip addr add "\${FFXIV_VPN_SUBNET}1/24" dev "br_\${FFXIV_VPN_NAMESPACE}"
    ip link set "br_\${FFXIV_VPN_NAMESPACE}" up
    # Assign VETH B to exist in network namespace, give it an IP address, start it up
    ip link set "veth_b_\${FFXIV_VPN_NAMESPACE}" netns "\${FFXIV_VPN_NAMESPACE}"
    ip netns exec "\${FFXIV_VPN_NAMESPACE}" ip addr add "\${FFXIV_VPN_SUBNET}2/24" dev "veth_b_\${FFXIV_VPN_NAMESPACE}"
    ip netns exec "\${FFXIV_VPN_NAMESPACE}" ip link set "veth_b_\${FFXIV_VPN_NAMESPACE}" up
    # Create a loopback interface in network namespace, start it up
    ip netns exec "\${FFXIV_VPN_NAMESPACE}" ip link set dev lo up
    # Set up NAT forwarding of traffic so that bridged network can communicate with internet
    iptables -t nat -A POSTROUTING -s "\${FFXIV_VPN_SUBNET}0/24" -o en+ -j MASQUERADE
    # Add default route to network namespace or else traffic won't route properly
    ip netns exec "\${FFXIV_VPN_NAMESPACE}" ip route add default via "\${FFXIV_VPN_SUBNET}1"
}

CLOSE_NETWORK_NAMESPACE() {
    # A bit overkill, deleting the network namespace should cascade delete the rest of these interfaces
    # But just in case something went wrong during the creation process
    ip netns delete "\${FFXIV_VPN_NAMESPACE}" &> /dev/null
    ip link delete "veth_a_\${FFXIV_VPN_NAMESPACE}" &> /dev/null
    ip link delete "veth_b_\${FFXIV_VPN_NAMESPACE}" &> /dev/null
    ip link delete "tap_\${FFXIV_VPN_NAMESPACE}" &> /dev/null
    ip link delete "br_\${FFXIV_VPN_NAMESPACE}" &> /dev/null
    # Clean up the DNS resolver for the network namespace
    rm -rf "/etc/netns/\${FFXIV_VPN_NAMESPACE}"
    # Drop the iptables rule for traffic forwarding to the network namespace
    iptables -t nat -D POSTROUTING -s "\${FFXIV_VPN_SUBNET}0/24" -o en+ -j MASQUERADE
}

RUN_VPN() {
    # Run the vpn command within the target network namespace as the target user
    ip netns exec "\${FFXIV_VPN_NAMESPACE}" FIXME
}

CLOSE_VPN() {
    FIXME
}

RUN_COMMAND() {
    ip netns exec "\${FFXIV_VPN_NAMESPACE}" sudo -u "\$TARGET_USER" "\$@"
}

EOF
)

SCRIPT_RUN_COMMON_PRE=$(cat << EOF
#!/bin/bash

. "$SCRIPT_HELPER_DEST"

RUN_NETWORK_NAMESPACE
RUN_VPN
EOF
)

SCRIPT_RUN_COMMON_POST=$(cat << EOF
CLOSE_VPN
CLOSE_NETWORK_NAMESPACE

EOF
)

SCRIPT_RESET_VPN=$(cat << EOF
#!/bin/bash

. "$SCRIPT_HELPER_DEST"

CLOSE_VPN
CLOSE_NETWORK_NAMESPACE

EOF
)

SCRIPT_RUN_ACT=$(cat << EOF
$SCRIPT_RUN_COMMON_PRE

RUN_COMMAND "\$(command -v bash)" "$HOME/$FFXIV_TOOLS_LOCATION/ffxiv-run-act.sh"

$SCRIPT_RUN_COMMON_POST
EOF
)

SCRIPT_RUN_GAME=$(cat << EOF
$SCRIPT_RUN_COMMON_PRE

RUN_COMMAND "\$(command -v bash)" "$HOME/$FFXIV_TOOLS_LOCATION/ffxiv-run-game.sh"

$SCRIPT_RUN_COMMON_POST
EOF
)

SCRIPT_RUN_BOTH=$(cat << EOF
$SCRIPT_RUN_COMMON_PRE

RUN_COMMAND "\$(command -v bash)" "$HOME/$FFXIV_TOOLS_LOCATION/ffxiv-run-both.sh"

$SCRIPT_RUN_COMMON_POST
EOF
)

SCRIPT_RUN_OTHER=$(cat << EOF
$SCRIPT_RUN_COMMON_PRE

RUN_COMMAND "\$@"

$SCRIPT_RUN_COMMON_POST
EOF
)

echo "Scripts built. Writing to $HOME/$FFXIV_TOOLS_LOCATION..."

echo "Writing $SCRIPT_HELPER_CONFIG_DEST"
echo "$SCRIPT_HELPER_CONFIG" > "$SCRIPT_HELPER_CONFIG_DEST"

echo "Writing $SCRIPT_HELPER_DEST"
echo "$SCRIPT_HELPER" > "$SCRIPT_HELPER_DEST"

echo "Writing $SCRIPT_RUN_ACT_DEST"
echo "$SCRIPT_RUN_ACT" > "$SCRIPT_RUN_ACT_DEST"
chmod +x "$SCRIPT_RUN_ACT_DEST"

echo "Writing $SCRIPT_RUN_GAME_DEST"
echo "$SCRIPT_RUN_GAME" > "$SCRIPT_RUN_GAME_DEST"
chmod +x "$SCRIPT_RUN_GAME_DEST"

echo "Writing $SCRIPT_RUN_BOTH_DEST"
echo "$SCRIPT_RUN_BOTH" > "$SCRIPT_RUN_BOTH_DEST"
chmod +x "$SCRIPT_RUN_BOTH_DEST"

echo "Writing $SCRIPT_RUN_OTHER_DEST"
echo "$SCRIPT_RUN_OTHER" > "$SCRIPT_RUN_OTHER_DEST"
chmod +x "$SCRIPT_RUN_OTHER_DEST"

echo "Writing $SCRIPT_RESET_VPN_DEST"
echo "$SCRIPT_RESET_VPN" > "$SCRIPT_RESET_VPN_DEST"
chmod +x "$SCRIPT_RESET_VPN_DEST"

echo "Scripts written. Run $HOME/$FFXIV_TOOLS_LOCATION/ffxiv-vpn-run-* to run within the VPN scope"
