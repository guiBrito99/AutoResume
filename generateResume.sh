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

# 0. Verify and install dependencies
echo -e "Checking and installing dependencies...\n"

check_install() {
    if ! command -v "$1" &> /dev/null; then
        echo "❌ $1 is not installed. Attempting to install..."
        if [ -n "$2" ]; then
            if command -v apt-get &> /dev/null; then
                sudo apt-get update && sudo apt-get install -y "$2"
            elif command -v dnf &> /dev/null; then
                sudo dnf install -y "$2"
            elif command -v pacman &> /dev/null; then
                sudo pacman -S --noconfirm "$2"
            elif command -v brew &> /dev/null; then
                brew install "$2"
            fi
        fi
        if ! command -v "$1" &> /dev/null && [ -n "$3" ]; then
            echo "Installing $1 via curl installer..."
            curl -fsSL "$3" | bash
        fi
        if ! command -v "$1" &> /dev/null; then
            echo "❌ Failed to install $1. Please install it manually:"
            [ -n "$4" ] && echo "  $4"
            exit 1
        fi
        echo "✅ $1 installed successfully."
    else
        echo "✅ $1 is already installed."
    fi
}

check_install "jq" "jq"
check_install "curl" "curl"
check_install "java" "default-jre"
check_install "opencode" "" "https://opencode.ai/install" "https://opencode.ai/docs/"

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

# 6. Handle Structure Rules
if [ -f "$DIR_NAME/structureRules.txt" ]; then
    echo "✅ Found existing structureRules.txt in '$DIR_NAME'. Skipping manual entry..."
elif [ -f "./structureRules.txt" ]; then
    echo "✅ Found master structureRules.txt in root folder. Copying to '$DIR_NAME'..."
    cp "./structureRules.txt" "$DIR_NAME/structureRules.txt"
else
    echo "Please paste the Structure Rules below."
    echo "(When you are finished pasting, press Ctrl+D on a new empty line to save):"
    cat > "$DIR_NAME/structureRules.txt"
    echo -e "\nSaved to $DIR_NAME/structureRules.txt"
fi

if [ ! -s "$DIR_NAME/structureRules.txt" ]; then
    echo "❌ Error: structureRules.txt is empty. Provide at least a few formatting constraints."
    exit 1
fi
echo ""

# 7. Handle Persona
if [ -f "$DIR_NAME/persona.txt" ]; then
    echo "✅ Found existing persona.txt in '$DIR_NAME'. Skipping manual entry..."
elif [ -f "./persona.txt" ]; then
    echo "✅ Found master persona.txt in root folder. Copying to '$DIR_NAME'..."
    cp "./persona.txt" "$DIR_NAME/persona.txt"
else
    echo "Please paste the Persona instructions below."
    echo "(When you are finished pasting, press Ctrl+D on a new empty line to save):"
    cat > "$DIR_NAME/persona.txt"
    echo -e "\nSaved to $DIR_NAME/persona.txt"
fi

if [ ! -s "$DIR_NAME/persona.txt" ]; then
    echo "❌ Error: persona.txt is empty. Provide instructions describing the LLM's role."
    exit 1
fi
echo ""

# 8. Read the contents of the files into variables for opencode
PERSONAL_DATA=$(cat "$DIR_NAME/personalData.txt")
JOB_DESC=$(cat "$DIR_NAME/jobDescription.txt")
RULES=$(cat "$DIR_NAME/structureRules.txt")
SYSTEM_PROMPT=$(cat "$DIR_NAME/persona.txt")

# 9. Call opencode
echo "Feeding data to opencode to generate the resume..."

# Combine the three files into the user prompt
USER_PROMPT="Aqui estão os dados:

=== Personal Data ===
$PERSONAL_DATA

=== Job Description ===
$JOB_DESC

=== Structure Rules ===
$RULES"

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
# tools: {} disables agent tool calls so the model returns the resume as text
# (the script itself writes resume.txt) instead of writing files on its own.
PAYLOAD=$(jq -n \
    --arg provider "$PROVIDER_ID" \
    --arg model "$MODEL_ID" \
    --arg sys "$SYSTEM_PROMPT" \
    --arg txt "$USER_PROMPT" \
    '{model: {providerID: $provider, modelID: $model}, system: $sys, tools: {}, parts: [{type: "text", text: $txt}]}')

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

# Extract the assistant's text parts (skips reasoning/step markers) and save them
RESUME_TEXT=$(jq -r '[.parts[] | select(.type == "text") | .text] | join("")' "$TMP_RESPONSE")

if [ -z "$RESUME_TEXT" ]; then
    echo "❌ opencode returned no text response."
    exit 1
fi

echo "$RESUME_TEXT" > "$DIR_NAME/resume.txt"
echo -e "\n✅ Success! Your tailored resume has been generated and saved at: $DIR_NAME/resume.txt"
