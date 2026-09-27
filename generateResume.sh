#!/bin/bash

# Configurable server location (override with env vars)
OPENCODE_URL="${OPENCODE_URL:-http://localhost:4096}"
OPENCODE_PORT="${OPENCODE_PORT:-4096}"
OPENCODE_START_TIMEOUT="${OPENCODE_START_TIMEOUT:-60}"
SERVER_STARTED=0

cleanup() {
    if [ "$SERVER_STARTED" -eq 1 ] && [ -n "${SERVER_PID:-}" ]; then
        kill "$SERVER_PID" 2>/dev/null
    fi
    rm -f "${TMP_RESPONSE:-}" "${TMP_SESSION:-}"
}
trap cleanup EXIT

# 0. Resolve dependencies
echo -e "Checking and installing dependencies...\n"

bash installDependencies.sh || exit 1

echo -e "\nAll dependencies are satisfied. Proceeding...\n"

# 1. Ensure an opencode server is reachable (start one if needed)
health_check() {
    curl -s -m 5 "$OPENCODE_URL/global/health" 2>/dev/null | jq -e '.healthy == true' &> /dev/null
}

if health_check; then
    echo "✅ Found opencode server at $OPENCODE_URL"
else
    echo "Starting opencode server on port $OPENCODE_PORT..."
    nohup opencode serve --port "$OPENCODE_PORT" >/tmp/opencode-server.log 2>&1 &
    SERVER_PID=$!
    SERVER_STARTED=1

    ELAPSED=0
    while [ "$ELAPSED" -lt "$OPENCODE_START_TIMEOUT" ]; do
        if health_check; then
            echo "✅ opencode server is up at $OPENCODE_URL"
            break
        fi
        sleep 1
        ELAPSED=$((ELAPSED + 1))
    done

    if ! health_check; then
        echo "❌ opencode server failed to start. Check /tmp/opencode-server.log and run 'opencode serve --port $OPENCODE_PORT' manually."
        exit 1
    fi
fi

# 2. Select LLM Model
echo -e "\nChecking available opencode models...\n"
AVAILABLE_MODELS=$(opencode models 2>/dev/null)

if [ -z "$AVAILABLE_MODELS" ]; then
    echo "❌ No models available through opencode."
    echo "Please log in to a provider with 'opencode auth login' (or add a provider to opencode.json) and try again."
    exit 1
else
    echo "Available models:"
    PS3="Enter the number of the model you want to use: "
    select SELECTED_MODEL in $AVAILABLE_MODELS; do
        if [ -n "$SELECTED_MODEL" ]; then
            echo -e "✅ Selected model: $SELECTED_MODEL\n"
            break
        else
            echo "❌ Invalid selection. Please try again."
        fi
    done
fi

PROVIDER_ID=$(echo "$SELECTED_MODEL" | cut -d'/' -f1)
MODEL_ID=$(echo "$SELECTED_MODEL" | cut -d'/' -f2-)

if [ -z "$PROVIDER_ID" ] || [ -z "$MODEL_ID" ]; then
    echo "❌ Could not parse model '$SELECTED_MODEL'. Expected format: provider/model"
    exit 1
fi

# 3. Ask for the name of the job title
read -p "Enter the job title (this will be used as the folder name): " JOB_TITLE

if [ -z "$JOB_TITLE" ]; then
    echo "❌ Job title cannot be empty."
    exit 1
fi

# Clean up the folder name by replacing spaces with underscores
DIR_NAME=$(echo "$JOB_TITLE" | tr ' ' '_')
mkdir -p "$DIR_NAME"
echo -e "\nFolder ready: $DIR_NAME\n"

# 4. Handle Personal Data
if [ -f "$DIR_NAME/personalData.txt" ]; then
    echo "✅ Found existing personalData.txt in '$DIR_NAME'. Skipping extraction..."
elif [ -f "./personalData.txt" ]; then
    echo "✅ Found master personalData.txt in root folder. Copying to '$DIR_NAME'..."
    cp "./personalData.txt" "$DIR_NAME/personalData.txt"
else
    echo "Extracting personal data from database..."
    DB_OUTPUT=$(java --enable-native-access=ALL-UNNAMED -jar sqlite-manager-complete.jar print)

    if [[ "$DB_OUTPUT" == *"No table to print"* ]]; then
        echo "❌ Error: The database is empty (returned 'No table to print')."
        echo "Please populate the database before generating a resume."
        exit 1
    fi

    echo "$DB_OUTPUT" > "$DIR_NAME/personalData.txt"
    echo -e "Saved to $DIR_NAME/personalData.txt"
fi

if [ ! -s "$DIR_NAME/personalData.txt" ]; then
    echo "❌ Error: personalData.txt is empty. Cannot generate a resume without career data."
    exit 1
fi
echo ""

# 5. Handle Job Description
if [ -f "$DIR_NAME/jobDescription.txt" ]; then
    echo "✅ Found existing jobDescription.txt in '$DIR_NAME'. Skipping manual entry..."
else
    echo "Please paste the Job Description below."
    echo "(When you are finished pasting, press Ctrl+D on a new empty line to save):"
    cat > "$DIR_NAME/jobDescription.txt"
    echo -e "\nSaved to $DIR_NAME/jobDescription.txt"
fi

if [ ! -s "$DIR_NAME/jobDescription.txt" ]; then
    echo "❌ Error: jobDescription.txt is empty. Cannot generate a tailored resume without a target job."
    exit 1
fi
echo ""

# 6. Read the contents of the files into variables for opencode
PERSONAL_DATA=$(cat "$DIR_NAME/personalData.txt")
JOB_DESC=$(cat "$DIR_NAME/jobDescription.txt")

# 7. Ask opencode for the job matches
echo "Feeding data to opencode to find the job matches..."

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

# Create a session
SESSION_BODY=$(jq -n --arg title "$JOB_TITLE" '{title: $title}')
TMP_SESSION=$(mktemp)
SESSION_CODE=$(curl -s -o "$TMP_SESSION" -w '%{http_code}' -X POST "$OPENCODE_URL/session" \
    -H "Content-Type: application/json" \
    -d "$SESSION_BODY")

if [ "$SESSION_CODE" != "200" ]; then
    echo "❌ Failed to create an opencode session (HTTP $SESSION_CODE)."
    echo "Body: $(jq -r '. // .error // empty' "$TMP_SESSION" 2>/dev/null | head -c 500)"
    echo "Ensure the opencode server is running at $OPENCODE_URL."
    exit 1
fi

SESSION_ID=$(jq -r '.id // empty' "$TMP_SESSION")
if [ -z "$SESSION_ID" ]; then
    echo "❌ opencode did not return a session id."
    echo "Body: $(head -c 500 "$TMP_SESSION")"
    exit 1
fi

# Construct the JSON payload securely using jq, injecting the selected model.
# tools: {} disables agent tool calls so the model returns the matches as text
# (the script itself writes matches.txt) instead of writing files on its own.
PAYLOAD=$(jq -n \
    --arg provider "$PROVIDER_ID" \
    --arg model "$MODEL_ID" \
    --arg txt "$USER_PROMPT" \
    '{model: {providerID: $provider, modelID: $model}, tools: {}, parts: [{type: "text", text: $txt}]}')

# Make the API call and save the response
TMP_RESPONSE=$(mktemp)
RESP_CODE=$(curl -s -o "$TMP_RESPONSE" -w '%{http_code}' -X POST "$OPENCODE_URL/session/$SESSION_ID/message" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD")

if [ "$RESP_CODE" != "200" ]; then
    echo "❌ opencode returned HTTP $RESP_CODE."
    echo "Body: $(head -c 500 "$TMP_RESPONSE")"
    echo "Please check the model name or ensure the opencode server is running."
    exit 1
fi

# Check if the response contains an error key
ERROR_MSG=$(jq -r '.error // empty' "$TMP_RESPONSE")

if [ -n "$ERROR_MSG" ]; then
    echo "❌ opencode returned an error: $ERROR_MSG"
    exit 1
fi

# Extract the assistant's text parts (skips reasoning/step markers)
MATCHES_TEXT=$(jq -r '[.parts[] | select(.type == "text") | .text] | join("")' "$TMP_RESPONSE")

if [ -z "$MATCHES_TEXT" ]; then
    echo "❌ opencode returned no text response."
    exit 1
fi

# Defensively strip a JSON code fence in case the model wraps its reply despite instructions
MATCHES_JSON=$(printf '%s' "$MATCHES_TEXT" | sed -e 's/^```json[[:space:]]*//' -e 's/^```[[:space:]]*//' -e 's/```[[:space:]]*$//')

# Validate the JSON shape before writing anything
if ! printf '%s' "$MATCHES_JSON" | jq -e '.profile and (.experience|type=="array") and (.education|type=="array") and (.skills|type=="array")' &> /dev/null; then
    echo "❌ opencode returned invalid JSON. Expected {profile, labels, experience, education, skills}."
    echo "Raw response (first 800 chars):"
    printf '%s' "$MATCHES_TEXT" | head -c 800
    echo ""
    exit 1
fi

echo "$MATCHES_JSON" > "$DIR_NAME/matches.txt"
echo -e "\n✅ Matches saved at: $DIR_NAME/matches.txt"

# 8. Build the HTML resume from the matches
echo "Building HTML resume with JavaResumeBuilder..."
if java --enable-native-access=ALL-UNNAMED JavaResumeBuilder.java "$DIR_NAME/matches.txt" "$DIR_NAME/resume.html"; then
    echo -e "\n✅ Success! Match report saved at: $DIR_NAME/matches.txt"
    echo "✅ HTML resume generated at: $DIR_NAME/resume.html"
else
    echo "❌ JavaResumeBuilder failed. See the errors above."
    exit 1
fi
