#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Initializes this template into a concrete TypeScript project.

.DESCRIPTION
    POSIX counterpart: scripts/init.sh — use whichever matches your shell.

    Replaces the placeholder tokens in file contents AND in file/folder names,
    then removes the template-only files (TEMPLATE.md, docs/AGENT-INIT-GUIDE.md,
    and — unless -KeepScript — both initializers, init.ps1 and init.sh).

    Two name tokens are stamped:
      __ProjectName__  the project / repo name, used verbatim (e.g.
                       "Acme.Widgets"). Goes into URLs, LICENSE, docs.
      __PackageName__  the npm package name, DERIVED from the project name
                       (lowercased, runs of non-alphanumerics -> '-', trimmed) —
                       e.g. "Acme.Widgets" -> "acme-widgets". Goes into
                       package.json `name` and the README install/usage lines.

    Run it once, right after creating a repository from the template:

        pwsh ./scripts/init.ps1 -ProjectName Acme.Widgets

.PARAMETER ProjectName
    Project / repo name. Required. Used verbatim in URLs and docs; the npm
    package name is derived from it.

.PARAMETER Author
    Author for LICENSE and package metadata. Defaults to `git config user.name`, else "Your Name".

.PARAMETER AuthorEmail
    Author email for package metadata and the release commit. Defaults to `git config user.email`, else "you@example.com".

.PARAMETER GitHubOwner
    GitHub owner/org used in repository URLs. Defaults to "your-org".

.PARAMETER Description
    Short package description. Defaults to "TODO: project description".

.PARAMETER Year
    Copyright year. Defaults to the current year.

.PARAMETER KeepScript
    Keep both initializers (init.ps1 and init.sh) after running. TEMPLATE.md and
    docs/AGENT-INIT-GUIDE.md are removed either way.

.EXAMPLE
    pwsh ./scripts/init.ps1 -ProjectName Acme.Widgets -Author "Jane Doe" -GitHubOwner acme -Description "Widget toolkit"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectName,
    [string]$Author,
    [string]$AuthorEmail,
    [string]$GitHubOwner,
    [string]$Description,
    [int]$Year = (Get-Date).Year,
    [switch]$KeepScript
)

$ErrorActionPreference = 'Stop'

# Validate the project name: ASCII letters, digits, '.', '-', '_', starting and
# ending with an alphanumeric. An out-of-set character (space, '/', '!', ...)
# would produce broken URLs and an underivable npm name — reject it here with a
# clear message.
if ($ProjectName -notmatch '^[A-Za-z0-9]([A-Za-z0-9._-]*[A-Za-z0-9])?$') {
    throw "Invalid -ProjectName '$ProjectName'. Use ASCII letters, digits, '.', '-', '_'; it must start and end with a letter or digit (e.g. Acme.Widgets)."
}

# Derive the npm package name: lowercase, collapse runs of non-alphanumerics to
# '-', trim leading/trailing '-'. npm names may start with a digit, so no prefix
# is needed — only the registry's 214-character cap is enforced.
$packageName = ($ProjectName.ToLowerInvariant() -replace '[^a-z0-9]+', '-').Trim('-')
if (-not $packageName) {
    throw "Invalid -ProjectName '$ProjectName'. It must contain at least one ASCII letter or digit so an npm package name can be derived (e.g. Acme.Widgets)."
}
if ($packageName.Length -gt 214) {
    throw "Invalid -ProjectName '$ProjectName'. The derived npm name exceeds npm's 214-character limit."
}

# try/catch: with $ErrorActionPreference = 'Stop', a missing git binary raises a
# terminating CommandNotFoundException that 2>$null alone does not suppress.
if (-not $Author) {
    try { $Author = (& git config user.name 2>$null) } catch { $Author = $null }
    if (-not $Author) { $Author = 'Your Name' }
}
if (-not $AuthorEmail) {
    try { $AuthorEmail = (& git config user.email 2>$null) } catch { $AuthorEmail = $null }
    if (-not $AuthorEmail) { $AuthorEmail = 'you@example.com' }
}
if (-not $GitHubOwner) { $GitHubOwner = 'your-org' }
if (-not $Description) { $Description = 'TODO: project description' }

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$selfPath = $PSCommandPath

$replacements = [ordered]@{
    '__ProjectName__' = $ProjectName
    '__PackageName__' = $packageName
    '__Author__'      = $Author
    '__AuthorEmail__' = $AuthorEmail
    '__GitHubOwner__' = $GitHubOwner
    '__Description__' = $Description
    '__Year__'        = "$Year"
}

# Values written into JSON files (package.json name/description/author/urls) sit
# inside double-quoted strings, so escape quotes, backslashes, and every C0
# control character. The derived package name is [a-z0-9-] only, so it is safe.
function ConvertTo-JsonStringContent([string]$value) {
    $builder = [System.Text.StringBuilder]::new()
    foreach ($character in $value.ToCharArray()) {
        $codePoint = [int]$character
        $escaped = switch ($codePoint) {
            0x08 { '\b' }
            0x09 { '\t' }
            0x0A { '\n' }
            0x0C { '\f' }
            0x0D { '\r' }
            0x22 { '\"' }
            0x5C { '\\' }
            default {
                if ($codePoint -lt 0x20) {
                    '\u{0:x4}' -f $codePoint
                } else {
                    [string]$character
                }
            }
        }
        [void]$builder.Append($escaped)
    }
    return $builder.ToString()
}

$jsonReplacements = [ordered]@{}
foreach ($key in $replacements.Keys) {
    $jsonReplacements[$key] = ConvertTo-JsonStringContent $replacements[$key]
}
$jsonFileExtensions = @('.json')

$excludedDirs = @('.git', '.jj', 'node_modules', 'dist', 'coverage', 'artifacts')

function Test-Excluded([string]$fullPath) {
    $rel = $fullPath.Substring($repoRoot.Length).TrimStart('\', '/')
    foreach ($seg in ($rel -split '[\\/]')) {
        if ($excludedDirs -contains $seg) { return $true }
    }
    return $false
}

Write-Host "==> Initializing template as '$ProjectName' (npm package '$packageName')" -ForegroundColor Cyan

# 1) Replace tokens in file contents. Both initializers are skipped: they carry
#    the literal token strings as search keys, so substituting inside them would
#    corrupt the sibling script. Match each source token once so token-looking
#    text inside a replacement value is never processed again.
$siblingSh = Join-Path $PSScriptRoot 'init.sh'
$tokenPattern = '__ProjectName__|__PackageName__|__Author__|__AuthorEmail__|__GitHubOwner__|__Description__|__Year__'
$files = Get-ChildItem -Force -Path $repoRoot -File -Recurse | Where-Object {
    -not (Test-Excluded $_.FullName) -and $_.FullName -ne $selfPath -and $_.FullName -ne $siblingSh
}
$contentChanged = 0
foreach ($file in $files) {
    $text = [System.IO.File]::ReadAllText($file.FullName)
    $map = if ($jsonFileExtensions -contains $file.Extension) { $jsonReplacements } else { $replacements }
    $new = [regex]::Replace($text, $tokenPattern, [System.Text.RegularExpressions.MatchEvaluator]{
        param([System.Text.RegularExpressions.Match]$match)
        [string]$map[$match.Value]
    })
    if ($new -ne $text) {
        # UTF-8 without BOM, LF preserved — matches .gitattributes (eol=lf).
        [System.IO.File]::WriteAllText($file.FullName, $new, (New-Object System.Text.UTF8Encoding($false)))
        $contentChanged++
    }
}
Write-Host "    Updated contents in $contentChanged file(s)." -ForegroundColor DarkGray

# 2) Rename files and folders whose name contains a name token. Deepest paths
#    first so child renames don't invalidate parent paths. (The TS layout ships
#    no token-named paths today; the sweep keeps renames working if you add any.)
$named = Get-ChildItem -Force -Path $repoRoot -Recurse | Where-Object {
    -not (Test-Excluded $_.FullName) -and ($_.Name -like '*__ProjectName__*' -or $_.Name -like '*__PackageName__*')
} | Sort-Object { $_.FullName.Length } -Descending
foreach ($item in $named) {
    $newName = $item.Name.Replace('__ProjectName__', $ProjectName).Replace('__PackageName__', $packageName)
    Rename-Item -LiteralPath $item.FullName -NewName $newName
    Write-Host "    Renamed $($item.Name) -> $newName" -ForegroundColor DarkGray
}

# 3) Activate the Claude Code shared settings (shipped inert as a .template file).
$claudeTemplate = Join-Path $repoRoot '.claude/settings.json.template'
if (Test-Path $claudeTemplate) {
    Move-Item -LiteralPath $claudeTemplate -Destination (Join-Path $repoRoot '.claude/settings.json') -Force
    Write-Host "    Activated .claude/settings.json" -ForegroundColor DarkGray
}

# 4) Remove template-only files.
$templateOnly = @('TEMPLATE.md', 'docs/AGENT-INIT-GUIDE.md')
foreach ($rel in $templateOnly) {
    $p = Join-Path $repoRoot $rel
    if (Test-Path $p) { Remove-Item -LiteralPath $p -Force }
}
# Drop docs/ if it's now empty.
$docsDir = Join-Path $repoRoot 'docs'
if ((Test-Path $docsDir) -and -not (Get-ChildItem -LiteralPath $docsDir -Force)) {
    Remove-Item -LiteralPath $docsDir -Force
}

Write-Host ""
Write-Host "Done. Next steps:" -ForegroundColor Green
Write-Host "  1. npm install   (then commit the generated package-lock.json)"
Write-Host "  2. npm run build && npm test"
Write-Host "  3. npm run lint && npm run typecheck"
Write-Host "  4. Review LICENSE (author/year) and the package metadata in package.json."
Write-Host "  5. Publishing: add the NPM_TOKEN repo secret, or delete"
Write-Host "     .github/workflows/release.yml and trim the publishing metadata."
Write-Host "  6. Replace src/greeter.ts with your code and delete the sample test, then commit."
Write-Host "  7. Optional, before the first push: keep CLAUDE.md/AGENTS.md/.claude out of"
Write-Host "     the remote — see the 'local-only' section in AGENTS.md."

# Remove both initializers unless asked to keep them.
if (-not $KeepScript) {
    if (Test-Path $siblingSh) { Remove-Item -LiteralPath $siblingSh -Force }
    Remove-Item -LiteralPath $selfPath -Force
}
