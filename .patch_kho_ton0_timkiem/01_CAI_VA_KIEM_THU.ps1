# Safe patch for the reviewed VLXD Bay Hai project. No Firebase deploy or SQLite edits.
$ErrorActionPreference = 'Stop'
$root = 'D:\app\vlxd_app'
$pkg = Split-Path -Parent $MyInvocation.MyCommand.Path
$utf8 = [System.Text.UTF8Encoding]::new($false)

function Replace-ExactlyOne([string]$source, [string]$pattern, [string]$replacement, [string]$label) {
  $re = [System.Text.RegularExpressions.Regex]::new($pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
  $m = $re.Match($source)
  if (-not $m.Success -or $re.Matches($source).Count -ne 1) {
    throw "Khong dung cau truc code mong doi: $label. CHUA SUA BAT KY FILE NAO."
  }
  return $source.Substring(0, $m.Index) + $replacement.TrimEnd("`r", "`n") + "`r`n`r`n" + $source.Substring($m.Index + $m.Length)
}
function ReadSnippet([string]$name) {
  $path = Join-Path $pkg ('snippets\' + $name)
  if (-not (Test-Path -LiteralPath $path)) { throw "Thieu file trong ZIP: $name" }
  return [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
}

if (-not (Test-Path (Join-Path $root 'pubspec.yaml'))) { throw 'Khong tim thay du an D:\app\vlxd_app' }
if (Get-Process -Name vlxd_app -ErrorAction SilentlyContinue) {
  throw 'Hay dong VLXD Bay Hai Windows truoc khi cai ban va. KHONG tu dong tat ung dung.'
}
$paths = @('lib\domain\shop.dart','lib\ui\catalog.dart','lib\ui\operations.dart','lib\ui\app.dart')
$inputs = @{}
foreach ($rel in $paths) {
  $path = Join-Path $root $rel
  if (-not (Test-Path -LiteralPath $path)) { throw "Khong co file: $rel" }
  $inputs[$rel] = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
}
if (-not $inputs['lib\domain\shop.dart'].Contains('correctReceivedProductUnit')) { throw 'Ban va truoc chua duoc cai vao code.' }
if ($inputs['lib\domain\shop.dart'].Contains('Zero-stock exception:')) { throw 'Ban va nay da duoc cai. Khong cai lap.' }
if (-not $inputs['lib\ui\catalog.dart'].Contains('correctReceivedUnitDialog')) { throw 'Chua co form dinh chinh tu ban va truoc.' }
if ($inputs['lib\ui\operations.dart'].Contains('class _InventoryPageState extends State<InventoryPage>')) { throw 'Tim kiem Kho da co. Can doi chieu phien ban truoc khi cai lap.' }
if ($inputs['lib\ui\app.dart'].Contains("titleText('Công việc đang mở'")) { throw 'Dashboard da duoc sua. Khong cai lap.' }

$updated = @{}
$updated['lib\domain\shop.dart'] = Replace-ExactlyOne $inputs['lib\domain\shop.dart'] `
  '(?s)  void correctReceivedProductUnit\(\{.*?\r?\n  \}\s*(?=  void archiveProduct\()' `
  (ReadSnippet 'shop_correct_unit.txt') 'domain correction'
$updated['lib\ui\catalog.dart'] = Replace-ExactlyOne $inputs['lib\ui\catalog.dart'] `
  '(?s)(?:// UI-only shorthand.*?\r?\n\r?\n)?/// Standalone, intentional correction workflow.*?(?=Future<String\?> pickImage\()' `
  (ReadSnippet 'catalog_unit_dialog.txt') 'catalog correction dialog'
$updated['lib\ui\operations.dart'] = Replace-ExactlyOne $inputs['lib\ui\operations.dart'] `
  '(?s)class InventoryPage extends StatelessWidget \{.*?(?=Future<void> receiveStock\()' `
  (ReadSnippet 'inventory_page.txt') 'inventory search page'
$computed = ReadSnippet 'dashboard_computed.txt'
$panel = ReadSnippet 'dashboard_panel.txt'
$dashboard = Replace-ExactlyOne $inputs['lib\ui\app.dart'] `
  '(?s)    final low = c\.data\.products.*?(?=    return ListView\()' `
  $computed 'dashboard computed values'
# Replace the dashboard card by the exact section headings. This avoids a
# fragile nested-regex string with single quotes and is safe in PS 5.1.
$oldHeading = "titleText('Việc cần chú ý', size: 18)"
$nextHeading = "titleText('Đơn hàng gần đây', size: 18)"
$oldIndex = $dashboard.IndexOf($oldHeading, [System.StringComparison]::Ordinal)
$nextIndex = $dashboard.IndexOf($nextHeading, [System.StringComparison]::Ordinal)
if ($oldIndex -lt 0 -or $nextIndex -le $oldIndex) {
  throw 'Khong tim thay tieu de Dashboard dung phien ban. CHUA SUA FILE NAO.'
}
if ($dashboard.IndexOf($oldHeading, $oldIndex + $oldHeading.Length, [System.StringComparison]::Ordinal) -ge 0) {
  throw 'Tieu de Dashboard bi trung. CHUA SUA FILE NAO.'
}
$panelStart = $dashboard.LastIndexOf('        panel(', $oldIndex, [System.StringComparison]::Ordinal)
$panelEnd = $dashboard.LastIndexOf('        panel(', $nextIndex, [System.StringComparison]::Ordinal)
if ($panelStart -lt 0 -or $panelEnd -le $panelStart) {
  throw 'Khong xac dinh duoc hai panel can thay. CHUA SUA FILE NAO.'
}
$oldSection = $dashboard.Substring($panelStart, $panelEnd - $panelStart)
if (-not $oldSection.Contains($oldHeading) -or $oldSection.Contains($nextHeading)) {
  throw 'Doan Dashboard khong khop. CHUA SUA FILE NAO.'
}
$dashboard = $dashboard.Substring(0, $panelStart) + $panel.TrimEnd("`r", "`n") + "`r`n" + $dashboard.Substring($panelEnd)
if (-not $dashboard.Contains("import 'package:flutter/services.dart';")) {
  if (-not $dashboard.Contains("import 'package:flutter/material.dart';")) { throw 'Khong tim thay Material import.' }
  $dashboard = $dashboard.Replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';`r`nimport 'package:flutter/services.dart';")
}
$updated['lib\ui\app.dart'] = $dashboard
$test = Join-Path $root 'test\zero_stock_unit_correction_test.dart'
if (Test-Path -LiteralPath $test) { throw 'File unit test da co; khong ghi de.' }
$testSource = Join-Path $pkg 'tests\zero_stock_unit_correction_test.dart'
if (-not (Test-Path $testSource)) { throw 'Thieu file unit test trong ZIP.' }

# All source checks above are dry-run. Only now write with backup.
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backup = Join-Path $root ('.vlxd_safe_backups\zero_inventory_search_' + $stamp)
New-Item -ItemType Directory -Path $backup -Force | Out-Null
foreach ($rel in $paths) {
  $destination = Join-Path $backup $rel
  New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
  Copy-Item -LiteralPath (Join-Path $root $rel) -Destination $destination -Force
}
Write-Host "[BACKUP] $backup" -ForegroundColor Cyan
try {
  foreach ($rel in $paths) {
    [System.IO.File]::WriteAllText((Join-Path $root $rel), $updated[$rel], $utf8)
  }
  Copy-Item -LiteralPath $testSource -Destination $test -Force
  Set-Location $root
  & dart format lib/domain/shop.dart lib/ui/catalog.dart lib/ui/operations.dart lib/ui/app.dart test/zero_stock_unit_correction_test.dart
  if ($LASTEXITCODE -ne 0) { throw 'dart format FAILED' }
  & flutter pub get
  if ($LASTEXITCODE -ne 0) { throw 'flutter pub get FAILED' }
  & flutter analyze --no-pub
  if ($LASTEXITCODE -ne 0) { throw 'flutter analyze FAILED' }
  & flutter test --no-pub
  if ($LASTEXITCODE -ne 0) { throw 'flutter test FAILED' }
  Write-Host '[OK] Patch installed. All automated tests passed.' -ForegroundColor Green
  Write-Host 'Next: run 02_BUILD_WINDOWS.ps1 and/or 03_BUILD_WEB_PWA.ps1.'
  Write-Host 'NO Firebase deployment, offline data deletion, or stock changes were performed.'
} catch {
  Write-Host "[FAILED] $_" -ForegroundColor Red
  foreach ($rel in $paths) {
    Copy-Item -LiteralPath (Join-Path $backup $rel) -Destination (Join-Path $root $rel) -Force
  }
  if (Test-Path -LiteralPath $test) { Remove-Item -LiteralPath $test -Force }
  Write-Host '[ROLLED BACK] Source files restored to pre-patch state.' -ForegroundColor Yellow
  throw
}
