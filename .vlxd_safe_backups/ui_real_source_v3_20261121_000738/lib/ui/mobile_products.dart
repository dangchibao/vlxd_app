part of 'app.dart';

/// Small-screen catalogue. Reuses the existing product form, barcode,
/// archive/restore and inventory flows; it never creates a new store of data.
class VlxdMobileProductsView extends StatelessWidget {
  const VlxdMobileProductsView({super.key});

  void _filters(BuildContext context, ShopController shop) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: .75,
        child: StatefulBuilder(
          builder: (context, updateSheet) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Lọc hàng hóa',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng bộ lọc',
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Trạng thái',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 7,
                runSpacing: 6,
                children:
                    ['Đang bán', 'Ngừng bán', 'Đã ẩn', 'Xóa nhầm', 'Tất cả']
                        .map(
                          (status) => ChoiceChip(
                            label: Text(status),
                            selected: shop.catalogStatus == status,
                            onSelected: (_) {
                              shop.catalogStatus = status;
                              shop.update();
                              updateSheet(() {});
                            },
                          ),
                        )
                        .toList(),
              ),
              const SizedBox(height: 16),
              const Text(
                'Danh mục gợi ý',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 7,
                runSpacing: 6,
                children: shop.catalogCategories
                    .map(
                      (category) => ChoiceChip(
                        label: Text(category),
                        selected: shop.catalogCategory == category,
                        onSelected: (_) {
                          shop.catalogCategory = category;
                          shop.group = 'Tất cả';
                          shop.update();
                          updateSheet(() {});
                        },
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              const Text(
                'Quy cách / kích thước',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 7,
                runSpacing: 6,
                children: shop.catalogSpecifications
                    .map(
                      (spec) => ChoiceChip(
                        label: Text(spec),
                        selected: shop.group == spec,
                        onSelected: (_) {
                          shop.group = spec;
                          shop.update();
                          updateSheet(() {});
                        },
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: const Text('Xem sản phẩm'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, Product p, ShopController shop) {
    return Card(
      key: ValueKey('mobile-catalog-card-${p.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 74, height: 84, child: ProductPicture(p)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${p.code} • ${p.size} • ${p.supplier}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF657993),
                        ),
                      ),
                      if (p.deleted)
                        const Text(
                          'Đã xóa mềm',
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        )
                      else if (p.archivedFromLists)
                        const Text(
                          'Đang ẩn khỏi danh sách',
                          style: TextStyle(fontSize: 12),
                        )
                      else if (!p.active)
                        const Text(
                          'Ngừng kinh doanh',
                          style: TextStyle(fontSize: 12),
                        ),
                      const SizedBox(height: 3),
                      Text(
                        '${money(p.price)} / ${p.unit}',
                        style: const TextStyle(
                          color: blue,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Tồn ${area(p.available)} ${p.unit}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF147B55),
                        ),
                      ),
                      if (latestRecordedLotCost(p) != null)
                        Text(
                          'Vốn lô gần nhất ${money(latestRecordedLotCost(p)!)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF805500),
                          ),
                        ),
                      if (p.note.isNotEmpty)
                        Text(
                          'Lưu ý: ${p.note}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF657993),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (p.active && !p.deleted && !p.archivedFromLists)
                  TextButton.icon(
                    onPressed: shop.busy
                        ? null
                        : () => receiveStock(context, p),
                    icon: const Icon(Icons.add_box_outlined, size: 17),
                    label: const Text('Nhập kho'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                  ),
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
                      // mobile-barcode-print-teal-v2: preserve action value = barcode.
                      const PopupMenuItem<String>(
                        value: 'barcode',
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.print_outlined,
                              color: Color(0xFF0F766E),
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Mã vạch & In',
                              style: TextStyle(
                                color: Color(0xFF0F766E),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
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
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = Get.find<ShopController>();
    final products = c.catalogProducts;
    return Column(
      children: [
        Container(
          color: const Color(0xFFF4F7FC),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 5),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('mobile-catalog-search'),
                      onChanged: (query) {
                        c.query = query;
                        c.update();
                      },
                      decoration: const InputDecoration(
                        hintText: 'Tên, mã, nhà cung cấp...',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    key: const ValueKey('mobile-catalog-create'),
                    tooltip: 'Thêm sản phẩm',
                    onPressed: c.busy ? null : () => editProduct(context),
                    icon: const Icon(Icons.add),
                  ),
                  const SizedBox(width: 4),
                  IconButton.outlined(
                    tooltip: 'Lọc danh mục, quy cách, trạng thái',
                    onPressed: () => _filters(context, c),
                    icon: const Icon(Icons.tune),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${products.length} sản phẩm',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF657993),
                      ),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      c.catalogCategory == 'Tất cả'
                          ? c.catalogStatus
                          : '${c.catalogCategory} • ${c.catalogStatus}',
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: blue),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: products.isEmpty
              ? const EmptyState(
                  'Không tìm thấy hàng',
                  'Thử tên khác hoặc đổi bộ lọc.',
                  Icons.search_off,
                )
              : ListView.builder(
                  key: const ValueKey('mobile-catalog-product-list'),
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  itemCount: products.length,
                  itemBuilder: (context, index) =>
                      _tile(context, products[index], c),
                ),
        ),
      ],
    );
  }
}
