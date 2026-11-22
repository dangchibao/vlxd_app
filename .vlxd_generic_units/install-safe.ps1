param(
  [Parameter(Mandatory=$false)][string]$ProjectPath = 'D:\app\vlxd_app'
)
$ErrorActionPreference = 'Stop'
$project = (Resolve-Path -LiteralPath $ProjectPath).Path
$manifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json

function Hash([string]$file) {
  return (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()
}
function DartEquivalent([string]$expected, [string]$actual, [bool]$shopFile) {
  $folder = Join-Path $env:TEMP ('vlxd_verify_' + [guid]::NewGuid().ToString('N'))
  New-Item -ItemType Directory -Path $folder -Force | Out-Null
  try {
    $a = Join-Path $folder 'baseline.dart'
    $b = Join-Path $folder 'current.dart'
    Copy-Item -LiteralPath $expected -Destination $a
    Copy-Item -LiteralPath $actual -Destination $b
    & dart format $a $b | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'dart format kiem tra that bai' }
    if ((Hash $a) -eq (Hash $b)) { return $true }
    if ($shopFile) {
      # Previous patch's only analyzer fix added braces to this exact guard.
      $source = [System.IO.File]::ReadAllText($expected)
      $original = 'if (p.deleted || p.lots.isNotEmpty || p.stock != 0 || p.reserved != 0) return false;'
      $fixed = 'if (p.deleted || p.lots.isNotEmpty || p.stock != 0 || p.reserved != 0) { return false; }'
      if ($source.Contains($original)) {
        [System.IO.File]::WriteAllText($a, $source.Replace($original, $fixed), ([System.Text.UTF8Encoding]::new($false)))
        & dart format $a | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'dart format shop fix that bai' }
        return ((Hash $a) -eq (Hash $b))
      }
    }
    return $false
  } finally {
    Remove-Item -LiteralPath $folder -Recurse -Force -ErrorAction SilentlyContinue
  }
}

$items = @()
foreach ($entry in @($manifest.files)) {
  $rel = [string]$entry.path
  if (!$rel -or $rel.Contains('..') -or $rel.Contains(':') -or $rel.StartsWith('/')) {
    throw "Duong dan file khong an toan: $rel"
  }
  $win = $rel.Replace('/', '\')
  $after = Join-Path $PSScriptRoot (Join-Path 'files' $win)
  $baseline = Join-Path $PSScriptRoot (Join-Path 'baseline' $win)
  $destination = Join-Path $project $win
  if (!(Test-Path -LiteralPath $after -PathType Leaf)) { throw "Thieu patch: $rel" }
  if ((Hash $after) -ne ([string]$entry.new_sha256)) { throw "Patch bi sua/loi: $rel" }
  if ([string]::IsNullOrWhiteSpace([string]$entry.before_sha256)) {
    if (Test-Path -LiteralPath $destination) { throw "File moi da ton tai: $rel. Khong ghi de." }
    $exists = $false
  } else {
    if (!(Test-Path -LiteralPath $destination -PathType Leaf)) { throw "Thieu code goc: $rel" }
    if (!(Test-Path -LiteralPath $baseline -PathType Leaf)) { throw "Thieu baseline: $rel" }
    if ((Hash $baseline) -ne ([string]$entry.before_sha256)) { throw "Baseline bi sua: $rel" }
    $same = (Hash $destination) -eq ([string]$entry.before_sha256)
    if (!$same -and $rel.EndsWith('.dart')) {
      $same = DartEquivalent $baseline $destination ($rel -eq 'lib/domain/shop.dart')
    }
    if (!$same) {
      throw "FILE DA THAY DOI so voi ban ZIP truoc: $rel. Dung an toan, khong ghi de."
    }
    $exists = $true
  }
  $items += [pscustomobject]@{ rel=$win; src=$after; dst=$destination; exists=$exists }
}

$backup = Join-Path $project ('.vlxd_patch_backups\GenericUnits_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
New-Item -ItemType Directory -Path $backup -Force | Out-Null
$written = New-Object System.Collections.ArrayList
try {
  foreach ($item in $items) {
    if ($item.exists) {
      $backupFile = Join-Path $backup $item.rel
      New-Item -ItemType Directory -Path (Split-Path -Parent $backupFile) -Force | Out-Null
      Copy-Item -LiteralPath $item.dst -Destination $backupFile -Force
    }
    New-Item -ItemType Directory -Path (Split-Path -Parent $item.dst) -Force | Out-Null
    [void]$written.Add($item)
    Copy-Item -LiteralPath $item.src -Destination $item.dst -Force
  }
} catch {
  $err = $_
  for ($i=$written.Count-1; $i -ge 0; $i--) {
    $item=$written[$i]
    $from = Join-Path $backup $item.rel
    if ($item.exists -and (Test-Path -LiteralPath $from)) {
      Copy-Item -LiteralPath $from -Destination $item.dst -Force
    } elseif (!$item.exists) {
      Remove-Item -LiteralPath $item.dst -Force -ErrorAction SilentlyContinue
    }
  }
  throw "Gap loi va da khoi phuc file goc: $err"
}
Write-Host "OK: Da cap nhat $($written.Count) file ma nguon / rules. KHONG deploy Firebase." -ForegroundColor Green
Write-Host "Backup: $backup"
Write-Host 'TIEP THEO: dart format lib test; flutter analyze --no-pub; flutter test --no-pub'
Write-Host 'Can review + deploy Firestore Rules truoc khi su dung don vi phu moi tren data that.'
