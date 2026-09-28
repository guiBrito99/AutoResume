#!/bin/bash

# Single job: obtain the job title and print it on stdout.
# Takes an optional override as $1; prompts only when absent. The prompt goes to
# stderr (via read -p) so a caller can capture stdout with $(...).

source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"

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

printf '%s' "$JOB_TITLE"
