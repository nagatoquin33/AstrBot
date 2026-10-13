#!/usr/bin/env sh
# AstrBot Portable launcher (Linux / macOS)
# All runtime data stays inside this folder.
set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
export ASTRBOT_ROOT="$DIR"

case ":$PATH:" in
    *":$DIR/python/bin:"*) ;;
    *) export PATH="$DIR/python/bin:$PATH" ;;
esac

if [ -z "$ASTRBOT_PORTABLE_USE_SYSTEM_TMP" ]; then
    mkdir -p "$DIR/data/temp/system"
    export TMPDIR="$DIR/data/temp/system"
fi

cd "$DIR"

echo "============================================================"
echo "  AstrBot Portable"
echo "  Root : $DIR"
echo "  WebUI: http://127.0.0.1:6185"
echo "  All data stays inside this folder."
echo "============================================================"

exec "$DIR/python/bin/python3" main.py "$@"
