#requires -Version 5.1
# UI-only safe patch, strict matching: run from downloaded ZIP extracted at project root.
$ErrorActionPreference = 'Stop'
$root = 'D:\app\vlxd_app'
$pkg = Split-Path -Parent $MyInvocation.MyCommand.Path
$utf8 = New-Object System.Text.UTF8Encoding($false)
$manifest = Join-Path $pkg 'manifest.json'
$testSource = Join-Path $pkg 'ui_responsive_review_test.dart'
$testDest = Join-Path $root 'test\ui_responsive_review_test.dart'
if (-not (Test-Path -LiteralPath (Join-Path $root 'pubspec.yaml'))) {
  throw 'Expected project D:\app\vlxd_app not found. Nothing changed.'
}
if (Get-Process -Name vlxd_app -ErrorAction SilentlyContinue) {
  throw 'Please close VLXD Bay Hai Windows before applying. Nothing changed.'
}
foreach ($needed in @($manifest,$testSource)) {
  if (-not (Test-Path -LiteralPath $needed)) { throw "Package missing: $needed. Nothing changed." }
}
if (Test-Path -LiteralPath $testDest) {
  throw 'Responsive test file already exists. Do not overwrite. Nothing changed.'
}
$cfg = [System.IO.File]::ReadAllText($manifest,[System.Text.Encoding]::UTF8) | ConvertFrom-Json
$paths = @($cfg.changes | ForEach-Object { [string]$_.file } | Select-Object -Unique)
$original = @{}
$updated = @{}
foreach ($rel in $paths) {
  $file = Join-Path $root $rel
  if (-not (Test-Path -LiteralPath $file)) { throw "Missing source: $rel. Nothing changed." }
  $original[$rel] = [System.IO.File]::ReadAllText($file, [System.Text.Encoding]::UTF8)
  $updated[$rel] = $original[$rel]
}
# Preflight: every replacement must match exactly once. No files are written yet.
foreach ($change in $cfg.changes) {
  $rel = [string]$change.file
  $pat = [string]$change.pattern
  $replacement = [string]$change.replacement
  $regex = New-Object System.Text.RegularExpressions.Regex($pat, [System.Text.RegularExpressions.RegexOptions]::Singleline)
  $matches = $regex.Matches($updated[$rel])
  if ($matches.Count -ne 1) {
    throw "Unsupported source or already patched: $($change.label) ($($matches.Count) matches). NO FILES CHANGED. Send this line and current source ZIP."
  }
  $m = $matches[0]
  $updated[$rel] = $updated[$rel].Substring(0,$m.Index) + $replacement + $updated[$rel].Substring($m.Index+$m.Length)
  Write-Host "[CHECK] $($change.label)" -ForegroundColor DarkCyan
}
# Important functional invariants: do not alter data/logic, barcode/print or auth handlers.
$catalog = $updated['lib/ui/catalog.dart']
$mobile = $updated['lib/ui/mobile_products.dart']
$operations = $updated['lib/ui/operations.dart']
$debt = $updated['lib/ui/debt.dart']
foreach ($symbol in @('product-action-glyphs-exact-v4','_ProductActionKind.clipboardCheck',
  'correctReceivedUnitDialog(context, p)','editProduct(context, original: p)',
  'showBarcode(context, p)','PrintService.barcode(p)','Barcode.code128()',
  'archiveProductDialog(context, p)','verifyUnitCorrectionReady()',
  'vlxd-responsive-correction-v1')) {
  if (-not $catalog.Contains($symbol)) { throw "Catalog safety check missing: $symbol. NO FILES CHANGED." }
}
foreach ($symbol in @("action == 'barcode'",'showBarcode(context, p)',
  "action == 'correct-unit'",'receiveStock(context, p)',
  "action == 'details'",'vlxd-mobile-details-v1')) {
  if (-not $mobile.Contains($symbol)) { throw "Mobile action missing: $symbol. NO FILES CHANGED." }
}
foreach ($symbol in @('receiveStock(context, p)','inspectStock(context, p)',
  'assignMissingLotNumbers','hideEmptyInventoryLot','stockMoves.take(20)')) {
  if (-not $operations.Contains($symbol)) { throw "Warehouse action missing: $symbol. NO FILES CHANGED." }
}
foreach ($symbol in @('editCustomer(context, original: customer)',
  'deleteCustomer(context, customer)','selectedId = customer')) {
  if (-not $debt.Contains($symbol)) { throw "Debt customer action missing: $symbol. NO FILES CHANGED." }
}
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backup = Join-Path $root ('.vlxd_safe_backups\ui_mobile_desktop_audit_' + $stamp)
New-Item -ItemType Directory -Path $backup -Force | Out-Null
foreach ($rel in $paths) {
  $dest = Join-Path $backup $rel
  New-Item -ItemType Directory -Path (Split-Path -Parent $dest) -Force | Out-Null
  Copy-Item -LiteralPath (Join-Path $root $rel) -Destination $dest -Force
}
Write-Host "[BACKUP] $backup" -ForegroundColor Cyan
try {
  foreach ($rel in $paths) {
    [System.IO.File]::WriteAllText((Join-Path $root $rel), $updated[$rel], $utf8)
  }
  Copy-Item -LiteralPath $testSource -Destination $testDest -Force
  Set-Location -LiteralPath $root
  $formatFiles = @($paths | ForEach-Object { $_ -replace '\\','/' })
  & dart format @formatFiles 'test/ui_responsive_review_test.dart'
  if ($LASTEXITCODE -ne 0) { throw 'dart format failed' }
  & flutter pub get
  if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed' }
  & flutter analyze --no-pub
  if ($LASTEXITCODE -ne 0) { throw 'flutter analyze failed' }
  & flutter test --no-pub
  if ($LASTEXITCODE -ne 0) { throw 'flutter test failed' }
  Write-Host '[SUCCESS] Responsive UI patch applied; all Flutter tests passed.' -ForegroundColor Green
  Write-Host '[INFO] No Firebase Hosting deploy, Firestore writes, SQLite deletion or setup overwrite.'
  Write-Host '[NEXT] Build Windows/Web separately, inspect on desktop and real phone.'
} catch {
  Write-Host "[FAIL] $_" -ForegroundColor Red
  foreach ($rel in $paths) {
    Copy-Item -LiteralPath (Join-Path $backup $rel) -Destination (Join-Path $root $rel) -Force
  }
  if (Test-Path -LiteralPath $testDest) { Remove-Item -LiteralPath $testDest -Force }
  Write-Host '[ROLLED BACK] Source and tests restored. Backups retained.' -ForegroundColor Yellow
  throw
}
