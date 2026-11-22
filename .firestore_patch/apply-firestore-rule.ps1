param(
  [string]$ProjectRoot = 'D:\app\vlxd_app'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

try {
  $ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
  $rulesFile = Join-Path $ProjectRoot 'firestore.rules'
  $configFile = Join-Path $ProjectRoot 'firebase.json'
  $sourceFile = Join-Path $ProjectRoot 'lib\domain\shop.dart'
  if (-not (Test-Path -LiteralPath $rulesFile -PathType Leaf)) { throw "Khong tim thay: $rulesFile" }
  if (-not (Test-Path -LiteralPath $configFile -PathType Leaf)) { throw "Khong tim thay: $configFile" }
  $config = Get-Content -LiteralPath $configFile -Raw -Encoding UTF8 | ConvertFrom-Json
  if ($config.firestore.rules -ne 'firestore.rules') {
    throw 'firebase.json khong tro den firestore.rules. Khong the sua an toan.'
  }
  $original = [System.IO.File]::ReadAllText($rulesFile, [System.Text.Encoding]::UTF8)
  $old = "&& (!('secondaryUnit' in p) || (p.secondaryUnit is string && p.secondaryUnit.size() > 0 && p.secondaryUnit.size() <= 40 && p.secondaryUnit != p.get('unit', 'm²') && p.ratio > 0))"
  $new = @'
&& (!('secondaryUnit' in p) ||
                (p.secondaryUnit is string &&
                 ((p.secondaryUnit == '' && p.ratio == 0) ||
                  (p.secondaryUnit.size() > 0 &&
                   p.secondaryUnit.size() <= 40 &&
                   p.secondaryUnit != p.get('unit', 'm²') &&
                   p.ratio > 0))))
'@
  $new = $new.Trim()
  $oldGuard = "&& (!('secondaryUnit' in resource.data.value) ||"
  $oldGuardNext = "'secondaryUnit' in request.resource.data.value)"
  $guardRegex = [regex]::Escape($oldGuard) + '\r?\n\s*' + [regex]::Escape($oldGuardNext)
  $newGuard = @'
&& (resource.data.value.get('secondaryUnit', '') == '' ||
              (('secondaryUnit' in request.resource.data.value) &&
               request.resource.data.value.secondaryUnit is string &&
               request.resource.data.value.secondaryUnit.size() > 0))
'@
  $newGuard = $newGuard.Trim()
  if ($original.Contains("p.secondaryUnit == '' && p.ratio == 0")) {
    Write-Host '[OK] File firestore.rules da duoc va truoc do. Khong sua them.' -ForegroundColor Green
    exit 0
  }
  if (-not $original.Contains($old)) { throw 'Khong tim thay dong rules cu dung mau. Dung de tranh ghi de sai phien ban.' }
  if ([regex]::Matches($original, [regex]::Escape($old)).Count -ne 1) { throw 'Co nhieu hon 1 vi tri trung khop: dung de bao ve.' }
  if ([regex]::Matches($original, $guardRegex).Count -ne 1) { throw 'Khong tim thay mot mau bao ve secondaryUnit cu. Dung de bao ve.' }

  $backupDir = Join-Path $ProjectRoot 'backup\firestore_rules'
  New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
  $stamp = Get-Date -Format 'yyyyMMdd_HHmmss_fff'
  $backupPath = Join-Path $backupDir ("firestore.rules.$stamp.bak")
  Copy-Item -LiteralPath $rulesFile -Destination $backupPath -ErrorAction Stop

  $updated = $original.Replace($old, $new)
  $updated = [regex]::Replace($updated, $guardRegex, $newGuard)
  $nl = if ($original.Contains("`r`n")) { "`r`n" } else { "`n" }
  $updated = $updated.Replace("`r`n", "`n").Replace("`n", $nl)
  [System.IO.File]::WriteAllText($rulesFile, $updated, ([System.Text.UTF8Encoding]::new($false)))
  $readback = [System.IO.File]::ReadAllText($rulesFile, [System.Text.Encoding]::UTF8)
  if (-not $readback.Contains("p.secondaryUnit == '' && p.ratio == 0") -or
      -not $readback.Contains("resource.data.value.get('secondaryUnit', '')")) {
    Copy-Item -LiteralPath $backupPath -Destination $rulesFile -Force
    throw 'Xac minh that bai; da khoi phuc backup.'
  }
  Write-Host '[OK] Da va firestore.rules, khong sua Dart/SQLite/EXE.' -ForegroundColor Green
  Write-Host "[BACKUP] $backupPath"
  if (Test-Path -LiteralPath $sourceFile -PathType Leaf) {
    $domain = [System.IO.File]::ReadAllText($sourceFile, [System.Text.Encoding]::UTF8)
    if ($domain -notmatch "'secondaryUnit'") {
      Write-Warning 'shop.dart hien tai khong tim thay serialization secondaryUnit; nguyen nhan loi co the khac.'
    }
  }
  Write-Host '[NEXT] Neu muon ap dung quy tac len Firebase: chay 02_CAP_NHAT_FIREBASE.cmd.' -ForegroundColor Cyan
  exit 0
} catch {
  Write-Host "[FAILED] $($_.Exception.Message)" -ForegroundColor Red
  exit 1
}
