#requires -Version 5.1
# UI-only patch. Does not change Firestore, SQLite, product IDs, barcode values or print logic.
$ErrorActionPreference = 'Stop'
$root = 'D:\app\vlxd_app'
$pkg = Split-Path -Parent $MyInvocation.MyCommand.Path
$utf8 = New-Object System.Text.UTF8Encoding($false)
$catalogFile = Join-Path $root 'lib\ui\catalog.dart'
$mobileFile = Join-Path $root 'lib\ui\mobile_products.dart'

function Read-Source([string]$path) {
  if (-not (Test-Path -LiteralPath $path)) { throw "Missing file: $path" }
  return [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
}
function Read-Snippet([string]$name) { return (Read-Source (Join-Path $pkg ('snippets\' + $name))).TrimEnd([char[]]@([char]13, [char]10)) }
function Replace-ExactlyOnce([string]$source, [string]$pattern, [string]$replacement, [string]$label) {
  $regex = New-Object System.Text.RegularExpressions.Regex($pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
  $matches = $regex.Matches($source)
  if ($matches.Count -ne 1) { throw "Unexpected source layout for $label ($($matches.Count) matches). NO FILES CHANGED." }
  $m = $matches[0]
  return $source.Substring(0, $m.Index) + $replacement + $source.Substring($m.Index + $m.Length)
}
if (-not (Test-Path -LiteralPath (Join-Path $root 'pubspec.yaml'))) { throw 'Project missing: D:\app\vlxd_app' }
if (Get-Process -Name 'vlxd_app' -ErrorAction SilentlyContinue) {
  throw 'Close the VLXD Bay Hai Windows app first. No files changed.'
}
$oldCatalog = Read-Source $catalogFile
$oldMobile = Read-Source $mobileFile
if (-not $oldCatalog.Contains('correctReceivedUnitDialog')) {
  throw 'Unit correction feature was not found. Apply the existing unit correction patch first.'
}
if (-not $oldCatalog.Contains('PrintService.barcode(p)')) { throw 'Barcode printing handler missing. No changes made.' }

# PREVIEW: apply all changes in memory, before touching the user's project.
$newCatalog = $oldCatalog
$newMobile = $oldMobile
if (-not $newCatalog.Contains('color: const Color(0xFF1976D2),')) {
  $p = "IconButton\(\s*tooltip: 'Chi tiết và sửa sản phẩm',\s*onPressed: \(\) => editProduct\(context, original: p\),\s*icon: const Icon\(Icons\.edit_outlined\),\s*\),"
  $newCatalog = Replace-ExactlyOnce $newCatalog $p (Read-Snippet 'edit_button.dart') 'regular edit button'
}
if (-not $newCatalog.Contains('unit-correction-amber-action-v1')) {
  $p = "IconButton\(\s*tooltip: 'Đính chính đơn vị nhập nhầm \(chỉ khi chưa bán/xuất\)',\s*onPressed: \(\) => correctReceivedUnitDialog\(context, p\),\s*icon: const Icon\(Icons\.edit_note_outlined\),\s*\),"
  $newCatalog = Replace-ExactlyOnce $newCatalog $p (Read-Snippet 'correction_button.dart') 'unit correction button'
  $pTitle = "title: const Text\('Đính chính đơn vị nhập nhầm'\),"
  $newTitle = "title: const Text('Đính chính đơn vị nhập nhầm', style: TextStyle(color: Color(0xFF8A5000), fontWeight: FontWeight.w800)),"
  $newCatalog = Replace-ExactlyOnce $newCatalog $pTitle $newTitle 'unit correction dialog title'
  $pConfirm = "FilledButton\(\s*onPressed: saving \|\| !confirmed \? null : \(\) => attempt\(\(\) async \{"
  $newConfirm = "FilledButton(style: FilledButton.styleFrom(backgroundColor: const Color(0xFF965600), foregroundColor: Colors.white), onPressed: saving || !confirmed ? null : () => attempt(() async {"
  $newCatalog = Replace-ExactlyOnce $newCatalog $pConfirm $newConfirm 'unit correction confirmation button'
}
if (-not $newCatalog.Contains('barcode-print-teal-v1')) {
  $p = "IconButton\(\s*tooltip: 'Mã vạch và in',\s*onPressed: \(\) => showBarcode\(context, p\),\s*icon: const Icon\(Icons\.qr_code_2\),\s*\),"
  $newCatalog = Replace-ExactlyOnce $newCatalog $p (Read-Snippet 'barcode_button.dart') 'barcode and print button'
  $newCatalog = Replace-ExactlyOnce $newCatalog "title: const Text\('Mã vạch sản phẩm'\)," "title: const Text('Mã vạch & In tem')," 'barcode dialog title'
  $pPrint = "FilledButton\.icon\(\s*onPressed: \(\) => attempt\(\(\) => PrintService\.barcode\(p\)\),\s*icon: const Icon\(Icons\.print_outlined\),\s*label: const Text\('In mã vạch'\),\s*\),"
  $newCatalog = Replace-ExactlyOnce $newCatalog $pPrint (Read-Snippet 'print_button.dart') 'barcode print confirmation'
}
if (-not $newMobile.Contains('mobile-barcode-print-teal-v1')) {
  $pMobile = "const PopupMenuItem<String>\(\s*value: 'barcode',\s*child: Text\('Mã vạch / in'\),\s*\),"
  $newMobile = Replace-ExactlyOnce $newMobile $pMobile (Read-Snippet 'mobile_barcode_menu.dart') 'mobile barcode menu'
}
if ($newCatalog -eq $oldCatalog -and $newMobile -eq $oldMobile) {
  Write-Host '[OK] The barcode/print color and labels are already installed.' -ForegroundColor Green
  exit 0
}
if (-not $newCatalog.Contains('PrintService.barcode(p)') -or -not $newCatalog.Contains('Barcode.code128()')) {
  throw 'Barcode printing contract check FAILED. NO FILES CHANGED.'
}
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backup = Join-Path $root ('.vlxd_safe_backups\barcode_print_ui_' + $stamp)
New-Item -ItemType Directory -Path $backup -Force | Out-Null
Copy-Item -LiteralPath $catalogFile -Destination (Join-Path $backup 'catalog.dart') -Force
Copy-Item -LiteralPath $mobileFile -Destination (Join-Path $backup 'mobile_products.dart') -Force
Write-Host "[BACKUP] $backup" -ForegroundColor Cyan
try {
  [System.IO.File]::WriteAllText($catalogFile, $newCatalog, $utf8)
  [System.IO.File]::WriteAllText($mobileFile, $newMobile, $utf8)
  Set-Location -LiteralPath $root
  & dart format lib/ui/catalog.dart lib/ui/mobile_products.dart
  if ($LASTEXITCODE -ne 0) { throw 'dart format FAILED' }
  & flutter pub get
  if ($LASTEXITCODE -ne 0) { throw 'flutter pub get FAILED' }
  & flutter analyze --no-pub
  if ($LASTEXITCODE -ne 0) { throw 'flutter analyze FAILED' }
  & flutter test --no-pub
  if ($LASTEXITCODE -ne 0) { throw 'flutter test FAILED' }
  Write-Host '[SUCCESS] Updated Edit (blue), Unit correction (amber), Barcode & Print (teal), Stop sale (red).' -ForegroundColor Green
  Write-Host '[SAFE] No barcode content, printing method, Firebase, SQLite or inventory logic changed.'
  Write-Host '[NEXT] Run 02_BUILD_WINDOWS.ps1 and/or 03_BUILD_WEB_PWA.ps1 from the same ZIP.'
} catch {
  Copy-Item -LiteralPath (Join-Path $backup 'catalog.dart') -Destination $catalogFile -Force
  Copy-Item -LiteralPath (Join-Path $backup 'mobile_products.dart') -Destination $mobileFile -Force
  Write-Host '[ROLLED BACK] Both source files restored from backup.' -ForegroundColor Yellow
  throw
}
