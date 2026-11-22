param(
  [string]$ProjectRoot = 'D:\app\vlxd_app'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
try {
  $ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
  $configPath = Join-Path $ProjectRoot 'firebase.json'
  $rulesPath = Join-Path $ProjectRoot 'firestore.rules'
  if (-not (Test-Path -LiteralPath $configPath)) { throw 'Khong co firebase.json' }
  if (-not (Test-Path -LiteralPath $rulesPath)) { throw 'Khong co firestore.rules' }
  $config = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
  if ($config.firestore.rules -ne 'firestore.rules') { throw 'Firebase config khong tro den firestore.rules: huy.' }
  $rulesText = [System.IO.File]::ReadAllText($rulesPath, [System.Text.Encoding]::UTF8)
  if (-not $rulesText.Contains("p.secondaryUnit == '' && p.ratio == 0") -or
      -not $rulesText.Contains("resource.data.value.get('secondaryUnit', '')")) {
    throw 'Chua thay ban va can thiet. Chay 01_CAI_BAN_VA.cmd truoc.'
  }
  $target = $null
  $firebasercPath = Join-Path $ProjectRoot '.firebaserc'
  if (Test-Path -LiteralPath $firebasercPath) {
    $fb = Get-Content -LiteralPath $firebasercPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($fb.projects -and $fb.projects.default) { $target = [string]$fb.projects.default }
  }
  $configuredProject = $null
  if ($config.flutter -and $config.flutter.platforms -and $config.flutter.platforms.dart) {
    $flutterOpts = $config.flutter.platforms.dart.PSObject.Properties['lib/firebase_options.dart']
    if ($flutterOpts) { $configuredProject = [string]$flutterOpts.Value.projectId }
  }
  if ($configuredProject -and $target -and $configuredProject -ne $target) {
    throw "Project mismatch: firebase.json=$configuredProject; .firebaserc=$target. Khong deploy."
  }
  if (-not $target) { $target = $configuredProject }
  if (-not $target) { throw 'Khong xac dinh duoc Firebase project ID. Khong deploy.' }
  if ($target -notmatch '^[a-zA-Z0-9-]+$') { throw 'Project ID co ky tu khong hop le.' }

  $firebaseCmd = Get-Command firebase -ErrorAction SilentlyContinue
  if (-not $firebaseCmd) {
    Write-Host '[MISSING] Chua cai Firebase CLI. Chay lan luot:' -ForegroundColor Yellow
    Write-Host '  npm install -g firebase-tools'
    Write-Host '  firebase login'
    Write-Host 'Sau do chay lai 02_CAP_NHAT_FIREBASE.cmd'
    exit 2
  }
  Write-Host "Firebase project ID: $target" -ForegroundColor Yellow
  Write-Host 'Se deploy FIRESTORE RULES, anh huong quyen doc/ghi du lieu tren server.' -ForegroundColor Yellow
  Write-Host 'Khong deploy Hosting/Auth/Flutter/SQLite.'
  $typed = Read-Host "Nhap dung project ID '$target' de xac nhan (Enter = huy)"
  if ($typed -cne $target) {
    Write-Host '[CANCELLED] Khong thay doi Firebase tren server.' -ForegroundColor Yellow
    exit 3
  }
  Push-Location $ProjectRoot
  try {
    & firebase deploy --only firestore:rules --project $target
    if ($LASTEXITCODE -ne 0) { throw "Firebase CLI failed, exit code $LASTEXITCODE" }
  } finally { Pop-Location }
  Write-Host '[OK] Firebase CLI bao deploy rules thanh cong.' -ForegroundColor Green
  Write-Host 'Mo lai app, thu chinh gia san pham va bam Luu thay doi.' -ForegroundColor Cyan
  exit 0
} catch {
  Write-Host "[FAILED] $($_.Exception.Message)" -ForegroundColor Red
  exit 1
}
