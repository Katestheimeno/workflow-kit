#!/usr/bin/env pwsh
# Shallow-clone Katestheimeno/workflow-kit at a tag and run install.ps1 against a target project.
# PowerShell port of bootstrap.sh — use when you do not have the kit checked out
# (e.g. one-line install from a clean Windows machine with git + network).
# Works on Windows PowerShell 5.1+ and PowerShell 7+.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoDefault = 'git@github.com:Katestheimeno/workflow-kit.git'
$Repo = if ($env:WORKFLOW_KIT_REPO) { $env:WORKFLOW_KIT_REPO } else { $RepoDefault }

$Tag       = 'v1.2.0'
$TargetArg = ''
$PassThru  = @()  # extra args forwarded to install.ps1 (e.g. --overlay django, --force)

function Write-Usage {
  @"
Usage: bootstrap.ps1 [OPTIONS] <TARGET_PROJECT_DIR>

  Clones the workflow-kit repository at a tag into a temporary directory, runs
  install.ps1 against TARGET_PROJECT_DIR, then removes the clone.

Options:
  -t, --tag TAG   Git tag to clone (default: v1.2.0). Must exist on the remote.
  -h, --help      Show this help.

  Any other options (e.g. --overlay django, --force, --only-protocol, --dry-run)
  are forwarded to install.ps1 unchanged.

Environment:
  WORKFLOW_KIT_REPO   Override the git URL (default: git@github.com:Katestheimeno/workflow-kit.git).

Requires: git, pwsh/PowerShell, and network access to GitHub.
"@
}

function Fail([string]$msg) {
  [Console]::Error.WriteLine($msg)
  exit 1
}

# --- argument parsing ---
$i = 0
while ($i -lt $args.Count) {
  $a = [string]$args[$i]
  if ($a -ceq '-h' -or $a -ceq '--help') {
    Write-Usage; exit 0
  } elseif ($a -ceq '-t' -or $a -ceq '--tag') {
    if ($i + 1 -ge $args.Count) { Fail 'bootstrap: --tag requires a value.' }
    $i++
    $Tag = [string]$args[$i]
  } elseif ($a -clike '--tag=*') {
    $Tag = $a.Substring($a.IndexOf('=') + 1)
  } elseif ($a.StartsWith('-')) {
    # Unknown option: forward to install.ps1.
    $PassThru += $a
  } else {
    if ($TargetArg -ne '') { Fail 'bootstrap: multiple targets specified.' }
    $TargetArg = $a
  }
  $i++
}

if ($TargetArg -eq '') {
  [Console]::Error.WriteLine('bootstrap: TARGET_PROJECT_DIR is required.')
  [Console]::Error.WriteLine((Write-Usage))
  exit 1
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
  Fail 'bootstrap: git is not installed or not in PATH.'
}

$TmpRoot  = Join-Path ([System.IO.Path]::GetTempPath()) ("workflow-kit-bootstrap." + [System.IO.Path]::GetRandomFileName())
$CloneDir = Join-Path $TmpRoot 'workflow-kit'

try {
  New-Item -ItemType Directory -Force -Path $TmpRoot | Out-Null

  # Non-interactive clone: fail if tag is missing.
  $env:GIT_TERMINAL_PROMPT = '0'
  & git clone --depth 1 --branch $Tag $Repo $CloneDir
  if ($LASTEXITCODE -ne 0) { Fail "bootstrap: git clone failed (tag $Tag, repo $Repo)." }

  $InstallPs1 = Join-Path $CloneDir 'install.ps1'
  if (-not (Test-Path -LiteralPath $InstallPs1 -PathType Leaf)) {
    Fail 'bootstrap: install.ps1 not found in clone.'
  }

  Write-Host "bootstrap: using tag $Tag, running $InstallPs1 $($PassThru -join ' ') $TargetArg"
  & $InstallPs1 @PassThru $TargetArg
  exit $LASTEXITCODE
}
finally {
  if (Test-Path -LiteralPath $TmpRoot) {
    Remove-Item -LiteralPath $TmpRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
}
