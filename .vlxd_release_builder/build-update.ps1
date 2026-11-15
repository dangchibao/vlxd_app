param(
  [string]$ProjectRoot = '',
  [string]$Version = '',
  [string]$OldInstallerScript = '',
  [switch]$SkipTests,
  [switch]$BuildWeb
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Info([string]$Message) { Write-Host "[VLXD] $Message" -ForegroundColor Cyan }
function Notice([string]$Message) { Write-Host "[CHU Y] $Message" -ForegroundColor Yellow }
function CheckExit([string]$Step) {
  if ($LASTEXITCODE -ne 0) { throw "$Step that bai (exit code $LASTEXITCODE). Dung dong goi." }
}
function Read-InnoSetting([string]$Source, [string]$Key) {
  $rx = '(?mi)^\s*' + [regex]::Escape($Key) + '\s*=\s*(.*?)\s*$'
  $m = [regex]::Match($Source, $rx)
  if (-not $m.Success) { return '' }
  $val = $m.Groups[1].Value.Trim()
  if ($val -match '^\{#([A-Za-z][A-Za-z0-9_]*)\}$') {
    $symbol = $Matches[1]
    $macroRx = '(?mi)^\s*#define\s+' + [regex]::Escape($symbol) + '\s+"([^"]+)"\s*$'
    $macro = [regex]::Match($Source, $macroRx)
    if (-not $macro.Success) { throw "Khong giai duoc Inno macro $symbol; can dung AppId cu." }
    return $macro.Groups[1].Value
  }
  return $val
}
function CleanInnoText([string]$Value, [string]$Field) {
  if ([string]::IsNullOrWhiteSpace($Value) -or $Value.Contains("`n") -or $Value.Contains("`r") -or $Value.Contains('"')) {
    throw "Gia tri $Field cua setup cu khong hop le. Dung de tranh cai sai AppId."
  }
  return $Value
}

try {
  if ([string]::IsNullOrWhiteSpace($ProjectRoot)) {
    $ProjectRoot = Split-Path -Parent $PSScriptRoot
  }
  $ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
  Set-Location -LiteralPath $ProjectRoot
  if (-not (Test-Path -LiteralPath '.\pubspec.yaml') -or -not (Test-Path -LiteralPath '.\windows\CMakeLists.txt')) {
    throw "Khong tim thay du an Flutter Windows tai $ProjectRoot"
  }
  $pubspec = Get-Content -LiteralPath '.\pubspec.yaml' -Raw
  if ($pubspec -notmatch '(?m)^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)\s*$') {
    throw 'Khong doc duoc version trong pubspec.yaml. Can giu dung phien ban.'
  }
  $baseMajor = [int]$Matches[1]
  $baseMinor = [int]$Matches[2]
  $basePatch = [int]$Matches[3]
  $baseBuild = [int]$Matches[4]
  $releaseDir = Join-Path $ProjectRoot 'release'
  $setupOutputDir = Join-Path $releaseDir 'installers'
  $null = New-Item -ItemType Directory -Force -Path $releaseDir, $setupOutputDir
  $lastVersionFile = Join-Path $releaseDir 'last_version.txt'
  if (-not $Version) {
    $patch = $basePatch
    $build = $baseBuild
    if (Test-Path -LiteralPath $lastVersionFile) {
      $last = (Get-Content -LiteralPath $lastVersionFile -Raw).Trim()
      if ($last -match '^(\d+)\.(\d+)\.(\d+)\+(\d+)$') {
        if ([int]$Matches[1] -eq $baseMajor -and [int]$Matches[2] -eq $baseMinor) {
          $patch = [math]::Max($patch, [int]$Matches[3])
          $build = [math]::Max($build, [int]$Matches[4])
        }
      }
    }
    $Version = "$baseMajor.$baseMinor.$($patch+1)"
    $buildNumber = $build + 1
  } else {
    if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw 'Version phai co dang 1.0.2' }
    $buildNumber = $baseBuild + 1
  }
  $releaseVersion = "$Version+$buildNumber"
  Info "Ma nguon hien tai: $ProjectRoot"
  Info "Phien ban dong goi: $releaseVersion (khong sua pubspec.yaml)"
  if (Get-Process -Name 'vlxd_app' -ErrorAction SilentlyContinue) {
    Notice 'VLXD dang mo. Hay dong ung dung truoc khi CHAY SETUP moi, khong can dong khi build.'
  }
  if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw 'Khong tim thay flutter trong PATH. Kiem tra D:\development\flutter\bin.'
  }
  Info 'flutter pub get'
  & flutter pub get; CheckExit 'flutter pub get'
  if (-not $SkipTests) {
    Info 'flutter analyze'
    & flutter analyze; CheckExit 'flutter analyze'
    Info 'flutter test'
    & flutter test; CheckExit 'flutter test'
  }
  Info 'flutter build windows --release'
  & flutter build windows --release --build-name $Version --build-number "$buildNumber"
  CheckExit 'flutter build windows'
  $candidateDirs = @(
    (Join-Path $ProjectRoot 'build\windows\x64\runner\Release'),
    (Join-Path $ProjectRoot 'build\windows\runner\Release')
  )
  $bundle = $null
  foreach ($candidate in $candidateDirs) {
    if (Test-Path -LiteralPath (Join-Path $candidate 'vlxd_app.exe')) { $bundle = $candidate; break }
  }
  if (-not $bundle) { throw 'Khong tim thay vlxd_app.exe trong thu muc release sau build.' }
  if (-not (Test-Path -LiteralPath (Join-Path $bundle 'data'))) { throw 'Thieu data folder trong Windows release.' }
  if (-not (Test-Path -LiteralPath (Join-Path $bundle 'flutter_windows.dll'))) { throw 'Thieu flutter_windows.dll trong Windows release.' }
  $portableZip = Join-Path $releaseDir "VLXD_Hai_Soc_Portable_$Version.zip"
  if (Test-Path -LiteralPath $portableZip) { Remove-Item -LiteralPath $portableZip -Force }
  Info 'Tao ZIP portable du cac DLL va data'
  Compress-Archive -Path (Join-Path $bundle '*') -DestinationPath $portableZip -CompressionLevel Optimal
  if ($BuildWeb) {
    Info 'flutter build web --release (khong deploy len Internet)'
    & flutter build web --release; CheckExit 'flutter build web'
    $webZip = Join-Path $releaseDir "VLXD_Hai_Soc_Web_$Version.zip"
    if (Test-Path -LiteralPath $webZip) { Remove-Item -LiteralPath $webZip -Force }
    Compress-Archive -Path (Join-Path $ProjectRoot 'build\web\*') -DestinationPath $webZip -CompressionLevel Optimal
  }

  # Lay AppId va che do cai dat CU. Khong tao AppId moi de tranh cai song song.
  $identitySource = ''
  $appId = ''
  $appName = ''
  $defaultDir = ''
  $defaultGroup = ''
  $privileges = ''
  $archMode = ''
  $archAllowed = ''
  $oldIssPath = ''
  if ($OldInstallerScript) {
    $oldIssPath = (Resolve-Path -LiteralPath $OldInstallerScript).Path
  } else {
    $existingSetupFolder = Join-Path (Split-Path -Parent $ProjectRoot) 'setup VLXD App'
    $lookups = @($existingSetupFolder, (Join-Path $ProjectRoot 'installer'))
    $issFiles = @()
    foreach ($lookup in $lookups) {
      if (Test-Path -LiteralPath $lookup) {
        $issFiles += @(Get-ChildItem -LiteralPath $lookup -Recurse -File -Filter '*.iss' -ErrorAction SilentlyContinue)
      }
    }
    if ($issFiles.Count -eq 1) { $oldIssPath = $issFiles[0].FullName }
    elseif ($issFiles.Count -gt 1) {
      Notice 'Tim thay nhieu file .iss; khong tu chon de tranh AppId sai.'
      $issFiles | ForEach-Object { Write-Host "  $($_.FullName)" }
    }
  }
  if ($oldIssPath) {
    $oldText = Get-Content -LiteralPath $oldIssPath -Raw
    $appId = Read-InnoSetting $oldText 'AppId'
    $appName = Read-InnoSetting $oldText 'AppName'
    if (-not $appName) { throw 'Inno script cu khong co AppName ro rang. Khong tao setup moi.' }
    if (-not $appId) { $appId = $appName }
    $defaultDir = Read-InnoSetting $oldText 'DefaultDirName'
    $defaultGroup = Read-InnoSetting $oldText 'DefaultGroupName'
    $privileges = Read-InnoSetting $oldText 'PrivilegesRequired'
    $archMode = Read-InnoSetting $oldText 'ArchitecturesInstallIn64BitMode'
    $archAllowed = Read-InnoSetting $oldText 'ArchitecturesAllowed'
    $identitySource = "Inno script cu: $oldIssPath"
  } elseif (-not $OldInstallerScript) {
    $regBases = @(
      'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall',
      'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
      'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
    )
    $matchesFound = @()
    foreach ($regBase in $regBases) {
      if (-not (Test-Path -LiteralPath $regBase)) { continue }
      foreach ($key in (Get-ChildItem -LiteralPath $regBase -ErrorAction SilentlyContinue)) {
        if ($key.PSChildName -notlike '*_is1') { continue }
        $r = Get-ItemProperty -LiteralPath $key.PSPath -ErrorAction SilentlyContinue
        if (-not $r) { continue }
        $display = [string]$r.DisplayName
        $install = [string]$r.InstallLocation
        $appPath = [string]$r.'Inno Setup: App Path'
        if ($display -match '(?i)VLXD|Hai S[oó]c|Bay Hai|B[aả]y Hai' -or
            $install -match '(?i)vlxd|hai.soc' -or $appPath -match '(?i)vlxd|hai.soc') {
          $matchesFound += [pscustomobject]@{ Key=$key.PSChildName; Base=$regBase; Display=$display; Folder=$install; AppPath=$appPath }
        }
      }
    }
    if ($matchesFound.Count -eq 1) {
      $found = $matchesFound[0]
      $rawId = $found.Key.Substring(0, $found.Key.Length - 4)
      $appId = if ($rawId.StartsWith('{')) { '{' + $rawId } else { $rawId }
      $appName = $found.Display
      $oldPath = if ($found.AppPath) { $found.AppPath } else { $found.Folder }
      $defaultDir = if ($oldPath) { $oldPath } else { '{autopf}\VLXD Hai Soc' }
      $privileges = if ($found.Base.StartsWith('HKCU:')) { 'lowest' } else { 'admin' }
      $identitySource = "Windows installed app: $($found.Base)\$($found.Key)"
    } elseif ($matchesFound.Count -gt 1) {
      Notice 'Tim thay nhieu ban VLXD trong Windows. Khong doan AppId; hay chi dinh -OldInstallerScript.'
      $matchesFound | ForEach-Object { Write-Host "  $($_.Display) : $($_.Base)\$($_.Key)" }
    }
  }
  if (-not $appId) {
    Notice 'DA BUILD WINDOWS + ZIP PORTABLE. CHUA TAO SETUP.EXE vi khong doc duoc AppId ban cu.'
    Notice 'Gui file .iss trong D:\app\setup VLXD App, hoac chay lai voi -OldInstallerScript duong-dan-cu.'
    Info "ZIP portable: $portableZip"
    exit 0
  }
  $appId = CleanInnoText $appId 'AppId'
  $appName = CleanInnoText $appName 'AppName'
  if ($appId.Contains('{#') -or $appName.Contains('{#')) {
    throw 'AppId/AppName cu co macro phuc tap; can doi chieu truoc khi tao bo cai de.'
  }
  if (-not $defaultDir) { $defaultDir = '{autopf}\VLXD Hai Soc' }
  if (-not $defaultGroup) { $defaultGroup = $appName }
  if (-not $privileges) { $privileges = 'admin' }
  $defaultDir = CleanInnoText $defaultDir 'DefaultDirName'
  $defaultGroup = CleanInnoText $defaultGroup 'DefaultGroupName'
  if ($privileges -notin @('admin', 'lowest', 'poweruser')) {
    throw "Che do cai dat cu chua ho tro: $privileges"
  }
  $installerScript = Join-Path $releaseDir 'VLXD_Hai_Soc_Update.iss'
  $iss = @"
[Setup]
AppId=$appId
AppName=$appName
AppVersion=$Version
DefaultDirName=$defaultDir
DefaultGroupName=$defaultGroup
OutputDir=$setupOutputDir
OutputBaseFilename=VLXD_Hai_Soc_Setup_$Version
PrivilegesRequired=$privileges
UsePreviousAppDir=yes
UsePreviousGroup=yes
CloseApplications=yes
RestartApplications=no
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\vlxd_app.exe

[Files]
Source: "$bundle\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\$appName"; Filename: "{app}\vlxd_app.exe"
"@
  # Giu kien truc cu neu duoc khai bao, khong ep doi mode khi nang cap.
  if ($archAllowed) { $iss = $iss.Replace('UsePreviousAppDir=yes', "ArchitecturesAllowed=$archAllowed`r`nUsePreviousAppDir=yes") }
  if ($archMode) { $iss = $iss.Replace('UsePreviousAppDir=yes', "ArchitecturesInstallIn64BitMode=$archMode`r`nUsePreviousAppDir=yes") }
  $utf8Bom = New-Object System.Text.UTF8Encoding($true)
  [System.IO.File]::WriteAllText($installerScript, $iss, $utf8Bom)
  Info "Dinh danh ban cai CU: $identitySource"
  Info "Inno script moi (co cung AppId): $installerScript"
  $iscc = $null
  foreach ($target in @(
    (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'),
    (Join-Path $env:ProgramFiles 'Inno Setup 6\ISCC.exe'),
    (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe')
  )) {
    if ($target -and (Test-Path -LiteralPath $target)) { $iscc = $target; break }
  }
  if (-not $iscc) {
    $cmd = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    if ($cmd) { $iscc = $cmd.Source }
  }
  if (-not $iscc) {
    Notice 'Chua tim thay Inno Setup 6 (ISCC.exe). Da tao .iss, can cai Inno Setup 6 roi chay lai script.'
    Info "ZIP portable: $portableZip"
    exit 0
  }
  Info 'Dang tao Setup.exe bang Inno Setup'
  & $iscc $installerScript
  CheckExit 'Inno Setup compile'
  $setupExe = Join-Path $setupOutputDir "VLXD_Hai_Soc_Setup_$Version.exe"
  if (-not (Test-Path -LiteralPath $setupExe)) { throw 'ISCC bao thanh cong nhung khong tim thay Setup.exe.' }
  [System.IO.File]::WriteAllText($lastVersionFile, $releaseVersion + "`r`n", $utf8Bom)
  $report = @"
Build: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Source: $ProjectRoot
Version: $releaseVersion
WindowsBundle: $bundle
PortableZip: $portableZip
SetupExe: $setupExe
PreviousIdentity: $identitySource
AppId: $appId
PrivilegeMode: $privileges
Note: Setup khong tu dong chay, khong xoa SQLite/AppData/Firebase. Can dong app va sao luu truoc khi chay Setup.
"@
  [System.IO.File]::WriteAllText((Join-Path $releaseDir 'build_info.txt'), $report, $utf8Bom)
  Write-Host ''
  Write-Host '===== DONG GOI THANH CONG =====' -ForegroundColor Green
  Write-Host "Setup: $setupExe" -ForegroundColor Green
  Write-Host "Portable: $portableZip" -ForegroundColor Green
  Notice 'Dong app cu. Backup du lieu/doi soat outbox chua dong bo. Sau do chay Setup de nang cap tai thu muc CU.'
}
catch {
  Write-Host ''
  Write-Host "[LOI] $($_.Exception.Message)" -ForegroundColor Red
  exit 1
}
