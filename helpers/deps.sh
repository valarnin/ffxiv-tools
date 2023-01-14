#!/bin/bash

CHECK_DEP_32() {
    DEP="$1"
    CHECK="$(ldconfig -p | grep -v ',x86-64)' | grep -P "$DEP$" | wc -l)"
    if [[ "$CHECK" -gt 0 ]]; then
        return 0;
    else
        return 1;
    fi
}

CHECK_DEP_64() {
    DEP="$1"
    CHECK="$(ldconfig -p | grep 'x86-64' | grep -P "$DEP$" | wc -l)"
    if [[ "$CHECK" -gt 0 ]]; then
        return 0;
    else
        return 1;
    fi
}

CHECK_TOOL() {
    DEP="$1"
    CHECK="$(command -v "$DEP" 2>/dev/null)"
    if [[ "$CHECK" == "" ]]; then
        return 1;
    else
        return 0;
    fi
}
