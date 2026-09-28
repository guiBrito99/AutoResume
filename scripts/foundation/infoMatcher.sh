#!/bin/bash

# Single job: produce <job>/matches.txt — the JSON match report.
#
# Usage: infoMatcher.sh <job title> <providerID> <modelID>
#
# This script does not prompt, does not manage the opencode server, and does not
# collect input files. It assumes <job>/personalData.txt and
# <job>/jobDescription.txt already exist (see collectPersonalData.sh and
# collectJobDescription.sh) and that a server is reachable.

source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"
cd "$PROJECT_ROOT" || exit 1

need_cmd curl
need_cmd jq

if [ $# -lt 3 ]; then
    echo "Usage: infoMatcher.sh <job title> <providerID> <modelID>" >&2
    exit 1
fi

JOB_TITLE="$1"
PROVIDER_ID="$2"
MODEL_ID="$3"

if [ -z "$JOB_TITLE" ] || [ -z "$PROVIDER_ID" ] || [ -z "$MODEL_ID" ]; then
    echo "❌ job title, providerID and modelID are all required." >&2
    exit 1
fi

DIR_NAME=$(echo "$JOB_TITLE" | tr ' ' '_')

for f in personalData.txt jobDescription.txt; do
    if [ ! -s "$DIR_NAME/$f" ]; then
        echo "❌ $DIR_NAME/$f is missing or empty. Run the collect scripts first." >&2
        exit 1
    fi
done

OPENCODE_URL="${OPENCODE_URL:-http://localhost:4096}"

PERSONAL_DATA=$(cat "$DIR_NAME/personalData.txt")
JOB_DESC=$(cat "$DIR_NAME/jobDescription.txt")

USER_PROMPT="Your task is to compare the Job Description against the Personal Data and report only the matches.

Rules:
- Report MATCHES ONLY. Never list gaps, missing requirements, or anything the candidate lacks.
- Group the matches into exactly three categories, in this fixed order: experience, education, skills.
- Every category must be an array; use an empty array when there is no match for it.
- Each match is an object with:
  - \"requirement\": the exact requirement or keyword quoted from the Job Description.
  - \"evidence\": the concrete proof quoted from the Personal Data (a role, institution, or skill).
  - Do not invent, infer, or embellish. Only pairs with literal support in the Personal Data.
- Add a \"labels\" object with the category names (experience, education, skills) written in the same language as the Job Description.
- Add a \"profile\" object with the candidate's personal info from the Personal Data: full_name, target_role, email, phone, location, linkedin, github. Copy the values as-is.
- Write every value in the same language as the Job Description.
- Reply with RAW JSON ONLY. No code fences, no commentary, no markdown. The JSON must have this exact shape:

{
  \"profile\": {\"full_name\": \"...\", \"target_role\": \"...\", \"email\": \"...\", \"phone\": \"...\", \"location\": \"...\", \"linkedin\": \"...\", \"github\": \"...\"},
  \"labels\": {\"experience\": \"...\", \"education\": \"...\", \"skills\": \"...\"},
  \"experience\": [{ \"requirement\": \"...\", \"evidence\": \"...\" }],
  \"education\": [{ \"requirement\": \"...\", \"evidence\": \"...\" }],
  \"skills\": [{ \"requirement\": \"...\", \"evidence\": \"...\" }]
}

=== Personal Data ===
$PERSONAL_DATA

=== Job Description ===
$JOB_DESC"

TMP_SESSION=$(mktemp)
TMP_RESPONSE=$(mktemp)
cleanup() {
    rm -f "$TMP_SESSION" "$TMP_RESPONSE"
}
trap cleanup EXIT

# Create a session
SESSION_BODY=$(jq -n --arg title "$JOB_TITLE" '{title: $title}')
# `|| true` so a connection failure reaches the friendly HTTP-error branch
# instead of aborting on the non-zero exit.
SESSION_CODE=$(curl -s -o "$TMP_SESSION" -w '%{http_code}' -X POST "$OPENCODE_URL/session" \
    -H "Content-Type: application/json" \
    -d "$SESSION_BODY" || true)

if [ "$SESSION_CODE" != "200" ]; then
    echo "❌ Failed to create an opencode session (HTTP ${SESSION_CODE:-no response})." >&2
    echo "Body: $(jq -r '. // .error // empty' "$TMP_SESSION" 2>/dev/null | head -c 500 || true)" >&2
    echo "Ensure the opencode server is running at $OPENCODE_URL." >&2
    exit 1
fi

SESSION_ID=$(jq -r '.id // empty' "$TMP_SESSION")
if [ -z "$SESSION_ID" ]; then
    echo "❌ opencode did not return a session id." >&2
    echo "Body: $(head -c 500 "$TMP_SESSION")" >&2
    exit 1
fi

# tools: {} disables agent tool calls so the model returns the JSON as response
# text (this script writes matches.txt) instead of writing files on its own.
PAYLOAD=$(jq -n \
    --arg provider "$PROVIDER_ID" \
    --arg model "$MODEL_ID" \
    --arg txt "$USER_PROMPT" \
    '{model: {providerID: $provider, modelID: $model}, tools: {}, parts: [{type: "text", text: $txt}]}')

RESP_CODE=$(curl -s -o "$TMP_RESPONSE" -w '%{http_code}' -X POST "$OPENCODE_URL/session/$SESSION_ID/message" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD" || true)

if [ "$RESP_CODE" != "200" ]; then
    echo "❌ opencode returned HTTP ${RESP_CODE:-no response}." >&2
    echo "Body: $(head -c 500 "$TMP_RESPONSE")" >&2
    echo "Please check the model name or ensure the opencode server is running." >&2
    exit 1
fi

ERROR_MSG=$(jq -r '.error // empty' "$TMP_RESPONSE")
if [ -n "$ERROR_MSG" ]; then
    echo "❌ opencode returned an error: $ERROR_MSG" >&2
    exit 1
fi

MATCHES_TEXT=$(jq -r '[.parts[] | select(.type == "text") | .text] | join("")' "$TMP_RESPONSE")
if [ -z "$MATCHES_TEXT" ]; then
    echo "❌ opencode returned no text response." >&2
    exit 1
fi

# Strip a JSON code fence in case the model wrapped its reply despite instructions.
MATCHES_JSON=$(printf '%s' "$MATCHES_TEXT" | sed -e 's/^```json[[:space:]]*//' -e 's/^```[[:space:]]*//' -e 's/```[[:space:]]*$//')

if ! printf '%s' "$MATCHES_JSON" | jq -e '.profile and (.experience|type=="array") and (.education|type=="array") and (.skills|type=="array")' &> /dev/null; then
    echo "❌ opencode returned invalid JSON. Expected {profile, labels, experience, education, skills}." >&2
    echo "Raw response (first 800 chars):" >&2
    printf '%s' "$MATCHES_TEXT" | head -c 800 >&2
    echo "" >&2
    exit 1
fi

printf '%s\n' "$MATCHES_JSON" > "$DIR_NAME/matches.txt"
echo "✅ Match report saved at: $DIR_NAME/matches.txt"
