#!/bin/bash

SCRIPTDIR="$(dirname $0)"

cd "$SCRIPTDIR"

# Call setup-stage1.sh to set up the environment
./setup-stage1.sh

if [[ "$?" == "1" ]]; then
    echo "Stage 1 setup (FFXIV Environment scripts) failed. Aborting setup."
    exit 1
fi

# Call setup-stage2.sh to configure setcaps and such
./setup-stage2.sh