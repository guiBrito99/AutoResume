#!/bin/bash

# Single job: build sqlite-manager-complete.jar from source.
# Clones java-sqlite-manager if needed, runs its Maven build, and copies the
# fat jar into the project root. Skips the build when the jar already exists.

source "$(dirname "${BASH_SOURCE[0]}")/../common.sh"
cd "$PROJECT_ROOT" || exit 1

need_cmd git

JAR_NAME="sqlite-manager-complete.jar"
TARGET_JAR="$PROJECT_ROOT/$JAR_NAME"
REPO_URL="https://github.com/guiBrito99/java-sqlite-manager.git"
REPO_DIR="/tmp/java-sqlite-manager"

if [ -f "$TARGET_JAR" ]; then
    echo "✅ $JAR_NAME already exists. Skipping build."
    exit 0
fi

if [ ! -d "$REPO_DIR" ]; then
    echo "Cloning java-sqlite-manager..."
    git clone --depth 1 "$REPO_URL" "$REPO_DIR"
fi

cd "$REPO_DIR" || exit 1

echo "Building fat JAR with Maven..."
if command -v mvn &> /dev/null; then
    mvn clean package -DskipTests -q
elif [ -f "./mvnw" ]; then
    ./mvnw clean package -DskipTests -q
else
    echo "❌ Maven not found. Please install Maven and re-run." >&2
    exit 1
fi

# Prefer the jar directly in target/, never the intermediate under archive-tmp/.
JAR_FILE=$(find target -maxdepth 1 -name "$JAR_NAME" 2>/dev/null | head -1)
if [ -z "$JAR_FILE" ] || [ ! -f "$JAR_FILE" ]; then
    JAR_FILE=$(find target -name "*jar-with-dependencies.jar" -o -name "$JAR_NAME" -o -name "*-shaded.jar" 2>/dev/null | grep -v archive-tmp | head -1)
fi

if [ -z "$JAR_FILE" ] || [ ! -f "$JAR_FILE" ]; then
    echo "❌ Failed to find the built jar in $REPO_DIR/target" >&2
    exit 1
fi

cp "$JAR_FILE" "$TARGET_JAR"
echo "✅ Built and copied to $TARGET_JAR"
