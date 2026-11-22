#requires -Version 5.1
param(
  [string]$ProjectRoot = 'D:\app\vlxd_app',
  [string]$Version = '1.0.8',
  [string]$InnoCompiler = 'D:\Inno Setup 6\ISCC.exe',
  [switch]$BuildOnly
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Step([string]$message) { Write-Host "[VLXD] $message" -ForegroundColor Cyan }
function EnsureLast([string]$message) {
  if ($LASTEXITCODE -ne 0) { throw "$message failed (exit $LASTEXITCODE). Setup was NOT installed." }
}

if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw 'Invalid version. No changes made.' }
$root = (Resolve-Path -LiteralPath $ProjectRoot -ErrorAction Stop).Path
$pubspec = Join-Path $root 'pubspec.yaml'
$catalog = Join-Path $root 'lib\ui\catalog.dart'
foreach ($file in @($pubspec, $catalog)) {
  if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "Missing project file: $file" }
}
if (-not (Test-Path -LiteralPath $InnoCompiler -PathType Leaf)) {
  throw "Inno Setup compiler not found: $InnoCompiler. No changes made."
}
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  throw 'Flutter not found in PATH. No changes made.'
}
if (Get-Process -Name vlxd_app -ErrorAction SilentlyContinue) {
  throw 'Close the running VLXD Bay Hai Windows app first. Setup was not started.'
}

$pub = [IO.File]::ReadAllText($pubspec, [Text.Encoding]::UTF8)
if ($pub -notmatch '(?m)^name:\s*vlxd_app\s*$') { throw 'Unexpected Flutter project. No changes made.' }
$code = [IO.File]::ReadAllText($catalog, [Text.Encoding]::UTF8)
# Check the V4 *exact pictogram* patch is present. Never install stale V3 UI.
foreach ($marker in @(
  'product-action-glyphs-exact-v4',
  'product-action-row-exact-v4',
  '_ProductActionKind.pencil',
  '_ProductActionKind.clipboardCheck',
  '_ProductActionKind.printer',
  '_ProductActionKind.ban',
  'Color(0xFF1976D2)',
  'Color(0xFFD97706)',
  'Color(0xFF0D9488)',
  'Color(0xFFDC2626)',
  'correctReceivedUnitDialog(context, p)',
  'showBarcode(context, p)',
  'PrintService.barcode(p)'
)) {
  if (-not $code.Contains($marker)) { throw "V4 icon source is missing: $marker. No installation." }
}

$firebaseFile = Join-Path $root 'lib\firebase_options.dart'
if (-not (Test-Path -LiteralPath $firebaseFile)) { throw 'Firebase options not found.' }
$firebase = [IO.File]::ReadAllText($firebaseFile, [Text.Encoding]::UTF8)
if (-not $firebase.Contains("projectId: 'vlxd-bay-hai'")) {
  throw 'Unexpected Firebase project! Installation cancelled.'
}

# Guard against accidentally installing side-by-side with a different legacy installer.
$uninstallRoots = @(
  'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall',
  'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall',
  'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
)
$knownId = 'VLXD.App.Windows.Desktop_is1'
foreach ($uninstallRoot in $uninstallRoots) {
  if (-not (Test-Path -LiteralPath $uninstallRoot)) { continue }
  $entries = @(Get-ChildItem -LiteralPath $uninstallRoot -ErrorAction SilentlyContinue)
  foreach ($entry in $entries) {
    $reg = Get-ItemProperty -LiteralPath $entry.PSPath -ErrorAction SilentlyContinue
    if ($null -eq $reg) { continue }
    $displayProp = $reg.PSObject.Properties['DisplayName']
    if ($null -eq $displayProp -or [string]::IsNullOrWhiteSpace([string]$displayProp.Value)) { continue }
    $displayName = [string]$displayProp.Value
    if ($displayName -match '^VLXD (App|Bay Hai|B[a-z]+ Hai)' -and $entry.PSChildName -ne $knownId) {
      throw "Another VLXD installer is registered with a different AppId: $displayName [$($entry.PSChildName)]. Stop to avoid parallel installation."
    }
  }
}

Set-Location -LiteralPath $root
Step 'Flutter analyze...'
& flutter analyze --no-pub
EnsureLast 'Flutter analyze'
Step 'Running Flutter tests...'
& flutter test --no-pub
EnsureLast 'Flutter tests'
Step 'Building Windows Release with V4 pictograms...'
& flutter build windows --release --no-pub --build-name=$Version --build-number=8
EnsureLast 'Flutter Windows build'

$bundle = Join-Path $root 'build\windows\x64\runner\Release'
foreach ($rel in @('vlxd_app.exe','flutter_windows.dll','data')) {
  if (-not (Test-Path -LiteralPath (Join-Path $bundle $rel))) {
    throw "Incomplete Windows release: $rel is missing. Setup not installed."
  }
}
$destination = Join-Path $root 'release\installers'
$null = New-Item -ItemType Directory -Path $destination -Force
$issDir = Join-Path $root 'release'
$issFile = Join-Path $issDir 'VLXD_Bay_Hai_V4_Setup.iss'
$setupBase = 'VLXD_Bay_Hai_Setup_' + $Version
$iss = @"
[Setup]
AppId=VLXD.App.Windows.Desktop
AppName=VLXD Bay Hai
AppVersion=$Version
AppVerName=VLXD Bay Hai $Version
DefaultDirName={localappdata}\Programs\VLXD App
DefaultGroupName=VLXD Bay Hai
OutputDir=$destination
OutputBaseFilename=$setupBase
PrivilegesRequired=lowest
UsePreviousAppDir=yes
UsePreviousGroup=no
CloseApplications=yes
RestartApplications=no
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\vlxd_app.exe
DisableProgramGroupPage=yes

[Files]
Source: "$bundle\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[InstallDelete]
Type: files; Name: "{autoprograms}\VLXD App.lnk"
Type: files; Name: "{autodesktop}\VLXD App.lnk"

[Icons]
Name: "{autoprograms}\VLXD Bay Hai"; Filename: "{app}\vlxd_app.exe"; WorkingDir: "{app}"
Name: "{autodesktop}\VLXD Bay Hai"; Filename: "{app}\vlxd_app.exe"; WorkingDir: "{app}"

[Run]
Filename: "{app}\vlxd_app.exe"; Description: "Launch VLXD Bay Hai"; Flags: nowait postinstall skipifsilent
"@
[IO.File]::WriteAllText($issFile, $iss, ([System.Text.UTF8Encoding]::new($true)))
Step 'Compiling the upgrade installer using Inno Setup...'
& $InnoCompiler $issFile
EnsureLast 'Inno Setup'

$setup = Join-Path $destination ($setupBase + '.exe')
if (-not (Test-Path -LiteralPath $setup -PathType Leaf)) { throw "Setup output missing: $setup" }
if ((Get-Item -LiteralPath $setup).Length -lt 1000000) { throw 'Setup output looks incomplete (<1 MB).' }
$hash = (Get-FileHash -LiteralPath $setup -Algorithm SHA256).Hash
Step "SETUP CREATED: $setup"
Write-Host "[SHA256] $hash" -ForegroundColor Gray
Write-Host '[SAFE] Reuses VLXD.App.Windows.Desktop AppId. Does NOT uninstall or delete SQLite, Firebase, or inventory.' -ForegroundColor Green

if ($BuildOnly) {
  Write-Host '[OK] BuildOnly selected; setup was not launched.' -ForegroundColor Yellow
  exit 0
}
if (Get-Process -Name vlxd_app -ErrorAction SilentlyContinue) {
  throw "VLXD app was opened during build. Close it, then run the setup manually: $setup"
}
Step 'Opening installer. Follow the Windows wizard to install / upgrade.'
$installerProcess = Start-Process -FilePath $setup -Wait -PassThru
if ($installerProcess.ExitCode -ne 0) {
  throw "Installer exited with code $($installerProcess.ExitCode). Check the wizard result."
}
Write-Host '[SUCCESS] Windows setup wizard completed. Open VLXD Bay Hai from the Start menu or Desktop.' -ForegroundColor Green
