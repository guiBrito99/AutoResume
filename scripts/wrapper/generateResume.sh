#!/bin/bash

# Wrapper: coordinates the pipeline end to end.
#
# Usage: generateResume.sh [job title] [provider/model]
#
# Resolves its own values by calling the scripts that prompt, so this file
# contains no prompting of its own. Anything passed as arguments is forwarded,
# which is how testScript.sh runs the whole pipeline without stdin.

source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FOUNDATION="$SCRIPTS_DIR/foundation"

cd "$PROJECT_ROOT" || exit 1

TITLE_ARG="${1:-}"
MODEL_ARG="${2:-}"

# 1. Dependencies must already be satisfied (installing is a menu action).
if ! bash "$FOUNDATION/checkDependencies.sh"; then
    echo "❌ Missing dependencies. Run 'bash $SCRIPTS_DIR/foundation/installDependencies.sh' first." >&2
    exit 1
fi

# 2. Resolve the job title and the model from the scripts that prompt.
JOB_TITLE=$(bash "$FOUNDATION/askJobTitle.sh" "$TITLE_ARG")
MODEL=$(bash "$FOUNDATION/selectModel.sh" "$MODEL_ARG")

PROVIDER_ID="${MODEL%%	*}"
MODEL_ID="${MODEL#*	}"
if [ -z "$PROVIDER_ID" ] || [ -z "$MODEL_ID" ] || [ "$PROVIDER_ID" = "$MODEL" ]; then
    echo "❌ Could not parse model '$MODEL'. Expected 'provider<TAB>model'." >&2
    exit 1
fi

DIR_NAME=$(echo "$JOB_TITLE" | tr ' ' '_')
mkdir -p "$DIR_NAME"

# 3. Collect the per-job input files.
bash "$FOUNDATION/collectJobDescription.sh" "$JOB_TITLE" || exit 1
echo ""
bash "$FOUNDATION/collectPersonalData.sh" "$JOB_TITLE" || exit 1
echo ""

# 4. Ensure a server is up. We own the PID if we started it.
SERVER_PID=$(bash "$FOUNDATION/startOpencodeServer.sh")
echo ""
stop_server() {
    if [ -n "$SERVER_PID" ]; then
        kill "$SERVER_PID" 2>/dev/null || true
    fi
}
trap stop_server EXIT

# 5. Produce the match report, then the HTML resume.
bash "$FOUNDATION/infoMatcher.sh" "$JOB_TITLE" "$PROVIDER_ID" "$MODEL_ID" || exit 1
echo ""
bash "$FOUNDATION/resumeBuilder.sh" "$DIR_NAME/matches.txt" "$DIR_NAME/resume.html" || exit 1

echo -e "\n✅ Success!"
echo "   Match report: $DIR_NAME/matches.txt"
echo "   HTML resume:  $DIR_NAME/resume.html"
