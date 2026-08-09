#!/bin/bash

# 0. Verify and install dependencies
echo -e "Checking and installing dependencies...\n"

check_install() {
    if ! command -v "$1" &> /dev/null; then
        echo "❌ $1 is not installed. Attempting to install..."
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y "$2"
        elif command -v dnf &> /dev/null; then
            sudo dnf install -y "$2"
        elif command -v pacman &> /dev/null; then
            sudo pacman -S --noconfirm "$2"
        elif command -v brew &> /dev/null; then
            brew install "$2"
        else
            echo "Please install $1 manually. Package manager not found."
            exit 1
        fi
    else
        echo "✅ $1 is already installed."
    fi
}

check_install "jq" "jq"
check_install "curl" "curl"
check_install "java" "default-jre"

# Ollama uses a dedicated install script
if ! command -v ollama &> /dev/null; then
    echo "❌ ollama is not installed. Attempting to install..."
    curl -fsSL https://ollama.com/install.sh | sh
else
    echo "✅ ollama is already installed."
fi

echo -e "\nAll dependencies are satisfied. Proceeding...\n"

# 1. Ask for the name of the job title
read -p "Enter the job title (this will be used as the folder name): " JOB_TITLE

# Clean up the folder name by replacing spaces with underscores
DIR_NAME=$(echo "$JOB_TITLE" | tr ' ' '_')
mkdir -p "$DIR_NAME"
echo -e "\nFolder ready: $DIR_NAME\n"

# 2. Handle Personal Data
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
echo ""

# 3. Handle Job Description
if [ -f "$DIR_NAME/jobDescription.txt" ]; then
    echo "✅ Found existing jobDescription.txt in '$DIR_NAME'. Skipping manual entry..."
else
    echo "Please paste the Job Description below."
    echo "(When you are finished pasting, press Ctrl+D on a new empty line to save):"
    cat > "$DIR_NAME/jobDescription.txt"
    echo -e "\nSaved to $DIR_NAME/jobDescription.txt"
fi
echo ""

# 4. Handle Structure Rules
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
echo ""

# 5. Handle Persona
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
echo ""

# 6. Read the contents of the files into variables for Ollama
PERSONAL_DATA=$(cat "$DIR_NAME/personalData.txt")
JOB_DESC=$(cat "$DIR_NAME/jobDescription.txt")
RULES=$(cat "$DIR_NAME/structureRules.txt")
SYSTEM_PROMPT=$(cat "$DIR_NAME/persona.txt")

# 7. Call Ollama (DeepSeek-R1)
echo "Feeding data to Ollama to generate the resume..."

# Combine the three files into the user prompt
USER_PROMPT="Aqui estão os dados:

=== Personal Data ===
$PERSONAL_DATA

=== Job Description ===
$JOB_DESC

=== Structure Rules ===
$RULES"

# Construct the JSON payload securely using jq
PAYLOAD=$(jq -n \
  --arg model "deepseek-r1" \
  --arg sys "$SYSTEM_PROMPT" \
  --arg prompt "$USER_PROMPT" \
  '{model: $model, system: $sys, prompt: $prompt, stream: false}')

# Make the API call and save the raw response to a variable
RAW_RESPONSE=$(curl -s http://localhost:11434/api/generate \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD")

# Check if the response contains an error key
ERROR_MSG=$(echo "$RAW_RESPONSE" | jq -r '.error // empty')

if [ -n "$ERROR_MSG" ]; then
    echo "❌ Ollama returned an error: $ERROR_MSG"
    echo "Please check your model name or ensure Ollama is running."
else
    # If no error, extract the response and save it
    echo "$RAW_RESPONSE" | jq -r '.response' > "$DIR_NAME/resume.txt"
    echo -e "\n✅ Success! Your tailored resume has been generated and saved at: $DIR_NAME/resume.txt"
fi
