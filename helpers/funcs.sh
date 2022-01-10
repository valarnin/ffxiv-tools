#!/bin/bash

GET_NEWEST_PID() {
    if [ "$#" -ne 2 ]; then
        echo "Must provide exactly two parameters (output variable name, and the regex pattern)."
        return 1
    fi

    # Search for the most recently started PID whose command matches the regex pattern.
    # NOTE: This pattern automatically skips the leading PID number and clamps the search
    # pattern towards the "cmd" portion of the PS output. The user only has to provide
    # the process cmd pattern they want to search for.
    eval "$1"="$(ps ax -o pid,cmd --sort=+start_time | grep -P "^\\s*\\d+\\s+$2" | grep -Pv '^\s*\d+\s+grep\b' | tail -n 1 | sed 's/^[[:space:]]*//' | cut -d' ' -f1)"

    # Return status code 1 if nothing found, else 0.
    if [ -z "${!1}" ]; then
        return 1
    fi
    return 0
}

