param([string]$ProjectPath = 'D:\app\vlxd_app')
$ErrorActionPreference = 'Stop'
$patchRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$project = (Resolve-Path -LiteralPath $ProjectPath).Path
if (!(Test-Path (Join-Path $project 'pubspec.yaml'))) {
    throw 'Khong tim thay pubspec.yaml. Hay chon thu muc vlxd_app.'
}

function Hash-Normalized([string]$path) {
    $value = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)
    $value = $value.Replace("`r`n", "`n").Replace("`r", "`n")
    $hash = [Security.Cryptography.SHA256]::Create()
    try {
        return [BitConverter]::ToString($hash.ComputeHash([Text.Encoding]::UTF8.GetBytes($value))).Replace('-','').ToLowerInvariant()
    } finally { $hash.Dispose() }
}

$manifest = Get-Content (Join-Path $patchRoot 'PATCH_MANIFEST.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$changes = @()
# KIEM TRA TOAN BO TRUOC KHI GHI BAT KY FILE NAO
foreach ($entry in $manifest.files) {
    $relative = $entry.path.Replace('/', [IO.Path]::DirectorySeparatorChar)
    $source = Join-Path (Join-Path $patchRoot 'source') $relative
    $target = Join-Path $project $relative
    if (!(Test-Path -LiteralPath $source -PathType Leaf)) { throw "Patch thieu: $relative" }
    if ((Hash-Normalized $source) -ne $entry.newHash) { throw "Patch bi sua: $relative" }
    $present = Test-Path -LiteralPath $target -PathType Leaf
    $current = if ($present) { Hash-Normalized $target } else { $null }
    if ($current -eq $entry.newHash) { continue }
    if ($null -ne $entry.oldHash) {
        if (!$present -or $current -ne $entry.oldHash) {
            throw "CODE DA THAY DOI: $relative. Chua ghi de. Chay collect-current-for-merge.ps1 neu can ghep."
        }
    } elseif ($present) {
        throw "FILE MOI DA CO NOI DUNG KHAC: $relative. Chua ghi de."
    }
    $changes += [PSCustomObject]@{ path=$relative; source=$source; target=$target; present=$present; newHash=$entry.newHash }
}
if ($changes.Count -eq 0) {
    Write-Host 'BAN NAY DA DUOC CAI. Khong can ghi de.' -ForegroundColor Green
    exit 0
}
$backup = Join-Path (Join-Path $project '.vlxd_patch_backups') ('Mobile_UI_' + (Get-Date -Format 'yyyyMMdd_HHmmss_fff'))
New-Item -ItemType Directory -Force -Path $backup | Out-Null
$records = @()
foreach ($item in $changes) {
    if ($item.present) {
        $backupFile = Join-Path $backup $item.path
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $backupFile) | Out-Null
        Copy-Item -LiteralPath $item.target -Destination $backupFile
    }
    $records += [PSCustomObject]@{
        path=$item.path.Replace('\','/'); wasPresent=$item.present; newHash=$item.newHash
    }
}
@{ files=$records } | ConvertTo-Json -Depth 5 | Set-Content -Path (Join-Path $backup 'restore-manifest.json') -Encoding UTF8
$done = @()
try {
    foreach ($item in $changes) {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $item.target) | Out-Null
        Copy-Item -LiteralPath $item.source -Destination $item.target -Force
        $done += $item
    }
} catch {
    foreach ($item in $done) {
        if ($item.present) {
            Copy-Item -LiteralPath (Join-Path $backup $item.path) -Destination $item.target -Force
        } else {
            Remove-Item -LiteralPath $item.target -Force -ErrorAction SilentlyContinue
        }
    }
    throw "Loi khi cai; da thu khoi phuc file goc: $_"
}
Write-Host 'CAI DAT MOBILE UI THANH CONG. KHONG THAY DOI FIREBASE.' -ForegroundColor Green
Write-Host "Backup: $backup"
Write-Host 'Chay: dart format lib/ui test/mobile_responsive_sales_test.dart'
Write-Host 'Chay: flutter analyze --no-pub; flutter test --no-pub'
