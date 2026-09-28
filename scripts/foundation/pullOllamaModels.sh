#!/bin/bash

# Single job: pull the Ollama models declared in opencode.json.
# Reads the provider's models map and pulls each one. No-op when Ollama is not
# installed or opencode.json declares no Ollama models.

source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"
cd "$PROJECT_ROOT" || exit 1

if ! command -v ollama &> /dev/null; then
    echo "⏭️ Ollama is not installed; nothing to pull."
    exit 0
fi

need_cmd jq
need_cmd ollama

MAP_FILE="$PROJECT_ROOT/opencode.json"
if [ ! -f "$MAP_FILE" ]; then
    echo "⏭️ No opencode.json found; nothing to pull."
    exit 0
fi

# `|| true` so a missing/!invalid Ollama block skips instead of aborting.
MODELS=$(jq -r '.provider.ollama.models | keys[]' "$MAP_FILE" 2>/dev/null || true)

if [ -z "$MODELS" ]; then
    echo "⏭️ No Ollama models declared in opencode.json."
    exit 0
fi

echo "Pulling models declared in opencode.json:"
for m in $MODELS; do
    echo "  ollama pull $m"
    ollama pull "$m"
done
