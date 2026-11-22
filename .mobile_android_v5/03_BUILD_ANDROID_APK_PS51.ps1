#requires -version 5.1
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$root = 'D:\app\vlxd_app'
if (-not (Test-Path -LiteralPath (Join-Path $root 'pubspec.yaml'))) { throw "Khong thay du an: $root" }
Set-Location -LiteralPath $root
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) { throw 'Chua tim thay flutter trong PATH. Chay flutter doctor -v de kiem tra.' }
if (-not (Test-Path -LiteralPath 'android\app\build.gradle.kts')) { throw 'Khong tim thay cau hinh Android; chua build APK.' }
if (-not (Test-Path -LiteralPath 'android\app\google-services.json')) {
  Write-Warning 'Thieu android\app\google-services.json. Firebase Android co the khong build/dang nhap duoc; can cau hinh Android app trong Firebase Console.'
  throw 'Dung an toan: can google-services.json dung cho applicationId truoc khi build.'
}
$gradle = [System.IO.File]::ReadAllText((Join-Path $root 'android\app\build.gradle.kts'))
if ($gradle -match 'signingConfig\s*=\s*signingConfigs\.getByName\("debug"\)') {
  Write-Warning 'Android release hien dang ky bang DEBUG KEY. APK chi de TEST NOI BO, KHONG phat hanh production.'
}
Write-Host '[1/4] Android prerequisites' -ForegroundColor Cyan
& flutter doctor -v
if ($LASTEXITCODE -ne 0) { Write-Warning 'flutter doctor reported problems; checking build result separately.' }
Write-Host '[2/4] Dependency resolution' -ForegroundColor Cyan
& flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed' }
Write-Host '[3/4] Compile APK (no code modification)' -ForegroundColor Cyan
& flutter build apk --release
if ($LASTEXITCODE -ne 0) { throw 'flutter build apk failed; no APK distributed.' }
$apk = Join-Path $root 'build\app\outputs\flutter-apk\app-release.apk'
if (-not (Test-Path -LiteralPath $apk)) { throw "APK not found: $apk" }
$dstDir = Join-Path $root '.vlxd_android_apk_outputs'
New-Item -ItemType Directory -Force -Path $dstDir | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$dest = Join-Path $dstDir "VLXD_Bay_Hai_Android_TEST_$stamp.apk"
Copy-Item -LiteralPath $apk -Destination $dest
$sha = (Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash
Write-Host '[4/4] APK available' -ForegroundColor Green
Write-Host "APK: $dest"
Write-Host "SHA256: $sha"
Write-Host '[CAUTION] Android APK test only: verify login, permissions, camera, offline storage & sync on physical device before use.' -ForegroundColor Yellow
Write-Host '[CAUTION] Do not uninstall existing Android app or clear app data to install; signing keys can differ.' -ForegroundColor Yellow
