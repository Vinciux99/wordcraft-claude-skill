#!/usr/bin/env bash
# artcraft-setup.sh - macOS setup for one ArtCraft app (storytold) + Claude.
#
#   ./artcraft-setup.sh --config ../app.json [options]
#
# What it does (each step can be skipped, --dry-run changes nothing):
#   1. finds the app (.app) and its CLI (downloads the CLI from the app's latest GitHub release if missing)
#   2. creates the "<App> (Claude)" launcher (starts the app with the control channel on)
#   3. registers the MCP server in Claude Desktop (backs the config up first)
#   4. registers it in Claude Code (`claude mcp add --scope user`) if the `claude` CLI is installed
#   5. installs the skill into ~/.claude/skills/<id>
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JSTOOL="$SCRIPT_DIR/json-tool.js"
CONFIG=""; SKILL_DIR=""; MODE=""; DRY=0; NO_LAUNCHER=0; NO_DESKTOP=0; NO_CODE=0; NO_SKILL=0; NO_DOWNLOAD=0
CLI_OVERRIDE=""; CLAUDE_CONFIG_OVERRIDE=""

usage() { sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; cat <<'USAGE'

Options:
  --config FILE          app.json of the app to set up (required)
  --skill-dir DIR        folder containing SKILL.md (default: <script dir>/../skills/<id>)
  --mode live|headless|both   MCP mode (default: the app's default, normally "live")
  --cli PATH             use this CLI binary instead of searching
  --claude-config FILE   Claude Desktop config to edit (default: ~/Library/Application Support/Claude/claude_desktop_config.json)
  --dry-run              print what would be done, change nothing
  --no-launcher | --no-claude-desktop | --no-claude-code | --no-skill | --no-download
  -h, --help
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --config) CONFIG="$2"; shift 2;;
    --skill-dir) SKILL_DIR="$2"; shift 2;;
    --mode) MODE="$2"; shift 2;;
    --cli) CLI_OVERRIDE="$2"; shift 2;;
    --claude-config) CLAUDE_CONFIG_OVERRIDE="$2"; shift 2;;
    --dry-run) DRY=1; shift;;
    --no-launcher) NO_LAUNCHER=1; shift;;
    --no-claude-desktop) NO_DESKTOP=1; shift;;
    --no-claude-code) NO_CODE=1; shift;;
    --no-skill) NO_SKILL=1; shift;;
    --no-download) NO_DOWNLOAD=1; shift;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 64;;
  esac
done
[ -n "$CONFIG" ] || { echo "Missing --config" >&2; usage >&2; exit 64; }
[ -f "$CONFIG" ] || { echo "Config not found: $CONFIG" >&2; exit 66; }

if command -v osascript >/dev/null 2>&1; then JSRUN=(osascript -l JavaScript "$JSTOOL")
elif command -v node >/dev/null 2>&1; then JSRUN=(node "$JSTOOL")
else echo "Need osascript (macOS) or node to read JSON." >&2; exit 69; fi

H="${HOME:?}"
VARS=(--var "home=$H" --var "documents=$H/Documents" --var "pictures=$H/Pictures" --var "music=$H/Music" --var "movies=$H/Movies" --var "appdata=$H/Library/Application Support")
jget() { "${JSRUN[@]}" get "$CONFIG" "$1" "${VARS[@]}" "${EXTRA_VARS[@]+"${EXTRA_VARS[@]}"}"; }
EXTRA_VARS=()

ID="$(jget id)"; NAME="$(jget name)"; UPSTREAM="$(jget upstream)"; PORT="$(jget port)"
SERVER="$(jget mcp.server)"
[ -n "$MODE" ] || MODE="$(jget mcp.default)"; [ -n "$MODE" ] || MODE="live"
case "$MODE" in live|headless|both) ;; *) echo "Bad --mode: $MODE" >&2; exit 64;; esac
[ -n "$PORT" ] && EXTRA_VARS+=(--var "port=$PORT")
[ -n "$SKILL_DIR" ] || SKILL_DIR="$SCRIPT_DIR/../skills/$ID"

say()  { printf '%s\n' "$*"; }
step() { printf '\n== %s\n' "$*"; }
act()  { if [ "$DRY" = 1 ]; then say "   [dry-run] $*"; return 0; fi; "$@"; }

DRYTXT=""; [ "$DRY" = 1 ] && DRYTXT=" (dry run)"
say "ArtCraft setup for $NAME ($ID) on macOS  mode=$MODE${PORT:+ port=$PORT}$DRYTXT"

# ---------------------------------------------------------------- 1. find app + CLI
step "1. Find $NAME"
BUNDLE=""
while IFS= read -r b; do
  [ -n "$b" ] || continue
  if [ -d "$b" ]; then BUNDLE="$b"; break; fi
done < <(jget macos.bundles)
if [ -n "$BUNDLE" ]; then say "   app: $BUNDLE"; EXTRA_VARS+=(--var "bundle=$BUNDLE")
else
  say "   $NAME.app not found. Install it first: https://github.com/$UPSTREAM/releases/latest (download the macOS .dmg, drag the app to Applications)."
fi

CLI=""
if [ -n "$CLI_OVERRIDE" ]; then CLI="$CLI_OVERRIDE"
else
  while IFS= read -r c; do
    [ -n "$c" ] || continue
    if [ -x "$c" ] && [ ! -d "$c" ]; then CLI="$c"; break; fi
  done < <(jget macos.cliPaths)
fi

if [ -z "$CLI" ] && [ "$NO_DOWNLOAD" = 0 ]; then
  ASSET_TMPL="$(jget macos.cliReleaseAsset)"; BIN_IN_ZIP="$(jget macos.cliBinaryInZip)"
  if [ -n "$ASSET_TMPL" ]; then
    DEST="$H/.artcraft/bin"
    say "   CLI not found; it comes from the app's GitHub release as a separate zip."
    if [ "$DRY" = 1 ]; then
      say "   [dry-run] would resolve the latest tag of $UPSTREAM, download $ASSET_TMPL and unzip it into $DEST"
      CLI="$DEST/${BIN_IN_ZIP:-$ID-cli}"
    else
      TAG_URL="$(curl -fsSIL -o /dev/null -w '%{url_effective}' "https://github.com/$UPSTREAM/releases/latest" || true)"
      TAG="${TAG_URL##*/}"; VER="${TAG#v}"
      if [ -z "$TAG" ] || [ "$TAG" = "latest" ]; then
        say "   Could not resolve the latest release tag (offline?)."
      else
        ASSET="${ASSET_TMPL//\{version\}/$VER}"
        URL="https://github.com/$UPSTREAM/releases/download/$TAG/$ASSET"
        say "   downloading $URL"
        TMP="$(mktemp -d)"
        if curl -fsSL -o "$TMP/cli.zip" "$URL" && unzip -q -o "$TMP/cli.zip" -d "$TMP/x"; then
          mkdir -p "$DEST"
          FOUND="$(find "$TMP/x" -type f -name "${BIN_IN_ZIP:-$ID-cli}" | head -n1)"
          if [ -n "$FOUND" ]; then
            cp "$FOUND" "$DEST/${BIN_IN_ZIP:-$ID-cli}"; chmod +x "$DEST/${BIN_IN_ZIP:-$ID-cli}"
            xattr -d com.apple.quarantine "$DEST/${BIN_IN_ZIP:-$ID-cli}" 2>/dev/null || true
            CLI="$DEST/${BIN_IN_ZIP:-$ID-cli}"
          else say "   The zip did not contain '${BIN_IN_ZIP:-$ID-cli}'. Unzip it by hand and re-run with --cli /path/to/cli."; fi
        else say "   Download failed. Get the CLI zip from https://github.com/$UPSTREAM/releases/latest and re-run with --cli /path/to/cli."; fi
        rm -rf "$TMP"
      fi
    fi
  fi
fi
if [ -n "$CLI" ]; then say "   cli: $CLI"; else say "   CLI: not found (MCP registration will be skipped)."; fi

# prepare dirs
while IFS= read -r d; do [ -n "$d" ] && { say "   folder: $d"; act mkdir -p "$d"; }; done < <(jget prepare.dirs)

# ---------------------------------------------------------------- 2. launcher
step "2. Launcher \"$NAME (Claude)\""
if [ "$NO_LAUNCHER" = 1 ]; then say "   skipped (--no-launcher)"
elif [ -z "$BUNDLE" ]; then say "   skipped: app not installed"
else
  LARGS=(); while IFS= read -r a; do [ -n "$a" ] && LARGS+=("$a"); done < <(jget launch.args)
  LAUNCH_APP="$H/Applications/$NAME (Claude).app"
  QARGS=""; for a in "${LARGS[@]+"${LARGS[@]}"}"; do QARGS="$QARGS $(printf '%q' "$a")"; done
  say "   $LAUNCH_APP  ->  open -n -a \"$BUNDLE\" --args$QARGS"
  if [ "$DRY" = 0 ]; then
    mkdir -p "$LAUNCH_APP/Contents/MacOS" "$LAUNCH_APP/Contents/Resources"
    ICON_LINE=""
    ICNS="$(find "$BUNDLE/Contents/Resources" -maxdepth 1 -name '*.icns' 2>/dev/null | head -n1 || true)"
    if [ -n "$ICNS" ]; then cp "$ICNS" "$LAUNCH_APP/Contents/Resources/icon.icns"; ICON_LINE="<key>CFBundleIconFile</key><string>icon</string>"; fi
    cat > "$LAUNCH_APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>launch</string>
<key>CFBundleIdentifier</key><string>local.artcraft.launcher.$ID</string>
<key>CFBundleName</key><string>$NAME (Claude)</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSUIElement</key><true/>
$ICON_LINE
</dict></plist>
PLIST
    {
      echo '#!/bin/bash'
      echo "# Starts $NAME with the control channel enabled so Claude can drive it."
      echo "exec /usr/bin/open -n -a $(printf '%q' "$BUNDLE") --args$QARGS"
    } > "$LAUNCH_APP/Contents/MacOS/launch"
    chmod +x "$LAUNCH_APP/Contents/MacOS/launch"
    command -v codesign >/dev/null 2>&1 && codesign --force --sign - "$LAUNCH_APP" >/dev/null 2>&1 || true
    if [ -d "$H/Desktop" ]; then ln -sfn "$LAUNCH_APP" "$H/Desktop/$NAME (Claude)"; say "   Desktop shortcut created"; fi
  fi
fi

# ---------------------------------------------------------------- 3/4. MCP registration
LIVE_ARGS=(); while IFS= read -r a; do [ -n "$a" ] && LIVE_ARGS+=("$a"); done < <(jget mcp.live)
HEAD_ARGS=(); while IFS= read -r a; do [ -n "$a" ] && HEAD_ARGS+=("$a"); done < <(jget mcp.headless)
args_json() { local out="[" first=1 x; for x in "$@"; do [ $first = 1 ] || out="$out,"; first=0; out="$out$("${JSRUN[@]}" quote "$x" 2>/dev/null || printf '"%s"' "${x//\"/\\\"}")"; done; echo "$out]"; }

# list of "name|mode" entries to register
ENTRIES=()
case "$MODE" in
  live) ENTRIES+=("$SERVER|live");;
  headless) ENTRIES+=("$SERVER|headless");;
  both) ENTRIES+=("$SERVER|live" "$SERVER-headless|headless");;
esac

step "3. Claude Desktop MCP config"
if [ "$NO_DESKTOP" = 1 ]; then say "   skipped (--no-claude-desktop)"
elif [ -z "$CLI" ]; then say "   skipped: no CLI"
else
  CFG="${CLAUDE_CONFIG_OVERRIDE:-$H/Library/Application Support/Claude/claude_desktop_config.json}"
  say "   config: $CFG"
  if [ "$DRY" = 0 ]; then
    mkdir -p "$(dirname "$CFG")"
    if [ -f "$CFG" ]; then B="$CFG.backup-$(date +%Y%m%d-%H%M%S)"; cp "$CFG" "$B"; say "   backup: $B"; fi
  fi
  for e in "${ENTRIES[@]}"; do
    n="${e%%|*}"; m="${e##*|}"
    if [ "$m" = live ]; then A=("${LIVE_ARGS[@]}"); else A=("${HEAD_ARGS[@]}"); fi
    AJ="$(args_json "${A[@]}")"
    say "   mcpServers.$n = $CLI $AJ"
    act "${JSRUN[@]}" mcp-set "$CFG" "$n" "$CLI" "$AJ" >/dev/null
  done
fi

step "4. Claude Code MCP registration"
if [ "$NO_CODE" = 1 ]; then say "   skipped (--no-claude-code)"
elif [ -z "$CLI" ]; then say "   skipped: no CLI"
elif ! command -v claude >/dev/null 2>&1; then say "   'claude' command not found - skipping (install Claude Code, then re-run)."
else
  for e in "${ENTRIES[@]}"; do
    n="${e%%|*}"; m="${e##*|}"
    if [ "$m" = live ]; then A=("${LIVE_ARGS[@]}"); else A=("${HEAD_ARGS[@]}"); fi
    say "   claude mcp add --scope user $n -- $CLI ${A[*]}"
    if [ "$DRY" = 0 ]; then claude mcp remove --scope user "$n" >/dev/null 2>&1 || true; claude mcp add --scope user "$n" -- "$CLI" "${A[@]}"; fi
  done
fi

# ---------------------------------------------------------------- 5. skill
step "5. Skill for Claude Code"
if [ "$NO_SKILL" = 1 ]; then say "   skipped (--no-skill)"
elif [ ! -f "$SKILL_DIR/SKILL.md" ]; then say "   skipped: $SKILL_DIR/SKILL.md not found"
else
  say "   $SKILL_DIR  ->  $H/.claude/skills/$ID"
  if [ "$DRY" = 0 ]; then mkdir -p "$H/.claude/skills"; rm -rf "$H/.claude/skills/$ID"; cp -R "$SKILL_DIR" "$H/.claude/skills/$ID"; fi
fi

step "Done"
cat <<EOT
Next:
  1. Fully quit Claude (Cmd+Q) and open it again so it reads the new MCP configuration.
  2. Start $NAME with the launcher "$NAME (Claude)" (in ~/Applications and on the Desktop) BEFORE asking Claude to use it.
  3. Ask Claude something like: "list the $NAME commands". If it answers, the MCP server is connected.
  Claude app (claude.ai / desktop): to use the skill there too, upload the zip from
  https://github.com/Vinciux99/$ID-claude-skill/releases/latest  (Customize > Skills > + > Create skill > Upload a skill).
EOT
