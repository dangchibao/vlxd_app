param([string]$ProjectRoot = 'D:\app\vlxd_app')
$ErrorActionPreference = 'Stop'
function Fail([string]$Message) { throw $Message }
function Step([string]$Message) { Write-Host "`n=== $Message ===" -ForegroundColor Cyan }

Set-Location -LiteralPath $ProjectRoot
if (-not (Test-Path '.\pubspec.yaml')) { Fail "Khong tim thay pubspec.yaml trong $ProjectRoot" }
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) { Fail 'Khong tim thay flutter tren PATH.' }
if (-not (Test-Path '.\firebase.json')) { Fail 'Thieu firebase.json.' }
$config = Get-Content '.\firebase.json' -Raw -Encoding UTF8 | ConvertFrom-Json
if ($config.hosting.public -ne 'build/web') { Fail 'firebase.json khong cau hinh hosting.public = build/web. Can kiem tra truoc khi deploy.' }
if (-not (Test-Path '.\web\manifest.json')) { Fail 'Thieu web/manifest.json - chua the kiem tra PWA.' }
if (-not (Test-Path '.\web\offline-sw.js')) { Fail 'Thieu web/offline-sw.js - chua the xac nhan offline PWA.' }
if (-not (Test-Path '.\web\flutter_bootstrap.js')) { Fail 'Thieu web/flutter_bootstrap.js.' }
$bootstrap = Get-Content '.\web\flutter_bootstrap.js' -Raw -Encoding UTF8
if (-not $bootstrap.Contains('offline-sw.js')) { Fail 'flutter_bootstrap.js chua dang ky offline-sw.js.' }
$manifest = Get-Content '.\web\manifest.json' -Raw -Encoding UTF8 | ConvertFrom-Json
if ($manifest.display -notin @('standalone','fullscreen','minimal-ui')) { Fail 'manifest.json chua dat display cho ung dung cai dat.' }
foreach ($icon in $manifest.icons) {
  $iconPath = Join-Path '.\web' ([string]$icon.src).Replace('/', '\')
  if (-not (Test-Path $iconPath)) { Fail "Thieu icon PWA: $iconPath" }
}

Step '1/5: Flutter pub get'
& flutter pub get
if ($LASTEXITCODE -ne 0) { Fail 'Flutter pub get that bai.' }
Step '2/5: Flutter analyze'
& flutter analyze --no-pub
if ($LASTEXITCODE -ne 0) { Fail 'Flutter analyze that bai.' }
Step '3/5: Chay tat ca Flutter test'
& flutter test --no-pub
if ($LASTEXITCODE -ne 0) { Fail 'Flutter test that bai. Khong build release.' }
Step '4/5: Build web release'
& flutter build web --release
if ($LASTEXITCODE -ne 0) { Fail 'Flutter build web that bai.' }

Step '5/5: Tao PWA offline-manifest.js theo tai nguyen build thuc te'
$build = Join-Path $ProjectRoot 'build\web'
if (-not (Test-Path $build)) { Fail 'Khong co build/web sau khi build.' }
foreach ($name in @('index.html','flutter_bootstrap.js','manifest.json','offline-sw.js')) {
  if (-not (Test-Path (Join-Path $build $name))) { Fail "Thieu tep Web/PWA: $name" }
}
$worker = Get-Content (Join-Path $build 'offline-sw.js') -Raw -Encoding UTF8
if (-not $worker.Contains('offline-manifest.js') -or -not $worker.Contains('vlxdOfflineManifest')) {
  Fail 'Service worker khac mau du kien. Dung de tranh tao manifest sai.'
}
$files = @(Get-ChildItem -LiteralPath $build -File -Recurse |
  Where-Object { $_.Name -notin @('offline-manifest.js','offline-sw.js') } |
  Sort-Object FullName)
if ($files.Count -lt 5) { Fail 'Build/web co qua it tep; can kiem tra.' }
$prefix = $build.TrimEnd('\','/') + '\'
$entries = New-Object System.Collections.Generic.List[string]
$versionSeed = New-Object System.Text.StringBuilder
foreach ($file in $files) {
  if (-not $file.FullName.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    Fail "Duong dan ngoai build/web: $($file.FullName)"
  }
  $relative = $file.FullName.Substring($prefix.Length).Replace('\','/')
  [void]$entries.Add($relative)
  $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
  [void]$versionSeed.Append($relative).Append(':').Append($hash).Append("`n")
}
$hasher = [System.Security.Cryptography.SHA256]::Create()
try {
  $seedBytes = [System.Text.Encoding]::UTF8.GetBytes($versionSeed.ToString())
  $version = ([BitConverter]::ToString($hasher.ComputeHash($seedBytes))).Replace('-','').Substring(0,20).ToLowerInvariant()
} finally { $hasher.Dispose() }
$obj = [ordered]@{ version = $version; files = $entries.ToArray() }
$json = ConvertTo-Json -InputObject $obj -Compress -Depth 6
$utf8 = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText((Join-Path $build 'offline-manifest.js'), "self.vlxdOfflineManifest = $json;`n", $utf8)
if (Get-Command node -ErrorAction SilentlyContinue) {
  & node --check (Join-Path $build 'offline-manifest.js')
  if ($LASTEXITCODE -ne 0) { Fail 'Cu phap offline-manifest.js khong hop le.' }
  & node --check (Join-Path $build 'offline-sw.js')
  if ($LASTEXITCODE -ne 0) { Fail 'Cu phap offline-sw.js khong hop le.' }
}
Write-Host "[OK] Build Web/PWA: $build" -ForegroundColor Green
Write-Host "[OK] Generated offline-manifest.js: $($entries.Count) files, version $version" -ForegroundColor Green
Write-Host '[CHU Y] Service worker, dang nhap va SQLite offline PHAI duoc thu thuc te tren HTTPS.' -ForegroundColor Yellow
Write-Host '[TIEP] Chay 02_DANG_WEB_XEM_TRUOC.cmd de tao link xem truoc; sau do 03_DANG_WEB_CHINH_THUC.cmd neu da kiem tra.'
