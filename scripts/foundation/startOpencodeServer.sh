#!/bin/bash

# Single job: ensure an opencode server is reachable, starting one if needed.
# Prints the PID of the server it started on stdout, or nothing when it attached
# to an already-running server. The caller owns that PID and is responsible for
# killing it — this script never kills anything.

# Deliberately does not `cd` to the project root: the opencode server is started
# from the caller's cwd so it discovers the right opencode.json.
source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"

need_cmd curl
need_cmd jq
need_cmd opencode

OPENCODE_URL="${OPENCODE_URL:-http://localhost:4096}"
OPENCODE_PORT="${OPENCODE_PORT:-4096}"
OPENCODE_START_TIMEOUT="${OPENCODE_START_TIMEOUT:-60}"

health_check() {
    curl -s -m 5 "$OPENCODE_URL/global/health" 2>/dev/null | jq -e '.healthy == true' &> /dev/null
}

if health_check; then
    echo "✅ Found opencode server at $OPENCODE_URL"
    exit 0
fi

echo "Starting opencode server on port $OPENCODE_PORT..."
nohup opencode serve --port "$OPENCODE_PORT" >/tmp/opencode-server.log 2>&1 &
SERVER_PID=$!

elapsed=0
while [ "$elapsed" -lt "$OPENCODE_START_TIMEOUT" ]; do
    if health_check; then
        echo "✅ opencode server is up at $OPENCODE_URL"
        printf '%s' "$SERVER_PID"
        exit 0
    fi
    sleep 1
    elapsed=$((elapsed + 1))
done

kill "$SERVER_PID" 2>/dev/null || true
echo "❌ opencode server failed to start. Check /tmp/opencode-server.log and run 'opencode serve --port $OPENCODE_PORT' manually." >&2
exit 1
