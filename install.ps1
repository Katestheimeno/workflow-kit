#!/usr/bin/env pwsh
# Installs the workflow-kit bundle into <target>\.claude\ and optionally CLAUDE.md.example at <target>\.
# PowerShell port of install.sh — same flags and behavior. Works on Windows PowerShell 5.1+ and PowerShell 7+.
# Canonical source: git@github.com:Katestheimeno/workflow-kit.git

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir       = $PSScriptRoot
$BundleDir       = Join-Path $ScriptDir 'bundle'
$VersionFile     = Join-Path $ScriptDir 'VERSION'
$CanonicalSource = 'git@github.com:Katestheimeno/workflow-kit.git'

# Kit-owned content directories copied (merged) into .claude\ on install and refresh.
$ContentDirs = @('agents', 'commands', 'rules', 'prompts', 'skills')

# --- option state ---
$DryRun          = $false
$Force           = $false
$NoClaudeExample = $false
$OnlyProtocol    = $false
$Overlay         = ''
$TargetArg       = ''

function Write-Usage {
  @"
Usage: install.ps1 [OPTIONS] [TARGET_DIR]

  TARGET_DIR   Root of the project to install into (default: current directory).

Options:
  --dry-run            Print actions only; do not modify the filesystem.
  --force              If .claude\ already exists, move it to .claude.bak.<epoch> then full install.
  --no-claude-example  Do not copy CLAUDE.md.example to TARGET_DIR.
  --only-protocol      Refresh only CLAUDE_ENTRYPOINT.md, example-feature\, and the kit-owned
                       content dirs (agents\ commands\ rules\ prompts\ skills\) from the bundle.
                       Requires an existing install (.claude\CLAUDE_ENTRYPOINT.md). Does not modify
                       tasks\, CONTEXT_MAP.md, or CLAUDE.md.example. Writes/updates .claude\WORKFLOW_KIT.
  --overlay NAME       After the generic core, apply a stack overlay from bundle\overlays\NAME\
                       (e.g. --overlay django). Overlay files override the generic agents/commands/
                       rules/prompts. See bundle\overlays\NAME\README.md.
  -h, --help           Show this help.
  --version            Print kit version and exit.

Full install refuses if .claude\CLAUDE_ENTRYPOINT.md already exists (use --force to replace).
Protocol-only: use after cloning or upgrading the kit to refresh the entrypoint without touching tasks\.
"@
}

function Get-KitVersion {
  if (Test-Path -LiteralPath $VersionFile) {
    try { return ((Get-Content -Raw -LiteralPath $VersionFile).Trim()) } catch { return 'unknown' }
  }
  return 'unknown'
}

function Fail([string]$msg) {
  [Console]::Error.WriteLine($msg)
  exit 1
}

function Write-WorkflowMarker([string]$claudeDir, [string]$targetDir, [string]$v) {
  $path = Join-Path $claudeDir 'WORKFLOW_KIT'
  if ($DryRun) {
    Write-Host "[dry-run] write $path (version, installed, source)"
    return
  }
  $iso = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss') + 'Z'
  $content = @(
    '# Written by workflow-kit install.ps1; safe to commit for team visibility.',
    "version=$v",
    "source=$CanonicalSource",
    "installed=$iso",
    "target=$targetDir"
  ) -join "`n"
  [System.IO.File]::WriteAllText($path, $content + "`n")
  Write-Host "workflow-kit: wrote $path"
}

# Merge one bundle subdir into .claude\<name>\ file-by-file (overwrites kit-owned files,
# leaves any unrelated user files in place). Used for hooks/ agents/ commands/ rules/ prompts/.
function Merge-OneDir([string]$src, [string]$dst) {
  if (-not (Test-Path -LiteralPath $src)) { return }
  if ($DryRun) {
    Write-Host "[dry-run] mkdir -p $dst"
    Get-ChildItem -LiteralPath $src | ForEach-Object {
      Write-Host "[dry-run] cp $($_.FullName) $dst\"
    }
    return
  }
  New-Item -ItemType Directory -Force -Path $dst | Out-Null
  Get-ChildItem -LiteralPath $src | ForEach-Object {
    if ($_.PSIsContainer) {
      # nested content (e.g. skills\<name>\): replace the kit-owned subdir wholesale,
      # leaving unrelated user subdirs in place.
      $dest = Join-Path $dst $_.Name
      if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force }
      Copy-Item -LiteralPath $_.FullName -Destination $dst -Recurse -Force
    } else {
      Copy-Item -LiteralPath $_.FullName -Destination $dst -Force
    }
  }
}

function Merge-HooksDir([string]$claudeDir) {
  Merge-OneDir (Join-Path $BundleDir 'hooks') (Join-Path $claudeDir 'hooks')
}

# Copy the kit-owned content dirs (agents\ commands\ rules\ prompts\ skills\) into .claude\.
function Merge-ContentDirs([string]$claudeDir) {
  foreach ($d in $ContentDirs) {
    Merge-OneDir (Join-Path $BundleDir $d) (Join-Path $claudeDir $d)
  }
}

# Apply a stack overlay over the generic content dirs (overlay files win).
function Apply-Overlay([string]$claudeDir) {
  if ([string]::IsNullOrEmpty($Overlay)) { return }
  $base = Join-Path (Join-Path $BundleDir 'overlays') $Overlay
  Write-Host "workflow-kit: applying '$Overlay' overlay over the generic core"
  foreach ($d in $ContentDirs) {
    Merge-OneDir (Join-Path $base $d) (Join-Path $claudeDir $d)
  }
}

# Recursively (re)place a bundle dir under .claude\ (rm -rf then copy). For tasks\ / example-feature\.
function Replace-TreeUnderClaude([string]$claudeDir, [string]$name) {
  $src = Join-Path $BundleDir $name
  if (-not (Test-Path -LiteralPath $src)) { return }
  $dst = Join-Path $claudeDir $name
  if (Test-Path -LiteralPath $dst) { Remove-Item -LiteralPath $dst -Recurse -Force }
  Copy-Item -LiteralPath $src -Destination $claudeDir -Recurse -Force
}

function Write-HooksPrompt([string]$claudeDir) {
  $ex   = Join-Path $claudeDir 'settings.json.example'
  $live = Join-Path $claudeDir 'settings.json'
  @"

workflow-kit: hooks are installed but NOT yet wired up.

  Sample config: $ex
  Your config:   $live

  -> To enable the hooks, merge the "hooks" block from settings.json.example
    into your $live. If you don't have one yet, you can just copy it:

      Copy-Item "$ex" "$live"

  Hooks that will run once enabled (require a bash runtime, e.g. Git Bash):
    - UserPromptSubmit -> hooks/checkpoint.sh         (injects the checkpoint protocol + active feature)
    - SessionStart     -> hooks/session-start.sh      (prints active-feature state)
    - PostToolUse      -> hooks/progress-heartbeat.sh (feature-completion + scope-drift + size-cap warnings)
    - PostToolUse      -> hooks/guard-bash-writes.sh  (size-cap on in-place bash writes: sed -i, tee, truncate, >)
    - Stop             -> hooks/validate-state.sh     (checks state invariants)

  Manual tool (invoke when a feature is done):
    bash "$claudeDir/hooks/archive-feature.sh" <feature>

  Strict mode (hooks exit 2 on violations, blocking tool calls):
    `$env:WORKFLOW_KIT_STRICT=1
"@ | Write-Host
}

# --- argument parsing (explicit if/elseif — no switch fall-through) ---
$i = 0
while ($i -lt $args.Count) {
  $a = [string]$args[$i]
  if ($a -ceq '-h' -or $a -ceq '--help') {
    Write-Usage; exit 0
  } elseif ($a -ceq '--version') {
    Write-Host "workflow-kit $(Get-KitVersion)"; exit 0
  } elseif ($a -ceq '--dry-run') {
    $DryRun = $true
  } elseif ($a -ceq '--force') {
    $Force = $true
  } elseif ($a -ceq '--no-claude-example') {
    $NoClaudeExample = $true
  } elseif ($a -ceq '--only-protocol') {
    $OnlyProtocol = $true
  } elseif ($a -ceq '--overlay') {
    if ($i + 1 -ge $args.Count) { Fail '--overlay requires a name (e.g. --overlay django)' }
    $i++
    $Overlay = [string]$args[$i]
  } elseif ($a -clike '--overlay=*') {
    $Overlay = $a.Substring($a.IndexOf('=') + 1)
  } elseif ($a.StartsWith('-')) {
    [Console]::Error.WriteLine("Unknown option: $a")
    [Console]::Error.WriteLine((Write-Usage))
    exit 1
  } else {
    if ($TargetArg -ne '') { Fail 'Multiple target directories specified.' }
    $TargetArg = $a
  }
  $i++
}

if (-not (Test-Path -LiteralPath $BundleDir -PathType Container)) {
  Fail "workflow-kit: bundle directory not found: $BundleDir"
}

if (-not [string]::IsNullOrEmpty($Overlay)) {
  $overlayPath = Join-Path (Join-Path $BundleDir 'overlays') $Overlay
  if (-not (Test-Path -LiteralPath $overlayPath -PathType Container)) {
    [Console]::Error.WriteLine("workflow-kit: overlay not found: $overlayPath")
    [Console]::Error.WriteLine('  Available overlays:')
    $overlaysRoot = Join-Path $BundleDir 'overlays'
    if (Test-Path -LiteralPath $overlaysRoot -PathType Container) {
      Get-ChildItem -LiteralPath $overlaysRoot -Directory | ForEach-Object {
        [Console]::Error.WriteLine("    - $($_.Name)")
      }
    } else {
      [Console]::Error.WriteLine('    (none)')
    }
    exit 1
  }
}

$Target = if ([string]::IsNullOrEmpty($TargetArg)) { '.' } else { $TargetArg }
if (-not (Test-Path -LiteralPath $Target -PathType Container)) {
  Fail "workflow-kit: target is not a directory: $Target"
}
$Target = (Resolve-Path -LiteralPath $Target).Path

$ClaudeDir  = Join-Path $Target '.claude'
$Entrypoint = Join-Path $ClaudeDir 'CLAUDE_ENTRYPOINT.md'
$ExampleDst = Join-Path $Target 'CLAUDE.md.example'
$KitVer     = Get-KitVersion

# --- protocol-only path ---
if ($OnlyProtocol) {
  if ($Force) {
    [Console]::Error.WriteLine('workflow-kit: --force is ignored with --only-protocol (tasks\ and CONTEXT_MAP are never replaced).')
  }
  if (-not (Test-Path -LiteralPath $Entrypoint -PathType Leaf)) {
    [Console]::Error.WriteLine("workflow-kit: --only-protocol requires an existing install: $Entrypoint not found.")
    [Console]::Error.WriteLine("  Run a full install first: .\install.ps1 $Target")
    exit 1
  }
  Write-Host "workflow-kit: protocol-only update (version $KitVer) -> $Target"
  if ($DryRun) {
    Write-Host "[dry-run] cp $(Join-Path $BundleDir 'CLAUDE_ENTRYPOINT.md') $ClaudeDir\"
    if (Test-Path -LiteralPath (Join-Path $BundleDir 'example-feature') -PathType Container) {
      Write-Host "[dry-run] rm -rf $ClaudeDir\example-feature && cp -r bundle\example-feature $ClaudeDir\"
    }
    Merge-HooksDir $ClaudeDir
    if (Test-Path -LiteralPath (Join-Path $BundleDir 'settings.json.example') -PathType Leaf) {
      Write-Host "[dry-run] cp $(Join-Path $BundleDir 'settings.json.example') $ClaudeDir\"
    }
  } else {
    New-Item -ItemType Directory -Force -Path $ClaudeDir | Out-Null
    Copy-Item -LiteralPath (Join-Path $BundleDir 'CLAUDE_ENTRYPOINT.md') -Destination $ClaudeDir -Force
    Replace-TreeUnderClaude $ClaudeDir 'example-feature'
    Merge-HooksDir $ClaudeDir
    if (Test-Path -LiteralPath (Join-Path $BundleDir 'settings.json.example') -PathType Leaf) {
      Copy-Item -LiteralPath (Join-Path $BundleDir 'settings.json.example') -Destination $ClaudeDir -Force
    }
  }
  Merge-ContentDirs $ClaudeDir
  Apply-Overlay $ClaudeDir
  Write-WorkflowMarker $ClaudeDir $Target $KitVer
  if ($DryRun) {
    Write-Host '[dry-run] done (protocol-only).'
  } else {
    Write-Host "workflow-kit: refreshed entrypoint, example-feature\, content dirs (agents\ commands\ rules\ prompts\ skills\), hook scripts, and settings.json.example under $ClaudeDir"
    Write-HooksPrompt $ClaudeDir
  }
  exit 0
}

# --- full install guards ---
if ((Test-Path -LiteralPath $Entrypoint -PathType Leaf) -and -not $Force) {
  [Console]::Error.WriteLine("workflow-kit: $Entrypoint already exists.")
  [Console]::Error.WriteLine('  Use --force to move existing .claude\ to .claude.bak.<epoch> and reinstall,')
  [Console]::Error.WriteLine('  or --only-protocol to refresh entrypoint and example-feature\ only.')
  exit 1
}

if ((Test-Path -LiteralPath (Join-Path $ClaudeDir 'tasks') -PathType Container) -and -not $Force -and -not (Test-Path -LiteralPath $Entrypoint -PathType Leaf)) {
  [Console]::Error.WriteLine("workflow-kit: $(Join-Path $ClaudeDir 'tasks') already exists (no kit entrypoint). Refusing to overwrite.")
  [Console]::Error.WriteLine('  Remove or move that directory, or use --force to back up the whole .claude\ and install.')
  exit 1
}

if ($Force -and (Test-Path -LiteralPath $ClaudeDir -PathType Container)) {
  $epoch  = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  $backup = Join-Path $Target ".claude.bak.$epoch"
  if ($DryRun) {
    Write-Host "[dry-run] mv $ClaudeDir $backup"
  } else {
    Move-Item -LiteralPath $ClaudeDir -Destination $backup
    Write-Host "workflow-kit: backed up existing .claude to $backup"
  }
}

function Install-ClaudeTree {
  if ($DryRun) {
    Write-Host "[dry-run] mkdir -p $ClaudeDir"
    Write-Host "[dry-run] cp bundle\CLAUDE_ENTRYPOINT.md $ClaudeDir\"
    Write-Host "[dry-run] cp bundle\CONTEXT_MAP.md $ClaudeDir\"
    Write-Host "[dry-run] cp -r bundle\tasks $ClaudeDir\"
    if (Test-Path -LiteralPath (Join-Path $BundleDir 'example-feature') -PathType Container) {
      Write-Host "[dry-run] cp -r bundle\example-feature $ClaudeDir\"
    }
    Merge-HooksDir $ClaudeDir
    Merge-ContentDirs $ClaudeDir
    Apply-Overlay $ClaudeDir
    if (Test-Path -LiteralPath (Join-Path $BundleDir 'settings.json.example') -PathType Leaf) {
      Write-Host "[dry-run] cp bundle\settings.json.example $ClaudeDir\"
    }
    return
  }

  New-Item -ItemType Directory -Force -Path $ClaudeDir | Out-Null
  Copy-Item -LiteralPath (Join-Path $BundleDir 'CLAUDE_ENTRYPOINT.md') -Destination $ClaudeDir -Force
  Copy-Item -LiteralPath (Join-Path $BundleDir 'CONTEXT_MAP.md') -Destination $ClaudeDir -Force
  Replace-TreeUnderClaude $ClaudeDir 'tasks'
  Replace-TreeUnderClaude $ClaudeDir 'example-feature'
  Merge-HooksDir $ClaudeDir
  Merge-ContentDirs $ClaudeDir
  Apply-Overlay $ClaudeDir
  if (Test-Path -LiteralPath (Join-Path $BundleDir 'settings.json.example') -PathType Leaf) {
    Copy-Item -LiteralPath (Join-Path $BundleDir 'settings.json.example') -Destination $ClaudeDir -Force
  }
}

function Install-Example {
  if ($NoClaudeExample) { return }
  if (Test-Path -LiteralPath $ExampleDst -PathType Leaf) {
    [Console]::Error.WriteLine("workflow-kit: $ExampleDst already exists; skipping (remove it or merge manually).")
    return
  }
  if ($DryRun) {
    Write-Host "[dry-run] cp bundle\CLAUDE.md.example $ExampleDst"
    return
  }
  Copy-Item -LiteralPath (Join-Path $BundleDir 'CLAUDE.md.example') -Destination $ExampleDst -Force
  Write-Host "workflow-kit: wrote $ExampleDst"
}

Write-Host "workflow-kit: installing kit version $KitVer into $Target"

Install-ClaudeTree
Write-WorkflowMarker $ClaudeDir $Target $KitVer
Install-Example

if ($DryRun) {
  Write-Host '[dry-run] done.'
} else {
  $overlayNote = if ([string]::IsNullOrEmpty($Overlay)) { '' } else { " (+ $Overlay overlay)" }
  Write-Host "workflow-kit: installed .claude\ task checkpoint under $ClaudeDir"
  Write-Host "workflow-kit: orchestration layer installed: agents\ commands\ rules\ prompts\ skills\$overlayNote"
  Write-Host "workflow-kit: read $Entrypoint first for every AI-assisted session."
  Write-HooksPrompt $ClaudeDir
}
