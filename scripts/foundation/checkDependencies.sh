#!/bin/bash

# Single job: report which pipeline dependencies are missing.
# Prints every missing item to stdout, then exits 1 if the list is non-empty.
# Read-only: never installs, never prompts, never mutates anything.

source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"

missing=()

for cmd in jq curl java opencode; do
    if ! command -v "$cmd" &>/dev/null; then
        missing+=("$cmd")
    fi
done

if [ ! -f "$PROJECT_ROOT/sqlite-manager-complete.jar" ]; then
    missing+=("sqlite-manager-complete.jar")
fi

if [ ${#missing[@]} -gt 0 ]; then
    printf '%s\n' "${missing[@]}"
    exit 1
fi

exit 0
