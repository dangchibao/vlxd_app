#requires -Version 5.1
# VLXD Bay Hai - product actions: ONLY replace 4 action icons.
# Does NOT touch any product values, unit correction logic, barcode printing, or Firestore.
$ErrorActionPreference = 'Stop'
$root = 'D:\app\vlxd_app'
$file = Join-Path $root 'lib\ui\catalog.dart'
$snippet = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) 'snippets\product_action_icons.dart.txt'
$utf8 = New-Object System.Text.UTF8Encoding($false)
if (-not (Test-Path -LiteralPath (Join-Path $root 'pubspec.yaml'))) { throw 'Project not found: D:\app\vlxd_app' }
if (-not (Test-Path -LiteralPath $file)) { throw 'Missing lib\ui\catalog.dart' }
if (-not (Test-Path -LiteralPath $snippet)) { throw 'Missing icon snippet' }
if (Get-Process -Name 'vlxd_app' -ErrorAction SilentlyContinue) {
  throw 'Please close VLXD Bay Hai Windows first. NO FILES CHANGED.'
}
$original = [System.IO.File]::ReadAllText($file, [System.Text.Encoding]::UTF8)
$marker = 'product-action-icons-only-v3'
if ($original.Contains($marker)) {
  Write-Host '[OK] All four product action icons already updated. No changes needed.' -ForegroundColor Green
  exit 0
}
$methodMarker = 'Widget actions(BuildContext context, Product p) => Wrap('
if ($original.IndexOf($methodMarker, [System.StringComparison]::Ordinal) -lt 0 -or
    $original.IndexOf($methodMarker, $original.IndexOf($methodMarker, [System.StringComparison]::Ordinal) + $methodMarker.Length, [System.StringComparison]::Ordinal) -ge 0) {
  throw 'Expected exactly one product actions() method. NO FILES CHANGED.'
}
$methodStart = $original.IndexOf($methodMarker, [System.StringComparison]::Ordinal)
$branchMarker = 'if (p.active && !p.deleted && !p.archivedFromLists) ...['
$branchStart = $original.IndexOf($branchMarker, $methodStart, [System.StringComparison]::Ordinal)
$elseMarker = '] else if (p.deleted) ...['
if ($branchStart -lt 0) { throw 'Product actions layout not recognized. NO FILES CHANGED.' }
$elseStart = $original.IndexOf($elseMarker, $branchStart, [System.StringComparison]::Ordinal)
if ($elseStart -lt 0 -or $elseStart - $branchStart -gt 12000) {
  throw 'Product actions branch boundary not recognized. NO FILES CHANGED.'
}
$oldBranch = $original.Substring($branchStart, $elseStart - $branchStart)
$handlers = @(
  'editProduct(context, original: p)',
  'correctReceivedUnitDialog(context, p)',
  'showBarcode(context, p)',
  'archiveProductDialog(context, p)'
)
foreach ($handler in $handlers) {
  $count = [regex]::Matches($oldBranch, [regex]::Escape($handler)).Count
  if ($count -ne 1) {
    throw "Expected one action handler [$handler]; found $count. NO FILES CHANGED."
  }
}
if (-not $original.Contains('PrintService.barcode(p)') -or -not $original.Contains('Barcode.code128()')) {
  throw 'Barcode printing invariants missing. NO FILES CHANGED.'
}
$newBranch = [System.IO.File]::ReadAllText($snippet, [System.Text.Encoding]::UTF8).TrimEnd([char[]]@([char]13,[char]10))
# Preserve original indentation before the if statement; include spaces before the existing else marker.
$changed = $original.Substring(0,$branchStart) + $newBranch + $original.Substring($elseStart)
foreach ($handler in $handlers) {
  if ([regex]::Matches($changed, [regex]::Escape($handler)).Count -lt 1) {
    throw "Action lost [$handler]. NO FILES CHANGED."
  }
}
if ($changed -ceq $original) { throw 'No source changes detected.' }
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backupDir = Join-Path $root ('.vlxd_safe_backups\icons_only_v3_' + $stamp)
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
$backupFile = Join-Path $backupDir 'catalog.dart'
Copy-Item -LiteralPath $file -Destination $backupFile -Force
Write-Host "[BACKUP] $backupFile" -ForegroundColor Cyan
try {
  [System.IO.File]::WriteAllText($file, $changed, $utf8)
  Set-Location -LiteralPath $root
  & dart format lib/ui/catalog.dart
  if ($LASTEXITCODE -ne 0) { throw 'dart format failed' }
  & flutter analyze --no-pub
  if ($LASTEXITCODE -ne 0) { throw 'flutter analyze failed' }
  & flutter test --no-pub
  if ($LASTEXITCODE -ne 0) { throw 'flutter test failed' }
  Write-Host '[SUCCESS] Only 4 product action icons changed. No labels, no wide buttons.' -ForegroundColor Green
  Write-Host '[NEXT] Build Windows / Web using the previously validated build scripts.'
} catch {
  Copy-Item -LiteralPath $backupFile -Destination $file -Force
  Write-Host '[ROLLBACK] Restored catalog.dart from backup.' -ForegroundColor Yellow
  throw
}
