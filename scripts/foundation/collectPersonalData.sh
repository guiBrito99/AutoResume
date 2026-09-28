#!/bin/bash

# Single job: ensure <job>/personalData.txt exists.
# Order of preference: already in the job folder, then a master copy in the
# project root, then extracted from the SQLite database. Takes an optional job
# title as $1 and prompts only when absent.

source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"
cd "$PROJECT_ROOT" || exit 1

need_cmd java
need_jar "$PROJECT_ROOT/sqlite-manager-complete.jar"

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

if [ -f "$DIR_NAME/personalData.txt" ]; then
    echo "✅ Found existing personalData.txt in '$DIR_NAME'. Skipping extraction..."
elif [ -f "$PROJECT_ROOT/personalData.txt" ]; then
    echo "✅ Found master personalData.txt in project root. Copying to '$DIR_NAME'..."
    cp "$PROJECT_ROOT/personalData.txt" "$DIR_NAME/personalData.txt"
else
    echo "Extracting personal data from the database..."
    DB_OUTPUT=$(java --enable-native-access=ALL-UNNAMED -jar "$PROJECT_ROOT/sqlite-manager-complete.jar" print)

    if [[ "$DB_OUTPUT" == *"No table to print"* ]]; then
        echo "❌ Error: The database is empty (returned 'No table to print')."
        echo "   Please populate the database before generating a resume."
        exit 1
    fi

    echo "$DB_OUTPUT" > "$DIR_NAME/personalData.txt"
    echo "Saved to $DIR_NAME/personalData.txt"
fi

if [ ! -s "$DIR_NAME/personalData.txt" ]; then
    echo "❌ Error: personalData.txt is empty. Cannot generate a resume without career data." >&2
    exit 1
fi
