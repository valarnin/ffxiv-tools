#!/bin/bash

SCRIPTDIR="$(dirname $0)"

cd "$SCRIPTDIR"

# Call setup-stage1.sh to set up the environment
./setup-stage1.sh

# Call setup-stage2.sh to configure setcaps and such
./setup-stage2.sh