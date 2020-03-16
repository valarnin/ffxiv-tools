#!/bin/bash

# Helpers for finding unused subnet for netns

GET_IP_RANGE() {
    IFS=/ read IP_ADDRESS IP_MASK <<< "$1"
    IFS=. read -a IP_OCTETS <<< "$IP_ADDRESS"
    MIN_IP=$((${IP_OCTETS[0]}*256*256*256 + ${IP_OCTETS[1]}*256*256 + ${IP_OCTETS[2]}*256 + ${IP_OCTETS[3]}))
    MIN_IP="$(($MIN_IP & "2#$(seq "$IP_MASK" | xargs -n1 -I{} echo -n "1")$(seq "$((32-$IP_MASK))" | xargs -n1 -I{} echo -n "0")"))"
    MAX_IP=$(($MIN_IP + (2**(32-$IP_MASK))-1))
    echo "$MIN_IP $MAX_IP"
}

# IP1_MIN IP1_MAX IP2_MIN IP2_MAX
IP_RANGES_OVERLAP() {
    if [ "$2" -lt "$3" ] || [ "$4" -lt "$1" ]; then
        echo "0"
    else
        echo "1"
    fi
}

IP_TO_OCTETS() {
    echo "$(($1>>24)).$((($1&(256*256*255))>>16)).$((($1&(256*255))>>8)).$(($1&255))"
}

FIND_UNUSED_SUBNET() {
    IFS=$'\n' read -a IP_RANGES <<< "$(ip addr | grep -Po 'inet \d+\.\d+\.\d+\.\d+/\d+' | sed -e 's/inet //g')"
    declare -a IP_RANGES_MIN
    declare -a IP_RANGES_MAX
    IP_RANGES_COUNT="${#IP_RANGES[*]}"
    for ((i=0;i<IP_RANGES_COUNT;++i)); do
        IFS=" " read IP_RANGE_MIN IP_RANGE_MAX <<< "$(GET_IP_RANGE ${IP_RANGES[i]})"
        IP_RANGES_MIN[i]=$IP_RANGE_MIN
        IP_RANGES_MAX[i]=$IP_RANGE_MAX
    done

    # Start at 14 as an easter egg :)
    for i1 in {14..255}; do
        for i2 in {14..255}; do
            IP_TO_CHECK="10.${i1}.${i2}."
            IFS=" " read IP_RANGE_MIN IP_RANGE_MAX <<< "$(GET_IP_RANGE "${IP_TO_CHECK}0/24")"
            OVERLAP="0"
            for ((i=0;i<IP_RANGES_COUNT;++i)); do
                OVERLAP_CHECK="$(IP_RANGES_OVERLAP $IP_RANGE_MIN $IP_RANGE_MAX ${IP_RANGES_MIN[i]} ${IP_RANGES_MAX[i]})"
                if [[ "$OVERLAP_CHECK" == "1" ]]; then
                    OVERLAP="1"
                fi
            done
            if [[ "$OVERLAP" == "0" ]]; then
                echo "$IP_TO_CHECK"
                return
            fi
        done
    done
    echo "1"
}