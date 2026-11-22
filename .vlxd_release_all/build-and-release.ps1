#Requires -Version 5.1
<#
  VLXD App unified release for Windows and Web PWA, with optional Android APK.
  Runs ON THE USER'S WINDOWS MACHINE against the CURRENT local source.
  Does not change lib/, Firebase rules, local databases, or the installed app.
#>
[CmdletBinding()]
param(
  [string]$ProjectRoot = 'D:\app\vlxd_app',
  [string]$Version = '1.0.3',
  [int]$BuildNumber = 4,
  [string]$InnoCompiler = 'D:\Inno Setup 6\ISCC.exe',
  [string]$FirebaseProject = 'vlxd-bay-hai',
  [switch]$BuildAndroidApk,
  [switch]$DeployHosting,
  [switch]$IReviewedAllDeviceQueues
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$originalLocation = (Get-Location).Path

function Say([string]$message) {
  Write-Host "[VLXD RELEASE] $message" -ForegroundColor Cyan
}
function Require-File([string]$path) {
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "Required file does not exist: $path"
  }
}
function Run-Checked([string]$description, [scriptblock]$action) {
  Say $description
  & $action
  if ($LASTEXITCODE -ne 0) {
    throw "$description FAILED (exit $LASTEXITCODE). Release stopped."
  }
}
function ShaLine([string]$path) {
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return '' }
  $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
  return "$([IO.Path]::GetFileName($path)) | SHA256 $hash"
}

try {
  if ($Version -notmatch '^\d+\.\d+\.\d+$') {
    throw 'Version must follow 1.0.3 format.'
  }
  if ($BuildNumber -lt 1) { throw 'BuildNumber must be >= 1.' }
  if ($FirebaseProject -cne 'vlxd-bay-hai') {
    throw 'Blocked unexpected Firebase project. This bundle only targets vlxd-bay-hai.'
  }
  if ($DeployHosting -and -not $IReviewedAllDeviceQueues) {
    throw 'Before deploying, inspect all offline/PWA/Android/Windows pending orders and backups, then add -IReviewedAllDeviceQueues.'
  }

  $ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot -ErrorAction Stop).Path
  Require-File (Join-Path $ProjectRoot 'pubspec.yaml')
  Require-File (Join-Path $ProjectRoot 'lib\main.dart')
  Require-File (Join-Path $ProjectRoot 'lib\firebase_options.dart')
  Require-File (Join-Path $ProjectRoot 'firebase.json')
  Require-File (Join-Path $ProjectRoot 'tools\build-web-offline.ps1')
  Require-File (Join-Path $ProjectRoot '.vlxd_fresh_setup\build-fresh.ps1')
  Require-File $InnoCompiler

  $pubspec = Get-Content -LiteralPath (Join-Path $ProjectRoot 'pubspec.yaml') -Raw -Encoding UTF8
  if ($pubspec -notmatch '(?m)^name:\s*vlxd_app\s*$') {
    throw 'Wrong application: pubspec.yaml must contain name: vlxd_app.'
  }
  $firebaseSource = Get-Content -LiteralPath (Join-Path $ProjectRoot 'lib\firebase_options.dart') -Raw -Encoding UTF8
  if (-not $firebaseSource.Contains('vlxd-bay-hai')) {
    throw 'Firebase options do not point at vlxd-bay-hai. Release blocked.'
  }
  $firebaseConfig = Get-Content -LiteralPath (Join-Path $ProjectRoot 'firebase.json') -Raw -Encoding UTF8 | ConvertFrom-Json
  if ([string]$firebaseConfig.hosting.public -cne 'build/web') {
    throw 'firebase.json hosting.public must be build/web. Release blocked.'
  }
  $mainSource = Get-Content -LiteralPath (Join-Path $ProjectRoot 'lib\main.dart') -Raw -Encoding UTF8
  foreach ($flag in @('AUTO_SYNC_OUTBOX','ALLOW_PRODUCTION_AUTO_SYNC','USE_FIREBASE_EMULATOR')) {
    if (-not $mainSource.Contains($flag)) {
      throw "main.dart missing offline-sync safety switch: $flag"
    }
  }
  if (-not [regex]::IsMatch($mainSource, 'autoSyncEnabled\s*&&\s*\(emulator\s*\|\|\s*allowProductionAutoSync\)')) {
    throw 'Expected production auto-sync guard changed. Review main.dart before releasing.'
  }

  $webBuilder = Get-Content -LiteralPath (Join-Path $ProjectRoot 'tools\build-web-offline.ps1') -Raw -Encoding UTF8
  foreach ($fragment in @('--pwa-strategy=none', 'offline-manifest.js', 'ALLOW_PRODUCTION_AUTO_SYNC=true')) {
    if (-not $webBuilder.Contains($fragment)) {
      throw "Web release script changed or missing $fragment. Review before releasing."
    }
  }

  $flutter = Get-Command flutter -ErrorAction Stop
  if ($DeployHosting) { $null = Get-Command firebase.cmd -ErrorAction Stop }

  Set-Location -LiteralPath $ProjectRoot
  Say "ProjectRoot: $ProjectRoot"
  Say "Git HEAD: $(& git rev-parse --short HEAD 2>$null)"
  Say "Windows Setup version: $Version ($BuildNumber)"
  Say "Web/PWA URL: https://vlxd-bay-hai.web.app/"
  Write-Warning 'Web build in this repo enables REAL production outbox auto-sync.'
  Write-Warning 'Do not deploy until all pending/uncertain/failed offline orders on ALL devices have been reviewed.'
  Write-Warning 'Do not clear browser storage or uninstall the old app before confirming local queue backups.'
  if ($DeployHosting) {
    Say 'Explicit deployment enabled: hosting only, to vlxd-bay-hai.'
  } else {
    Say 'Build/package mode. Hosting will NOT be changed.'
  }

  Run-Checked 'flutter pub get' { & $flutter.Source pub get }
  Run-Checked 'flutter analyze --no-pub' { & $flutter.Source analyze --no-pub }
  Run-Checked 'flutter test --no-pub' { & $flutter.Source test --no-pub }

  # Reuse the user's proven Inno Setup pipeline. Tests have already passed above.
  $windowsBuilder = Join-Path $ProjectRoot '.vlxd_fresh_setup\build-fresh.ps1'
  Run-Checked 'Windows Release + Inno Setup' {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $windowsBuilder `
      -ProjectRoot $ProjectRoot -Version $Version -BuildNumber $BuildNumber `
      -InnoCompiler $InnoCompiler -SkipTests
  }

  $setup = Join-Path $ProjectRoot "release\installers\VLXD_App_Setup_$Version.exe"
  Require-File $setup
  if ((Get-Item -LiteralPath $setup).Length -lt 1000000) {
    throw "Setup file unexpectedly small: $setup"
  }
  $iss = Get-Content -LiteralPath (Join-Path $ProjectRoot 'release\VLXD_App_Fresh_Setup.iss') -Raw -Encoding UTF8
  if ($iss -notmatch '(?m)^AppId=VLXD\.App\.Windows\.Desktop\s*$') {
    throw 'Windows AppId mismatch. Do not replace installed VLXD App.'
  }

  # The repo's Web builder generates an offline manifest with a content hash.
  Run-Checked 'Flutter Web + PWA offline bundle' {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File `
      (Join-Path $ProjectRoot 'tools\build-web-offline.ps1') -Output 'build/web'
  }
  $webRoot = Join-Path $ProjectRoot 'build\web'
  foreach ($required in @(
    'index.html','main.dart.js','flutter_bootstrap.js','manifest.json',
    'offline-sw.js','offline-manifest.js','sqlite3.wasm','drift_worker.js'
  )) {
    Require-File (Join-Path $webRoot $required)
  }
  $pwaManifest = Get-Content -LiteralPath (Join-Path $webRoot 'manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
  if ([string]$pwaManifest.display -ne 'standalone') {
    throw 'PWA manifest is not standalone. Build blocked.'
  }
  if (@($pwaManifest.icons).Count -lt 2) {
    throw 'PWA icons are missing.'
  }
  $offlineManifest = Get-Content -LiteralPath (Join-Path $webRoot 'offline-manifest.js') -Raw -Encoding UTF8
  $manifestMatch = [regex]::Match($offlineManifest, '"version"\s*:\s*"([A-Fa-f0-9]+)"')
  if (-not $manifestMatch.Success) {
    throw 'Invalid offline-manifest.js version.'
  }
  $webCacheVersion = $manifestMatch.Groups[1].Value

  $releasePackages = Join-Path $ProjectRoot 'release\packages'
  $null = New-Item -Path $releasePackages -ItemType Directory -Force
  $webZip = Join-Path $releasePackages "VLXD_Web_PWA_$Version.zip"
  if (Test-Path -LiteralPath $webZip) { Remove-Item -LiteralPath $webZip -Force }
  Say 'Packaging Web/PWA build ZIP'
  Compress-Archive -Path (Join-Path $webRoot '*') -DestinationPath $webZip -CompressionLevel Optimal
  Require-File $webZip

  $apk = ''
  if ($BuildAndroidApk) {
    Run-Checked 'Android APK Release build' {
      & $flutter.Source build apk --release --no-pub `
        --build-name $Version --build-number "$BuildNumber"
    }
    $apkSource = Join-Path $ProjectRoot 'build\app\outputs\flutter-apk\app-release.apk'
    Require-File $apkSource
    $apk = Join-Path $releasePackages "VLXD_Android_$Version.apk"
    Copy-Item -LiteralPath $apkSource -Destination $apk -Force
    Write-Warning 'Verify Android signing configuration before distributing this APK publicly.'
  }

  $gitRevision = (& git rev-parse HEAD 2>$null)
  $report = Join-Path $releasePackages "VLXD_Release_$Version.txt"
  $reportText = @"
VLXD App RELEASE $Version / build $BuildNumber
Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Git HEAD: $gitRevision
Source: $ProjectRoot
Windows AppId: VLXD.App.Windows.Desktop
Windows Setup: $setup
Web/PWA ZIP: $webZip
Web/PWA manifest fingerprint: $webCacheVersion
Android APK: $apk
Firebase project: $FirebaseProject
Hosting: https://vlxd-bay-hai.web.app/
Hosting deploy requested: $DeployHosting
Offline queues reviewed (user assertion): $IReviewedAllDeviceQueues

$(ShaLine $setup)
$(ShaLine $webZip)
$(if ($apk) { ShaLine $apk })

IMPORTANT:
- Windows Setup upgrades the same AppId. Installer is NOT auto-installed.
- Web/PWA deployment does NOT happen automatically unless -DeployHosting is provided.
- Web build enables production auto-sync as configured by the existing project.
- Review pending/failed/uncertain transactions on ALL devices before deploying.
- Do not clear PWA site storage/IndexedDB or delete local SQLite databases.
- No firestore rules/functions/auth/database deployments are performed by this script.
- iOS uses Safari's Add to Home Screen; this does not generate a native IPA.
"@
  $utf8Bom = New-Object System.Text.UTF8Encoding($true)
  [IO.File]::WriteAllText($report, $reportText, $utf8Bom)

  # One combined transport ZIP, containing built artifacts rather than source code.
  $combined = Join-Path $releasePackages "VLXD_All_Platforms_$Version.zip"
  $staging = Join-Path $releasePackages "VLXD_Release_Staging_$Version"
  if (Test-Path -LiteralPath $staging) {
    throw "Staging directory already exists: $staging. Inspect it before retrying."
  }
  $null = New-Item -Path $staging -ItemType Directory
  try {
    Copy-Item -LiteralPath $setup -Destination $staging
    Copy-Item -LiteralPath $webZip -Destination $staging
    Copy-Item -LiteralPath $report -Destination $staging
    if ($apk) { Copy-Item -LiteralPath $apk -Destination $staging }
    if (Test-Path -LiteralPath $combined) { Remove-Item -LiteralPath $combined -Force }
    Compress-Archive -Path (Join-Path $staging '*') -DestinationPath $combined -CompressionLevel Optimal
  } finally {
    # Only the staging directory created by this run is removed.
    Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue
  }
  Require-File $combined

  if ($DeployHosting) {
    Say 'DEPLOYING Hosting ONLY; Firebase Rules/Firestore untouched.'
    Run-Checked 'Firebase Hosting deployment to vlxd-bay-hai' {
      & firebase.cmd deploy --only hosting --project $FirebaseProject --non-interactive
    }
    $reportText += "`r`nDeployment completed: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`r`n"
    [IO.File]::WriteAllText($report, $reportText, $utf8Bom)
    Write-Warning 'Browser/PWA clients may continue using cached old assets until service-worker update/restart.'
  }

  Write-Host ''
  Write-Host '===== VLXD RELEASE BUILT SUCCESSFULLY =====' -ForegroundColor Green
  Write-Host "WINDOWS SETUP : $setup"
  Write-Host "WEB/PWA ZIP   : $webZip"
  if ($apk) { Write-Host "ANDROID APK   : $apk" }
  Write-Host "FULL ZIP      : $combined"
  Write-Host "BUILD REPORT  : $report"
  if ($DeployHosting) {
    Write-Host 'HOSTING: DEPLOYED to https://vlxd-bay-hai.web.app/' -ForegroundColor Green
  } else {
    Write-Host 'HOSTING: NOT deployed. Run deploy-hosting-after-review.ps1 after reviewing offline queues.' -ForegroundColor Yellow
  }
  Write-Host 'Windows is NOT automatically installed; run the generated Setup after backup.' -ForegroundColor Yellow
} catch {
  Write-Host ''
  Write-Host "[VLXD RELEASE FAILED] $($_.Exception.Message)" -ForegroundColor Red
  exit 1
} finally {
  Set-Location -LiteralPath $originalLocation
}
