param(
  [switch]$Emulator,
  [string]$Output = 'build/web'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2

if ($Emulator -and ($Output -eq 'build/web')) {
  throw 'Emulator builds must use a separate output directory.'
}
if ((-not $Emulator) -and ($Output -ne 'build/web')) {
  Write-Warning 'Production build uses live Firebase config with auto-sync disabled.'
}

$argsList = @(
  'build', 'web', '--release', '--no-pub',
  '--no-web-resources-cdn', '--pwa-strategy=none',
  "--output=$Output"
)
if ($Emulator) {
  $argsList += '--dart-define=USE_FIREBASE_EMULATOR=true'
  $argsList += '--dart-define=AUTO_SYNC_OUTBOX=true'
} else {
  # Fail-safe: production binaries must never auto-dispatch without separate approval.
  $argsList += '--dart-define=AUTO_SYNC_OUTBOX=false'
  $argsList += '--dart-define=ALLOW_PRODUCTION_AUTO_SYNC=false'
}

& flutter @argsList
if ($LASTEXITCODE -ne 0) { throw 'Flutter web build failed.' }

$root = (Resolve-Path -LiteralPath $Output).Path
$resources = @(
  Get-ChildItem -LiteralPath $root -File -Recurse |
    ForEach-Object { $_.FullName.Substring($root.Length + 1).Replace('\', '/') } |
    Where-Object { $_ -notmatch '^\.|\.symbols$|\.map$|^offline-(sw|manifest)\.js$' } |
    Sort-Object
)
foreach ($required in @('index.html', 'main.dart.js', 'sqlite3.wasm', 'drift_worker.js', 'flutter_bootstrap.js')) {
  if ($required -notin $resources) { throw "Missing web resource: $required" }
}
# Windows PowerShell 5.1-compatible SHA-256 and UTF-8 without BOM.
$fingerprint = ($resources | ForEach-Object {
  $fullPath = Join-Path $root ($_.Replace('/', [IO.Path]::DirectorySeparatorChar))
  "$_=$((Get-FileHash -LiteralPath $fullPath -Algorithm SHA256).Hash)"
}) -join "`n"
$sha = [System.Security.Cryptography.SHA256]::Create()
try {
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($fingerprint)
  $hash = [BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-', '')
} finally { $sha.Dispose() }
$version = $hash.Substring(0, 24)
$manifest = @{ version = $version; files = $resources } | ConvertTo-Json -Compress -Depth 5
$outPath = Join-Path $root 'offline-manifest.js'
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($outPath, "self.vlxdOfflineManifest = $manifest;", $utf8NoBom)
Write-Output "Web offline build complete: $version"
Write-Output "Output: $root"
