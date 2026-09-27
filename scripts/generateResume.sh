#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT" || exit 1

# 0. Verify dependencies (install is an explicit menu action)
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

DEPS=$(missing_deps)
if [ -n "$DEPS" ]; then
    echo "❌ Missing dependencies: $DEPS"
    echo "   Run 'bash $PROJECT_ROOT/scripts/installDependencies.sh' to install them."
    exit 1
fi

# 1. Ask for the job title
read -p "Enter the job title (this will be used as the folder name): " JOB_TITLE

if [ -z "$JOB_TITLE" ]; then
    echo "❌ Job title cannot be empty."
    exit 1
fi

DIR_NAME=$(echo "$JOB_TITLE" | tr ' ' '_')
mkdir -p "$DIR_NAME"
echo -e "\nFolder ready: $DIR_NAME\n"

# 2. Collect the job description
echo "Collecting the job description..."
if ! bash "$SCRIPT_DIR/collectJobDescription.sh" "$JOB_TITLE"; then
    echo "❌ Could not collect the job description. Aborting."
    exit 1
fi
echo ""

# 3. Match the job description against the personal data
echo "Finding matches between the job description and your data..."
if ! bash "$SCRIPT_DIR/infoMatcher.sh" "$JOB_TITLE"; then
    echo "❌ infoMatcher.sh failed. Aborting before the HTML build."
    exit 1
fi
echo ""

# 4. Build the HTML resume from the matches
echo "Building HTML resume with JavaResumeBuilder..."
if ! java --enable-native-access=ALL-UNNAMED "$SCRIPT_DIR/JavaResumeBuilder.java" "$DIR_NAME/matches.txt" "$DIR_NAME/resume.html"; then
    echo "❌ JavaResumeBuilder failed. See the errors above."
    exit 1
fi

echo -e "\n✅ Success!"
echo "   Match report: $DIR_NAME/matches.txt"
echo "   HTML resume:  $DIR_NAME/resume.html"
