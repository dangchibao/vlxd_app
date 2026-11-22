part of 'app.dart';

/// Compact sales screen for Android and iPhone PWA/Web.
/// This is intentionally a presentation-only layer. All checkout, cart,
/// inventory, Outbox and authorization rules stay in existing controllers.
class VlxdMobileSalesView extends StatefulWidget {
  const VlxdMobileSalesView({super.key});

  @override
  State<VlxdMobileSalesView> createState() => _VlxdMobileSalesViewState();
}

class _VlxdMobileSalesViewState extends State<VlxdMobileSalesView> {
  String _category = 'Tất cả';
  final Map<String, int> _quantities = {};

  int _quantity(Product p) => _quantities[p.id] ?? 1;

  void _setQuantity(Product p, int delta) {
    setState(() {
      _quantities[p.id] = (_quantity(p) + delta).clamp(1, 9999);
    });
  }

  Future<void> _openCart(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.sizeOf(sheetContext).height * .90,
        child: GetBuilder<ShopController>(
          builder: (_) => const CartPanel(compact: true),
        ),
      ),
    );
  }

  Widget _action({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
    required Key key,
    bool accent = false,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Tooltip(
          message: label,
          child: Material(
            color: accent ? const Color(0xFFE6F2FF) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              key: key,
              onTap: onTap,
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 46,
                child: Center(
                  child: Icon(
                    icon,
                    size: 23,
                    color: onTap == null ? const Color(0xFF9BADBF) : blue,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _quickActions(BuildContext context, ShopController c) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
    child: Row(
      key: const ValueKey('mobile-sales-actions'),
      children: [
        _action(
          key: const ValueKey('mobile-create-product'),
          label: 'Tạo sản phẩm',
          icon: Icons.add_circle_outline,
          accent: true,
          onTap: c.busy ? null : () => editProduct(context),
        ),
        _action(
          key: const ValueKey('restore-local-cart-draft'),
          label: 'Khôi phục giỏ nháp',
          icon: Icons.restore,
          onTap: !c.isLive || c.busy || c.cart.isNotEmpty || c.cartEditingLocked
              ? null
              : () => attempt(() async {
                  if (!await c.restoreLocalDraft()) {
                    throw StateError('Không có giỏ nháp phù hợp để khôi phục.');
                  }
                }),
        ),
        _action(
          key: const ValueKey('mobile-scan-code'),
          label: 'Quét / nhập mã',
          icon: Icons.qr_code_scanner,
          onTap: () => scanProduct(context),
        ),
        _action(
          key: const ValueKey('mobile-sold-invoices'),
          label: 'Hóa đơn đã bán',
          icon: Icons.description_outlined,
          onTap: () => c.navigate(9),
        ),
        _action(
          key: const ValueKey('open-offline-orders'),
          label: 'Đơn chờ đồng bộ',
          icon: Icons.cloud_off_outlined,
          onTap: c.isLive
              ? () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const OfflineOrdersPage(),
                  ),
                )
              : null,
        ),
        _action(
          key: const ValueKey('mobile-order-history'),
          label: 'Lịch sử đơn hàng',
          icon: Icons.receipt_long_outlined,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const OrdersPage()),
          ),
        ),
      ],
    ),
  );

  Widget _productTile(BuildContext context, Product p) {
    final qty = _quantity(p);
    final stockColor = p.available <= 0
        ? const Color(0xFFB42333)
        : const Color(0xFF147B55);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        key: ValueKey('mobile-sale-card-${p.id}'),
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFDCE5F0)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () =>
              confirmProduct(context, p, suggested: qty * p.quantityStep),
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 84, height: 116, child: ProductPicture(p)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              p.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: ink,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 28,
                            height: 26,
                            child: PopupMenuButton<String>(
                              key: ValueKey('mobile-product-options-${p.id}'),
                              tooltip: 'Sửa hoặc ngừng bán ${p.name}',
                              padding: EdgeInsets.zero,
                              icon: const Icon(Icons.more_vert, size: 18),
                              onSelected: (action) {
                                if (action == 'edit') {
                                  editProduct(context, original: p);
                                } else if (action == 'archive') {
                                  archiveProductDialog(context, p);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Sửa sản phẩm'),
                                ),
                                PopupMenuItem(
                                  value: 'archive',
                                  child: Text('Ngừng kinh doanh'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${p.code} • ${p.size}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF657993),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Còn ${area(p.available)} ${p.unit}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: stockColor,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${money(p.price)}/${p.unit}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: blue,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          _quantityButton(
                            key: ValueKey('mobile-qty-minus-${p.id}'),
                            icon: Icons.remove,
                            label: 'Giảm số lượng ${p.name}',
                            onPressed: qty <= 1
                                ? null
                                : () => _setQuantity(p, -1),
                          ),
                          SizedBox(
                            width: 25,
                            child: Text(
                              '$qty',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          _quantityButton(
                            key: ValueKey('mobile-qty-plus-${p.id}'),
                            icon: Icons.add,
                            label: 'Tăng số lượng ${p.name}',
                            onPressed: () => _setQuantity(p, 1),
                          ),
                          const Spacer(),
                          SizedBox(
                            height: 34,
                            child: FilledButton(
                              key: ValueKey('mobile-add-to-cart-${p.id}'),
                              onPressed: () => confirmProduct(
                                context,
                                p,
                                suggested: qty * p.quantityStep,
                              ),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                minimumSize: const Size(62, 34),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text('Thêm'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _quantityButton({
    required Key key,
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) => SizedBox(
    width: 33,
    height: 34,
    child: IconButton.outlined(
      key: key,
      tooltip: label,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      iconSize: 17,
      visualDensity: VisualDensity.compact,
      icon: Icon(icon),
    ),
  );

  Widget _cartBar(BuildContext context, ShopController c) => Material(
    elevation: 5,
    color: Colors.white,
    child: InkWell(
      key: const ValueKey('mobile-sales-open-cart'),
      onTap: () => _openCart(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.shopping_cart_outlined, color: blue, size: 27),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${c.cart.length} mặt hàng',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    money(c.subtotal),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: blue,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: () => _openCart(context),
              icon: const Icon(Icons.shopping_bag_outlined, size: 18),
              label: const Text('Xem giỏ'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(110, 42),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final c = Get.find<ShopController>();
    // Discovery only suggests groups. Never persist a guessed category.
    final availableCategories =
        c.data.products
            .where((p) => p.active && !p.deleted && !p.archivedFromLists)
            .map(ProductDiscovery.suggestedCategory)
            .toSet()
            .toList()
          ..sort();
    final categories = <String>['Tất cả', ...availableCategories];
    final selectedCategory = categories.contains(_category)
        ? _category
        : 'Tất cả';
    final visible = c.visibleProducts
        .where(
          (p) =>
              selectedCategory == 'Tất cả' ||
              ProductDiscovery.suggestedCategory(p) == selectedCategory,
        )
        .toList();

    return Column(
      children: [
        Container(
          color: const Color(0xFFF4F7FC),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 3),
          child: TextField(
            key: const ValueKey('mobile-sales-search'),
            onChanged: (value) {
              c.query = value;
              c.update();
            },
            decoration: InputDecoration(
              hintText: 'Tìm tên hoặc mã sản phẩm...',
              hintStyle: const TextStyle(fontSize: 14),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                tooltip: 'Quét mã sản phẩm',
                onPressed: () => scanProduct(context),
                icon: const Icon(Icons.document_scanner_outlined, size: 22),
              ),
            ),
          ),
        ),
        _quickActions(context, c),
        SizedBox(
          height: 43,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 7),
            itemBuilder: (context, i) {
              final category = categories[i];
              return ChoiceChip(
                label: Text(category, style: const TextStyle(fontSize: 12)),
                selected: selectedCategory == category,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => setState(() => _category = category),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 3, 12, 6),
          child: Row(
            children: [
              const Text(
                'Hàng hóa',
                style: TextStyle(fontWeight: FontWeight.w800, color: ink),
              ),
              const Spacer(),
              Text(
                '${visible.length} sản phẩm',
                style: const TextStyle(color: Color(0xFF657993), fontSize: 12),
              ),
            ],
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? const EmptyState(
                  'Không có sản phẩm phù hợp',
                  'Đổi từ khóa hoặc chọn nhóm Tất cả.',
                  Icons.search_off,
                )
              : ListView.builder(
                  key: const ValueKey('mobile-sales-product-list'),
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  itemCount: visible.length,
                  itemBuilder: (context, i) =>
                      _productTile(context, visible[i]),
                ),
        ),
        _cartBar(context, c),
      ],
    );
  }
}
