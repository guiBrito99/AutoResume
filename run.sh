#!/bin/bash

# Wrapper: the menu entry point.
#
# Sits at the project root (rather than in scripts/wrapper/) so ./run.sh is the
# obvious way in. Calls the foundation scripts; holds no domain logic itself.

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT" || exit 1

SCRIPTS_DIR="$PROJECT_ROOT/scripts"
FOUNDATION="$SCRIPTS_DIR/foundation"
WRAPPER="$SCRIPTS_DIR/wrapper"

# Color formatting
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

# Passive dependency status line, delegated to the foundation script.
DEPS=$(bash "$FOUNDATION/checkDependencies.sh" || true)
if [ -n "$DEPS" ]; then
    echo -e "Dependencies: ${YELLOW}not installed${NC} — use option 1 ($DEPS)"
else
    echo -e "Dependencies: ${GREEN}ready${NC}"
fi

while true; do
    echo -e "\n${CYAN}=== AutoResume ===${NC}"
    PS3="Select an option: "
    select OPTION in "Install dependencies" "Generate resume" "Exit"; do
        case $REPLY in
            1)
                # Installing is always explicit, and is the only place the
                # installer trio is chained together.
                bash "$FOUNDATION/installDependencies.sh" &&
                    bash "$FOUNDATION/buildSqliteManager.sh" &&
                    bash "$FOUNDATION/pullOllamaModels.sh" &&
                    bash "$FOUNDATION/checkDependencies.sh" &&
                    echo -e "\n${GREEN}✅ Dependencies ready.${NC}"
                break
                ;;
            2)
                DEPS=$(bash "$FOUNDATION/checkDependencies.sh" || true)
                if [ -n "$DEPS" ]; then
                    echo -e "\n${RED}⚠️  Cannot generate a resume yet. Missing: $DEPS${NC}"
                    echo "    Run option 1 to install dependencies first."
                else
                    bash "$WRAPPER/generateResume.sh"
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
