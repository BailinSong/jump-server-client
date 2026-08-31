#!/usr/bin/env bash
# Pack one plugin directory (or all platform plugins) into .jscplugin ZIP archives.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
exec python3 "$ROOT/scripts/pack-client-plugins.py" "$@"
