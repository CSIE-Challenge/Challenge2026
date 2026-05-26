#!/bin/bash
set -e

REPO_ROOT="$(git rev-parse --show-toplevel)"
PRECOMMIT_PYZ="$REPO_ROOT/tools/pre-commit-4.6.0.pyz"

echo "[INFO] Switching to the root of the git repository..."
cd "$REPO_ROOT"

if ! command -v python3 &>/dev/null; then
    echo "[ERROR] python3 is not installed or not in PATH."
    echo "        Please install Python 3.8 or newer."
    exit 1
fi

PYTHON_VERSION=$(python3 --version 2>&1 | awk '{print $2}')
PYTHON_MINOR=$(echo "$PYTHON_VERSION" | cut -d. -f2)

if [ "$PYTHON_MINOR" -lt 8 ]; then
    echo "[ERROR] Python 3.8+ is required, found $PYTHON_VERSION"
    exit 1
fi

if [ ! -f "$PRECOMMIT_PYZ" ]; then
    echo "[ERROR] pre-commit zipapp not found at: $PRECOMMIT_PYZ"
    echo "        Run git pull to ensure you have the latest version of the repository."
    exit 1
fi

echo "[INFO] Installing pre-commit hook..."
python3 "$PRECOMMIT_PYZ" install

echo "[INFO] Installing commit-msg hook..."
python3 "$PRECOMMIT_PYZ" install --hook-type commit-msg

echo "[INFO] Installing post-checkout hook..."
python3 "$PRECOMMIT_PYZ" install --hook-type post-checkout

echo "[INFO] Pre-installing all hook environments..."
python3 "$PRECOMMIT_PYZ" install-hooks

echo "[SUCCESS] pre-commit is fully set up and active."
