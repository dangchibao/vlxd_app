#requires -Version 5.1
# Patch V2: barcode/printing visual elements ONLY. Does not depend on unit-correction button structure.
# No Firebase changes, SQLite changes, print handler changes, or inventory writes.
$ErrorActionPreference = 'Stop'
$root = 'D:\app\vlxd_app'
$pkg = Split-Path -Parent $MyInvocation.MyCommand.Path
$utf8 = New-Object System.Text.UTF8Encoding($false)
$catalogPath = Join-Path $root 'lib\ui\catalog.dart'
$mobilePath = Join-Path $root 'lib\ui\mobile_products.dart'

function Read-Utf8([string]$path) {
  if (-not (Test-Path -LiteralPath $path)) { throw "File not found: $path" }
  return [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
}
function Snippet([string]$name) {
  return (Read-Utf8 (Join-Path $pkg ('snippets\' + $name))).TrimEnd([char[]]@([char]13,[char]10))
}
function Replace-OneRegex([string]$source,[string]$pattern,[string]$replacement,[string]$label) {
  $regex = New-Object System.Text.RegularExpressions.Regex($pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
  $matches = $regex.Matches($source)
  if ($matches.Count -ne 1) { throw "Unsupported layout: $label ($($matches.Count) matches). NO FILES CHANGED." }
  $m = $matches[0]
  return $source.Substring(0,$m.Index) + $replacement + $source.Substring($m.Index+$m.Length)
}
function Replace-OneLiteral([string]$source,[string]$old,[string]$new,[string]$label) {
  $a = $source.IndexOf($old,[System.StringComparison]::Ordinal)
  if ($a -lt 0 -or $source.IndexOf($old,$a+$old.Length,[System.StringComparison]::Ordinal) -ge 0) {
    throw "Unsupported layout: $label. NO FILES CHANGED."
  }
  return $source.Substring(0,$a) + $new + $source.Substring($a+$old.Length)
}
if (-not (Test-Path (Join-Path $root 'pubspec.yaml'))) { throw 'Project not found at D:\app\vlxd_app' }
if (Get-Process -Name 'vlxd_app' -ErrorAction SilentlyContinue) {
  throw 'Close VLXD Bay Hai before applying this patch. NO FILES CHANGED.'
}
$originalCatalog = Read-Utf8 $catalogPath
$originalMobile = Read-Utf8 $mobilePath
if (-not $originalCatalog.Contains('PrintService.barcode(p)') -or -not $originalCatalog.Contains('Barcode.code128()')) {
  throw 'Code 128 printing feature not found. NO FILES CHANGED.'
}
$patchedCatalog = $originalCatalog
$patchedMobile = $originalMobile

# The amber unit-correction action can be old or already modified; leave it untouched.
# Barcode desktop action: patch only known original QR-like icon, or skip already-patched action.
if ($patchedCatalog.Contains('barcode-print-teal-v2') -or $patchedCatalog.Contains('barcode-print-teal-v1')) {
  Write-Host '[SKIP] Barcode desktop action already has the teal visual patch.' -ForegroundColor Cyan
} else {
  $pattern = "IconButton\(\s*tooltip:\s*'Mã vạch và in',\s*onPressed:\s*\(\)\s*=>\s*showBarcode\(context,\s*p\),\s*icon:\s*const Icon\(Icons\.qr_code_2\),\s*\),"
  $patchedCatalog = Replace-OneRegex $patchedCatalog $pattern (Snippet 'barcode_action.dart') 'barcode desktop icon'
}
# Dialog title: may be old or already updated. Print logic remains intact.
$oldTitle = "title: const Text('Mã vạch sản phẩm'),"
$newTitle = "title: const Text('Mã vạch & In tem'),"
if ($patchedCatalog.Contains($oldTitle)) {
  $patchedCatalog = Replace-OneLiteral $patchedCatalog $oldTitle $newTitle 'barcode title'
} elseif (-not $patchedCatalog.Contains($newTitle)) { throw 'Unknown barcode dialog title. NO FILES CHANGED.' }

if ($patchedCatalog.Contains("label: const Text('In tem mã vạch')")) {
  Write-Host '[SKIP] Print button already labeled In tem ma vach.' -ForegroundColor Cyan
} else {
  $pPrint = "FilledButton\.icon\(\s*onPressed:\s*\(\)\s*=>\s*attempt\(\(\)\s*=>\s*PrintService\.barcode\(p\)\),\s*icon:\s*const Icon\(Icons\.print_outlined\),\s*label:\s*const Text\('In mã vạch'\),\s*\),"
  $patchedCatalog = Replace-OneRegex $patchedCatalog $pPrint (Snippet 'print_button.dart') 'barcode print action'
}
# Mobile popup remains a barcode action, not a scanner.
if ($patchedMobile.Contains('mobile-barcode-print-teal-v2') -or $patchedMobile.Contains('mobile-barcode-print-teal-v1')) {
  Write-Host '[SKIP] Mobile barcode action already updated.' -ForegroundColor Cyan
} else {
  $pMobile = "const PopupMenuItem<String>\(\s*value:\s*'barcode',\s*child:\s*Text\('Mã vạch / in'\),\s*\),"
  $patchedMobile = Replace-OneRegex $patchedMobile $pMobile (Snippet 'mobile_menu.dart') 'mobile barcode action'
}
# Ensure actions are still wired to the same handlers.
if (-not $patchedCatalog.Contains('PrintService.barcode(p)') -or -not $patchedCatalog.Contains('Barcode.code128()') -or -not $patchedCatalog.Contains('showBarcode(context, p)')) {
  throw 'Barcode handler invariant failed. NO FILES CHANGED.'
}
if (-not $patchedMobile.Contains("action == 'barcode'") -or -not $patchedMobile.Contains('showBarcode(context, p)')) {
  throw 'Mobile barcode action invariant failed. NO FILES CHANGED.'
}
if ($patchedCatalog -ceq $originalCatalog -and $patchedMobile -ceq $originalMobile) {
  Write-Host '[OK] Barcode & Print UI was already updated. No files changed.' -ForegroundColor Green
  exit 0
}

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backup = Join-Path $root ('.vlxd_safe_backups\barcode_print_v2_' + $stamp)
New-Item -ItemType Directory -Path $backup -Force | Out-Null
Copy-Item -LiteralPath $catalogPath -Destination (Join-Path $backup 'catalog.dart') -Force
Copy-Item -LiteralPath $mobilePath -Destination (Join-Path $backup 'mobile_products.dart') -Force
Write-Host "[BACKUP] $backup" -ForegroundColor Cyan
try {
  [System.IO.File]::WriteAllText($catalogPath,$patchedCatalog,$utf8)
  [System.IO.File]::WriteAllText($mobilePath,$patchedMobile,$utf8)
  Set-Location -LiteralPath $root
  & dart format lib/ui/catalog.dart lib/ui/mobile_products.dart
  if ($LASTEXITCODE -ne 0) { throw 'dart format FAILED' }
  & flutter pub get
  if ($LASTEXITCODE -ne 0) { throw 'flutter pub get FAILED' }
  & flutter analyze --no-pub
  if ($LASTEXITCODE -ne 0) { throw 'flutter analyze FAILED' }
  & flutter test --no-pub
  if ($LASTEXITCODE -ne 0) { throw 'flutter test FAILED' }
  Write-Host '[SUCCESS] Ma vach & In updated (teal); unit correction UI untouched. All Flutter tests passed.' -ForegroundColor Green
  Write-Host '[NEXT] Build Windows and/or Web/PWA separately.'
} catch {
  Copy-Item -LiteralPath (Join-Path $backup 'catalog.dart') -Destination $catalogPath -Force
  Copy-Item -LiteralPath (Join-Path $backup 'mobile_products.dart') -Destination $mobilePath -Force
  Write-Host '[ROLLBACK] Restored source files from backup.' -ForegroundColor Yellow
  throw
}
