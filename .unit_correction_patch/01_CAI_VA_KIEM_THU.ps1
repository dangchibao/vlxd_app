$ErrorActionPreference = 'Stop'
$root = 'D:\app\vlxd_app'
$pkg = Split-Path -Parent $MyInvocation.MyCommand.Path
$expectedPath = Join-Path $pkg 'meta\source_hashes.json'
$expected = Get-Content -LiteralPath $expectedPath -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not (Test-Path -LiteralPath (Join-Path $root 'pubspec.yaml'))) {
    throw 'Project D:\app\vlxd_app not found.'
}
$tracked = @(
    'lib/domain/shop.dart',
    'lib/ui/catalog.dart',
    'lib/controllers/shop_controller.dart',
    'lib/data/sync/outbox_repository.dart'
)
foreach ($rel in $tracked) {
    $target = Join-Path $root ($rel.Replace('/', '\'))
    $overlay = Join-Path $pkg ('overlay\' + $rel.Replace('/', '\'))
    $prop = $expected.PSObject.Properties[$rel]
    if (-not (Test-Path -LiteralPath $target) -or -not (Test-Path -LiteralPath $overlay)) {
        throw "Missing project/patch file: $rel"
    }
    $actual = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $prop.Value.ToLowerInvariant()) {
        throw "SOURCE CHANGED: $rel. NO FILES MODIFIED. This patch only fits the reviewed ZIP baseline."
    }
}
$testRel = 'test/unit_correction_receipts_test.dart'
$testTarget = Join-Path $root ($testRel.Replace('/', '\'))
if (Test-Path -LiteralPath $testTarget) { throw 'Test file already exists. No files modified.' }
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backupRoot = Join-Path $root ('.unit_correction_backups\' + $stamp)
New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
foreach ($rel in $tracked) {
    $target = Join-Path $root ($rel.Replace('/', '\'))
    $backup = Join-Path $backupRoot ($rel.Replace('/', '\'))
    New-Item -ItemType Directory -Path (Split-Path $backup -Parent) -Force | Out-Null
    Copy-Item -LiteralPath $target -Destination $backup -Force
}
Write-Host "[BACKUP] $backupRoot"
try {
    foreach ($rel in $tracked) {
        Copy-Item -LiteralPath (Join-Path $pkg ('overlay\' + $rel.Replace('/', '\'))) -Destination (Join-Path $root ($rel.Replace('/', '\'))) -Force
    }
    Copy-Item -LiteralPath (Join-Path $pkg ('overlay\' + $testRel.Replace('/', '\'))) -Destination $testTarget -Force
    Set-Location $root
    Write-Host '[1/4] dart format...' -ForegroundColor Cyan
    & dart format lib/domain/shop.dart lib/ui/catalog.dart lib/controllers/shop_controller.dart lib/data/sync/outbox_repository.dart test/unit_correction_receipts_test.dart
    if ($LASTEXITCODE -ne 0) { throw 'Dart format FAILED' }
    Write-Host '[2/4] flutter pub get...' -ForegroundColor Cyan
    & flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'pub get FAILED' }
    Write-Host '[3/4] flutter analyze...' -ForegroundColor Cyan
    & flutter analyze --no-pub
    if ($LASTEXITCODE -ne 0) { throw 'flutter analyze FAILED' }
    Write-Host '[4/4] full widget/unit tests...' -ForegroundColor Cyan
    & flutter test --no-pub
    if ($LASTEXITCODE -ne 0) { throw 'flutter test FAILED' }
    Write-Host '[SUCCESS] Unit correction code installed and tests passed.' -ForegroundColor Green
    Write-Host 'Next: run 02_BUILD_WINDOWS.ps1, and separately 03_BUILD_WEB_PWA.ps1.'
    Write-Host 'DO NOT manually edit Firestore data or deploy rules for this patch.'
} catch {
    Write-Host '[FAILED] Restoring original Dart files from backup...' -ForegroundColor Red
    foreach ($rel in $tracked) {
        Copy-Item -LiteralPath (Join-Path $backupRoot ($rel.Replace('/', '\'))) -Destination (Join-Path $root ($rel.Replace('/', '\'))) -Force
    }
    if (Test-Path -LiteralPath $testTarget) { Remove-Item -LiteralPath $testTarget -Force }
    Write-Host '[RESTORED] Project source restored. Check log above.' -ForegroundColor Yellow
    throw
}
