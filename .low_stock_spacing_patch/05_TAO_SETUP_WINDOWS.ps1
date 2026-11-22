#Requires -Version 5.1
param(
    [string]$InnoCompiler = 'D:\Inno Setup 6\ISCC.exe',
    [string]$Version = '1.0.10'
)
$ErrorActionPreference = 'Stop'
$root = (Get-Location).Path
if (-not (Test-Path '.\pubspec.yaml')) { throw 'Run from D:\app\vlxd_app.' }
if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw 'Invalid version number.' }
$catalog = [IO.File]::ReadAllText((Join-Path $root 'lib\ui\catalog.dart'), [Text.Encoding]::UTF8)
if (-not $catalog.Contains('vlxd-low-stock-space-v1')) { throw 'Spacing patch missing. Run 01 first.' }
if (-not (Test-Path -LiteralPath $InnoCompiler -PathType Leaf)) { throw "Inno Setup missing: $InnoCompiler" }
if (Get-Process -Name vlxd_app -ErrorAction SilentlyContinue) { throw 'Close VLXD Bay Hai Windows app before packaging.' }
# Rebuild from current Dart sources.  The Windows launcher EXE may keep an
# older file timestamp after a Dart-only change; the compiled app.so is the
# correct output to validate instead.
Write-Host '[BUILD] Compiling latest Windows Release before creating Setup...' -ForegroundColor Cyan
& flutter build windows --release
if ($LASTEXITCODE -ne 0) { throw 'Windows Release build failed; Setup was not created.' }
$bundle = Join-Path $root 'build\windows\x64\runner\Release'
$exe = Join-Path $bundle 'vlxd_app.exe'
if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) { throw "Windows launcher missing: $exe" }
$appSo = Join-Path $bundle 'data\app.so'
if (-not (Test-Path -LiteralPath $appSo -PathType Leaf)) {
    throw "Compiled Windows Flutter app.so missing: $appSo. Please send the Windows Release folder listing. Setup was not created."
}
$latestDart = Get-ChildItem -LiteralPath (Join-Path $root 'lib') -Filter '*.dart' -Recurse -File |
    Sort-Object -Property LastWriteTimeUtc -Descending | Select-Object -First 1
if ($null -eq $latestDart) { throw 'Dart sources were not found.' }
# Allow 2 sec for filesystems with coarse modification-time resolution.
if ((Get-Item -LiteralPath $appSo).LastWriteTimeUtc.AddSeconds(2) -lt $latestDart.LastWriteTimeUtc) {
    throw "Compiled app.so is older than source $($latestDart.FullName). Setup not created; inspect Flutter build logs."
}
Write-Host '[OK] Compiled app.so is up to date with Dart source.' -ForegroundColor Green
foreach ($needed in @('flutter_windows.dll', 'data')) {
    if (-not (Test-Path (Join-Path $bundle $needed))) { throw "Incomplete Windows Release: $needed missing." }
}
$outDir = Join-Path $root 'release\installers'
New-Item -ItemType Directory -Path $outDir -Force | Out-Null
$issFile = Join-Path $outDir 'VLXD_Bay_Hai_Low_Stock_Spacing.iss'
$base = "VLXD_Bay_Hai_Setup_$Version"
$iss = @"
[Setup]
AppId=VLXD.App.Windows.Desktop
AppName=VLXD Bay Hai
AppVersion=$Version
AppVerName=VLXD Bay Hai $Version
DefaultDirName={localappdata}\Programs\VLXD App
DefaultGroupName=VLXD Bay Hai
UsePreviousAppDir=yes
PrivilegesRequired=lowest
OutputDir=$outDir
OutputBaseFilename=$base
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=no
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\vlxd_app.exe

[Files]
Source: "$bundle\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\VLXD Bay Hai"; Filename: "{app}\vlxd_app.exe"; WorkingDir: "{app}"
Name: "{autodesktop}\VLXD Bay Hai"; Filename: "{app}\vlxd_app.exe"; WorkingDir: "{app}"
"@
[IO.File]::WriteAllText($issFile, $iss, ([System.Text.UTF8Encoding]::new($true)))
& $InnoCompiler $issFile
if ($LASTEXITCODE -ne 0) { throw 'Inno Setup compile failed. Existing installation unchanged.' }
$installer = Join-Path $outDir ($base + '.exe')
if (-not (Test-Path $installer)) { throw 'Setup EXE missing.' }
Write-Host "[SUCCESS] New setup built: $installer" -ForegroundColor Green
Write-Host '[SAFETY] Do not uninstall old app. Back up / sync offline data before running setup.' -ForegroundColor Yellow
Write-Host '[NEXT] Double-click Setup EXE to upgrade the same AppId, after verifying sync/backup.' -ForegroundColor Cyan
