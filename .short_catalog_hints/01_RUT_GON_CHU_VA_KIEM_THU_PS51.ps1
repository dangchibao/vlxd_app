#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = (Get-Location).Path
$target = Join-Path $root 'lib\ui\catalog.dart'
$manifestPath = Join-Path $PSScriptRoot 'text_changes.json'
if (!(Test-Path -LiteralPath $target -PathType Leaf)) {
  throw "File not found: $target. Run from D:\app\vlxd_app."
}
if (!(Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw 'Patch manifest missing.' }
$json = [System.IO.File]::ReadAllText($manifestPath, [System.Text.Encoding]::UTF8)
$manifest = ConvertFrom-Json -InputObject $json
$edits = @($manifest.edits)
if ($edits.Count -ne 10) { throw 'Unexpected edit count. STOP.' }
$encoding = New-Object System.Text.UTF8Encoding($false)
$original = [System.IO.File]::ReadAllText($target,[System.Text.Encoding]::UTF8)
$next = $original
$pending = 0
$already = 0
foreach ($edit in $edits) {
  $old = [string]$edit.old
  $new = [string]$edit.new
  $oldCount = [regex]::Matches($original,[regex]::Escape($old)).Count
  $newCount = [regex]::Matches($original,[regex]::Escape($new)).Count
  if ($oldCount -eq 1 -and $newCount -eq 0) {
    $next = $next.Replace($old,$new)
    $pending++
    Write-Host "[CHECK] $($edit.label)" -ForegroundColor DarkCyan
  } elseif ($oldCount -eq 0 -and $newCount -eq 1) {
    $already++
    Write-Host "[ALREADY] $($edit.label)" -ForegroundColor Gray
  } else {
    throw "SOURCE-MISMATCH at $($edit.label): old=$oldCount new=$newCount. NO FILES CHANGED."
  }
}
if ($pending -eq 0) {
  Write-Host '[OK] All labels already shortened. No files changed.' -ForegroundColor Green
  exit 0
}
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backupDir = Join-Path $root ".vlxd_safe_backups\short_catalog_hints_$stamp"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
$backup = Join-Path $backupDir 'catalog.dart'
[System.IO.File]::Copy($target,$backup,$false)
$written = $false
try {
  [System.IO.File]::WriteAllText($target,$next,$encoding)
  $written = $true
  Write-Host "[BACKUP] $backupDir" -ForegroundColor Cyan
  Write-Host "[UPDATED] $pending text labels (no behavior changes)" -ForegroundColor Cyan
  flutter analyze
  if ($LASTEXITCODE -ne 0) { throw 'flutter analyze failed' }
  flutter test
  if ($LASTEXITCODE -ne 0) { throw 'flutter test failed' }
  Write-Host '[SUCCESS] Catalog help text shortened. Analyze and tests passed.' -ForegroundColor Green
  Write-Host '[NEXT] Build Web/PWA or Windows when ready. No deployment performed.' -ForegroundColor Cyan
} catch {
  if ($written) {
    [System.IO.File]::Copy($backup,$target,$true)
    Write-Host '[ROLLBACK] Original catalog.dart restored.' -ForegroundColor Yellow
  }
  throw
}
