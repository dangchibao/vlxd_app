#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = (Get-Location).Path
$target = Join-Path $root 'lib\ui\catalog.dart'
$pubspec = Join-Path $root 'pubspec.yaml'
if (-not (Test-Path -LiteralPath $pubspec -PathType Leaf)) { throw 'Chay script tu thu muc goc du an vlxd_app.' }
if (-not (Test-Path -LiteralPath $target -PathType Leaf)) { throw 'Khong tim thay lib/ui/catalog.dart.' }
$pub = [IO.File]::ReadAllText($pubspec, [Text.Encoding]::UTF8)
if ($pub -notmatch '(?m)^name:\s*vlxd_app\s*$') { throw 'Khong dung du an vlxd_app. NO FILES CHANGED.' }
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) { throw 'Khong tim thay flutter trong PATH.' }
if (-not (Get-Command dart -ErrorAction SilentlyContinue)) { throw 'Khong tim thay dart trong PATH.' }

$utf8 = New-Object System.Text.UTF8Encoding($false)
$source = [IO.File]::ReadAllText($target, [Text.Encoding]::UTF8)
$marker = 'vlxd-low-stock-space-v1'
$pattern = '(?m)^(?<indent>[ \t]*)field\(\s*minimum,\s*''Báo tồn thấp \(tùy chọn\)'',\s*number:\s*true,\s*\),'
$found = [regex]::Matches($source, $pattern)
if ($found.Count -ne 1) {
    throw "SOURCE-MISMATCH: Bao ton thap field count=$($found.Count). NO FILES CHANGED."
}
$match = $found[0]
$start = [Math]::Max(0, $match.Index - 250)
$preceding = $source.Substring($start, $match.Index - $start)
if ($preceding.Contains($marker)) {
    Write-Host '[ALREADY] Low-stock spacing already applied. No files changed.' -ForegroundColor Green
    exit 0
}
if ($source.Contains($marker)) {
    throw 'Marker exists elsewhere in source; stopping to avoid duplicate/misplaced patch. NO FILES CHANGED.'
}

$indent = $match.Groups['indent'].Value
$nl = if ($source.Contains("`r`n")) { "`r`n" } else { "`n" }
$spacer = @(
    "${indent}SizedBox(",
    "${indent}  key: const ValueKey('$marker'),",
    "${indent}  height: MediaQuery.sizeOf(ctx).width < 600 ? 12 : 16,",
    "${indent}),"
) -join $nl
$spacer += $nl
$updated = $source.Substring(0, $match.Index) + $spacer + $source.Substring($match.Index)
if ([regex]::Matches($updated, [regex]::Escape($marker)).Count -ne 1) {
    throw 'Failed to validate generated patch. NO FILES CHANGED.'
}

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backupDir = Join-Path $root ".vlxd_safe_backups\low_stock_spacing_$stamp"
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
$backup = Join-Path $backupDir 'catalog.dart'
[IO.File]::Copy($target, $backup, $false)
Write-Host "[BACKUP] $backup" -ForegroundColor Cyan
$written = $false
try {
    [IO.File]::WriteAllText($target, $updated, $utf8)
    $written = $true
    Write-Host '[UPDATED] Spacing before Bao ton thap: phone 12px, desktop 16px.' -ForegroundColor Cyan
    & dart format 'lib/ui/catalog.dart'
    if ($LASTEXITCODE -ne 0) { throw 'dart format failed' }
    $after = [IO.File]::ReadAllText($target, [Text.Encoding]::UTF8)
    if (-not $after.Contains($marker)) { throw 'Patched spacing marker was lost after formatting' }
    & flutter analyze
    if ($LASTEXITCODE -ne 0) { throw 'flutter analyze failed' }
    & flutter test
    if ($LASTEXITCODE -ne 0) { throw 'flutter test failed' }
    Write-Host '[SUCCESS] Spacing updated; Flutter analyze and tests passed.' -ForegroundColor Green
    Write-Host '[INFO] No Windows installation or Firebase deployment performed.' -ForegroundColor Cyan
} catch {
    if ($written) {
        [IO.File]::Copy($backup, $target, $true)
        Write-Host '[ROLLBACK] Restored catalog.dart from exact byte backup.' -ForegroundColor Yellow
    }
    throw
}
