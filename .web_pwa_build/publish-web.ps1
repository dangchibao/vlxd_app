param(
  [string]$ProjectRoot = 'D:\app\vlxd_app',
  [ValidateSet('preview','live')][string]$Mode = 'preview'
)
$ErrorActionPreference = 'Stop'
function Fail([string]$Message) { throw $Message }
Set-Location -LiteralPath $ProjectRoot
if (-not (Get-Command firebase -ErrorAction SilentlyContinue)) { Fail 'Chua tim thay Firebase CLI. Can cai/dang nhap firebase-tools.' }
$config = Get-Content '.\firebase.json' -Raw -Encoding UTF8 | ConvertFrom-Json
if ($config.hosting.public -ne 'build/web') { Fail 'hosting.public khong phai build/web. Dung.' }
$files = @('build\web\index.html','build\web\manifest.json','build\web\offline-sw.js','build\web\offline-manifest.js')
foreach ($file in $files) { if (-not (Test-Path $file)) { Fail "Thieu $file - hay chay 01_BUILD_WEB_PWA.cmd truoc." } }
$projectId = 'vlxd-bay-hai'
$firebaseOptions = Get-Content '.\lib\firebase_options.dart' -Raw -Encoding UTF8
if (-not $firebaseOptions.Contains("projectId: '$projectId'")) { Fail 'FirebaseOptions khong khop projectId. Dung de tranh deploy nham.' }
Write-Host "PROJECT: $projectId" -ForegroundColor Yellow
Write-Host "MODE: $Mode" -ForegroundColor Yellow
Write-Host 'Chu y: Firebase Hosting preview/live co URL cong khai; du lieu van can dang nhap/phan quyen.' -ForegroundColor Yellow
if ($Mode -eq 'live') {
  Write-Host 'Ban sap CAP NHAT HOSTING CHINH THUC, co the thay the ban web dang hoat dong.' -ForegroundColor Yellow
  $confirm = Read-Host 'Nhap DANG WEB de dong y'
  if ($confirm -cne 'DANG WEB') { Fail 'Da huy, khong thay doi Firebase Hosting.' }
  & firebase deploy --only hosting --project $projectId
} else {
  $confirm = Read-Host 'Tao link Hosting xem truoc? Nhap YES de dong y'
  if ($confirm -cne 'YES') { Fail 'Da huy, khong thay doi Firebase Hosting.' }
  & firebase hosting:channel:deploy 'vlxd-pwa-preview' --project $projectId
}
if ($LASTEXITCODE -ne 0) { Fail 'Firebase Hosting deployment that bai.' }
Write-Host '[OK] Firebase Hosting command completed.' -ForegroundColor Green
Write-Host 'Neu dang nhap bi tu choi, kiem tra Firebase Authentication > Settings > Authorized domains cho ten mien preview/web.app.' -ForegroundColor Yellow
