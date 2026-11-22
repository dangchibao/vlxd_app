#requires -Version 5.1
# V4: Replace ONLY the four HANG HOA action glyphs. ASCII PS5.1 script.
$ErrorActionPreference = 'Stop'
$root = 'D:\app\vlxd_app'
$file = Join-Path $root 'lib\ui\catalog.dart'
$package = Split-Path -Parent $MyInvocation.MyCommand.Path
$glyphFile = Join-Path $package 'snippets\product_action_painter.txt'
$rowFile = Join-Path $package 'snippets\product_action_row.txt'
$utf8 = New-Object System.Text.UTF8Encoding($false)
if (-not (Test-Path -LiteralPath (Join-Path $root 'pubspec.yaml'))) { throw 'Wrong project root. No changes made.' }
foreach ($f in @($file, $glyphFile, $rowFile)) {
  if (-not (Test-Path -LiteralPath $f)) { throw "Missing file: $f. No changes made." }
}
if (Get-Process -Name vlxd_app -ErrorAction SilentlyContinue) {
  throw 'Close VLXD Bay Hai Windows before updating. No changes made.'
}
$original = [System.IO.File]::ReadAllText($file, [System.Text.Encoding]::UTF8)
$startKey = 'Widget actions(BuildContext context, Product p) => Wrap('
$branchKey = 'if (p.active && !p.deleted && !p.archivedFromLists) ...['
$endKey = '] else if (p.deleted) ...['
$helperMarker = 'product-action-glyphs-exact-v4'
$rowMarker = 'product-action-row-exact-v4'
$glyph = [System.IO.File]::ReadAllText($glyphFile, [System.Text.Encoding]::UTF8).TrimEnd()
$row = [System.IO.File]::ReadAllText($rowFile, [System.Text.Encoding]::UTF8).TrimEnd()
function Assert-ActionRow([string] $full) {
  if (([regex]::Matches($full, [regex]::Escape($helperMarker))).Count -ne 1 -or
      ([regex]::Matches($full, [regex]::Escape($rowMarker))).Count -ne 1) {
    throw 'V4 markers not found exactly once.'
  }
  $methodAt = $full.IndexOf($startKey, [System.StringComparison]::Ordinal)
  $from = $full.IndexOf($branchKey, $methodAt, [System.StringComparison]::Ordinal)
  $to = $full.IndexOf($endKey, $from, [System.StringComparison]::Ordinal)
  if ($methodAt -lt 0 -or $from -lt 0 -or $to -lt 0) { throw 'Cannot verify action row.' }
  $segment = $full.Substring($from, $to-$from)
  foreach ($part in @(
    '_ProductActionKind.pencil', '_ProductActionKind.clipboardCheck',
    '_ProductActionKind.printer', '_ProductActionKind.ban',
    'Color(0xFF1976D2)', 'Color(0xFFD97706)',
    'Color(0xFF0D9488)', 'Color(0xFFDC2626)',
    'editProduct(context, original: p)',
    'correctReceivedUnitDialog(context, p)',
    'showBarcode(context, p)',
    'archiveProductDialog(context, p)',
    'Get.find<ShopController>().actor?.canAdmin == true'
  )) {
    if (-not $segment.Contains($part)) { throw "Missing required action/icon: $part" }
  }
  if ([regex]::Matches($segment,'\bIconButton\s*\(').Count -ne 4 -or
      [regex]::Matches($segment,'\b_ProductActionGlyph\s*\(').Count -ne 4 -or
      $segment.Contains('Icons.qr_code_2') -or
      $segment.Contains('Icons.edit_note_outlined') -or
      $segment.Contains('OutlinedButton') -or
      $segment.Contains('label:')) {
    throw 'Incorrect action layout or old icon remains.'
  }
  if (-not $full.Contains('Barcode.code128()') -or -not $full.Contains('PrintService.barcode(p)')) {
    throw 'Printing invariants not found.'
  }
  Write-Host '[VERIFY] All four EXACT vector shapes, colors, handlers and Admin check found.' -ForegroundColor Green
}
if ($original.Contains($helperMarker) -and $original.Contains($rowMarker)) {
  Assert-ActionRow $original
  Write-Host '[OK] V4 already applied and verified. Source not changed.' -ForegroundColor Green
  exit 0
}
if ($original.Contains($helperMarker) -or $original.Contains($rowMarker)) {
  throw 'Partial V4 state detected. No files changed.'
}
if ([regex]::Matches($original, [regex]::Escape($startKey)).Count -ne 1) {
  throw 'actions() method not unique. No files changed.'
}
$methodAt = $original.IndexOf($startKey, [System.StringComparison]::Ordinal)
$from = $original.IndexOf($branchKey, $methodAt, [System.StringComparison]::Ordinal)
$to = $original.IndexOf($endKey, $from, [System.StringComparison]::Ordinal)
if ($from -lt 0 -or $to -lt 0 -or $to - $from -gt 16000) {
  throw 'Unknown product action layout. No files changed.'
}
$oldActionRow = $original.Substring($from, $to-$from)
foreach ($handler in @(
  'editProduct(context, original: p)',
  'correctReceivedUnitDialog(context, p)',
  'showBarcode(context, p)',
  'archiveProductDialog(context, p)'
)) {
  if ([regex]::Matches($oldActionRow, [regex]::Escape($handler)).Count -ne 1) {
    throw "Handler [$handler] must occur exactly once. No files changed."
  }
}
if (-not $original.Contains('Barcode.code128()') -or -not $original.Contains('PrintService.barcode(p)')) {
  throw 'Existing barcode functionality not found. No files changed.'
}
$changed = $original.Substring(0, $from) + $row + $original.Substring($to)
$header = "part of 'app.dart';"
if (-not $changed.StartsWith($header)) { throw 'Unexpected Dart file header. No files changed.' }
$changed = $changed.Insert($header.Length, "`r`n`r`n" + $glyph + "`r`n")
Assert-ActionRow $changed
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backupDir = Join-Path $root ('.vlxd_safe_backups\action_icons_exact_v4_' + $stamp)
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
$backup = Join-Path $backupDir 'catalog.dart'
Copy-Item -LiteralPath $file -Destination $backup -Force
Write-Host "[BACKUP] $backup" -ForegroundColor Cyan
try {
  [System.IO.File]::WriteAllText($file, $changed, $utf8)
  Set-Location -LiteralPath $root
  & dart format lib/ui/catalog.dart
  if ($LASTEXITCODE -ne 0) { throw 'dart format failed' }
  $formatted = [System.IO.File]::ReadAllText($file, [System.Text.Encoding]::UTF8)
  Assert-ActionRow $formatted
  & flutter analyze --no-pub
  if ($LASTEXITCODE -ne 0) { throw 'flutter analyze failed' }
  & flutter test --no-pub
  if ($LASTEXITCODE -ne 0) { throw 'flutter test failed' }
  Write-Host '[SUCCESS] V4: EXACT four pictograms applied; NO labels or wide buttons.' -ForegroundColor Green
  Write-Host '[IMPORTANT] Flutter build alone does not update vlxd-bay-hai.web.app. Build + Firebase Hosting deploy required.' -ForegroundColor Yellow
} catch {
  Copy-Item -LiteralPath $backup -Destination $file -Force
  Write-Host '[ROLLBACK] Original catalog.dart restored.' -ForegroundColor Yellow
  throw
}
