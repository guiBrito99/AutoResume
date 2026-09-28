#!/bin/bash

# Single job: install the external tools the pipeline needs.
# Installs jq, curl, a JDK, and opencode via the distro package manager or a
# curl installer, and optionally offers Ollama. Building the SQLite jar is
# buildSqliteManager.sh's job; pulling models is pullOllamaModels.sh's job.

source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"
cd "$PROJECT_ROOT" || exit 1

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
    if [ -n "$docs" ]; then
        echo "  $docs"
    fi
    return 1
}

resolve "jq" "jq"
resolve "curl" "curl"
resolve "java" "default-jdk"
resolve "opencode" "" "https://opencode.ai/install" "https://opencode.ai/docs/"

# Ollama is optional: only a cloud user can skip it.
if command -v ollama &> /dev/null; then
    echo "✅ ollama is already installed."
else
    INSTALL_OLLAMA="n"
    if [ -t 0 ]; then
        read -r -p "Install Ollama for local models? (y/N): " INSTALL_OLLAMA || true
    fi
    case "$INSTALL_OLLAMA" in
        y | Y)
            resolve "ollama" "" "https://ollama.com/install.sh" "https://ollama.com/download"
            ;;
        *)
            echo "⏭️ Skipping Ollama (you can use a cloud provider via 'opencode auth login' instead)."
            ;;
    esac
fi

echo ""
echo "=== Tool installation complete ==="
echo "Next: build the SQLite jar (buildSqliteManager.sh) and pull local models (pullOllamaModels.sh)."
echo "Run ./run.sh option 1 to do all of it in one go."
