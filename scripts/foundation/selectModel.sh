#!/bin/bash

# Single job: resolve which opencode model to use and print "provider<TAB>model".
#
# Accepts an optional override as $1, either "provider/model" or a bare model
# id (provider defaults to "opencode"). When an override is given it is validated
# against `opencode models` and echoed back without prompting. With no override
# it lists the available models and prompts. The menu and prompt go to stderr
# (select/read do this natively) so stdout carries only the resolved value.

source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"

need_cmd opencode

# `|| true` so an unavailable opencode CLI falls through to the empty-list check
# below rather than aborting before we can print a useful message.
AVAILABLE_MODELS=$(opencode models 2>/dev/null || true)

resolve_from_list() {
    local raw="$1"
    local provider model

    if [[ "$raw" == */* ]]; then
        provider="${raw%%/*}"
        model="${raw#*/}"
    else
        provider="opencode"
        model="$raw"
    fi

    if [ -z "$provider" ] || [ -z "$model" ]; then
        return 1
    fi
    if ! printf '%s\n' "$AVAILABLE_MODELS" | grep -qxF "$provider/$model"; then
        return 1
    fi

    printf '%s\t%s' "$provider" "$model"
}

if [ -n "${1:-}" ]; then
    if RESULT=$(resolve_from_list "$1"); then
        printf '%s' "$RESULT"
        exit 0
    fi
    echo "❌ '$1' is not an available model. Run 'opencode models' to see the list." >&2
    exit 1
fi

if [ -z "$AVAILABLE_MODELS" ]; then
    echo "❌ No models available through opencode." >&2
    echo "   Log in with 'opencode auth login' or add a provider to opencode.json." >&2
    exit 1
fi

echo "Available models:" >&2
# PS3 must be set on its own line: `select` is a reserved word, so a leading
# assignment would be a syntax error.
PS3="Enter the number of the model you want to use: "
select SELECTED in $AVAILABLE_MODELS; do
    if [ -n "$SELECTED" ]; then
        printf '%s' "$(resolve_from_list "$SELECTED")"
        exit 0
    fi
    echo "❌ Invalid selection. Please try again." >&2
done
