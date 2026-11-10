param(
  [ValidateSet('windows','web')][string]$Target = 'windows',
  [string]$Database = '',
  [switch]$IReviewedAllDeviceQueues
)

# Standalone opt-in production builder. Windows PowerShell 5.1 compatible.
# Does NOT start app, deploy web, or modify SQLite/Firestore.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2

if (!(Test-Path -LiteralPath 'pubspec.yaml') -or !(Test-Path -LiteralPath 'lib/main.dart')) {
  throw 'Run from the Flutter project root (e.g. D:\app\vlxd_app).'
}
if (-not $IReviewedAllDeviceQueues) {
  throw 'Add -IReviewedAllDeviceQueues only after reviewing unsynced transactions on ALL devices, including Web/PWA.'
}

# Check this build has the explicit double opt-in gate in main.dart.
$mainSource = [System.IO.File]::ReadAllText((Resolve-Path 'lib/main.dart').Path)
foreach ($required in @('AUTO_SYNC_OUTBOX','ALLOW_PRODUCTION_AUTO_SYNC','USE_FIREBASE_EMULATOR')) {
  if (-not $mainSource.Contains($required)) { throw "main.dart missing expected switch: $required" }
}
if (-not [regex]::IsMatch($mainSource, 'autoSyncEnabled\s*&&\s*\(emulator\s*\|\|\s*allowProductionAutoSync\)')) {
  throw 'Expected production auto-sync safeguard not found in main.dart. Review manually.'
}

# Read-only check the Windows outbox to guard against accidental replay.
# This cannot inspect queues on Web/Android/other Windows users.
if ($Database -ne '') {
  if (-not [System.IO.Path]::IsPathRooted($Database)) { throw 'Database path must be absolute.' }
  if (-not (Test-Path -LiteralPath $Database -PathType Leaf)) { throw 'Database file not found.' }
  $nodeScript = @'
const {DatabaseSync}=require('node:sqlite');
const fs=require('node:fs');
const file=process.argv[2];
if (!fs.existsSync(file)) process.exit(3);
const db=new DatabaseSync(file,{readOnly:true});
try {
  const rows=db.prepare("SELECT status, COUNT(*) AS count FROM pending_operations GROUP BY status").all();
  console.log('Local outbox (read only):',JSON.stringify(rows));
  const blocked=rows.filter(x=>['pending','failed','syncing'].includes(x.status)).reduce((n,x)=>n+Number(x.count),0);
  if (blocked!==0) {console.error('BLOCKED: local unsynced transactions = '+blocked);process.exitCode=4;}
} finally {db.close();}
'@
  # Windows PowerShell 5.1 can strip nested JS double quotes in node -e.
  # Run the same read-only audit from a temporary .cjs file instead.
  $auditFile = Join-Path ([System.IO.Path]::GetTempPath()) ("vlxd-outbox-audit-" + [guid]::NewGuid().ToString('N') + '.cjs')
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  try {
    [System.IO.File]::WriteAllText($auditFile, $nodeScript, $utf8NoBom)
    & node $auditFile $Database
    if ($LASTEXITCODE -ne 0) { throw 'Local outbox audit failed. Stop before production build.' }
  } finally {
    Remove-Item -LiteralPath $auditFile -Force -ErrorAction SilentlyContinue
  }
}
elseif ($Target -eq 'windows') {
  throw 'For Windows builds, supply -Database with an audited local SQLite file path.'
}

Write-Host ''
Write-Warning 'LIVE FIREBASE PRODUCTION BUILD: Automatic sync will be ENABLED in the generated application.'
Write-Warning 'This does not verify server IDs, users, or PWA/Android queues; no deployment will be performed.'
Write-Host 'Review all device queues and backups before distributing the generated build.'
$consent = Read-Host 'Type exactly BAT DONG BO FIREBASE THAT to continue'
if ($consent -cne 'BAT DONG BO FIREBASE THAT') { throw 'Cancelled. No production build was started.' }

$flags = @(
  '--dart-define=USE_FIREBASE_EMULATOR=false',
  '--dart-define=AUTO_SYNC_OUTBOX=true',
  '--dart-define=ALLOW_PRODUCTION_AUTO_SYNC=true'
)
if ($Target -eq 'windows') {
  & flutter build windows --release @flags
  if ($LASTEXITCODE -ne 0) { throw "Windows build failed ($LASTEXITCODE)." }
  Write-Host 'Built Windows release under build/windows/x64/runner/Release (depending on Flutter version).'
  Write-Warning 'Do not copy only the .exe: distribute its full Release directory.'
} else {
  if (!(Test-Path -LiteralPath 'tools/build-web-offline.ps1')) {
    throw 'Missing tools/build-web-offline.ps1.'
  }
  $env:VLXD_PRODUCTION_BUILD_APPROVED = 'explicitly-reviewed'
  try {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File '.\tools\build-web-offline.ps1' `
      -ProductionAutoSync -Output 'build/web'
    if ($LASTEXITCODE -ne 0) { throw 'Web production build failed.' }
  } finally { Remove-Item Env:VLXD_PRODUCTION_BUILD_APPROVED -ErrorAction SilentlyContinue }
  Write-Host 'Built Web output in build/web. NOT deployed.'
  Write-Warning 'PWA users can hold separate browser outboxes; inspect them independently before publishing.'
}
Write-Host 'Production auto-sync build completed. No app was started and nothing was deployed.'
