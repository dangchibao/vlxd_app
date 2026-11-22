param([string]$ProjectPath = 'D:\app\vlxd_app')
$ErrorActionPreference = 'Stop'
$patch = Split-Path -Parent $MyInvocation.MyCommand.Path
$project = (Resolve-Path -LiteralPath $ProjectPath).Path
$manifest = Get-Content (Join-Path $patch 'PATCH_MANIFEST.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$temp = Join-Path $env:TEMP ('vlxd-mobile-' + (Get-Date -Format 'yyyyMMdd_HHmmss_fff'))
New-Item -ItemType Directory -Force -Path $temp | Out-Null
foreach ($entry in $manifest.files) {
    $relative = $entry.path.Replace('/',[IO.Path]::DirectorySeparatorChar)
    $file = Join-Path $project $relative
    if (!(Test-Path -LiteralPath $file)) { continue }
    $dest = Join-Path $temp $relative
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
    Copy-Item -LiteralPath $file -Destination $dest
}
$destZip = Join-Path $project 'VLXD_Mobile_Current_For_Merge.zip'
if (Test-Path $destZip) { throw 'Doi ten file VLXD_Mobile_Current_For_Merge.zip cu truoc khi thu lai.' }
Compress-Archive -Path (Join-Path $temp '*') -DestinationPath $destZip
Remove-Item -LiteralPath $temp -Recurse -Force
Write-Host "File code de ghep: $destZip"
