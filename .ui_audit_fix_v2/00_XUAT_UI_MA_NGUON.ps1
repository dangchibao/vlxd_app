#requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = 'D:\app\vlxd_app'
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$dest = Join-Path $root ('.vlxd_ui_source_for_review_' + $stamp + '.zip')
$paths = @('lib/ui/app.dart','lib/ui/catalog.dart','lib/ui/operations.dart','lib/ui/mobile_products.dart','lib/ui/debt.dart','lib/ui/vlxd_theme.dart')
$staging = Join-Path $env:TEMP ('vlxd_ui_diagnostic_' + $stamp)
New-Item -ItemType Directory -Force -Path $staging | Out-Null
try {
  foreach ($rel in $paths) {
    $src = Join-Path $root $rel
    if (-not (Test-Path -LiteralPath $src)) { throw "Missing UI source: $rel" }
    $target = Join-Path $staging $rel
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
    Copy-Item -LiteralPath $src -Destination $target -Force
  }
  Compress-Archive -Path (Join-Path $staging 'lib') -DestinationPath $dest -Force
  Write-Host "[READY] UI code ZIP only (6 files): $dest" -ForegroundColor Green
  Write-Host 'Do not include .env, keys, Firebase service account files or business data.'
} finally {
  if (Test-Path -LiteralPath $staging) { Remove-Item -LiteralPath $staging -Recurse -Force }
}
