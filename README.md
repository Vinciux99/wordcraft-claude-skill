# WordCraft skill for Claude

WordCraft (ArtCraft suite, storytold/wordcraft) is a clean-room, open-source Rust reimplementation of **Microsoft Word**: ribbon, styles, lists, tables, headers/footers, table of contents, notes, citations, tracked changes, comments, mail merge. It reads and writes **.docx** (also .odt, .rtf, .html, .md, .tex, .txt, .json; opens legacy .doc 97-2003 read-only; Word 2003 XML / Flat OPC `.xml`) and exports **PDF** with selectable text and PNG. Status: **alpha** (roughly 60% of Word for real work; Word charts and SmartArt are read-only).

This repository packages a **skill** that teaches Claude to drive WordCraft (part of the [ArtCraft suite](https://github.com/storytold/wordcraft) by storytold) and that **knows how to create the MCP server and guide you through it**, on **Windows and macOS**. It is unofficial and not affiliated with storytold.

> Part of the [ArtCraft Claude skills hub](https://github.com/Vinciux99/artcraft-claude-skills): all 13 skills, a picker and a one-command installer.

## What it does
- Operating manual for WordCraft: connection modes, ground rules, every MCP tool, recipes, CLI, control channel, command families and a safe workflow (work on copies, verify, save only with your OK).
- Built-in MCP setup assistant: Claude checks whether the server is connected, then walks you through installing it (automatic script or manual config), the launcher, authentication and verification.
- Troubleshooting table for the usual problems (server "disconnected", ports, macOS quarantine, Windows Store config location...).

## What you can ask Claude
- "Create a quarterly report: Heading 1 title, two paragraphs, bold the key phrase and add a 2x2 table."
- "Open `contract.docx` (a copy), turn on track changes as 'Claude (copyedit)' and fix typos and tone."
- "Change the Heading 1 style to Georgia 18 pt with 12 pt before and keep-with-next."
- "Export this document to PDF and render page 1 so I can check the layout."
- "Merge `letter.docx` with `recipients.csv` and save the merged file."
- "Convert `report.docx` to Markdown and to PDF with margin comments."
- "Add `logo.png` under the title and a hyperlink on the word 'documentation'."

## Highlights
- Headless (with optional read/write roots) and live MCP, 16 tools plus resources.
- Byte-offset positions, paragraph/style/property rules and tracked-changes pitfalls spelled out.
- CharProps / ParaProps reference, recipes for styles, review, mail merge, exports.
- CLI `convert`/`run`/`render` pipelines and the authenticated control-channel protocol.
- Built-in guidance for creating and troubleshooting the MCP server on Windows and macOS.

## App-specific notes
- Kit port **7987** (upstream docs use 7981, DesignCraft's port here); live MCP `mcp --connect 127.0.0.1:7987`; headless `mcp`.
- **Authenticated** channel: the app writes a per-launch key file (`control-key.local-7987`); the CLI reads it automatically.
- Roots apply to headless only; `--connect` plus roots is an error.
- `review.trackChanges` without `value` toggles; always pass `{"value": true}`.
- Alpha: Word charts/SmartArt are read-only and can be lost on save.

## Get the skill

| Where | How |
|---|---|
| **Claude app** (claude.ai / Desktop) | Download [`wordcraft-skill.zip](https://github.com/Vinciux99/wordcraft-claude-skill/releases/latest/download/wordcraft-skill.zip)`, then Customize > Skills > "+" > Create skill > Upload a skill. Needs Settings > Capabilities > "Code execution and file creation" on. |
| **Claude Code, plugin** | `/plugin marketplace add Vinciux99/artcraft-claude-skills` then `/plugin install wordcraft@artcraft` |
| **Claude Code, manual** | copy `skills/wordcraft/` to `~/.claude/skills/wordcraft/` (the setup script below does it) |

## Create the MCP server

Prerequisite: install WordCraft from [upstream releases](https://github.com/storytold/wordcraft/releases) (Windows `.msi`, macOS `.dmg`) and Claude Desktop and/or Claude Code.

**One command (recommended)**

Windows (PowerShell):
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "& ([scriptblock]::Create((irm https://raw.githubusercontent.com/Vinciux99/artcraft-claude-skills/main/install.ps1))) -Apps wordcraft"
```
macOS (Terminal):
```sh
curl -fsSL https://raw.githubusercontent.com/Vinciux99/artcraft-claude-skills/main/install.sh | bash -s -- --apps wordcraft
```
Add `-DryRun` (Windows) or `--dry-run` (macOS) to preview, and `-Mode live|headless|both` / `--mode ...` to choose the mode.

**Or from a clone:** double-click `setup-windows.cmd` (Windows) or `setup-macos.command` (macOS; first time right-click > Open).

**Or just ask Claude:** once the skill is installed, say "set up the WordCraft MCP server" and Claude will guide you step by step.

After setup: fully quit and reopen Claude, open WordCraft with the **"WordCraft (Claude)"** launcher, then ask Claude to use it. If the server shows "disconnected", the app was not running when Claude started: open it with the launcher and re-enable the server, or use headless mode.

What the setup changes (all backed up or reversible): Claude Desktop config (`mcpServers.wordcraft`, backup `<file>.backup-<timestamp>`), the launcher, Claude Code's user-scope MCP list and `~/.claude/skills/wordcraft/`.

## Repository layout
```
skills/wordcraft/SKILL.md      the skill
app.json                   machine-readable settings (ports, paths, MCP args) used by the scripts
scripts/                   artcraft-setup.ps1 (Windows), artcraft-setup.sh (macOS), json-tool.js
setup-windows.cmd          double-click wrapper
setup-macos.command        double-click wrapper
.claude-plugin/plugin.json Claude Code plugin manifest
.github/workflows/ci.yml   validation, setup tests on Windows and macOS, release zip
```

## CI and releases
Every push validates `app.json`, `SKILL.md` and the scripts, then runs the setup scripts against a fake install on **Windows** and **macOS** runners. Every push to `main` builds `wordcraft-skill.zip` and publishes (or updates) the GitHub release `v1.0.0`.

## Status and caveats
- Windows paths and arguments come from a working install. The macOS paths (`/Applications/WordCraft.app`, CLI location and release asset name) follow the upstream packaging but have **not** been verified on a Mac; the skill marks unverified items and the setup script reports what it could not find.
- WordCraft is a young open-source project; behaviour can change between releases. `list_commands` / `wordcraft-cli commands` is always the source of truth.
- Unofficial community packaging, MIT licensed (see `LICENSE`).
