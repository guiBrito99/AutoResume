#!/bin/bash

# Single job: ensure <job>/jobDescription.txt exists.
# Takes an optional job title as $1 and prompts only when absent. When the file
# already exists it is left alone, which is how the wrapper flow avoids a second
# paste prompt.

source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"
cd "$PROJECT_ROOT" || exit 1

JOB_TITLE="${1:-}"

if [ -z "$JOB_TITLE" ]; then
    # `|| true`: read returns non-zero at EOF, which set -e would treat as fatal
    # before the empty-value check below could report the error.
    read -p "Enter the job title (this will be used as the folder name): " JOB_TITLE || true
fi

if [ -z "$JOB_TITLE" ]; then
    echo "❌ Job title cannot be empty." >&2
    exit 1
fi

DIR_NAME=$(echo "$JOB_TITLE" | tr ' ' '_')
mkdir -p "$DIR_NAME"
echo -e "\nFolder ready: $DIR_NAME\n"

if [ -f "$DIR_NAME/jobDescription.txt" ]; then
    echo "✅ Found existing jobDescription.txt in '$DIR_NAME'. Skipping manual entry..."
else
    echo "Please paste the Job Description below."
    echo "(When you are finished pasting, press Ctrl+D on a new empty line to save):"
    cat > "$DIR_NAME/jobDescription.txt"
    echo -e "\nSaved to $DIR_NAME/jobDescription.txt"
fi

if [ ! -s "$DIR_NAME/jobDescription.txt" ]; then
    echo "❌ Error: jobDescription.txt is empty. Cannot generate a tailored resume without a target job." >&2
    exit 1
fi
