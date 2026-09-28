# Shared constants, dependency primitives, and strict-mode settings.
#
# This is the ONLY file in the project that is ever `source`d, and the only file
# that is not a single-purpose script. Security rule: never `source` anything
# derived from user input (jobDescription.txt, matches.txt, per-job folders).

set -e
set -o pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPTS_DIR/.." && pwd)"

# Verify a command is on PATH. Returns 1 and explains on stderr when missing.
need_cmd() {
    command -v "$1" &>/dev/null || {
        echo "❌ Missing command: $1" >&2
        return 1
    }
}

# Verify a required file exists. Returns 1 and explains on stderr when missing.
need_jar() {
    [ -f "$1" ] || {
        echo "❌ Missing file: $1" >&2
        return 1
    }
}
