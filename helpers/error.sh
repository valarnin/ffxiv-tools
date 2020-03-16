#!/bin/bash

# Deliberately put these before the include check to reset counters
ERRORS=0
WARNINGS=0
SUCCESSES=0

if [[ "$HELPERS_ERROR" == "Y" ]]; then
  return;
fi

HELPERS_ERROR="Y"

error() {
    ((++ERRORS))
    echo -e "\e[31m$1\e[0m"
}

warn() {
    ((++WARNINGS))
    echo -e "\e[33m$1\e[0m"
}

success() {
    ((++SUCCESSES))
    echo -e "\e[32m$1\e[0m"
}
