#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Checks this machine can build and test the generated TypeScript project
    before you run scripts/init.ps1.

.DESCRIPTION
    POSIX counterpart: scripts/check-env.sh — use whichever matches your shell.

    Verifies Node.js (major version at or above the floor pinned in .nvmrc) and
    npm are on PATH — npm drives everything (installs dependencies, runs build/
    lint/type/test via package.json scripts). Prints "Environment ready" and
    exits 0 on success; if anything is missing it prints per-OS install commands
    and exits 1 — install it, then re-run:

        pwsh ./scripts/check-env.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$problems = @()

$repoRoot = Split-Path -Parent $PSScriptRoot
$floor = 24
$nvmrc = Join-Path $repoRoot '.nvmrc'
if (Test-Path $nvmrc) {
    # First number in .nvmrc is the major floor — works for "24", "v24.1.0", "24.1".
    # Guard the empty-file case: Get-Content -Raw returns $null, which
    # [regex]::Match would reject with ArgumentNullException.
    $raw = Get-Content $nvmrc -Raw
    if ($raw) {
        $m = [regex]::Match($raw, '\d+')
        if ($m.Success) { $floor = [int]$m.Value }
    }
}

Write-Host "==> Checking environment for TypeScript development" -ForegroundColor Cyan

# Required: Node.js at or above the .nvmrc floor (the runtime everything runs on).
if (Get-Command node -ErrorAction SilentlyContinue) {
    $major = [int](node -p 'process.versions.node.split(".")[0]')
    if ($major -lt $floor) {
        $problems += "Node.js >= $floor (found $(node --version))"
    } else {
        Write-Host "    node $(node --version)" -ForegroundColor DarkGray
    }
} else {
    $problems += "Node.js >= $floor ('node' is not on PATH)"
}

# Required: npm (build/test/lint/format driver; ships with Node.js).
if (Get-Command npm -ErrorAction SilentlyContinue) {
    Write-Host "    npm $(npm --version)" -ForegroundColor DarkGray
} else {
    $problems += "npm ('npm' is not on PATH — it normally ships with Node.js)"
}

# Soft: git drives init's author/email defaults and the VCS workflow, but is not
# required to build.
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "    note: git is not on PATH — init falls back to placeholder author/email." -ForegroundColor DarkGray
}

if ($problems.Count -eq 0) {
    Write-Host ""
    Write-Host "Environment ready. Next: pwsh ./scripts/init.ps1 -ProjectName ..." -ForegroundColor Green
    exit 0
}

Write-Host ""
Write-Host "Environment NOT ready. Missing:" -ForegroundColor Red
foreach ($p in $problems) { Write-Host "  - $p" -ForegroundColor Red }
Write-Host ""
Write-Host "Install Node.js (LTS, includes npm), then re-run this check:" -ForegroundColor Yellow
Write-Host "  Windows : winget install --id=OpenJS.NodeJS.LTS -e"
Write-Host "  macOS   : brew install node"
Write-Host "  Linux   : your distro's nodejs package (e.g. apt-get install nodejs npm),"
Write-Host "            or nvm: nvm install $floor && nvm use $floor"
Write-Host "  (any OS) : see https://nodejs.org/en/download"
exit 1
