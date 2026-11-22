param(
    [string]$Project = 'D:\app\vlxd_app',
    [switch]$NoLaunch
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Say([string]$value) { Write-Host $value -ForegroundColor Cyan }
function Fail([string]$value) { throw $value }
function Run([string]$Executable, [string[]]$Arguments) {
    Write-Host ("> " + $Executable + ' ' + ($Arguments -join ' ')) -ForegroundColor DarkGray
    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) {
        Fail("Lenh that bai: $Executable ($LASTEXITCODE). Da dung, KHONG ghi de du lieu cua hang.")
    }
}

if (!(Test-Path -LiteralPath $Project -PathType Container)) {
    Fail("Khong tim thay thu muc du an: $Project")
}
$Project = (Resolve-Path -LiteralPath $Project).Path
$catalogPath = Join-Path $Project 'lib\ui\catalog.dart'
$shopPath = Join-Path $Project 'lib\domain\shop.dart'
$exePath = Join-Path $Project 'build\windows\x64\runner\Release\vlxd_app.exe'
if (!(Test-Path -LiteralPath $catalogPath) -or !(Test-Path -LiteralPath $shopPath)) {
    Fail('Khong tim thay catalog.dart / shop.dart. Hay mo dung du an vlxd_app.')
}

# Do not kill user processes, interrupt unsaved orders, or uninstall anything.
if (Get-Process -Name 'vlxd_app' -ErrorAction SilentlyContinue) {
    Fail('VLXD Bay Hai dang mo. Hay dong hoan toan app (ke ca cua so tu shortcut cu) roi chay lai file CMD.')
}

Push-Location $Project
$backup = $null
$didEdit = $false
try {
    Say '=== BUOC 1: Kiem tra ma nguon don vi phu ==='
    $catalog = [System.IO.File]::ReadAllText($catalogPath, [System.Text.Encoding]::UTF8)
    $shop = [System.IO.File]::ReadAllText($shopPath, [System.Text.Encoding]::UTF8)

    # The user's LOCAL source, not the older remote GitHub version, is authoritative.
    $domainOk = $shop.Contains('secondaryUnitLabel') -and $shop.Contains("'secondaryUnit'")
    $saveOk = ($catalog -match 'p\.secondaryUnitLabel\s*=') -and ($catalog -match 'secondaryUnit\.text')
    $controllerOk = ($catalog -match 'secondaryUnit\s*=\s*TextEditingController\s*\(')
    if (-not ($domainOk -and $saveOk -and $controllerOk)) {
        Fail('Code local chua day du controller / luu / JSON cua don vi phu. Vi an toan, ban va KHONG tu y thay shop.dart. Hay gui lib/ui/catalog.dart va lib/domain/shop.dart de tao ban va dung phien ban.')
    }

    $hasField = $catalog -match '(?s)\bfield\s*\(\s*secondaryUnit\s*,' -or $catalog -match '(?s)\bcontroller\s*:\s*secondaryUnit\b'
    if ($hasField) {
        Say '[OK] Code da co o nhap don vi phu. Kha nang cao dang mo nham EXE cu; se build va tao shortcut moi.'
    } else {
        Say '[FIX] Code co xu ly don vi phu nhung thieu o nhap: them o nhap vao form sua san pham.'
        # Restrict editing to a single, explicitly recognized UI insertion point.
        $pattern = '(?m)^(?<indent>[ \t]*)field\s*\(\s*supplier\s*,'
        $rx = [regex]::new($pattern)
        $uiMatches = $rx.Matches($catalog)
        if ($uiMatches.Count -ne 1) {
            Fail("Khong tim thay CHINH XAC 1 vi tri truong nha cung cap (tim thay $($uiMatches.Count)). Dung de tranh sua nham form.")
        }
        $backupRoot = Join-Path $Project 'backup\secondary_unit_patch'
        New-Item -ItemType Directory -Path $backupRoot -Force | Out-Null
        $backup = Join-Path $backupRoot ('catalog.dart.' + (Get-Date -Format 'yyyyMMdd_HHmmss_fff') + '.bak')
        Copy-Item -LiteralPath $catalogPath -Destination $backup
        Say "[BACKUP] $backup"
        $indent = $uiMatches[0].Groups['indent'].Value
        $insert = $indent + "field(secondaryUnit, 'Đơn vị phụ (ví dụ: thùng, bao, cây, hộp)'),`r`n" + $indent + 'field(supplier,'
        # Use MatchEvaluator so the replacement is always literal, never regex expansion.
        $newContent = $rx.Replace($catalog, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $insert }, 1)
        if ($newContent -eq $catalog) { Fail('Khong the them truong don vi phu.') }
        [System.IO.File]::WriteAllText($catalogPath, $newContent, [System.Text.UTF8Encoding]::new($false))
        $didEdit = $true
        Say '[OK] Da them o nhap don vi phu. Khong sua logic gia, kho, hoa don, Firestore.'
        Run 'dart' @('format', 'lib/ui/catalog.dart')
    }

    Say '=== BUOC 2: Kiem tra code / test ==='
    Run 'flutter' @('pub', 'get')
    Run 'flutter' @('analyze', '--no-pub')
    Run 'flutter' @('test', '--no-pub')

    Say '=== BUOC 3: Build Windows Release ==='
    Run 'flutter' @('build', 'windows', '--release')
    if (!(Test-Path -LiteralPath $exePath -PathType Leaf)) {
        Fail("Da build nhung khong tim thay EXE: $exePath")
    }

    Say '=== BUOC 4: Tao shortcut dung EXE moi ==='
    $desktop = [Environment]::GetFolderPath('Desktop')
    if ([string]::IsNullOrWhiteSpace($desktop)) {
        Fail('Khong xac dinh duoc Desktop. EXE da build xong, mo truc tiep trong thu muc Release.')
    }
    $shortcutPath = Join-Path $desktop 'VLXD Bay Hai - BAN MOI.lnk'
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $exePath
    $shortcut.WorkingDirectory = Split-Path -Parent $exePath
    $shortcut.Description = 'VLXD Bay Hai - Windows Release moi nhat tu D:\app\vlxd_app'
    $shortcut.IconLocation = "$exePath,0"
    $shortcut.Save()
    Say "[OK] Shortcut: $shortcutPath"
    Say "[OK] EXE: $exePath"
    Say '[LUU Y] Khong mo shortcut VLXD Bay Hai cu khi kiem tra o don vi phu.'
    if (-not $NoLaunch) {
        Start-Process -FilePath $exePath -WorkingDirectory (Split-Path -Parent $exePath)
    }
    Write-Host 'HOAN TAT! Kiem tra Hang hoa > Sua san pham > Don vi phu.' -ForegroundColor Green
} catch {
    Write-Host ("[FAILED] " + $_.Exception.Message) -ForegroundColor Red
    if ($didEdit -and $backup -and (Test-Path -LiteralPath $backup)) {
        Copy-Item -LiteralPath $backup -Destination $catalogPath -Force
        Say '[ROLLBACK] Da phuc hoi catalog.dart do ban va khong qua kiem tra/build.'
    }
    exit 1
} finally {
    Pop-Location
}
