---
name: wordcraft
description: Write, format, review and export documents (.docx, PDF) with WordCraft (Word-style, ArtCraft suite) through MCP, the CLI or the control channel, and set up, connect or troubleshoot its MCP server on Windows and macOS.
---

# WordCraft for Claude

WordCraft (ArtCraft suite, storytold/wordcraft) is a clean-room, open-source Rust reimplementation of **Microsoft Word**: ribbon, styles, lists, tables, headers/footers, table of contents, notes, citations, tracked changes, comments, mail merge. It reads and writes **.docx** (also .odt, .rtf, .html, .md, .tex, .txt, .json; opens legacy .doc 97-2003 read-only; Word 2003 XML / Flat OPC `.xml`) and exports **PDF** with selectable text and PNG. Status: **alpha** (roughly 60% of Word for real work; Word charts and SmartArt are read-only).

**Every action is a command** with an `id` (e.g. `format.bold`, `insert.table`) and JSON parameters. Ribbon, shortcuts, command search, CLI, control channel and MCP call the same registry (README: 422 commands; docs/mcp.md says "over 270", outdated). Programmatic calls **never open dialogs**.

## Quick check: is the MCP server connected?

1. Look at the tools you have. If tools from the MCP server `wordcraft` are available (for example `list_commands`, `execute` or `inspect_*` tools) the server is connected: skip to "Operating knowledge" below and use them directly.
2. If they are missing, check whether the user installed it under the name `wordcraft` or `wordcraft-headless`. In Claude Desktop the server may show as **disconnected**.
3. **Most common cause of "disconnected":** the live server (`mcp --connect 127.0.0.1:{port}`) exits when WordCraft is not running at the moment Claude starts. Fix: open WordCraft with the **"WordCraft (Claude)" launcher** (it starts the app with its control channel on), then re-enable the server in Claude's settings or fully quit and reopen Claude.
4. If the user does not need to watch the app live, **headless mode** always starts (no window, works on files). See "Live, headless or both".
5. If nothing is configured yet, follow "Set up the MCP server" below. Ask the user which OS they use if you do not know.

## Set up the MCP server (guide the user)

Walk the user through this step by step. Ask for the OS (Windows or macOS) first. If you have a shell on the user's machine you may run the steps yourself, but **ask before editing any config file and always back it up first**. Never print tokens or keys in chat.

### 1. Prerequisites
- Install WordCraft from its upstream releases page: https://github.com/storytold/wordcraft/releases (Windows: the `.msi` installer; macOS: the `.dmg`, then drag the app to `/Applications`).
- Install Claude Desktop and/or Claude Code. For Claude Desktop, fully quit and reopen it after any config change.
- The MCP server is the **CLI** that ships with the app: `wordcraft-cli`. Windows installs it next to the app (`C:\Program Files\WordCraft\wordcraft-cli.exe`, not on `PATH`). On macOS the CLI is a separate release download (asset `wordcraft-cli-<version>-macos-universal.zip`) unless it is bundled in the app (unverified): the setup script below fetches it into `~/.artcraft/bin/` and clears the macOS quarantine flag.
- Upstream docs use port 7981; this kit uses **7987** so that all 13 ArtCraft apps can run together without clashing.

### 2. Option A: automatic setup (recommended)
The setup script finds the app and CLI, creates the launcher, backs up and updates Claude Desktop's config, registers the server in Claude Code (if the `claude` command exists) and installs this skill. Preview first with a dry run: nothing is changed.

Windows (PowerShell):
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "& ([scriptblock]::Create((irm https://raw.githubusercontent.com/Vinciux99/artcraft-claude-skills/main/install.ps1))) -Apps wordcraft"
```
macOS (Terminal):
```sh
curl -fsSL https://raw.githubusercontent.com/Vinciux99/artcraft-claude-skills/main/install.sh | bash -s -- --apps wordcraft
```
Or clone/download this repository and double-click `setup-windows.cmd` (Windows) or `setup-macos.command` (macOS; first time: right-click, Open). Useful options: `-Mode live|headless|both` / `--mode ...` (default `live`; `both` registers `wordcraft` live and `wordcraft-headless`), `-DryRun` / `--dry-run`, `-NoLauncher`, `-NoClaudeDesktop`, `-NoClaudeCode`, `-NoSkill` (macOS: `--no-launcher`, `--no-claude-desktop`, `--no-claude-code`, `--no-skill`).

What it changes: Claude Desktop config (`%APPDATA%\Claude\claude_desktop_config.json` plus the Microsoft Store/MSIX copy under `%LOCALAPPDATA%\Packages\Claude_*\LocalCache\Roaming\Claude\`; macOS `~/Library/Application Support/Claude/claude_desktop_config.json`; backup saved next to it as `<file>.backup-<timestamp>`), the launcher "WordCraft (Claude)" (Windows: Desktop shortcut; macOS: `~/Applications/WordCraft (Claude).app` plus a Desktop alias), Claude Code's user-scope MCP list, and `~/.claude/skills/wordcraft/`.

### 3. Option B: manual setup
**Windows** - edit `%APPDATA%\Claude\claude_desktop_config.json` (if Claude was installed from the Microsoft Store, also the copy under `%LOCALAPPDATA%\Packages\Claude_*\LocalCache\Roaming\Claude\`). Keep other servers; add this inside `mcpServers`. Backslashes must be doubled in JSON.
```json
{
  "mcpServers": {
    "wordcraft": {
      "command": "C:\\Program Files\\WordCraft\\wordcraft-cli.exe",
      "args": [
        "mcp",
        "--connect",
        "127.0.0.1:7987"
      ]
    },
    "wordcraft-headless": {
      "command": "C:\\Program Files\\WordCraft\\wordcraft-cli.exe",
      "args": [
        "mcp",
        "--author",
        "AI assistant"
      ]
    }
  }
}
```
**macOS** - edit `~/Library/Application Support/Claude/claude_desktop_config.json`. Use the absolute CLI path (replace `YOUR_NAME`; JSON does not expand `~`). The CLI path is unverified if your install differs: check with `ls ~/.artcraft/bin /Applications/WordCraft.app/Contents/MacOS`.
```json
{
  "mcpServers": {
    "wordcraft": {
      "command": "/Users/YOUR_NAME/.artcraft/bin/wordcraft-cli",
      "args": [
        "mcp",
        "--connect",
        "127.0.0.1:7987"
      ]
    },
    "wordcraft-headless": {
      "command": "/Users/YOUR_NAME/.artcraft/bin/wordcraft-cli",
      "args": [
        "mcp",
        "--author",
        "AI assistant"
      ]
    }
  }
}
```
**Launcher** (starts the app with the control channel; needed before the live server can connect):
- Windows: create a Desktop shortcut named "WordCraft (Claude)" with target `"C:\Program Files\WordCraft\wordcraft.exe" --control 7987`
- macOS: run `open -n -a "/Applications/WordCraft.app" --args --control 7987`, or save it as an app with Script Editor/`osacompile` (the setup script does this for you).

**Claude Code** (any OS; run once):
Windows (PowerShell):
```powershell
claude mcp add --scope user wordcraft -- "C:\Program Files\WordCraft\wordcraft-cli.exe" mcp --connect 127.0.0.1:7987
claude mcp add --scope user wordcraft-headless -- "C:\Program Files\WordCraft\wordcraft-cli.exe" mcp --author "AI assistant"
```
macOS (Terminal):
```sh
claude mcp add --scope user wordcraft -- "$HOME/.artcraft/bin/wordcraft-cli" mcp --connect 127.0.0.1:7987
claude mcp add --scope user wordcraft-headless -- "$HOME/.artcraft/bin/wordcraft-cli" mcp --author "AI assistant"
```
Check with `claude mcp list`.

### 4. Authentication
The app writes a fresh random key file at every start (`control-key.local-7987` inside its settings folder). `wordcraft-cli mcp --connect` reads it by itself, so there is nothing to create by hand. Never print the key in chat.

### 5. Finish and verify
1. **Fully quit and reopen Claude** (Desktop: quit from the tray/menu bar, not just close the window).
2. Open WordCraft with the **"WordCraft (Claude)" launcher** before asking Claude to use it.
3. In Claude, confirm the server `wordcraft` is connected and call its `list_commands` tool (or equivalent). A non-empty command list means it works.

### Live, headless or both
- **Live** (`wordcraft`): drives the open app; the user sees every change and screenshots/UI tools work. Needs the launcher first.
- **Headless** (`wordcraft-headless`): in-process engine, no window; always starts; works on files; UI/screenshot tools are not available.
- **Both**: register both and pick per task. Switch with `-Mode` / `--mode`, or by editing the config entries above.

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Server shows "disconnected" right after Claude starts | Live server exits when WordCraft is not running | Open WordCraft with the "WordCraft (Claude)" launcher, then re-enable the server or restart Claude; or use headless mode |
| "Port already in use" / app opens but Claude cannot connect | Another app or an old WordCraft instance holds port 7987 | Quit all WordCraft windows, check the launcher uses the kit port, make sure no other ArtCraft app uses the same port |
| `command not found` / spawn error | CLI path wrong or the CLI is not installed (Windows: not on `PATH`; macOS: separate download) | Use the full absolute path in the config; macOS: run the setup script (it downloads the CLI to `~/.artcraft/bin/`) |
| macOS: "cannot be opened because the developer cannot be verified" | Gatekeeper/quarantine on the app or CLI | Right-click the app, Open; for the CLI: `xattr -dr com.apple.quarantine ~/.artcraft/bin/wordcraft-cli` |
| `unauthorized` / token or key errors | Auth file missing or stale (key-file) | Restart the app with the launcher so it writes a fresh file; never paste the secret in chat |
| Config edited but nothing changed (Windows) | Claude installed from the Microsoft Store reads the MSIX copy of the config | Edit/update `%LOCALAPPDATA%\Packages\Claude_*\LocalCache\Roaming\Claude\claude_desktop_config.json` too |
| JSON config error / server not listed | Unescaped backslashes or trailing comma | Double the backslashes on Windows; validate the JSON; restore the `.backup-*` file if needed |
| App crashes on start or window is blank | Graphics backend problem | Windows: set `WGPU_BACKEND=vulkan` (or `dx12`) for one launch; avoid `gl` on some AMD drivers |
| Changes do not appear in the window | You are on the headless server | Use the live server (launcher first) |
| Quotes disappear in PowerShell JSON arguments | Windows PowerShell 5.1 quoting for `.exe` | Use `--script`/files where the CLI supports them, or single-quote the whole JSON |

## Operating knowledge

## App, settings, environment
- **Settings:** Windows `%APPDATA%\WordCraft\` (preferences, `fonts\` added with `font.add`); macOS `~/Library/Application Support/WordCraft` (unverified).
- **Log:** `<settings>/logs/wordcraft.log` (`wordcraft.1.log` / `.2.log` = previous launches; max 16 MiB). Document text is never logged.
- **Control key file:** Windows `%APPDATA%\WordCraft\control-key.local-7987`. The **app writes it** at launch with `--control 7987` and deletes it on close; new at every launch. The macOS location is unverified (likely under `~/Library/Application Support/WordCraft`).
- **Key:** no need to create files by hand: the app generates the key in that file and `wordcraft-cli mcp --connect` reads it by itself. Alternatively pass it with `WORDCRAFT_CONTROL_KEY`.
- **Other app options:** `--sample` (opens the sample document "The Open Studio Handbook"), `--version`, a file path as argument. With `--control` the Start screen is not shown (docs/ui-parity.md). If `document.inspect` then says `no document is open`, run `file.new` or `file.open`. Others: check `wordcraft --help` (undocumented).

| Variable | Effect |
|---|---|
| `WORDCRAFT_CONTROL_PORT=7987` | same as `--control 7987` |
| `WORDCRAFT_CONTROL_KEY` | key used by `wordcraft-cli mcp --connect` instead of the file |
| `WORDCRAFT_NO_PREFS` | no preferences read/written, log to stderr only (test runs) |
| `WORDCRAFT_SPEECH=off` | mute Read Aloud |
| `RUST_LOG` | log level, e.g. `debug`, `warn,wordcraft_docx=trace`, `wordcraft*=debug` |
| `WGPU_BACKEND` (`dx12` default, `vulkan`, `gl`), `WGPU_DX12_COMPILER` (`fxc` default, `dxc`, `auto`) | if the app does not open or crashes at startup (AMD driver `atio6axx.dll`, "Parent device is lost") |

## Connecting

| Mode | How to start | What it does |
|---|---|---|
| **MCP headless** | `wordcraft-cli mcp [--author NAME] [--automation-read-root DIR] [--automation-write-root DIR]` | in-process engine, no window; stdio |
| **MCP attached to the app** | app with `--control 7987`, then `wordcraft-cli mcp --connect 127.0.0.1:7987` | works on the app's session (edits visible live); enables `screenshot`, `click`, `key`, `ui_inspect` |
| **CLI** | `wordcraft-cli convert / text / info / inspect / render / run / commands / parity / zotero` | one-shot headless jobs |
| **Control channel** | `wordcraft --control 7987` (or `WORDCRAFT_CONTROL_PORT`) | JSON lines over TCP `127.0.0.1:7987`, with key |

- **Port:** upstream docs use **7981**, the kit uses **7987** so it does not collide with DesignCraft (7981). The other ArtCraft kit ports (9876, 9877, 7878, 7979-7990 except 7987) belong to other apps.
- **Authentication: yes.** Random 256-bit key (hex) per window, see "Control channel". `--connect` sends it **only** to loopback addresses (`127.0.0.0/8`, `::1`, `localhost`) and re-reads it on every new connection. Always give `HOST:PORT` (the port is needed to find the key file).
- **Automation roots** (headless only): `--automation-read-root DIR` / `--automation-write-root DIR` (also `--flag=DIR`, once each; folders must exist). Every file read (`open_document`, `file.open`, `file.newFromTemplate`, `insert.textFromFile`, `insert.object`, `insert.picture`/`picture.change` with `path`, `mailings.recipients`, `review.compare`, `tools.updateStyles`, `styles.organizer`, `styles.copyFrom`) must be inside the read root; every file written (`save_document`, `file.save`, `file.saveAs`, `file.exportPdf`, `file.exportPng`, `file.printPdf`, `file.saveTemplate`, `mailings.finish` with `path`) inside the write root. An omitted root = no access of that kind. On Windows comparison ignores case; `CON`, `NUL`, `COM1`... rejected. Readable error, e.g. `automation path rejected: outside the write root ...`.
- **`--connect` + roots = error**, and `--connect` + `--author` = error (with the app use `file.setAuthor`). **The desktop app is not confined** by any root.

### Choose the channel
1. **MCP server available** (tools `list_commands`, `execute`, ...) -> use it: it is attached to the app, so the user sees the work in the window.
2. **Shell on the user's machine** (PowerShell/cmd/bash) -> CLI with full path (`run` with several `--cmd`, `convert`). Mind JSON quoting in PowerShell: single quotes around `'id={"k":"v"}'`.
3. **A cloud/Linux sandbox cannot run the user's app or reach its `127.0.0.1:7987`.** There you can only prepare files (text, Markdown, CSV for mail merge, images).
4. **Fallback: computer use** on the GUI. Non-US keyboards: shortcuts with `[` `]` and other AltGr keys may not arrive; use the ribbon and Alt+Q (command search).

## Basic rules
- **Positions:** `{"story": "body" | {"part": n}, "path": [block, row, cell, block, ...], "off": byteOffset}`. `path` addresses the block (paragraph or table) by index; inside a table it continues with row, cell, block. **`off` is in UTF-8 bytes**, not characters: accented letters like `e`-grave count 2 bytes, em dash and curly apostrophe 3. Non-body stories (headers, footers, notes) are `{"part": n}`: indexes from `inspect_document` (`parts`).
- **Select by text** (safest way): `select_text {"text", "occurrence"}` (1-based) = `select.text`. `type_text` replaces the selection.
- **Paragraphs:** `\n` inside `text.insert` does NOT create paragraphs: use `text.newParagraph` or `type_text {"paragraphs": true}`.
- **Styles:** `para.style {"style": "Heading 1"}` accepts the name; `inspect_document` returns the id (`"Heading1"`), and `styles.modify` uses the id (`"style": "Heading1"`).
- **Properties:** `format.set {"props": CharProps}`, `para.set {"props": ParaProps}` (tables below). Lengths in **points**; colors `"RRGGBB"`, `"#RRGGBB"` or `[r,g,b]` (read back as `[r,g,b]`).
- **Parameters are NOT strict:** in CharProps/ParaProps an unknown field is **ignored**, not rejected: check spelling and re-read with `inspect_document`. CLI options, instead, are validated (`unknown option`).
- **Errors:** a failed command leaves the document unchanged.
- **Undo:** every command is a step (snapshot in `Session::run`); `edit.undoHistory` (most recent first, max 100), `edit.undoTo {"count": n}`. Other ids (simple undo/redo): `list_commands {"query": "undo"}`.
- **Batch:** runs in order and stops at the first error unless `keepGoing: true`. **No `$N` references** between commands: to use a step's result, call it alone and read the response. Not documented as a single undo step.
- **Tracked changes and comments:** recorded under the session user ("WordCraft User" by default). Name the agent: `--author "Claude (copyedit)"` (headless/`run`) or `file.setAuthor {"name": "Claude (copyedit)"}`. Turn tracking on **explicitly** with `review.trackChanges {"value": true}`: without `value` it toggles, and in a document saved with tracking on it turns it **off**.
- **Proofing language:** per run (`lang` BCP 47, e.g. `en-US`); spelling uses a system-installed Hunspell dictionary (may be missing on Windows: verify).
- **Pitfalls:** MCP `list_commands` help filters only id/label/location; the channel's `engine.commands {"search"}` also searches parameter descriptions. Proprietary fonts (Calibri, Cambria...) are rendered with metric-compatible substitutes. A .docx with Word charts/SmartArt risks loss on save (beta not reached yet).

### CharProps (`format.set`, `styles.modify.chr`)

`style`, `font`, `size` (pt), `bold`, `italic`, `strike`, `doubleStrike`, `caps`, `smallCaps`, `hidden`, `outline`, `shadow`, `emboss`, `engrave`, `noProof`; `underline` (`none|single|words|double|thick|dotted|dash|dotDash|dotDotDash|wave|doubleWave`), `underlineColor`; `color` (`"Auto"` or color or `{"Rgb": color}`); `highlight` (`none|yellow|brightGreen|turquoise|pink|blue|red|darkBlue|teal|green|violet|darkRed|darkYellow|gray50|gray25|black|white`); `shading`; `border` (Border); `vertAlign` (`baseline|superscript|subscript`); `spacing`, `position`, `kern` (pt); `scale` (%); `textEffects`; `lang`; `rtl`, `cs`, `fontCs`, `fontEa`, `sizeCs`, `boldCs`, `italicCs`, `langBidi`; `link` (URL or `#bookmark`); `ins`/`del`/`fmtChange` (revision bookkeeping). `format.set` also copies `size`/`bold`/`italic` to the `*Cs` fields; `styles.modify` sets only what it receives.

**Border** = `{"style": none|single|double|dotted|dashed|thick|triple|dotDash|wave, "width": pt, "color": color|null, "space": pt}` (needs `width` > 0 to be visible).

### ParaProps (`para.set`, `styles.modify.para`, `para` of `table.newStyle`/`table.modifyStyle`)

`style`; `align` (`left|center|right|justify|distribute`); `indentLeft`, `indentRight`, `indentFirst` (pt, negative = hanging) and `indentLeftChars`/`indentRightChars`/`indentFirstChars`; `spaceBefore`, `spaceAfter` (pt); `lineSpacing` `{"rule": "multiple"|"atLeast"|"exactly", "value": n}`; `contextualSpacing`, `mirrorIndents`, `keepNext`, `keepLines`, `pageBreakBefore`, `widowControl`; `outlineLevel` (0-8 = levels 1-9, 9 = body); `numbering` `{"num": n, "level": n}` (both required, `num` 0 removes the style's numbering); `tabs` `[{"pos": pt, "align"?, "leader"?: none|dot|hyphen|underscore|middleDot}]`; `shading`; `borders` `{top,left,bottom,right,between}`; `suppressHyphens`, `suppressLineNumbers`; `bidi`; `dropCap` (lines); East-Asian typography options (`kinsoku`, `wordWrap`, `overflowPunct`, `autoSpaceDE`, `autoSpaceDN`, `snapToGrid`, `topLinePunct`).

## MCP tools (16)

| Tool | Arguments | Notes |
|---|---|---|
| `list_commands` | `query?` | all commands: id, label, ribbon location, shortcut, params; case-insensitive filter on id/label/location |
| `execute` | `command`, `params?` | one command: `{command: "insert.table", params: {rows: 3, cols: 4}}` |
| `batch` | `commands: [{command, params?}]`, `keepGoing?` | in order; stops at the first error |
| `new_document` | `template?` | `blank` (default), `sample`, `letter`, `resume`, `report` (= `file.new`) |
| `open_document` | `path` | docx, doc (open only), odt, rtf, md, tex, html, txt, json; other text files as plain text (= `file.open`) |
| `save_document` | `path?` | format from extension: docx, pdf, odt, rtf, html, md, tex, txt, png (png -> `file.exportPng`); without `path` saves in place |
| `type_text` | `text`, `paragraphs?` | types at the caret replacing the selection (`text.insert` with `raw: true`) |
| `select_text` | `text`, `occurrence?` | selects the n-th occurrence (1-based) |
| `get_text` | none | plain body text (`document.text`) |
| `inspect_document` | none | blocks (text, style, runs with formatting, lists, tables), sections, parts, selection, pages |
| `render_page` | `page?` (1-based), `scale?` (px per point, default 1) | page PNG returned inline (no temp file) |
| `parity` | none | feature coverage versus Word |
| `screenshot` | none | app only (`--connect`): window PNG, inline |
| `click` | `x`, `y`, `count?` (1-3), `shift?`, `cmd?` | app only; window coordinates |
| `key` | `key`, `shift?`, `alt?`, `cmd?` | app only; e.g. `{key: "B", cmd: true}` (cmd = Ctrl on Windows) |
| `ui_inspect` | none | app only: tab, panels, dialog, on-screen page rects, caret |

**Resources:** `wordcraft://document` (= `document.inspect`) and `wordcraft://commands` (= `engine.commands`). No prompts. The server instructions summarize the flow: new_document -> type_text -> execute text.newParagraph -> execute para.style -> select_text -> execute format.bold -> inspect_document -> render_page -> save.

## Recipes

**Formatted document (from the MCP acceptance test):**

```json
{"tool": "new_document", "args": {}}
{"tool": "type_text", "args": {"text": "Quarterly Report"}}
{"tool": "execute", "args": {"command": "para.style", "params": {"style": "Heading 1"}}}
{"tool": "execute", "args": {"command": "text.newParagraph"}}
{"tool": "type_text", "args": {"text": "Sales grew strongly this quarter.\nCosts fell.", "paragraphs": true}}
{"tool": "select_text", "args": {"text": "strongly"}}
{"tool": "execute", "args": {"command": "format.bold"}}
{"tool": "batch", "args": {"commands": [{"command": "caret.docEnd"}, {"command": "insert.table", "params": {"rows": 2, "cols": 2}}]}}
{"tool": "inspect_document", "args": {}}
```

**Modify a style:**

```json
{"command": "styles.modify", "params": {"style": "Heading1",
  "chr": {"font": "Georgia", "size": 18, "bold": true, "color": "1B1611"},
  "para": {"spaceBefore": 12, "lineSpacing": {"rule": "multiple", "value": 1.15}, "keepNext": true}}}
```

**Direct formatting:** `select_text {"text": "important"}` then `execute format.set {"props": {"highlight": "yellow", "color": "C00000"}}`; paragraph: `execute para.set {"props": {"align": "justify", "spaceAfter": 6}}`.

**Hyperlink:** select the text, then `format.set {"props": {"link": "https://example.com"}}` (the `link` field is documented in CharProps; if a dedicated command exists: `list_commands {"query": "link"}`).

**Picture:** `execute insert.picture {"path": "/path/to/photo.png"}` (`path` documented; other params: check with `list_commands {"query": "picture"}`); replace: `picture.change {"path": ...}`.

**Find and replace:** command `edit.findReplace` (supports regex per the README), but its params are not in the docs: `list_commands {"query": "findReplace"}` before using it. For a single occurrence `select_text` + `type_text` is enough.

**Agent tracked-changes review:**

```json
{"command": "file.setAuthor", "params": {"name": "Claude (copyedit)"}}
{"command": "review.trackChanges", "params": {"value": true}}
```

then `select_text` + `type_text` for the corrections. Accept/reject and comments: ids not in the docs, find them with `list_commands {"query": "accept"}` / `{"query": "comment"}`. Display options: `review.trackingOptions`. Compare: `review.compare {"path": ..., "original": ...}`.

**Exports:** `save_document {"path": ".../out.docx"}` / `.pdf` / `.odt` / `.md` / `.png`; `file.save {"path": ".../out.xml", "format": "wordml2003"}`; `markup: true` on save/export commands prints margin comments (Print Markup); `file.exportPdf`, `file.printPdf`, `file.exportPng` have params to check with `list_commands`.

**Mail merge:** `mailings.recipients {"path": ".../recipients.csv"}` (csv, tsv, txt, xlsx, xlsm, ods), fields via `list_commands {"query": "mailings"}`, then `mailings.finish {"path": ".../merged.docx"}`.

**Undo the last steps:** `edit.undoHistory`, then `edit.undoTo {"count": 3}`.

**Extra fonts:** `font.add` / `font.list` / `font.remove` (TTF/OTF/TTC/WOFF/WOFF2, max 50 MB; params: check).

**Interface (app only):** `ui.language {"value": "en"}`, `ui.theme {"value": "dark"}`, `ui.tab`, `view.zoom`.

## CLI

```powershell
$wc = "C:\Program Files\WordCraft\wordcraft-cli.exe"
& $wc convert report.docx report.pdf            # docx, doc [read], pdf, odt, rtf, html, md, tex, txt, json, png, xml
& $wc convert report.docx report.pdf --markup   # margin comments and revisions in the PDF/PNG
& $wc convert report.docx report.xml --format wordml2003   # or flatopc
& $wc text report.docx                          # plain text (with list labels)
& $wc info report.docx                          # pages, words, paragraphs, properties (JSON)
& $wc inspect report.docx                       # structure (JSON)
& $wc render report.docx p1.png --page 1 --scale 2
& $wc run --template sample --cmd 'select.text={"text":"Membership"}' --cmd format.bold --save out.docx
& $wc run --file in.docx --author "Claude" --cmd 'review.trackChanges={"value":true}' --cmd ... --save out.docx --print
& $wc commands [--json]                         # all commands (--json with params)
& $wc parity [--markdown]
& $wc mcp [--connect HOST:PORT | --author NAME] [--automation-read-root DIR] [--automation-write-root DIR]
& $wc zotero refresh paper.docx --save paper.docx [--trace] [--port P]   # Zotero must be open
& $wc --version
```

- `run`: `--file F` or `--template T` (blank/sample/letter/resume/report), then repeated `--cmd 'id={json}'` (without `=` -> params `{}`), `--save OUT` (`.png` uses `--page`/`--scale`), `--print` prints each command's result.
- A failed `--cmd` aborts with `id: error` and a non-zero exit code; nothing is saved.
- `zotero` commands: `addEditCitation`, `addEditBibliography`, `addNote`, `refresh`, `removeCodes`, `setDocPrefs`.

## Control channel

- **Transport:** TCP on `127.0.0.1:<port>` only, one JSON object per line -> one response line. Request `{"id": 1, "key": "...", "method": "engine.execute", "params": {"command": "text.insert", "params": {"text": "Hello"}}}`; response `{"id": 1, "ok": true, "result": {...}}` or `{"id": ..., "ok": false, "error": "message"}`.
- **Key:** in every request as top-level `"key"`, or once per connection with `{"method": "auth", "key": "..."}` -> `{"ok": true, "result": {}}`. Wrong/missing key -> `unauthorized` and the connection closes. (Only `auth` reads `params.key`; for `ui.key`, `params.key` is the key to press.)
- **Limits:** line > 1 MiB -> `line too long` and close; invalid JSON -> one error and close (reconnect); no authorized request within 30 s of accept -> close; the app answers within ~60 s.
- **No open document:** `document.inspect` and `ui.render` say there is no document -> `file.new`/`file.open`.
- Any other method name is treated as a command id: `{"method": "format.bold"}`.

| Method | Parameters | Result |
|---|---|---|
| `engine.execute` | `command`, `params` | command result (also `ui.*`) |
| `engine.commands` | `search?` | id, label, location, shortcut, params, enabled |
| `document.inspect` | `text?` | blocks, parts, sections, selection, pages |
| `ui.inspect` | none | UI state, view, dialog, window, page rects, caret, comment `balloons` (id + rect), perf, `dirty` |
| `ui.click` | `x`, `y`, `button?`, `count?`, `shift?`, `cmd?`, `alt?` | real click in window coordinates |
| `ui.clickText` | `page` (0-based), `x`, `y` (pt from page corner), `count?` | click inside a page |
| `ui.move` / `ui.drag` | `x`,`y` / `x`,`y`,`toX`,`toY`,`steps?` | move / drag |
| `ui.press` / `ui.release` | `x`, `y`, modifiers | button down / up |
| `ui.wheel` | `x`, `y`, `dy`, `dx?`, `unit?` (`point|line|page`), `phase?` | scroll (`dy` < 0 scrolls down) |
| `ui.key` | `key` (`B`, `Enter`, `Left`...), `shift?`, `alt?`, `cmd?` | key via egui (shortcuts active) |
| `ui.text` | `text` | text typed via egui |
| `ui.screenshot` | `path?` | window PNG (without `path`: base64 `png`) |
| `ui.render` | `path?`, `page?` (1-based), `scale?` | page PNG from the engine |
| `ui.parity` | none | catalog parity |
| `ui.resize` / `ui.focus` / `app.quit` | | window control |

Example PowerShell (app started with the "WordCraft (Claude)" launcher):

```powershell
$port = 7987
$key = (Get-Content "$env:APPDATA\WordCraft\control-key.local-$port" -Raw).Trim()
$c = New-Object System.Net.Sockets.TcpClient('127.0.0.1', $port); $s = $c.GetStream()
$w = New-Object System.IO.StreamWriter($s); $w.AutoFlush = $true; $r = New-Object System.IO.StreamReader($s)
$w.WriteLine((@{id=1; method='auth'; key=$key} | ConvertTo-Json -Compress)); $r.ReadLine()
$w.WriteLine('{"id":2,"method":"engine.execute","params":{"command":"text.insert","params":{"text":"Hello"}}}'); $r.ReadLine()
$c.Close()
```

Native printing: `ui.printSettings` (`{}` reads, `{"refresh": true}` discovers printers; `printer`, `copies` 1-999, `duplex` `printerDefault|off|longEdge|shortEdge`, `grayscale`), `ui.printSubmit` (also `range`, `pages`, `parity`, `copies`, `collate`) sends **without a dialog**: only with the user's explicit OK.

## Commands by family

Only ids cited in the docs; for the rest use `list_commands {"query": ...}`, `engine.commands {"search": ...}`, `tools.search` or `wordcraft-cli commands --json`.

- **file.\***: `new {template}`, `open {path}`, `save {path?, format?, markup?}`, `saveAs`, `exportPdf`, `exportPng`, `printPdf`, `printMarkup`, `saveTemplate`, `newFromTemplate`, `info`, `setAuthor {name}`, `options` (e.g. `{"region": "pl-PL"}` or `"auto"`), `privacy`, `privacyOptions`
- **edit.\***: `findReplace`, `goto` (`pageBy`), `undoTo {count}`, `undoHistory`
- **text.\* / select.\* / caret.\***: `text.insert {text}`, `text.newParagraph`; `select.text {text, occurrence}`, `select.line {pos}`, `select.dragUnit`; `caret.docEnd`, `caret.pastCitation`
- **format.\* / para.\* / styles.\* / list.\* / font.\***: `format.bold`, `format.set {props}`, `format.font {eastAsia}`; `para.style {style}`, `para.set {props}`; `styles.modify {style, chr?, para?}`, `styles.organizer`, `styles.copyFrom`; `list.define`; `font.add`, `font.list`, `font.remove`
- **insert.\* / picture.\* / arrange.\***: `insert.table {rows, cols}`, `insert.picture {path}`, `insert.textFromFile`, `insert.object`, `insert.chart`; `picture.change {path}`; `arrange.moveWithText`
- **table.\***: `newStyle`, `modifyStyle`, `selectAt`, `insertAt`, `selectColumn`, `fitColumn`, `moveDrag`, `resizeDrag`, `rtl`; **layout.\***: `sectionRtl`
- **references.\***: `updateAuthorities` (table of contents, notes, citations, captions, index: ids via `list_commands {"query": "references"}`)
- **review.\***: `trackChanges {value}`, `trackingOptions`, `compare {path, original}`, `addToDictionary {word}`, `readAloud`; **readAloud.\***: `playPause`, `next`, `previous`, `stop`, `speed {value}`, `skipCitations {value}`, `status`
- **mailings.\***: `recipients {path}`, `finish {path}`
- **tools.\***: `search`, `recordMacro`, `macros`, `autocorrect`, `customizeKeyboard`, `customizeRibbon`, `updateStyles`
- **view.\***: `zoom`, `hideWhiteSpace`; **document.\***: `text`, `inspect`
- **ui.\*** (app only): `tab`, `dialog`, `backstage`, `language`, `theme`, `interfaceSize`, `animations`, `fileBrowser {purpose}`, `caretAnimation`, `startScreen`, `contextMenu`, `printSettings`, `printSubmit`, `print`; **ui.zotero.\***: `addEditCitation`, `addEditBibliography`, `addNote`, `refresh`, `setDocPrefs`, `removeCodes`, `status`, `answer {button}`
- **Not yet implemented** (catalog): `tools.dictate`, `insert.onlinePicture`, `insert.model3d`, `insert.screenshot`, `insert.video`, `insert.inkEquation`, `addins.get`, `draw.inkToMath`, `review.translate`, `review.blockAuthors`, `view.arrangeAll`, `view.sideBySide`, `view.syncScroll`, `view.switchWindows`.

## Recommended workflow

1. **Orient:** `inspect_document` (or `document.inspect`) and `get_text`; with the app also `ui_inspect`/`screenshot`. If there is no document: `new_document` or `open_document`.
2. **Work on a copy:** for a user's file, open the original and immediately `save_document` under a new name (e.g. `...-edited.docx`), or copy it first. For reviews the user will check: `file.setAuthor` + `review.trackChanges {"value": true}`.
3. **Find the commands:** `list_commands {"query": "..."}` and read `params` before using ids not listed here.
4. **Edit in small steps:** `select_text` + `type_text` / `execute`; `batch` only for sequences already tried.
5. **Verify:** re-read with `get_text` / `inspect_document` (style, runs, `props`) and look at `render_page` (or `wordcraft-cli render`). If something went wrong: `edit.undoHistory` + `edit.undoTo`.
6. **Save/export only with the user's OK**, never over the original; prefer PDF as a preview. Remember .docx files with Word charts/SmartArt can lose content (alpha).
7. **At the end:** the channel has a key but is reachable by any local process that can read the settings folder: quit the app (`app.quit`, only if the work is saved) or reopen it without `--control` when no longer needed.
