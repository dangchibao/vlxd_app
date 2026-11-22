#requires -version 5.1
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = (Get-Location).Path
if (-not (Test-Path (Join-Path $root 'pubspec.yaml'))) { throw 'Hay cd D:\app\vlxd_app truoc khi chay.' }
$patchFile = Join-Path $PSScriptRoot 'edits.json'
# Windows PowerShell 5.1: ConvertFrom-Json may return the whole JSON array as
# one pipeline object. Normalize it explicitly to one patch per list item.
$parsed = ConvertFrom-Json -InputObject ([System.IO.File]::ReadAllText($patchFile, [System.Text.Encoding]::UTF8))
$changes = New-Object 'System.Collections.Generic.List[object]'
foreach ($entry in $parsed) { [void]$changes.Add($entry) }
if ($changes.Count -ne 15) { throw "PATCH-MANIFEST-ERROR: Expected 15 edits, got $($changes.Count). NO FILES CHANGED." }
Write-Host "[MANIFEST] Loaded $($changes.Count) individual UI edits" -ForegroundColor Cyan
$files = @('lib/ui/mobile_products.dart', 'lib/ui/debt.dart')
$prepared = @{}
$patternOpts = [System.Text.RegularExpressions.RegexOptions]::Singleline
$utf8 = New-Object System.Text.UTF8Encoding($false)
Write-Host '[CHECK] Dang kiem tra cac thay doi tren source hien tai...' -ForegroundColor Cyan
foreach ($rel in $files) {
    $target = Join-Path $root ($rel -replace '/', '\')
    if (-not (Test-Path -LiteralPath $target)) { throw "SOURCE-MISSING: $rel; no files changed." }
    $text = [System.IO.File]::ReadAllText($target)
    foreach ($change in $changes) {
        if ([string]$change.file -ne $rel) { continue }
        $regex = New-Object System.Text.RegularExpressions.Regex([string]$change.pattern, $patternOpts)
        $matches = $regex.Matches($text)
        if ($matches.Count -ne 1) {
            throw "SOURCE-MISMATCH: $rel :: $($change.label), count=$($matches.Count). NO FILES CHANGED."
        }
        $replacement = [string]$change.replacement
        $evaluator = [System.Text.RegularExpressions.MatchEvaluator] ({ param($match) $replacement }.GetNewClosure())
        $text = $regex.Replace($text, $evaluator, 1)
        Write-Host "[CHECK] $($change.label)" -ForegroundColor DarkGray
    }
    $prepared[$rel] = $text
}
if ($changes.Count -ne 15) { throw 'Invalid patch manifest; no files changed.' }
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backup = Join-Path $root ".vlxd_safe_backups\mobile_pwa_ui_v4_$stamp"
New-Item -ItemType Directory -Force -Path $backup | Out-Null
foreach ($rel in $files) {
    $target = Join-Path $root ($rel -replace '/', '\')
    $original = Join-Path $backup ($rel -replace '/', '\')
    New-Item -ItemType Directory -Force -Path (Split-Path $original) | Out-Null
    Copy-Item -LiteralPath $target -Destination $original -Force
}
Write-Host "[BACKUP] $backup" -ForegroundColor Yellow
$success = $false
try {
    foreach ($rel in $files) {
        $target = Join-Path $root ($rel -replace '/', '\')
        [System.IO.File]::WriteAllText($target, [string]$prepared[$rel], $utf8)
    }
    & dart format lib/ui/mobile_products.dart lib/ui/debt.dart
    if ($LASTEXITCODE -ne 0) { throw 'dart format failed' }
    & flutter analyze
    if ($LASTEXITCODE -ne 0) { throw 'flutter analyze failed' }
    & flutter test
    if ($LASTEXITCODE -ne 0) { throw 'flutter test failed' }
    $success = $true
    Write-Host '[SUCCESS] Mobile PWA V4 UI applied. No hosting deployment performed.' -ForegroundColor Green
    Write-Host '[NEXT] Review build + Firebase preview before publishing LIVE.' -ForegroundColor Cyan
} finally {
    if (-not $success) {
        foreach ($rel in $files) {
            $target = Join-Path $root ($rel -replace '/', '\')
            $original = Join-Path $backup ($rel -replace '/', '\')
            Copy-Item -LiteralPath $original -Destination $target -Force
        }
        Write-Host '[ROLLBACK] Restored original mobile_products.dart and debt.dart.' -ForegroundColor Yellow
    }
}
