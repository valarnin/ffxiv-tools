#!/bin/bash

. helpers/prompt.sh
. helpers/error.sh
. helpers/deps.sh

HARD_DEPS_32=( libpng12.so.0 )
HARD_DEPS_64=( libpng12.so.0 )

SOFT_DEPS_32=( libgcrypt.so )
SOFT_DEPS_64=( libgcrypt.so )

HARD_TOOLS=( unzip patchelf )
SOFT_TOOLS=( winetricks )

MISSING_HARD_32=(  )
MISSING_HARD_64=(  )
MISSING_SOFT_32=(  )
MISSING_SOFT_64=(  )

MISSING_HARD_TOOLS=(  )
MISSING_SOFT_TOOLS=(  )

echo "Checking for dependencies..."

echo "Checking required 32-bit dependencies..."

for DEP in "${HARD_DEPS_32[@]}"; do
    CHECK_DEP_32 "$DEP"
    if [[ "$?" -eq 0 ]]; then
        success "Found dependency $DEP..."
    else
        error "Missing dependency $DEP..."
        MISSING_HARD_32+=("$DEP")
    fi
done

echo "Checking required 64-bit dependencies..."

for DEP in "${HARD_DEPS_64[@]}"; do
    CHECK_DEP_64 "$DEP"
    if [[ "$?" -eq 0 ]]; then
        success "Found dependency $DEP..."
    else
        error "Missing dependency $DEP..."
        MISSING_HARD_64+=("$DEP")
    fi
done

echo "Checking recommended 32-bit dependencies..."

for DEP in "${SOFT_DEPS_32[@]}"; do
    CHECK_DEP_32 "$DEP"
    if [[ "$?" -eq 0 ]]; then
        success "Found dependency $DEP..."
    else
        error "Missing dependency $DEP..."
        MISSING_SOFT_32+=("$DEP")
    fi
done

echo "Checking recommended 64-bit dependencies..."

for DEP in "${SOFT_DEPS_64[@]}"; do
    CHECK_DEP_64 "$DEP"
    if [[ "$?" -eq 0 ]]; then
        success "Found dependency $DEP..."
    else
        error "Missing dependency $DEP..."
        MISSING_SOFT_64+=("$DEP")
    fi
done

echo "Checking for required tools..."

for DEP in "${HARD_TOOLS[@]}"; do
    CHECK_TOOL "$DEP"
    if [[ "$?" -eq 0 ]]; then
        success "Found tool $DEP..."
    else
        error "Missing tool $DEP..."
        MISSING_HARD_TOOLS+=("$DEP")
    fi
done

echo "Checking for optional tools..."

for DEP in "${SOFT_TOOLS[@]}"; do
    CHECK_TOOL "$DEP"
    if [[ "$?" -eq 0 ]]; then
        success "Found tool $DEP..."
    else
        error "Missing tool $DEP..."
        MISSING_SOFT_TOOLS+=("$DEP")
    fi
done

echo
echo

if [[ $ERRORS -gt 0 ]] || [[ $WARNINGS -gt 0 ]]; then
    . dependency-resolvers/detect.sh
    RESOLVE_DEPS
else
    success "All required and recommended dependencies and tools found."
fi
