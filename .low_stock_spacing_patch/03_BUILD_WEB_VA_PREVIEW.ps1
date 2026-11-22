#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
$root = (Get-Location).Path
if (-not (Test-Path '.\pubspec.yaml')) { throw 'Run from D:\app\vlxd_app.' }
$catalog = [IO.File]::ReadAllText((Join-Path $root 'lib\ui\catalog.dart'), [Text.Encoding]::UTF8)
if (-not $catalog.Contains('vlxd-low-stock-space-v1')) { throw 'Spacing patch not found. Run 01 first.' }
$builder = Join-Path $root '.web_pwa_build\build-web-pwa.ps1'
if (-not (Test-Path -LiteralPath $builder -PathType Leaf)) {
    throw 'Existing PWA offline builder missing: .web_pwa_build\build-web-pwa.ps1. Stop to avoid deploying incomplete PWA.'
}
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $builder
if ($LASTEXITCODE -ne 0) { throw 'PWA build failed.' }
foreach ($name in @('main.dart.js', 'offline-manifest.js')) {
    if (-not (Test-Path -LiteralPath (Join-Path $root "build\web\$name"))) {
        throw "Incomplete PWA output: $name missing."
    }
}
& firebase hosting:channel:deploy low-stock-spacing --project vlxd-bay-hai --expires 2d
if ($LASTEXITCODE -ne 0) { throw 'Firebase PREVIEW deployment failed.' }
Write-Host '[SUCCESS] Preview deployed. Production website NOT changed.' -ForegroundColor Green
