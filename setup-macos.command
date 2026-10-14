#!/usr/bin/env bash
# Sets up this ArtCraft app for Claude on macOS: launcher + MCP server + skill.
# Double-click in Finder (first time: right-click > Open), or run in Terminal.
# Extra options are passed through, e.g.:  ./setup-macos.command --mode both --dry-run
HERE="$(cd "$(dirname "$0")" && pwd)"
ID="$(osascript -l JavaScript "$HERE/scripts/json-tool.js" get "$HERE/app.json" id)"
"$HERE/scripts/artcraft-setup.sh" --config "$HERE/app.json" --skill-dir "$HERE/skills/$ID" "$@"
STATUS=$?
echo
read -r -p "Press Enter to close..." _ || true
exit $STATUS
