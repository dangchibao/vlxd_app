param(
    [Parameter(Mandatory=$true)][string]$BackupPath,
    [string]$ProjectPath = 'D:\app\vlxd_app'
)
$ErrorActionPreference = 'Stop'
function Hash-Normalized([string]$path) {
    $value = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)
    $value = $value.Replace("`r`n", "`n").Replace("`r", "`n")
    $hash = [Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($hash.ComputeHash([Text.Encoding]::UTF8.GetBytes($value))).Replace('-','').ToLowerInvariant() }
    finally { $hash.Dispose() }
}
$backup = (Resolve-Path -LiteralPath $BackupPath).Path
$project = (Resolve-Path -LiteralPath $ProjectPath).Path
$manifest = Get-Content (Join-Path $backup 'restore-manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($entry in $manifest.files) {
    $relative = $entry.path.Replace('/', [IO.Path]::DirectorySeparatorChar)
    $target = Join-Path $project $relative
    if (!(Test-Path -LiteralPath $target) -or (Hash-Normalized $target) -ne $entry.newHash) {
        throw "File da thay doi sau khi cai: $relative. DUNG phuc hoi de tranh ghi de code moi."
    }
    if ($entry.wasPresent -and !(Test-Path (Join-Path $backup $relative))) {
        throw "Thieu file backup: $relative"
    }
}
foreach ($entry in $manifest.files) {
    $relative = $entry.path.Replace('/', [IO.Path]::DirectorySeparatorChar)
    $target = Join-Path $project $relative
    if ($entry.wasPresent) {
        Copy-Item -LiteralPath (Join-Path $backup $relative) -Destination $target -Force
    } else {
        Remove-Item -LiteralPath $target -Force
    }
}
Write-Host 'DA PHUC HOI CODE CU. KHONG SUA FIREBASE.' -ForegroundColor Green
