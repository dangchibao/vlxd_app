#requires -Version 5.1
# UI exact-source patch; no Firebase deploys or data mutations.
$ErrorActionPreference = 'Stop'
$root = 'D:\app\vlxd_app'
$pkg = Split-Path -Parent $MyInvocation.MyCommand.Path
$manifestPath = Join-Path $pkg 'manifest.json'
$testSource = Join-Path $pkg 'tests\ui_responsive_review_test.dart'
$testDest = Join-Path $root 'test\ui_responsive_real_source_v3_test.dart'
if (-not (Test-Path -LiteralPath (Join-Path $root 'pubspec.yaml'))) { throw 'Wrong project folder. No changes.' }
if (Get-Process -Name vlxd_app -ErrorAction SilentlyContinue) { throw 'Close VLXD Bay Hai Windows first. No changes.' }
if (-not (Test-Path -LiteralPath $manifestPath)) { throw 'Missing manifest. No changes.' }
if (-not (Test-Path -LiteralPath $testSource)) { throw 'Missing test. No changes.' }
if (Test-Path -LiteralPath $testDest) { throw 'Test file already exists; check previous install. No changes.' }
$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($manifest.patch_name -ne 'VLXD-UI-Source-Exact-20261121-V3') { throw 'Wrong patch manifest. No changes.' }
$files = @($manifest.file_pairs)
if ($files.Count -ne 6 -or @($manifest.changes).Count -ne 22) { throw 'Incomplete manifest. No changes.' }
foreach ($entry in $files) {
  $rel = [string]$entry.file
  if ($rel -notmatch '^lib/ui/(app|catalog|debt|mobile_products|operations|vlxd_theme)\.dart$') {
    throw "Unexpected file in patch: $rel. No changes."
  }
  $dest = Join-Path $root $rel
  $overlay = Join-Path $pkg ('overlay\' + $rel)
  if (-not (Test-Path -LiteralPath $dest) -or -not (Test-Path -LiteralPath $overlay)) {
    throw "Missing source/overlay: $rel. No changes."
  }
  $current = (Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash.ToLowerInvariant()
  $overlayHash = (Get-FileHash -LiteralPath $overlay -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($overlayHash -ne ([string]$entry.new_sha256)) {
    throw "Overlay checksum mismatch: $rel. No changes."
  }
  if ($current -ne ([string]$entry.old_sha256)) {
    if ($current -eq ([string]$entry.new_sha256)) {
      throw "UI code already matches patch output: $rel. Do not apply twice."
    }
    throw "[SOURCE CHANGED] $rel does not match your uploaded 2026-11-21 00:02 source ZIP. NO FILES CHANGED. Export a new source ZIP before updating."
  }
  Write-Host "[MATCH] $rel" -ForegroundColor DarkCyan
}
# Check important action strings in final overlay before touching the live project.
$catalogOverlay = [IO.File]::ReadAllText((Join-Path $pkg 'overlay\lib\ui\catalog.dart'),[Text.Encoding]::UTF8)
$mobileOverlay = [IO.File]::ReadAllText((Join-Path $pkg 'overlay\lib\ui\mobile_products.dart'),[Text.Encoding]::UTF8)
$operationsOverlay = [IO.File]::ReadAllText((Join-Path $pkg 'overlay\lib\ui\operations.dart'),[Text.Encoding]::UTF8)
foreach ($name in @('product-action-glyphs-exact-v4','_ProductActionKind.clipboardCheck','PrintService.barcode(p)','Barcode.code128()','verifyUnitCorrectionReady()','_unitCorrectionInput(reason')) {
  if (-not $catalogOverlay.Contains($name)) { throw "Catalog protection invariant failed: $name" }
}
foreach ($name in @("action == 'barcode'","action == 'correct-unit'","action == 'details'",'showBarcode(context, p)','receiveStock(context, p)')) {
  if (-not $mobileOverlay.Contains($name)) { throw "Mobile protection invariant failed: $name" }
}
foreach ($name in @('assignMissingLotNumbers','hideEmptyInventoryLot','receiveStock(context, p)','inspectStock(context, p)')) {
  if (-not $operationsOverlay.Contains($name)) { throw "Warehouse protection invariant failed: $name" }
}
foreach ($toolName in @('dart','flutter')) {
  if (-not (Get-Command $toolName -ErrorAction SilentlyContinue)) { throw "Missing $toolName on PATH. No changes." }
}
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backup = Join-Path $root ('.vlxd_safe_backups\ui_real_source_v3_' + $stamp)
foreach ($entry in $files) {
  $rel = [string]$entry.file
  $backupFile = Join-Path $backup $rel
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $backupFile) | Out-Null
  Copy-Item -LiteralPath (Join-Path $root $rel) -Destination $backupFile -Force
}
Write-Host "[BACKUP] $backup" -ForegroundColor Cyan
try {
  foreach ($entry in $files) {
    $rel = [string]$entry.file
    Copy-Item -LiteralPath (Join-Path $pkg ('overlay\' + $rel)) -Destination (Join-Path $root $rel) -Force
  }
  Copy-Item -LiteralPath $testSource -Destination $testDest -Force
  Set-Location -LiteralPath $root
  $formatted = @($files | ForEach-Object { [string]$_.file })
  & dart format @formatted 'test/ui_responsive_real_source_v3_test.dart'
  if ($LASTEXITCODE -ne 0) { throw 'dart format failed' }
  & flutter analyze --no-pub
  if ($LASTEXITCODE -ne 0) { throw 'flutter analyze failed' }
  & flutter test --no-pub
  if ($LASTEXITCODE -ne 0) { throw 'flutter test failed' }
  Write-Host '[SUCCESS] Updated 6 UI source files from exact source ZIP. Flutter analyze/test passed.' -ForegroundColor Green
  Write-Host '[INFO] No Firebase deploy, setup install, SQLite/Firestore change, or package dependency upgrade.'
  Write-Host '[NEXT] Build and visually test phone/desktop preview before any LIVE deployment.'
} catch {
  Write-Host "[FAIL] $($_.Exception.Message)" -ForegroundColor Red
  foreach ($entry in $files) {
    $rel = [string]$entry.file
    Copy-Item -LiteralPath (Join-Path $backup $rel) -Destination (Join-Path $root $rel) -Force
  }
  if (Test-Path -LiteralPath $testDest) { Remove-Item -LiteralPath $testDest -Force }
  Write-Host '[ROLLED BACK] All 6 UI files restored, test removed. Backup kept.' -ForegroundColor Yellow
  throw
}
