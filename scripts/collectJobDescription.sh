#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT" || exit 1

# Job title (passed as $1 by generateResume.sh, or prompted for when run standalone)
JOB_TITLE="${1:-}"

if [ -z "$JOB_TITLE" ]; then
    read -p "Enter the job title (this will be used as the folder name): " JOB_TITLE
fi

if [ -z "$JOB_TITLE" ]; then
    echo "❌ Job title cannot be empty."
    exit 1
fi

# Clean up the folder name by replacing spaces with underscores
DIR_NAME=$(echo "$JOB_TITLE" | tr ' ' '_')
mkdir -p "$DIR_NAME"
echo -e "\nFolder ready: $DIR_NAME\n"

# Collect the job description
if [ -f "$DIR_NAME/jobDescription.txt" ]; then
    echo "✅ Found existing jobDescription.txt in '$DIR_NAME'. Skipping manual entry..."
else
    echo "Please paste the Job Description below."
    echo "(When you are finished pasting, press Ctrl+D on a new empty line to save):"
    cat > "$DIR_NAME/jobDescription.txt"
    echo -e "\nSaved to $DIR_NAME/jobDescription.txt"
fi

if [ ! -s "$DIR_NAME/jobDescription.txt" ]; then
    echo "❌ Error: jobDescription.txt is empty. Cannot match against a target job without a job description."
    exit 1
fi
