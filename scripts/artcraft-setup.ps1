<#
.SYNOPSIS
  Windows setup for one ArtCraft app (storytold) + Claude.
.DESCRIPTION
  1. finds the app and its CLI
  2. creates a Desktop shortcut "<App> (Claude)" that starts the app with the control channel on
  3. registers the MCP server in Claude Desktop (classic install and Microsoft Store/MSIX install), backing the config up first
  4. registers it in Claude Code (claude mcp add --scope user) when the claude command exists
  5. installs the skill into %USERPROFILE%\.claude\skills\<id>
  -DryRun prints what would happen and changes nothing.
.EXAMPLE
  .\artcraft-setup.ps1 -Config ..\app.json -Mode both
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$Config,
  [string]$SkillDir = '',
  [ValidateSet('', 'live', 'headless', 'both')][string]$Mode = '',
  [switch]$DryRun,
  [switch]$NoLauncher,
  [switch]$NoClaudeDesktop,
  [switch]$NoClaudeCode,
  [switch]$NoSkill,
  [string]$InstallDir = '',
  [string[]]$ClaudeConfigPath = @()
)
$ErrorActionPreference = 'Stop'
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Say([string]$m)  { Write-Host $m }
function Step([string]$m) { Write-Host ''; Write-Host "== $m" -ForegroundColor Cyan }
function Warn([string]$m) { Write-Host $m -ForegroundColor Yellow }

if (-not (Test-Path -LiteralPath $Config)) { throw "Config not found: $Config" }
$app = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $Config)) | ConvertFrom-Json

# ---------- placeholder expansion
$vars = @{
  home         = $env:USERPROFILE
  documents    = [Environment]::GetFolderPath('MyDocuments')
  pictures     = [Environment]::GetFolderPath('MyPictures')
  music        = [Environment]::GetFolderPath('MyMusic')
  movies       = [Environment]::GetFolderPath('MyVideos')
  appdata      = $env:APPDATA
  ProgramFiles = $env:ProgramFiles
  LocalAppData = $env:LOCALAPPDATA
  port         = "$($app.port)"
}
function Expand-Text([string]$s) {
  if ($null -eq $s) { return '' }
  $pathy = $s -match '^\{(home|documents|pictures|music|movies|appdata|ProgramFiles|LocalAppData)\}'
  $r = [regex]::Replace($s, '\{([A-Za-z]+)\}', { param($m) $k = $m.Groups[1].Value; if ($vars.ContainsKey($k)) { $vars[$k] } else { $m.Value } })
  if ($pathy) { $r = $r.Replace('/', '\') }
  return $r
}
function Expand-List($list) { $o = @(); foreach ($x in @($list)) { if ($null -ne $x) { $o += (Expand-Text ([string]$x)) } }; return ,$o }
function Quote-Arg([string]$a) { if ($a -match '[\s"]') { return '"' + $a.Replace('"', '\"') + '"' } else { return $a } }

$id = $app.id; $name = $app.name
if (-not $Mode) { $Mode = [string]$app.mcp.default }
if (-not $Mode) { $Mode = 'live' }
if (-not $SkillDir) { $SkillDir = Join-Path $scriptDir (Join-Path '..\skills' $id) }
$dry = ''; if ($DryRun) { $dry = ' (dry run)' }
Say "ArtCraft setup for $name ($id) on Windows  mode=$Mode  port=$($app.port)$dry"

# ---------- 1. find app + CLI
Step "1. Find $name"
$dir = $null
$candidates = @()
if ($InstallDir) { $candidates += $InstallDir }
foreach ($d in @($app.windows.dirs)) { $candidates += (Expand-Text $d) }
foreach ($d in $candidates) { if ($d -and (Test-Path -LiteralPath (Join-Path $d $app.windows.app))) { $dir = $d; break } }
$exe = $null; $cli = $null
if ($dir) {
  $exe = Join-Path $dir $app.windows.app
  $cli = Join-Path $dir $app.windows.cli
  Say "   app: $exe"
  if (Test-Path -LiteralPath $cli) { Say "   cli: $cli" } else { Warn "   CLI not found next to the app ($cli): MCP registration will be skipped."; $cli = $null }
} else {
  Warn "   $name is not installed. Install it first: https://github.com/$($app.upstream)/releases/latest (download the Windows .msi)."
}
foreach ($p in @($app.prepare.dirs)) {
  $pd = Expand-Text $p
  if ($pd) { Say "   folder: $pd"; if (-not $DryRun -and -not (Test-Path -LiteralPath $pd)) { New-Item -ItemType Directory -Path $pd -Force | Out-Null } }
}

# ---------- 2. launcher
Step "2. Desktop shortcut `"$name (Claude)`""
$launchArgs = Expand-List $app.launch.args
$argString = (($launchArgs | ForEach-Object { Quote-Arg $_ }) -join ' ')
if ($NoLauncher) { Say '   skipped (-NoLauncher)' }
elseif (-not $exe) { Say '   skipped: app not installed' }
else {
  $desktop = [Environment]::GetFolderPath('Desktop')
  if (-not $desktop -or -not (Test-Path -LiteralPath $desktop)) { $desktop = Join-Path $env:USERPROFILE 'Desktop' }
  $lnk = Join-Path $desktop "$name (Claude).lnk"
  Say "   $lnk  ->  `"$exe`" $argString"
  if (-not $DryRun) {
    if (Test-Path -LiteralPath $lnk) { Remove-Item -LiteralPath $lnk -Force }
    $sh = New-Object -ComObject WScript.Shell
    $l = $sh.CreateShortcut($lnk)
    $l.TargetPath = $exe
    $l.Arguments = $argString
    $l.WorkingDirectory = $dir
    $l.IconLocation = "$exe,0"
    $l.Description = "$name with the control channel enabled for Claude"
    $l.Save()
  }
}

# ---------- 3. Claude Desktop config
$liveArgs = Expand-List $app.mcp.live
$headArgs = Expand-List $app.mcp.headless
$entries = @()
switch ($Mode) {
  'live'     { $entries += ,@([string]$app.mcp.server, 'live') }
  'headless' { $entries += ,@([string]$app.mcp.server, 'headless') }
  'both'     { $entries += ,@([string]$app.mcp.server, 'live'); $entries += ,@(([string]$app.mcp.server + '-headless'), 'headless') }
}

Step '3. Claude Desktop MCP config'
if ($NoClaudeDesktop) { Say '   skipped (-NoClaudeDesktop)' }
elseif (-not $cli) { Say '   skipped: no CLI' }
else {
  $cfgFiles = @()
  if ($ClaudeConfigPath.Count -gt 0) { $cfgFiles = @($ClaudeConfigPath) }
  else {
    $classic = Join-Path $env:APPDATA 'Claude'
    if (Test-Path -LiteralPath $classic) { $cfgFiles += (Join-Path $classic 'claude_desktop_config.json') }
    $pkgRoot = Join-Path $env:LOCALAPPDATA 'Packages'
    if (Test-Path -LiteralPath $pkgRoot) {
      foreach ($pk in @(Get-ChildItem -LiteralPath $pkgRoot -Directory -Filter 'Claude_*' -ErrorAction SilentlyContinue)) {
        $pp = Join-Path $pk.FullName 'LocalCache\Roaming\Claude'
        if (Test-Path -LiteralPath $pp) { $cfgFiles += (Join-Path $pp 'claude_desktop_config.json') }
      }
    }
    if ($cfgFiles.Count -eq 0) { $cfgFiles += (Join-Path $classic 'claude_desktop_config.json'); Warn '   Claude Desktop config folder not found; creating the standard one.' }
  }
  $utf8 = New-Object System.Text.UTF8Encoding($false)
  foreach ($cfgPath in $cfgFiles) {
    Say "   config: $cfgPath"
    $cfg = $null
    if (Test-Path -LiteralPath $cfgPath) {
      if (-not $DryRun) {
        $b = "$cfgPath.backup-" + (Get-Date -Format 'yyyyMMdd-HHmmss')
        Copy-Item -LiteralPath $cfgPath -Destination $b
        Say "   backup: $b"
      }
      $raw = [IO.File]::ReadAllText($cfgPath)
      if ($raw.Trim().Length -gt 0) { $cfg = $raw | ConvertFrom-Json }
    }
    if ($null -eq $cfg) { $cfg = New-Object PSObject }
    if (-not ($cfg.PSObject.Properties.Name -contains 'mcpServers')) { $cfg | Add-Member -NotePropertyName 'mcpServers' -NotePropertyValue (New-Object PSObject) }
    foreach ($e in $entries) {
      $n = $e[0]; $m = $e[1]
      if ($m -eq 'live') { $a = $liveArgs } else { $a = $headArgs }
      $entry = New-Object PSObject -Property @{ command = $cli; args = [object[]]$a }
      Say ("   mcpServers.{0} = {1} {2}" -f $n, $cli, ($a -join ' '))
      if ($cfg.mcpServers.PSObject.Properties.Name -contains $n) { $cfg.mcpServers.$n = $entry } else { $cfg.mcpServers | Add-Member -NotePropertyName $n -NotePropertyValue $entry }
    }
    if (-not $DryRun) {
      $parent = Split-Path -Parent $cfgPath
      if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
      [IO.File]::WriteAllText($cfgPath, ($cfg | ConvertTo-Json -Depth 32), $utf8)
    }
  }
}

# ---------- 4. Claude Code
Step '4. Claude Code MCP registration'
if ($NoClaudeCode) { Say '   skipped (-NoClaudeCode)' }
elseif (-not $cli) { Say '   skipped: no CLI' }
elseif (-not (Get-Command claude -ErrorAction SilentlyContinue)) { Say "   'claude' command not found - skipping (install Claude Code, then re-run)." }
else {
  foreach ($e in $entries) {
    $n = $e[0]; $m = $e[1]
    if ($m -eq 'live') { $a = $liveArgs } else { $a = $headArgs }
    Say ("   claude mcp add --scope user {0} -- {1} {2}" -f $n, $cli, ($a -join ' '))
    if (-not $DryRun) {
      try { & claude @('mcp', 'remove', '--scope', 'user', $n) 2>&1 | Out-Null } catch {}
      & claude (@('mcp', 'add', '--scope', 'user', $n, '--', $cli) + $a)
    }
  }
}

# ---------- 5. skill
Step '5. Skill for Claude Code'
if ($NoSkill) { Say '   skipped (-NoSkill)' }
elseif (-not (Test-Path -LiteralPath (Join-Path $SkillDir 'SKILL.md'))) { Say "   skipped: $SkillDir\SKILL.md not found" }
else {
  $dest = Join-Path $env:USERPROFILE ".claude\skills\$id"
  Say "   $SkillDir  ->  $dest"
  if (-not $DryRun) {
    New-Item -ItemType Directory -Path (Split-Path -Parent $dest) -Force | Out-Null
    if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force }
    Copy-Item -LiteralPath $SkillDir -Destination $dest -Recurse
  }
}

Step 'Done'
Say '  1. Fully quit Claude (tray icon > Quit) and open it again so it reads the new MCP configuration.'
Say "  2. Start $name with the Desktop shortcut `"$name (Claude)`" BEFORE asking Claude to use it."
Say "  3. Ask Claude: `"list the $name commands`". If it answers, the MCP server is connected."
Say "  Claude app (claude.ai / desktop): upload the skill zip from https://github.com/Vinciux99/$id-claude-skill/releases/latest"
Say '  (Customize > Skills > + > Create skill > Upload a skill).'
