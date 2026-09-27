#!/bin/bash

echo -e "Resolving dependencies for AutoResume...\n"

resolve() {
    local cmd="$1" pkg="${2:-}" curl_url="${3:-}" docs="${4:-}"

    if command -v "$cmd" &> /dev/null; then
        echo "✅ $cmd is already installed."
        return 0
    fi

    echo "❌ $cmd is not installed. Attempting to install..."

    if [ -n "$pkg" ]; then
        if command -v apt-get &> /dev/null && sudo apt-get update && sudo apt-get install -y "$pkg"; then
            echo "✅ $cmd installed via apt."
            return 0
        fi
        if command -v dnf &> /dev/null && sudo dnf install -y "$pkg"; then
            echo "✅ $cmd installed via dnf."
            return 0
        fi
        if command -v pacman &> /dev/null && sudo pacman -S --noconfirm "$pkg"; then
            echo "✅ $cmd installed via pacman."
            return 0
        fi
        if command -v brew &> /dev/null && brew install "$pkg"; then
            echo "✅ $cmd installed via brew."
            return 0
        fi
    fi

    if [ -n "$curl_url" ]; then
        echo "Installing $cmd via curl installer..."
        if curl -fsSL "$curl_url" | bash; then
            echo "✅ $cmd installed via curl."
            return 0
        fi
    fi

    echo "❌ Failed to install $cmd. Please install it manually:"
    [ -n "$docs" ] && echo "  $docs"
    return 1
}

resolve "jq" "jq"
resolve "curl" "curl"
resolve "java" "default-jdk"
resolve "javac" "default-jdk"
resolve "opencode" "" "https://opencode.ai/install" "https://opencode.ai/docs/"

INSTALL_OLLAMA="n"
if ! command -v ollama &> /dev/null; then
    if [ -t 0 ]; then
        read -r -p "Install Ollama for local models? (y/N): " INSTALL_OLLAMA
    fi
    case "$INSTALL_OLLAMA" in
        y | Y)
            resolve "ollama" "" "https://ollama.com/install.sh" "https://ollama.com/download"
            ;;
        *)
            echo "⏭️ Skipping Ollama (you can use a cloud provider via 'opencode auth login' instead)."
            ;;
    esac
else
    echo "✅ ollama is already installed."
fi

echo ""
echo "=== Dependency check complete ==="

if ! command -v jq &> /dev/null || ! command -v curl &> /dev/null || \
   ! command -v java &> /dev/null || ! command -v javac &> /dev/null || \
   ! command -v opencode &> /dev/null; then
    echo "❌ Some required dependencies are still missing. Fix the errors above and re-run."
    exit 1
fi

if command -v ollama &> /dev/null; then
    MAP_FILE="opencode.json"
    if [ -f "$MAP_FILE" ]; then
        MODELS=$(jq -r '.provider.ollama.models | keys[]' "$MAP_FILE" 2>/dev/null)
        if [ -n "$MODELS" ]; then
            echo "Pulling models declared in $MAP_FILE:"
            for m in $MODELS; do
                echo "  ollama pull $m"
                ollama pull "$m"
            done
        fi
    fi
fi

echo ""
echo "✅ All dependencies resolved. Verify with:"
echo "  opencode models"
echo "If no models appear, run 'opencode auth login' to add a provider or start Ollama and pull the models above."