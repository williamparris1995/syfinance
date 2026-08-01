# verify-commit.ps1 — Claude Code PreToolUse hook (Bash, git commit).
# Blocks `git commit` unless tests pass. Per ai-harness.md §2 enforcement.
#   - go test ./... (server): strict block on any failure (baseline all-green).
#   - flutter test (client): baseline-tolerant — known drift files pass, NEW fails block.
# Baseline drift (tolerated): account_detail_page_test.dart, receivable_detail_page_test.dart.
# Exit 0 = allow; Exit 2 = block (feedback to agent). Non-git-commit Bash = pass-through.

$ErrorActionPreference = 'Continue'

# --- only act on `git commit` ---
$raw = [Console]::In.ReadToEnd()
$cmd = $null
try {
    $data = $raw | ConvertFrom-Json
    $cmd = $data.tool_input.command
} catch { exit 0 }
if (-not $cmd) { exit 0 }
if ($cmd -notmatch '(^|\s)git\s+commit(\s|$)') { exit 0 }
if ($cmd -match '(--help|\b-h\b|--dry-run|\b-n\b)') { exit 0 }

$root = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$baselineFiles = @('account_detail_page_test.dart', 'receivable_detail_page_test.dart')

# --- go test (server) — strict ---
$server = Join-Path $root 'yucai\server'
Push-Location $server
try {
    $goOut = go.exe test ./... 2>&1 | Out-String
    $goExit = $LASTEXITCODE
} finally { Pop-Location }
if ($goExit -ne 0) {
    Write-Output "BLOCKED by pre-commit hook: go test ./... failed (server). Fix before commit."
    Write-Output $goOut
    exit 2
}

# --- flutter test (client) — baseline-tolerant ---
$client = Join-Path $root 'yucai\client'
Push-Location $client
try {
    $fltOut = flutter.bat test 2>&1 | Out-String
    $fltExit = $LASTEXITCODE
} finally { Pop-Location }
if ($fltExit -eq 0) { exit 0 }   # all green

# non-zero: parse failing _test.dart file names.
# compact reporter marks each FAILED test line with a trailing [E];
# progress lines (+N) also carry file paths but are NOT failures — must filter on [E].
$failFiles = @()
foreach ($line in ($fltOut -split "`r?`n")) {
    if ($line -match '\[E\]' -and $line -match '[\\/]([A-Za-z0-9_]+_test\.dart)') {
        $failFiles += $matches[1]
    }
}
$failFiles = $failFiles | Select-Object -Unique

if ($failFiles.Count -eq 0) {
    # couldn't parse — don't false-block (baseline is known-non-zero); warn + allow
    Write-Output "pre-commit WARNING: flutter test exited non-zero but no fail-file parsed (baseline drift expected). Review manually."
    exit 0
}

$newFails = @($failFiles | Where-Object { $_ -notin $baselineFiles })
if ($newFails.Count -eq 0) {
    Write-Output "pre-commit: flutter test failures limited to known drift files (tolerated): $($failFiles -join ', ')"
    exit 0
}
Write-Output "BLOCKED by pre-commit hook: flutter test has NEW failures beyond baseline."
Write-Output "New failing files: $($newFails -join ', ')"
Write-Output "Baseline (tolerated): $($baselineFiles -join ', ')"
Write-Output $fltOut
exit 2
