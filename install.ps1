# Over9k for Herdr on Windows: install, update or remove (PowerShell 5.1 or 7).
#
#   powershell -ExecutionPolicy Bypass -File install.ps1               install or update
#   powershell -ExecutionPolicy Bypass -File install.ps1 -Uninstall    remove it again
#
# Options:
#   -HerdrHome <dir>  Herdr's home (default: what `herdr-app --help` says, else
#                     $env:HERDR_APP_HOME, else %USERPROFILE%\.config\herdr-app)
#   -NoClaude         leave Claude Code's settings alone (turn things on later in
#                     Over9k's Options instead)
#   -AddGitToPath     put Git for Windows' tools (sh, sed, grep...) on your user
#                     PATH, which Over9k's mods need to run their scripts
#   -Yes              don't ask
#
# Over9k's scripts are POSIX shell: on Windows they run in Git for Windows' sh.
# Needs Git for Windows; jq and Python 3 for some features (see README).
param(
  [string]$HerdrHome = "",
  [switch]$Uninstall,
  [switch]$NoClaude,
  [switch]$AddGitToPath,
  [switch]$Yes
)
$ErrorActionPreference = "Stop"
$here = $PSScriptRoot

function Say($text) { Write-Host $text }
function Ask($question) {
  if ($Yes) { return $true }
  $a = Read-Host "$question [Y/n]"
  return -not ($a -match '^(n|no)$')
}

# Herdr's home: -HerdrHome, what Herdr itself says, $env:HERDR_APP_HOME, or the default.
if (-not $HerdrHome) {
  try {
    $line = (& herdr-app --help 2>$null) | Where-Object { $_ -match '^Home: (\S+)' } | Select-Object -First 1
    if ($line -match '^Home: (\S+)') { $HerdrHome = $Matches[1] -replace '^~', $env:USERPROFILE }
  } catch { }
}
if (-not $HerdrHome) { $HerdrHome = $env:HERDR_APP_HOME }
if (-not $HerdrHome) { $HerdrHome = Join-Path $env:USERPROFILE ".config\herdr-app" }
$modsDir = Join-Path $HerdrHome "mods"
$layoutsDir = Join-Path $HerdrHome "layouts"
# The mods folder as Over9k's scripts get it (forward slashes).
$modsArg = $modsDir -replace '\\', '/'

# Git for Windows' sh: on PATH, else where Git installs it.
$sh = (Get-Command sh -ErrorAction SilentlyContinue).Source
$gitUsrBin = $null
foreach ($root in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, (Join-Path $env:LOCALAPPDATA "Programs"))) {
  if ($root -and (Test-Path (Join-Path $root "Git\usr\bin\sh.exe"))) { $gitUsrBin = Join-Path $root "Git\usr\bin"; break }
}
if (-not $sh -and $gitUsrBin) { $sh = Join-Path $gitUsrBin "sh.exe" }
function Setup([string[]]$arguments) {
  if (-not $sh) { return 1 }
  & $sh (Join-Path $modsDir "over9k-options\setup.sh") @arguments
  return $LASTEXITCODE
}

# JSON objects as ordered hashtables (PowerShell 5.1 has no -AsHashtable).
function ToTable($o) {
  $t = [ordered]@{}
  if ($o) { foreach ($p in $o.PSObject.Properties) { $t[$p.Name] = if ($p.Value -is [System.Management.Automation.PSCustomObject]) { ToTable $p.Value } else { $p.Value } } }
  return $t
}
function ReadJson($path) { if (Test-Path $path) { return ToTable (Get-Content $path -Raw | ConvertFrom-Json) } else { return [ordered]@{} } }
# UTF-8 without a byte-order mark (PowerShell 5.1's UTF8 adds one, which JSON readers may refuse).
function WriteJson($path, $value) { [IO.File]::WriteAllText($path, ($value | ConvertTo-Json -Depth 10), (New-Object Text.UTF8Encoding $false)) }

# Key bindings: Over9k's merged into Herdr's, or taken out again (what they
# replaced is kept in keys.over9k-was.json and given back).
function Keys([string]$how) {
  $ours = ReadJson (Join-Path $here "keys.json")
  $keysPath = Join-Path $HerdrHome "keys.json"
  $wasPath = Join-Path $HerdrHome "keys.over9k-was.json"
  $theirs = ReadJson $keysPath
  $was = ReadJson $wasPath
  if ((Test-Path $keysPath) -and -not (Test-Path "$keysPath.before-over9k")) { Copy-Item $keysPath "$keysPath.before-over9k" }
  foreach ($section in $ours.Keys) {
    if (-not $theirs.Contains($section)) { $theirs[$section] = [ordered]@{} }
    $have = $theirs[$section]
    foreach ($key in $ours[$section].Keys) {
      $action = $ours[$section][$key]
      if ($how -eq "add") {
        if ($have.Contains($key) -and $have[$key] -ne $action) {
          if (-not $was.Contains($section)) { $was[$section] = [ordered]@{} }
          if (-not $was[$section].Contains($key)) { $was[$section][$key] = $have[$key] }
        }
        $have[$key] = $action
      } elseif ($have.Contains($key) -and $have[$key] -eq $action) {
        $have.Remove($key)
        if ($was.Contains($section) -and $was[$section].Contains($key)) { $have[$key] = $was[$section][$key] }
      }
    }
    if ($have.Count -eq 0) { $theirs.Remove($section) }
  }
  WriteJson $keysPath $theirs
  if ($how -eq "add" -and $was.Count -gt 0) { WriteJson $wasPath $was }
  if ($how -ne "add" -and (Test-Path $wasPath)) { Remove-Item $wasPath }
}

$packageMods = Get-ChildItem (Join-Path $here "mods") -Directory

if ($Uninstall) {
  Say "Removing Over9k from $HerdrHome"
  if ($sh -and (Get-Command jq -ErrorAction SilentlyContinue)) {
    Setup @("status", "off", $modsArg) | Out-Null
    Setup @("cleanup") | Out-Null
    Setup @("todo", "off", $modsArg) | Out-Null
  }
  foreach ($m in $packageMods) { Remove-Item (Join-Path $modsDir $m.Name) -Recurse -Force -ErrorAction SilentlyContinue }
  Remove-Item (Join-Path $layoutsDir "over9k.json"), (Join-Path $layoutsDir "over9k.svg") -ErrorAction SilentlyContinue
  if (Test-Path (Join-Path $HerdrHome "keys.json")) { Keys "remove" }
  Say "Done. Your to-do lists stay in %USERPROFILE%\.local\share\over9k (delete it to remove them too)."
  Say "If Over9k's layout was showing, pick another in Herdr's settings."
  exit 0
}

Say "Installing Over9k into $HerdrHome"
New-Item -ItemType Directory -Force -Path $modsDir, $layoutsDir | Out-Null

# The mods. Files the mods write themselves aren't replaced on an update.
foreach ($m in $packageMods) {
  $dest = Join-Path $modsDir $m.Name
  Get-ChildItem $m.FullName -Recurse -File | Where-Object { $_.Name -notin @("gpui-kit.d.ts", "herdr.d.ts", "jsconfig.json") -and $_.Extension -ne ".pyc" } | ForEach-Object {
    $rel = $_.FullName.Substring($m.FullName.Length).TrimStart('\', '/')
    $target = Join-Path $dest $rel
    if ($m.Name -eq "over9k-new-menu" -and $rel -eq "servers.json" -and (Test-Path $target)) { return }
    New-Item -ItemType Directory -Force -Path (Split-Path $target) | Out-Null
    Copy-Item $_.FullName $target -Force
  }
  # Files an earlier version had that this one doesn't (Herdr's own and what
  # the mods write themselves stay).
  Get-ChildItem $dest -Recurse -File | Where-Object { $_.Name -notin @("gpui-kit.d.ts", "herdr.d.ts", "jsconfig.json") -and $_.Extension -ne ".error" } | ForEach-Object {
    $rel = $_.FullName.Substring($dest.Length).TrimStart('\', '/')
    if ($m.Name -eq "over9k-new-menu" -and $rel -eq "servers.json") { return }
    if (-not (Test-Path (Join-Path $m.FullName $rel))) { Remove-Item $_.FullName -Force }
  }
}
Say "  Mods: $($packageMods.Count) copied"

$layout = Join-Path $layoutsDir "over9k.json"
if ((Test-Path $layout) -and ((Get-FileHash $layout).Hash -ne (Get-FileHash (Join-Path $here "layouts\over9k.json")).Hash)) {
  Copy-Item $layout "$layout.before-update" -Force
}
Copy-Item (Join-Path $here "layouts\over9k.json"), (Join-Path $here "layouts\over9k.svg") $layoutsDir -Force
Say "  Layout: over9k"
Keys "add"
Say "  Key bindings: added (Herdr's earlier keys.json is kept as keys.json.before-over9k)"

# Git for Windows on PATH: Herdr runs the mods' scripts with `sh`.
if (-not (Get-Command sh -ErrorAction SilentlyContinue)) {
  if ($gitUsrBin -and ($AddGitToPath -or (Ask "Put Git for Windows' tools ($gitUsrBin) on your PATH so Over9k's scripts can run?"))) {
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if (-not ($userPath -split ';' -contains $gitUsrBin)) {
      [Environment]::SetEnvironmentVariable("Path", ($userPath.TrimEnd(';') + ";" + $gitUsrBin), "User")
    }
    $env:Path += ";$gitUsrBin"
    Say "  PATH: added $gitUsrBin (restart Herdr to pick it up)"
  } elseif (-not $gitUsrBin) {
    Say ""
    Say "Git for Windows isn't installed: Over9k's sidebar shows, but its scripts can't run."
    Say "  Install it (winget install Git.Git), then run this again with -AddGitToPath."
  }
}

# Hooks earlier versions of Over9k added (removed features).
if ($sh) { Setup @("cleanup") | Out-Null }

# What else the mods use.
$missing = @()
if (-not (Get-Command jq -ErrorAction SilentlyContinue)) { $missing += "jq: Claude Code's status line, subagents, background tasks, resume, hand-off (winget install jqlang.jq)" }
if (-not ((Get-Command python3 -ErrorAction SilentlyContinue) -or (Get-Command python -ErrorAction SilentlyContinue))) { $missing += "Python 3: the Timeline, TODO.md sync (winget install Python.Python.3.12)" }
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { $missing += "git: the sidebar's branch, changes and push/pull (winget install Git.Git)" }
if ($missing.Count) { Say ""; Say "Missing (Over9k works without them, minus these):"; $missing | ForEach-Object { Say "  - $_" } }

# Claude Code: its status line, the to-do rule, command and hook.
$claudeHere = (Test-Path (Join-Path $env:USERPROFILE ".claude")) -or (Get-Command claude -ErrorAction SilentlyContinue)
if ($claudeHere -and -not $NoClaude -and $sh -and (Ask "Set up Claude Code for Over9k (status line, to-do rule and hook; your own status line is kept aside)?")) {
  if (Get-Command jq -ErrorAction SilentlyContinue) {
    Setup @("status", "on", $modsArg) | Out-Null
    Setup @("todo", "on", $modsArg) | Out-Null
    Say "  Claude Code: status line, to-do rule, todo command and hook set up"
  } else {
    Setup @("todo", "on", $modsArg) | Out-Null
    Say "  Claude Code: to-do rule and todo command set up; the status line and hook need jq (then Options > Claude Code)"
  }
}

Say ""
Say "Next:"
Say "  1. Open Herdr (or restart it), then Settings > Layout > Over9k."
Say "  2. Over9k help & options is at the bottom of the sidebar: pick your projects"
Say "     folder, then what each row shows. Claude Code extras: Options > Claude Code."
Say "  Update: get a newer copy and run this again. Remove: install.ps1 -Uninstall"
