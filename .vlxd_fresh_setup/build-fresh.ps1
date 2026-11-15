#requires -version 5.1
param(
  [string]$ProjectRoot = '',
  [string]$Version = '1.0.1',
  [int]$BuildNumber = 2,
  [switch]$SkipTests,
  [string]$InnoCompiler = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Step([string]$message) { Write-Host "[VLXD] $message" -ForegroundColor Cyan }
function Fail([string]$message) { throw $message }
function RequireExit([string]$task) {
  if ($LASTEXITCODE -ne 0) { Fail "$task that bai (exit $LASTEXITCODE). KHONG tao bo cai." }
}
function Find-InnoCompiler {
  # Explicit override, useful if the installer put ISCC.exe in an unusual folder.
  if ($InnoCompiler) {
    if (Test-Path -LiteralPath $InnoCompiler -PathType Leaf) {
      return (Resolve-Path -LiteralPath $InnoCompiler).Path
    }
    Fail "Khong tim thay ISCC.exe tai duong dan ban chi dinh: $InnoCompiler"
  }

  $cmd = Get-Command 'ISCC.exe' -ErrorAction SilentlyContinue
  if ($cmd -and $cmd.Source -and (Test-Path -LiteralPath $cmd.Source -PathType Leaf)) {
    return $cmd.Source
  }

  # Supports Inno Setup 6, 7, and later versions; both per-machine and per-user installs.
  $bases = @()
  if (${env:ProgramFiles(x86)}) { $bases += ${env:ProgramFiles(x86)} }
  if ($env:ProgramFiles) { $bases += $env:ProgramFiles }
  if ($env:LOCALAPPDATA) { $bases += (Join-Path $env:LOCALAPPDATA 'Programs') }
  if ($env:APPDATA) { $bases += $env:APPDATA }
  foreach ($base in ($bases | Select-Object -Unique)) {
    if (-not (Test-Path -LiteralPath $base -PathType Container)) { continue }
    $dirs = @(Get-ChildItem -LiteralPath $base -Directory -Filter 'Inno Setup*' -ErrorAction SilentlyContinue)
    foreach ($dir in $dirs) {
      $candidate = Join-Path $dir.FullName 'ISCC.exe'
      if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    }
  }

  # Look at uninstall registry entries: winget may have installed a new version elsewhere.
  $uninstallKeys = @(
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
  )
  foreach ($key in $uninstallKeys) {
    foreach ($entry in @(Get-ItemProperty -Path $key -ErrorAction SilentlyContinue)) {
      if (-not ($entry.PSObject.Properties.Name -contains 'DisplayName')) { continue }
      if ([string]$entry.DisplayName -notmatch 'Inno Setup') { continue }
      if ($entry.PSObject.Properties.Name -contains 'InstallLocation' -and $entry.InstallLocation) {
        $candidate = Join-Path ([string]$entry.InstallLocation) 'ISCC.exe'
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
      }
    }
  }

  # Winget portable-managed packages can live under a nonstandard package directory.
  if ($env:LOCALAPPDATA) {
    $wingetRoot = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'
    if (Test-Path -LiteralPath $wingetRoot -PathType Container) {
      foreach ($pkg in @(Get-ChildItem -LiteralPath $wingetRoot -Directory -Filter '*InnoSetup*' -ErrorAction SilentlyContinue)) {
        $compiler = Get-ChildItem -LiteralPath $pkg.FullName -File -Filter 'ISCC.exe' -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($compiler) { return $compiler.FullName }
      }
    }
  }
  return ''
}
try {
  if (-not $ProjectRoot) { $ProjectRoot = Split-Path -Parent $PSScriptRoot }
  $ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
  if (-not (Test-Path -LiteralPath (Join-Path $ProjectRoot 'pubspec.yaml') -PathType Leaf)) {
    Fail 'Khong co pubspec.yaml: ban chua chon dung thu muc du an.'
  }
  if (-not (Test-Path -LiteralPath (Join-Path $ProjectRoot 'windows\CMakeLists.txt') -PathType Leaf)) {
    Fail 'Du an chua co Windows runner (windows\CMakeLists.txt).'
  }
  $pubspec = Get-Content -LiteralPath (Join-Path $ProjectRoot 'pubspec.yaml') -Raw -Encoding UTF8
  if ($pubspec -notmatch '(?m)^name:\s*vlxd_app\s*$') {
    Fail 'Day khong phai du an vlxd_app. Dung de tranh dong goi nham.'
  }
  if ($Version -notmatch '^\d+\.\d+\.\d+$') { Fail 'Phien ban phai dung dang 1.0.1' }
  if ($BuildNumber -lt 1) { Fail 'BuildNumber phai lon hon 0' }
  $flutter = Get-Command flutter -ErrorAction SilentlyContinue
  if (-not $flutter) { Fail 'Khong tim thay flutter trong PATH. Kiem tra D:\development\flutter\bin.' }

  # Check before running Flutter so the earlier mistake (portable only, empty installers/) cannot repeat.
  $iscc = Find-InnoCompiler
  if (-not $iscc) {
    Write-Host ''
    Write-Host 'KHONG TIM THAY ISCC.exe (du winget co the bao Inno Setup da cai).' -ForegroundColor Yellow
    Write-Host 'Hay tim ISCC.exe, sau do chay lai voi tham so -InnoCompiler.' -ForegroundColor Yellow
    Write-Host 'Vi du: -InnoCompiler ''C:\Program Files (x86)\Inno Setup 7\ISCC.exe''' -ForegroundColor White
    Write-Host 'KHONG CAN GO HOAC CAI LAI Inno Setup.' -ForegroundColor Yellow
    exit 2
  }

  Step "Du an: $ProjectRoot"
  Step "Ten phan mem: VLXD App (2 cua hang trong cung ung dung)"
  Step "Phien ban bo cai moi: $Version ($BuildNumber)"
  Step "Inno Setup: $iscc"
  Step 'Build chi tao bo cai; KHONG go ban cu, KHONG xoa du lieu.'

  Set-Location -LiteralPath $ProjectRoot
  Step 'flutter pub get'
  & $flutter.Source pub get
  RequireExit 'flutter pub get'
  if (-not $SkipTests) {
    Step 'flutter analyze'
    & $flutter.Source analyze
    RequireExit 'flutter analyze'
    Step 'flutter test'
    & $flutter.Source test
    RequireExit 'flutter test'
  }
  Step 'flutter build windows --release'
  & $flutter.Source build windows --release --build-name $Version --build-number "$BuildNumber"
  RequireExit 'flutter build windows'

  $possible = @(
    (Join-Path $ProjectRoot 'build\windows\x64\runner\Release'),
    (Join-Path $ProjectRoot 'build\windows\runner\Release')
  )
  $bundle = ''
  foreach ($item in $possible) {
    if ((Test-Path -LiteralPath (Join-Path $item 'vlxd_app.exe') -PathType Leaf) -and
        (Test-Path -LiteralPath (Join-Path $item 'flutter_windows.dll') -PathType Leaf) -and
        (Test-Path -LiteralPath (Join-Path $item 'data') -PathType Container)) {
      $bundle = $item
      break
    }
  }
  if (-not $bundle) { Fail 'Thieu exe/DLL/data sau build. Khong duoc tao bo cai khong hoan chinh.' }

  $release = Join-Path $ProjectRoot 'release'
  $installers = Join-Path $release 'installers'
  $null = New-Item -Path $installers -ItemType Directory -Force
  $scriptPath = Join-Path $release 'VLXD_App_Fresh_Setup.iss'
  $setupName = "VLXD_App_Setup_$Version"
  # Inno Setup AppId is deliberately fixed for subsequent releases of the new VLXD App installer.
  # This is a CLEAN installer; it does not reuse guessed AppIds from older unknown installers.
  $iss = @"
[Setup]
AppId=VLXD.App.Windows.Desktop
AppName=VLXD App
AppVersion=$Version
AppVerName=VLXD App $Version
DefaultDirName={localappdata}\Programs\VLXD App
DefaultGroupName=VLXD App
OutputDir=$installers
OutputBaseFilename=$setupName
PrivilegesRequired=lowest
UsePreviousAppDir=yes
UsePreviousGroup=yes
CloseApplications=yes
RestartApplications=no
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\vlxd_app.exe
DisableDirPage=no
DisableProgramGroupPage=yes

[Tasks]
Name: "desktopicon"; Description: "Tao loi tat tren Desktop"; Flags: unchecked

[Files]
Source: "$bundle\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\VLXD App"; Filename: "{app}\vlxd_app.exe"; WorkingDir: "{app}"
Name: "{autodesktop}\VLXD App"; Filename: "{app}\vlxd_app.exe"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\vlxd_app.exe"; Description: "Mo VLXD App"; Flags: nowait postinstall skipifsilent
"@
  $utf8Bom = New-Object System.Text.UTF8Encoding($true)
  [System.IO.File]::WriteAllText($scriptPath, $iss, $utf8Bom)

  Step 'Dong goi Setup.exe bang Inno Setup'
  & $iscc $scriptPath
  RequireExit 'Inno Setup ISCC'

  $output = Join-Path $installers "$setupName.exe"
  if (-not (Test-Path -LiteralPath $output -PathType Leaf)) {
    Fail "ISCC ket thuc nhung khong tim thay file: $output"
  }
  $hash = (Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash
  $info = @"
Ten phan mem: VLXD App
Hai cua hang: Bay Hai va Hai Soc
Build luc: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Ma nguon: $ProjectRoot
Version: $Version / Build: $BuildNumber
Setup: $output
SHA256: $hash
Inno AppId: VLXD.App.Windows.Desktop
Che do: Cai moi cho nguoi dung hien tai, trong LOCALAPPDATA
Ghi chu: Khong tu xoa AppData, Firebase, SQLite, hoac du lieu web.
Can dong bo het giao dich offline va sao luu du lieu truoc khi go ban cu.
"@
  [System.IO.File]::WriteAllText((Join-Path $release 'VLXD_App_Build_Report.txt'), $info, $utf8Bom)

  Write-Host ''
  Write-Host '===============================' -ForegroundColor Green
  Write-Host 'DA TAO SETUP.EXE THANH CONG' -ForegroundColor Green
  Write-Host $output -ForegroundColor Green
  Write-Host '===============================' -ForegroundColor Green
  Write-Host 'Chua tu dong cai dat. Chi go ban cu SAU KHI backup va kiem tra file Setup moi.' -ForegroundColor Yellow
}
catch {
  Write-Host ''
  Write-Host "[LOI] $($_.Exception.Message)" -ForegroundColor Red
  exit 1
}
