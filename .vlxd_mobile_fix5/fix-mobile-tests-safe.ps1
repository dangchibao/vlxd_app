param([string]$ProjectPath = 'D:\app\vlxd_app')
$ErrorActionPreference = 'Stop'
$project = (Resolve-Path -LiteralPath $ProjectPath).Path
if (!(Test-Path -LiteralPath (Join-Path $project 'pubspec.yaml'))) {
    throw 'Khong thay du an Flutter. Hay chon dung ProjectPath.'
}
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$edits = @(
    @{
        Relative = 'lib/ui/sales.dart'
        Pattern = @'
text:\s*suggested\s*==\s*null\s*\?\s*'1'\s*:\s*'\$\{suggested\s*/\s*p\.quantityStep\}'\s*,
'@
        Replacement = @'
text: suggested == null
        ? '1'
        : NumberFormat('0.####', 'vi').format(suggested / p.quantityStep),
'@
        Already = "NumberFormat('0.####', 'vi').format(suggested / p.quantityStep)"
    },
    @{
        Relative = 'lib/ui/mobile_products.dart'
        Pattern = @'
const Spacer\(\),\s*// Preserve the existing edit, barcode, archive and restore actions\.\s*const ProductsPage\(\)\.actions\(context, p\),
'@
        Replacement = @'
const Spacer(),
                PopupMenuButton<String>(
                  key: ValueKey('mobile-catalog-options-${p.id}'),
                  tooltip: 'Thao tác với ${p.name}',
                  icon: const Icon(Icons.more_horiz),
                  onSelected: (action) {
                    if (action == 'edit') {
                      editProduct(context, original: p);
                    } else if (action == 'barcode') {
                      showBarcode(context, p);
                    } else if (action == 'archive') {
                      archiveProductDialog(context, p);
                    } else if (action == 'restore-deleted') {
                      restoreCatalogProduct(context, p, 'deleted');
                    } else if (action == 'restore-hidden') {
                      restoreCatalogProduct(context, p, 'archived');
                    } else if (action == 'restore-inactive') {
                      restoreCatalogProduct(context, p, 'inactive');
                    }
                  },
                  itemBuilder: (context) => [
                    if (p.active && !p.deleted && !p.archivedFromLists) ...[
                      const PopupMenuItem<String>(
                        value: 'edit',
                        child: Text('Chi tiết / sửa sản phẩm'),
                      ),
                      const PopupMenuItem<String>(
                        value: 'barcode',
                        child: Text('Mã vạch / in'),
                      ),
                      const PopupMenuItem<String>(
                        value: 'archive',
                        child: Text('Ngừng kinh doanh'),
                      ),
                    ] else if (p.deleted) ...[
                      if (shop.actor?.canAdmin == true)
                        const PopupMenuItem<String>(
                          value: 'restore-deleted',
                          child: Text('Khôi phục xóa nhầm'),
                        ),
                    ] else if (p.archivedFromLists) ...[
                      const PopupMenuItem<String>(
                        value: 'restore-hidden',
                        child: Text('Hiện lại'),
                      ),
                    ] else ...[
                      const PopupMenuItem<String>(
                        value: 'restore-inactive',
                        child: Text('Kinh doanh lại'),
                      ),
                    ],
                  ],
                ),
'@
        Already = 'mobile-catalog-options-'
    },
    @{
        Relative = 'lib/ui/invoices.dart'
        Pattern = @'
Text\(\s*'Đã trả\s+\$\{money\(ShopData\.collected\(invoice\)\)\}'\s*,\s*style:\s*const\s+TextStyle\(fontSize:\s*12\)\s*,?\s*\),
'@
        Replacement = @'
Text(
                            'Đã trả ${money(ShopData.collected(invoice))}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          Row(
                            children: [
                              const Text(
                                'Còn nợ: ',
                                style: TextStyle(fontSize: 12),
                              ),
                              Text(
                                money(
                                  invoice['status'] == 'Đã trả hàng'
                                      ? 0
                                      : (invoice['total'] as int) -
                                          ShopData.collected(invoice),
                                ),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF9D2B39),
                                ),
                              ),
                            ],
                          ),
'@
        Already = "'Còn nợ: '"
    },
    @{
        Relative = 'test/product_notes_test.dart'
        Pattern = @'
await tester\.tap\(find\.byIcon\(Icons\.add_circle\)\.first\);
'@
        Replacement = @'
if (width < 600) {
          // Mobile UI uses a compact action keyed by product ID.
          await tester.tap(
            find.byKey(ValueKey('mobile-add-to-cart-${p.id}')),
          );
        } else {
          await tester.tap(find.byIcon(Icons.add_circle).first);
        }
'@
        Already = "mobile-add-to-cart-" 
    }
)
$updates = @()
foreach ($e in $edits) {
    $relative = $e.Relative.Replace('/', [IO.Path]::DirectorySeparatorChar)
    $file = Join-Path $project $relative
    if (!(Test-Path -LiteralPath $file -PathType Leaf)) {
        throw "Khong tim thay file: $relative"
    }
    $content = [IO.File]::ReadAllText($file, [Text.Encoding]::UTF8)
    $matches = [regex]::Matches($content, $e.Pattern, [Text.RegularExpressions.RegexOptions]::Singleline)
    if ($matches.Count -eq 0 -and $content.Contains($e.Already)) {
        Write-Host "Da sua truoc do: $relative" -ForegroundColor DarkGreen
        continue
    }
    if ($matches.Count -ne 1) {
        throw "Khong the sua an toan: $relative (so doan trung: $($matches.Count)). Dung lai; chua ghi de."
    }
    $m = $matches[0]
    $updated = $content.Remove($m.Index, $m.Length).Insert($m.Index, $e.Replacement.TrimEnd())
    $updates += [PSCustomObject]@{Relative=$relative;File=$file;Content=$updated;Original=$content}
}
if ($updates.Count -eq 0) {
    Write-Host 'Tat ca thay doi da co san. Khong ghi de file.' -ForegroundColor Green
    exit 0
}
$backup = Join-Path (Join-Path $project '.vlxd_patch_backups') ('Mobile_Fix5_' + (Get-Date -Format 'yyyyMMdd_HHmmss_fff'))
foreach ($u in $updates) {
    $dest = Join-Path $backup $u.Relative
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
    Copy-Item -LiteralPath $u.File -Destination $dest
}
try {
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    foreach ($u in $updates) {
        [IO.File]::WriteAllText($u.File, $u.Content, $utf8NoBom)
        Write-Host "DA SUA: $($u.Relative)" -ForegroundColor Green
    }
} catch {
    foreach ($u in $updates) {
        $original = Join-Path $backup $u.Relative
        if (Test-Path -LiteralPath $original) {
            Copy-Item -LiteralPath $original -Destination $u.File -Force
        }
    }
    throw "Ghi file loi, da thu khoi phuc ban goc: $_"
}
Write-Host 'HOAN TAT BAN VA 5 LOI. CHUA CHAY FLUTTER TEST.' -ForegroundColor Green
Write-Host "BACKUP: $backup"
Write-Host 'TIEP THEO: dart format lib/ui/sales.dart lib/ui/mobile_products.dart lib/ui/invoices.dart test/product_notes_test.dart'
Write-Host 'SAU DO: flutter analyze --no-pub; flutter test --no-pub'
