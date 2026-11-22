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

  // vlxd-mobile-details-real-v3: show secondary facts on demand, no data lost.
  Future<void> _showDetails(
    BuildContext context,
    Product p,
  ) => safeDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(p.name),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${p.code} • ${p.size} • ${p.supplier}'),
            const SizedBox(height: 10),
            Text('Giá bán: ${money(p.price)} / ${p.unit}'),
            Text('Tồn khả dụng: ${area(p.available)} ${p.unit}'),
            if (p.hasPackConversion) Text('Quy đổi: ${conversionHint(p)}'),
            if (latestRecordedLotCost(p) != null)
              Text(
                'Vốn lô gần nhất: ${money(latestRecordedLotCost(p)!)} / ${p.unit}',
              ),
            if (p.note.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Ghi chú: ${p.note}'),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Đóng'),
        ),
      ],
    ),
  );

  Widget _tile(BuildContext context, Product p, ShopController shop) {
    return Card(
      key: ValueKey('mobile-catalog-card-${p.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 44, height: 50, child: ProductPicture(p)),
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
                        '${productAvailability(p)} • Khả dụng ${area(p.available)} ${p.unit}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF147B55),
                        ),
                      ),
                      // Giá vốn và ghi chú xem trong menu Chi tiết.
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                if (p.active && !p.deleted && !p.archivedFromLists)
                  OutlinedButton.icon(
                    onPressed: shop.busy
                        ? null
                        : () => receiveStock(context, p),
                    icon: const Icon(Icons.add_box_outlined, size: 19),
                    label: const Text('Nhập kho'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0759BB),
                      backgroundColor: const Color(0xFFF0F7FF),
                      side: const BorderSide(color: Color(0xFFC0D9F8)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                const Spacer(),
                IconButton(
                  key: ValueKey('mobile-catalog-details-${p.id}'),
                  tooltip: 'Xem chi tiết sản phẩm',
                  onPressed: () => _showDetails(context, p),
                  icon: const Icon(Icons.info_outline, color: Color(0xFF344760)),
                ),
                PopupMenuButton<String>(
                  key: ValueKey('mobile-catalog-options-${p.id}'),
                  tooltip: 'Thao tác với ${p.name}',
                  icon: const Icon(Icons.more_vert, color: Color(0xFF344760)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 196,
                    maxWidth: 232,
                  ),
                  onSelected: (action) {
                    if (action == 'edit') {
                      editProduct(context, original: p);
                    } else if (action == 'details') {
                      _showDetails(context, p);
                    } else if (action == 'correct-unit') {
                      correctReceivedUnitDialog(context, p);
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
                    const PopupMenuItem<String>(
                      value: 'details',
                      height: 46,
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Color(0xFF344760),
                            size: 21,
                          ),
                          SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              'Chi tiết',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (p.active && !p.deleted && !p.archivedFromLists) ...[
                      if (shop.actor?.canAdmin == true && p.lots.isNotEmpty)
                        const PopupMenuItem<String>(
                          value: 'correct-unit',
                          height: 46,
                          child: Row(
                            children: [
                              Icon(
                                Icons.fact_check_outlined,
                                color: Color(0xFFD97706),
                                size: 21,
                              ),
                              SizedBox(width: 12),
                              Flexible(
                                child: Text(
                                  'Đính chính',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false,
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const PopupMenuItem<String>(
                        value: 'edit',
                        height: 46,
                        child: Row(
                          children: [
                            Icon(
                              Icons.edit_outlined,
                              color: Color(0xFF1976D2),
                              size: 21,
                            ),
                            SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                'Sửa',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // mobile-barcode-print-teal-v2: preserve action value = barcode.
                      const PopupMenuItem<String>(
                        value: 'barcode',
                        height: 46,
                        child: Row(
                          children: [
                            Icon(
                              Icons.print_outlined,
                              color: Color(0xFF0F766E),
                              size: 21,
                            ),
                            SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                'Mã vạch & In',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'archive',
                        height: 46,
                        child: Row(
                          children: [
                            Icon(
                              Icons.block_outlined,
                              color: Color(0xFFDC2626),
                              size: 21,
                            ),
                            SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                'Ngừng bán',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (p.deleted) ...[
                      if (shop.actor?.canAdmin == true)
                        const PopupMenuItem<String>(
                          value: 'restore-deleted',
                          height: 46,
                          child: Row(
                            children: [
                              Icon(
                                Icons.restore_outlined,
                                color: Color(0xFF147B55),
                                size: 21,
                              ),
                              SizedBox(width: 12),
                              Flexible(
                                child: Text(
                                  'Khôi phục',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false,
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ] else if (p.archivedFromLists) ...[
                      const PopupMenuItem<String>(
                        value: 'restore-hidden',
                        height: 46,
                        child: Row(
                          children: [
                            Icon(
                              Icons.visibility_outlined,
                              color: Color(0xFF147B55),
                              size: 21,
                            ),
                            SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                'Hiện lại',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      const PopupMenuItem<String>(
                        value: 'restore-inactive',
                        height: 46,
                        child: Row(
                          children: [
                            Icon(
                              Icons.replay_outlined,
                              color: Color(0xFF147B55),
                              size: 21,
                            ),
                            SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                'Bán lại',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
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
                  IconButton(
                    key: const ValueKey('mobile-catalog-create'),
                    tooltip: 'Thêm sản phẩm',
                    onPressed: c.busy ? null : () => editProduct(context),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFE7F1FF),
                      foregroundColor: const Color(0xFF0759BB),
                      disabledBackgroundColor: const Color(0xFFF1F5F9),
                      side: const BorderSide(color: Color(0xFFBCD8FC)),
                    ),
                    icon: const Icon(Icons.add, size: 25),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Lọc danh mục, quy cách, trạng thái',
                    onPressed: () => _filters(context, c),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFF0F3F8),
                      foregroundColor: const Color(0xFF344760),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    icon: const Icon(Icons.tune, size: 23),
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
