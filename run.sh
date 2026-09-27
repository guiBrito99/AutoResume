#!/bin/bash

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT" || exit 1

# Color formatting
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

# Check which dependencies are missing
missing_deps() {
    local missing=()
    command -v jq &>/dev/null || missing+=("jq")
    command -v curl &>/dev/null || missing+=("curl")
    command -v java &>/dev/null || missing+=("java")
    command -v javac &>/dev/null || missing+=("javac")
    command -v opencode &>/dev/null || missing+=("opencode")
    [ -f "$PROJECT_ROOT/sqlite-manager-complete.jar" ] || missing+=("sqlite-manager-complete.jar")
    echo "${missing[@]}"
}

# Passive status line at launch
DEPS=$(missing_deps)
if [ -n "$DEPS" ]; then
    echo -e "Dependencies: ${YELLOW}not installed${NC} — use option 1 to install"
else
    echo -e "Dependencies: ${GREEN}ready${NC}"
fi

# Menu loop
while true; do
    echo -e "\n${CYAN}=== AutoResume ===${NC}"
    PS3="Select an option: "
    select OPTION in "Install dependencies" "Generate resume" "Exit"; do
        case $REPLY in
            1)
                bash "$PROJECT_ROOT/scripts/installDependencies.sh"
                break
                ;;
            2)
                DEPS=$(missing_deps)
                if [ -n "$DEPS" ]; then
                    echo -e "\n${RED}⚠️  Cannot generate a resume yet. Missing: $DEPS${NC}"
                    echo "    Run option 1 to install dependencies first."
                else
                    bash "$PROJECT_ROOT/scripts/generateResume.sh"
                fi
                break
                ;;
            3)
                exit 0
                ;;
            *)
                echo "Invalid option. Please try again."
                continue
                ;;
        esac
    done
done