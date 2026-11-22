part of 'app.dart';

class SalesPage extends StatelessWidget {
  const SalesPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = Get.find<ShopController>();
    return LayoutBuilder(
      builder: (context, box) {
        // Mobile-first sales layout; desktop and tablet keep their old widgets.
        if (box.maxWidth < 600) {
          return VlxdMobileSalesView();
        }
        final catalogue = Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Tìm tên hoặc mã sản phẩm',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (v) {
                      c.query = v;
                      c.update();
                    },
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: c.busy ? null : () => editProduct(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Tạo sản phẩm'),
                      ),
                      if (c.isLive)
                        OutlinedButton.icon(
                          key: const ValueKey('restore-local-cart-draft'),
                          onPressed:
                              c.busy || c.cart.isNotEmpty || c.cartEditingLocked
                              ? null
                              : () => attempt(() async {
                                  final restored = await c.restoreLocalDraft();
                                  if (!restored) {
                                    throw StateError(
                                      'Không có giỏ nháp phù hợp để khôi phục.',
                                    );
                                  }
                                }),
                          icon: const Icon(Icons.restore),
                          label: const Text('Khôi phục giỏ nháp'),
                        ),
                      OutlinedButton.icon(
                        onPressed: () => scanProduct(context),
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Quét / nhập mã'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => c.navigate(9),
                        icon: const Icon(Icons.description_outlined),
                        label: const Text('Hóa đơn đã bán'),
                      ),
                      if (c.isLive)
                        OutlinedButton.icon(
                          key: const ValueKey('open-offline-orders'),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => const OfflineOrdersPage(),
                            ),
                          ),
                          icon: const Icon(Icons.cloud_off_outlined),
                          label: const Text('Đơn chờ đồng bộ'),
                        ),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const OrdersPage(),
                          ),
                        ),
                        icon: const Icon(Icons.receipt_long_outlined),
                        label: const Text('Lịch sử đơn hàng'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, grid) => VlxdPagedGrid<Product>(
                  key: ValueKey('sales-${c.query}'),
                  items: c.visibleProducts,
                  pageSize: 12,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    // Compact sales cards: prioritize selecting products,
                    // while keeping management actions in a separate menu.
                    crossAxisCount: grid.maxWidth >= 1100
                        ? 4
                        : grid.maxWidth >= 800
                        ? 3
                        : grid.maxWidth >= 510
                        ? 2
                        : 1,
                    mainAxisExtent:
                        VlxdDisplayPreferences.instance.comfortableDensity
                        ? 260
                        : 230,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemBuilder: (context, p) {
                    return panel(
                      InkWell(
                        onTap: () => confirmProduct(context, p),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: 88,
                              width: double.infinity,
                              child: ProductPicture(p),
                            ),
                            const SizedBox(height: 5),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    '${p.name} ${p.size}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 36,
                                  height: 36,
                                  child: PopupMenuButton<String>(
                                    key: ValueKey('sale-product-options-${p.id}'),
                                    tooltip: 'Quản lý sản phẩm',
                                    icon: const Icon(Icons.more_vert, size: 19),
                                    padding: EdgeInsets.zero,
                                    enabled: !c.busy,
                                    onSelected: (action) {
                                      if (action == 'edit') {
                                        editProduct(context, original: p);
                                      }
                                      if (action == 'archive') {
                                        archiveProductDialog(context, p);
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      PopupMenuItem(
                                        value: 'edit',
                                        key: ValueKey('edit-sale-product-${p.id}'),
                                        child: const Text('Sửa sản phẩm'),
                                      ),
                                      PopupMenuItem(
                                        value: 'archive',
                                        key: ValueKey('delete-sale-product-${p.id}'),
                                        child: const Text('Ngừng kinh doanh'),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${money(p.price)} / ${p.unit}',
                              style: const TextStyle(
                                color: blue,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: hint(
                                    '${productAvailability(p)} • ${area(p.available)} ${p.unit}',
                                  ),
                                ),
                                const Icon(Icons.add_circle, color: blue),
                              ],
                            ),
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.all(9),
                    );
                  },
                ),
              ),
            ),
          ],
        );
        if (box.maxWidth >= 1050) {
          return Row(
            children: [
              Expanded(child: catalogue),
              const SizedBox(width: 365, child: CartPanel(compact: false)),
            ],
          );
        }
        return Column(
          children: [
            Expanded(child: catalogue),
            SafeArea(
              top: false,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${c.cart.length} mặt hàng\n${money(c.subtotal)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        builder: (ctx) => SizedBox(
                          height: MediaQuery.sizeOf(ctx).height * .9,
                          child: GetBuilder<ShopController>(
                            builder: (_) => const CartPanel(compact: true),
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.shopping_bag_outlined),
                      label: const Text('Xem giỏ hàng'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// Ngăn thêm sản phẩm vào request đã lưu Outbox.
// Đây là kiểm tra phía giao diện; quy tắc cuối cùng vẫn phải được giữ
// tại controller khi tích hợp đường bán offline thật.
Future<void> _ensureCartRequestIsEditable(ShopController c) async {
  if (!c.isLive) return;
  if (!Get.isRegistered<OutboxRepository>()) {
    throw StateError('Chưa kết nối Outbox của cửa hàng.');
  }
  final operation = await Get.find<OutboxRepository>().getById(c.requestId);
  if (operation != null) {
    throw StateError(
      'Đơn này đã có trong Outbox (${operation.status}). '
      'Không thể thêm sản phẩm vào cùng mã giao dịch.',
    );
  }
}

Future<void> confirmProduct(
  BuildContext context,
  Product p, {
  int? suggested,
}) async {
  final c = Get.find<ShopController>();
  final qty = TextEditingController(
    text: suggested == null
        ? '1'
        : NumberFormat('0.####', 'vi').format(suggested / p.quantityStep),
  );
  final note = TextEditingController(text: p.note);
  var unit = p.packUnit;
  final existing = c.cart.any((l) => l.productId == p.id);
  await safeDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text(
          existing ? 'Cộng thêm vào giỏ hàng?' : 'Thêm sản phẩm vào giỏ?',
        ),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 140,
                  width: double.infinity,
                  child: ProductPicture(p),
                ),
                const SizedBox(height: 14),
                titleText('${p.name} ${p.size}', size: 18),
                hint('${p.code} • ${money(p.price)} / ${p.unit}'),
                hint(
                  'Còn ${area(p.available)} ${p.unit}${p.hasPackConversion ? ' • ${conversionHint(p)}' : ''}',
                ),
                const SizedBox(height: 16),
                if (p.hasPackConversion)
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: p.secondaryUnit,
                        label: Text('Theo ${p.secondaryUnit}'),
                      ),
                      ButtonSegment(
                        value: p.unit,
                        label: Text('Theo ${p.unit}'),
                      ),
                    ],
                    selected: {unit},
                    onSelectionChanged: (v) {
                      final next = v.first;
                      if (next == unit) return;
                      final n = decimal(qty.text);
                      if (n.isFinite && n > 0) {
                        final oldFactor = p.factorForUnit(unit);
                        final newFactor = p.factorForUnit(next);
                        // Preserve the physical quantity when switching units.
                        qty.text = NumberFormat(
                          '0.##########',
                          'vi',
                        ).format(n * oldFactor / newFactor);
                      }
                      set(() => unit = next);
                    },
                  ),
                const SizedBox(height: 16),
                field(qty, 'Số lượng ($unit)', number: true),
                // Listen to the existing editor; never rewrite its value or
                // wait for submit/focus changes to show the derived amounts.
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: qty,
                  builder: (context, value, _) {
                    final n = decimal(value.text);
                    final scaled = n * (p.factorForUnit(unit));
                    if (!scaled.isFinite ||
                        scaled <= 0 ||
                        scaled.round() <= 0) {
                      return const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text('Nhập số lượng hợp lệ để tính tiền.'),
                      );
                    }
                    final units = scaled.round();
                    final amount = lineMoney(units, p.price);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Số lượng quy đổi: ${area(units)} ${p.unit}'),
                          Text(
                            'Thành tiền: ${money(amount)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: blue,
                            ),
                          ),
                          GetBuilder<ShopController>(
                            builder: (shop) => Text(
                              'Tổng tiền hàng dự kiến: ${money(shop.subtotal + amount)}',
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                TextField(
                  controller: note,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    labelText: 'Lưu ý cho lần bán này (tùy chọn)',
                    hintText: 'Ghi số tấm, kích thước, cách tự ước tính…',
                    helperText: 'Bạn tự tính và nhập số lượng ở ô phía trên. Lưu ý không làm đổi số tiền.',
                    helperMaxLines: 3,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => attempt(() async {
              final n = decimal(qty.text);
              if (!n.isFinite || n <= 0) {
                throw ArgumentError('Nhập số lượng dương.');
              }
              // Cũng kiểm tra tại điểm ghi, không chỉ khóa nút trong giỏ.
              await _ensureCartRequestIsEditable(c);
              c.addCart(
                p,
                (n * (p.factorForUnit(unit))).round(),
                note: note.text,
                saleUnit: unit,
                saleQuantity: qty.text,
              );
              if (ctx.mounted) Navigator.pop(ctx);
            }),
            child: Text(existing ? 'Xác nhận cộng thêm' : 'Thêm vào giỏ hàng'),
          ),
        ],
      ),
    ),
  );
  qty.dispose();
  note.dispose();
}

Future<void> scanProduct(BuildContext context) async {
  final code = TextEditingController();
  final result = await safeDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Quét mã hoặc nhập mã'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: code,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Mã vạch sản phẩm'),
              onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
            ),
            const SizedBox(height: 10),
            hint(
              'Máy quét USB nhập như bàn phím. Đặt con trỏ vào ô trên và quét.',
            ),
            if (kIsWeb ||
                [
                  TargetPlatform.android,
                  TargetPlatform.iOS,
                  TargetPlatform.macOS,
                ].contains(defaultTargetPlatform))
              TextButton.icon(
                onPressed: () async {
                  final scanned = await Navigator.push<String>(
                    ctx,
                    MaterialPageRoute(builder: (_) => const CameraScanner()),
                  );
                  if (scanned != null && ctx.mounted) {
                    Navigator.pop(ctx, scanned);
                  }
                },
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Quét bằng camera'),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, code.text.trim()),
          child: const Text('Tìm sản phẩm'),
        ),
      ],
    ),
  );
  code.dispose();
  if (result == null || !context.mounted) return;
  final matches = Get.find<ShopController>().data.products.where(
    (p) => p.active && p.code.toLowerCase() == result.toLowerCase(),
  );
  if (matches.isEmpty) {
    await attempt(
      () async => throw StateError(
        'Không tìm thấy mã "$result". Hãy quét lại hoặc tìm thủ công.',
      ),
    );
    return;
  }
  await confirmProduct(context, matches.first);
}

class CameraScanner extends StatefulWidget {
  const CameraScanner({super.key});
  @override
  State<CameraScanner> createState() => _CameraScannerState();
}

class _CameraScannerState extends State<CameraScanner> {
  final controller = MobileScannerController();
  bool returned = false;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Đưa mã vạch vào camera')),
    body: MobileScanner(
      controller: controller,
      errorBuilder: (ctx, error) => const EmptyState(
        'Không mở được camera',
        'Cho phép camera hoặc quay lại nhập mã bằng tay. Trên web cần HTTPS hoặc localhost.',
        Icons.no_photography_outlined,
      ),
      onDetect: (capture) {
        final value = capture.barcodes.firstOrNull?.rawValue;
        if (!returned && value != null) {
          returned = true;
          Navigator.pop(context, value);
        }
      },
    ),
  );
}

class CartPanel extends StatefulWidget {
  final bool compact;
  const CartPanel({required this.compact, super.key});
  @override
  State<CartPanel> createState() => _CartPanelState();
}

enum _PaymentMode { full, partial, debt }

class _CartPanelState extends State<CartPanel> {
  _PaymentMode paymentMode = _PaymentMode.full;
  final paid = TextEditingController(),
      shipping = TextEditingController(text: '0'),
      discountInput = TextEditingController(),
      reason = TextEditingController();
  String customerId = '';
  bool hold = false;
  bool showDiscount = false;
  bool restoringForm = false;
  int? _seenDraftFormRevision;

  // Cache one Outbox check per requestId, rather than launching a new
  // database read whenever the cart widget rebuilds.
  String? _checkedRequestId;
  Future<String?>? _outboxStatusFuture;

  Future<String?> _readOutboxStatus(String id) async {
    if (!Get.isRegistered<OutboxRepository>()) {
      throw StateError('Chưa kết nối Outbox của cửa hàng.');
    }
    final operation = await Get.find<OutboxRepository>().getById(id);
    return operation?.status;
  }

  Future<String?> _statusFor(ShopController c) {
    if (_checkedRequestId != c.requestId || _outboxStatusFuture == null) {
      _checkedRequestId = c.requestId;
      _outboxStatusFuture = _readOutboxStatus(c.requestId);
    }
    return _outboxStatusFuture!;
  }

  void _refreshOutboxStatus(ShopController c) {
    setState(() {
      _checkedRequestId = c.requestId;
      _outboxStatusFuture = _readOutboxStatus(c.requestId);
    });
  }

  @override
  void initState() {
    super.initState();
    shipping.addListener(refresh);
    paid.addListener(refresh);
    discountInput.addListener(refresh);
    discountInput.addListener(_saveFormDraft);
    paid.addListener(_saveFormDraft);
    shipping.addListener(_saveFormDraft);
    reason.addListener(_saveFormDraft);
  }

  void _saveFormDraft() {
    if (restoringForm) return;
    if (!Get.isRegistered<ShopController>()) return;
    final shop = Get.find<ShopController>();
    if (!shop.isLive || shop.cart.isEmpty || shop.cartEditingLocked) return;
    shop.updateDraftForm(
      customerId: customerId,
      shippingText: shipping.text,
      paidText: paid.text,
      discountText: showDiscount ? discountInput.text : '',
      hold: hold,
      negativeReason: reason.text,
    );
  }

  void refresh() {
    if (mounted && !restoringForm) setState(() {});
  }

  ({int ship, int discount, int total, int paid}) _saleAmounts(int subtotal) {
    final ship = shipping.text.trim().isEmpty ? 0 : whole(shipping.text);
    final discount = showDiscount && discountInput.text.trim().isNotEmpty
        ? whole(discountInput.text)
        : 0;
    if (ship < 0 || discount < 0 || discount > subtotal) {
      throw ArgumentError('Kiểm tra phí giao hàng và số tiền giảm giá.');
    }
    final total = subtotal - discount + ship;
    if (paymentMode == _PaymentMode.partial && paid.text.trim().isEmpty) {
      throw ArgumentError('Nhập số tiền thu hoặc chọn Thanh toán đủ / Ghi nợ.');
    }
    final received = switch (paymentMode) {
      _PaymentMode.full => total,
      _PaymentMode.debt => 0,
      _PaymentMode.partial => whole(paid.text),
    };
    if (received < 0 || received > total) {
      throw ArgumentError('Tiền đã thu phải từ 0 đến tổng thanh toán.');
    }
    if (paymentMode == _PaymentMode.partial &&
        (received == 0 || received == total)) {
      throw ArgumentError(
        'Thanh toán một phần phải lớn hơn 0 và nhỏ hơn tổng tiền. '
        'Chọn Thanh toán đủ hoặc Ghi nợ nếu phù hợp.',
      );
    }
    return (ship: ship, discount: discount, total: total, paid: received);
  }

  String _saleSummary(
    ({int ship, int discount, int total, int paid}) amounts,
  ) =>
      'Tổng ${money(amounts.total)} (gồm phí giao hàng ${money(amounts.ship)})\n'
      '${amounts.discount > 0 ? 'Giảm giá: ${money(amounts.discount)}\n' : ''}'
      'Thu ${money(amounts.paid)}\n'
      'Còn phải thu: ${money(amounts.total - amounts.paid)}';

  @override
  void dispose() {
    paid.removeListener(_saveFormDraft);
    shipping.removeListener(_saveFormDraft);
    reason.removeListener(_saveFormDraft);
    paid.dispose();
    shipping.dispose();
    discountInput.dispose();
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      GetBuilder<ShopController>(builder: (c) => _buildCart(context, c));

  Widget _buildCart(BuildContext context, ShopController c) {
    if (c.isLive && _seenDraftFormRevision != c.draftFormRevision) {
      // Phục hồi cả trường đang nhập sau khi controller khôi phục nháp.
      // Ghi trực tiếp vào controller text (không gọi setState trong build).
      _seenDraftFormRevision = c.draftFormRevision;
      customerId = c.draftCustomerId;
      hold = c.draftHold;
      restoringForm = true;
      try {
        shipping.text = c.draftShippingText;
        paid.text = c.draftPaidText;
        paymentMode = paid.text.trim().isEmpty
            ? _PaymentMode.full
            : whole(paid.text) == 0
            ? _PaymentMode.debt
            : _PaymentMode.partial;
        reason.text = c.draftNegativeReason;
        discountInput.text = c.draftDiscountText;
        showDiscount = discountInput.text.isNotEmpty;
      } finally {
        restoringForm = false;
      }
    }
    if (!c.isLive) return _buildCartBody(context, c, false);

    return FutureBuilder<String?>(
      future: _statusFor(c),
      builder: (context, snapshot) {
        // Khóa cả khi đang đọc và khi đọc thất bại (fail closed).
        final locked =
            snapshot.connectionState != ConnectionState.done ||
            snapshot.hasError ||
            snapshot.data != null;
        // Controller may have locked the request while the cached DB read
        // still says null. Never enable editing during that interval.
        return _buildCartBody(context, c, locked || c.cartEditingLocked);
      },
    );
  }

  Widget _buildCartBody(BuildContext context, ShopController c, bool locked) {
    final exceeds = c.cart.any(
      (l) => l.area > c.data.product(l.productId).available,
    );
    final shippingValue = shipping.text.trim().isEmpty
        ? 0
        : whole(shipping.text);
    final invalidShipping = shippingValue < 0;
    final ship = math.max(0, shippingValue);
    final enteredDiscount = showDiscount && discountInput.text.trim().isNotEmpty
        ? whole(discountInput.text)
        : 0;
    final invalidDiscount = enteredDiscount < 0 || enteredDiscount > c.subtotal;
    final total = c.subtotal + ship - (invalidDiscount ? 0 : enteredDiscount);
    final received = switch (paymentMode) {
      _PaymentMode.full => total,
      _PaymentMode.debt => 0,
      _PaymentMode.partial => paid.text.trim().isEmpty ? 0 : whole(paid.text),
    };
    final invalidReceived = received < 0 || received > total;
    final invalidPartial = paymentMode == _PaymentMode.partial &&
        (paid.text.trim().isEmpty || received <= 0 || received >= total);
    final needsCustomer = customerId.isEmpty &&
        (hold || (!invalidReceived && received < total));
    return Material(
      color: Colors.white,
      child: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Row(
            children: [
              Expanded(child: titleText('Đơn hàng mới', size: 20)),
              if (widget.compact)
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: ValueKey(customerId),
            initialValue: customerId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Khách hàng'),
            items: [
              const DropdownMenuItem(
                value: '',
                child: Text('Khách lẻ • thanh toán đủ'),
              ),
              ...c.data.customers
                  .where((p) => p['active'] != false || p['id'] == customerId)
                  .map(
                    (p) => DropdownMenuItem<String>(
                      value: p['id'],
                      child: Text(p['name'], overflow: TextOverflow.ellipsis),
                    ),
                  ),
            ],
            onChanged: locked
                ? null
                : (v) {
                    setState(() => customerId = v!);
                    _saveFormDraft();
                  },
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: c.busy || locked
                  ? null
                  : () async {
                      final id = await editCustomer(context);
                      if (id != null && mounted) {
                        setState(() => customerId = id);
                        _saveFormDraft();
                      }
                    },
              icon: const Icon(Icons.person_add_alt_1_outlined, size: 20),
              label: const Text('Thêm khách hàng mới'),
            ),
          ),
          if (c.cart.isEmpty)
            const EmptyState(
              'Giỏ hàng trống',
              'Chọn hoặc quét mã gạch để bắt đầu.',
              Icons.shopping_bag_outlined,
            ),
          ...c.cart.map((l) {
            final p = c.data.product(l.productId);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${p.name} ${p.size}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Bỏ khỏi giỏ',
                        onPressed: c.busy || locked
                            ? null
                            : () {
                                c.cart.remove(l);
                                c.update();
                              },
                        icon: const Icon(Icons.close, size: 18),
                      ),
                    ],
                  ),
                  hint(
                    p.isSecondaryUnit(
                          l.saleUnit.isEmpty ? p.packUnit : l.saleUnit,
                        )
                        ? '${NumberFormat('0.####', 'vi').format(l.area / p.ratio)} ${p.secondaryUnit} • ${area(l.area)} ${p.unit}'
                        : '${area(l.area)} ${p.unit}',
                  ),
                  if (l.note.isNotEmpty)
                    Text(
                      'Lưu ý: ${l.note}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF657993),
                      ),
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          money(lineMoney(l.area, p.price)),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: blue,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip:
                            'Bớt một ${l.saleUnit.isEmpty ? p.packUnit : l.saleUnit}',
                        onPressed: c.busy || locked
                            ? null
                            : () {
                                final i = c.cart.indexOf(l);
                                final step =
                                    p.isSecondaryUnit(
                                      l.saleUnit.isEmpty
                                          ? p.packUnit
                                          : l.saleUnit,
                                    )
                                    ? p.ratio
                                    : productUnitScale;
                                if (l.area <= step) {
                                  c.cart.removeAt(i);
                                } else {
                                  c.cart[i] = CartLine(
                                    p.id,
                                    l.area - step,
                                    note: l.note,
                                    saleUnit: l.saleUnit,
                                    saleQuantity: l.saleQuantity == null
                                        ? null
                                        : addSaleQuantities(
                                            l.saleQuantity!,
                                            '1',
                                            subtract: true,
                                          ),
                                  );
                                }
                                c.update();
                              },
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      IconButton(
                        tooltip:
                            'Thêm một ${l.saleUnit.isEmpty ? p.packUnit : l.saleUnit}',
                        onPressed: c.busy || locked
                            ? null
                            : () => c.addCart(
                                p,
                                p.isSecondaryUnit(
                                      l.saleUnit.isEmpty
                                          ? p.packUnit
                                          : l.saleUnit,
                                    )
                                    ? p.ratio
                                    : productUnitScale,
                                note: '',
                                saleUnit: l.saleUnit,
                                saleQuantity: '1',
                              ),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                  const Divider(height: 1),
                ],
              ),
            );
          }),
          field(
            shipping,
            'Phí giao hàng (đ)',
            moneyInput: true,
            enabled: !locked,
          ),
          if (invalidShipping)
            const Text(
              'Phí giao hàng không hợp lệ.',
              style: TextStyle(color: Colors.red),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: locked || c.cart.isEmpty
                  ? null
                  : () {
                      setState(() => showDiscount = !showDiscount);
                      if (!showDiscount) discountInput.clear();
                      _saveFormDraft();
                    },
              icon: Icon(showDiscount ? Icons.close : Icons.discount_outlined),
              label: Text(showDiscount ? 'Bỏ giảm giá' : 'Giảm giá'),
            ),
          ),
          if (showDiscount) ...[
            field(
              discountInput,
              'Số tiền giảm giá (đ)',
              moneyInput: true,
              enabled: !locked,
            ),
            if (invalidDiscount)
              const Text(
                'Giảm giá không được vượt tổng tiền hàng.',
                style: TextStyle(color: Colors.red),
              ),
          ],
          Row(
            children: [
              const Expanded(child: Text('Tổng thanh toán')),
              Flexible(
                child: Text(
                  invalidDiscount || invalidShipping ? '—' : money(total),
                  style: const TextStyle(
                    color: blue,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Cách thanh toán',
            style: TextStyle(fontWeight: FontWeight.w700, color: ink),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final mode in _PaymentMode.values)
                ChoiceChip(
                  key: ValueKey('payment-${mode.name}'),
                  label: Text(switch (mode) {
                    _PaymentMode.full => 'Thanh toán đủ',
                    _PaymentMode.partial => 'Một phần',
                    _PaymentMode.debt => 'Ghi nợ',
                  }),
                  selected: paymentMode == mode,
                  onSelected: locked
                      ? null
                      : (_) {
                          setState(() {
                            paymentMode = mode;
                            if (mode == _PaymentMode.full) {
                              paid.clear();
                            } else if (mode == _PaymentMode.debt) {
                              paid.text = '0';
                            } else if (paid.text.trim().isEmpty ||
                                whole(paid.text) == 0) {
                              paid.clear();
                            }
                          });
                          _saveFormDraft();
                        },
                ),
            ],
          ),
          if (paymentMode == _PaymentMode.partial) ...[
            const SizedBox(height: 8),
            field(
              paid,
              'Số tiền thu lần này (đ)',
              moneyInput: true,
              enabled: !locked,
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final amount in [100000, 500000, 1000000])
                  if (amount < total)
                    ActionChip(
                      label: Text(money(amount)),
                      onPressed: locked ? null : () => paid.text = '$amount',
                    ),
                if (total > 1)
                  ActionChip(
                    key: const ValueKey('payment-quick-30-percent'),
                    label: const Text('Thu 30%'),
                    onPressed: locked
                        ? null
                        : () => paid.text = '${(total * 3 / 10).round().clamp(1, total - 1)}',
                  ),
                if (total > 1)
                  ActionChip(
                    key: const ValueKey('payment-quick-half'),
                    label: const Text('50%'),
                    onPressed: locked
                        ? null
                        : () => paid.text = '${((total + 1) ~/ 2).clamp(1, total - 1)}',
                  ),
                ActionChip(
                  key: const ValueKey('payment-quick-full'),
                  label: const Text('Trả đủ'),
                  onPressed: locked
                      ? null
                      : () {
                          setState(() {
                            paymentMode = _PaymentMode.full;
                            paid.clear();
                          });
                          _saveFormDraft();
                        },
                ),
              ],
            ),
          ] else if (paymentMode == _PaymentMode.debt) ...[
            const SizedBox(height: 6),
            hint('Không thu tiền trong lần bán này.'),
          ],
          if (invalidReceived || invalidPartial)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Số tiền thu không hợp lệ. Một phần phải lớn hơn 0 và nhỏ hơn tổng đơn.',
                style: TextStyle(color: Colors.red),
              ),
            ),
          if (!invalidShipping && !invalidDiscount && !invalidReceived)
            Container(
              key: const ValueKey('payment-summary'),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F6FC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(child: Text('Đã thu lần này')),
                      Text(
                        money(received),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Còn phải thu: ${money(total - received)}',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: ink),
                    ),
                  ),
                ],
              ),
            ),
          if (needsCustomer)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Chọn khách hàng trước khi ghi nợ hoặc giữ hàng.',
                style: TextStyle(color: Color(0xFFAD5700)),
              ),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Giữ hàng / đặt cọc'),
            value: hold,
            onChanged: locked
                ? null
                : (v) {
                    setState(() => hold = v);
                    _saveFormDraft();
                  },
          ),
          if (exceeds) ...[
            badge('Vượt tồn • cần xác nhận bán âm', warning: true),
            const SizedBox(height: 12),
            field(reason, 'Lý do duyệt bán âm', enabled: !locked),
          ],
          const SizedBox(height: 8),
          // For real accounts, show Outbox status before attempting a sale.
          // Demo keeps the original checkout button behavior.
          FutureBuilder<String?>(
            future: c.isLive ? _statusFor(c) : null,
            builder: (context, snapshot) {
              final checking =
                  c.isLive && snapshot.connectionState != ConnectionState.done;
              final checkFailed = c.isLive && snapshot.hasError;
              final status = snapshot.data;
              final alreadyQueued = c.isLive && status != null;
              final blocked =
                  locked ||
                  c.busy ||
                  c.cart.isEmpty ||
                  checking ||
                  checkFailed ||
                  alreadyQueued ||
                  invalidShipping ||
                  invalidDiscount ||
                  invalidReceived ||
                  invalidPartial ||
                  needsCustomer;

              String? message;
              if (checking) {
                message = 'Đang kiểm tra hóa đơn trên máy...';
              } else if (checkFailed) {
                message =
                    'Không kiểm tra được Outbox. '
                    'Tạm khóa Chốt đơn để bảo vệ dữ liệu.';
              } else if (alreadyQueued) {
                message = switch (status) {
                  'pending' =>
                    'Đã lưu trên máy • Chờ đồng bộ Firebase. '
                        'Chưa phải hóa đơn đã chốt.',
                  'syncing' => 'Đơn đang đồng bộ. Không chốt lại.',
                  'failed' =>
                    'Chưa xác minh được đơn trên Firebase. '
                        'Không tạo đơn mới.',
                  'synced' =>
                    'Đơn đã được đồng bộ. '
                        'Không chốt lại mã giao dịch này.',
                  _ =>
                    'Đơn đã có trong Outbox ($status). '
                        'Cần kiểm tra trước khi thao tác.',
                };
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (message != null) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              message,
                              style: const TextStyle(
                                color: Color(0xFF657993),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (c.isLive)
                            IconButton(
                              tooltip: 'Kiểm tra lại trạng thái Outbox',
                              onPressed: () => _refreshOutboxStatus(c),
                              icon: const Icon(Icons.refresh),
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (alreadyQueued && !checking && !checkFailed) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      key: const ValueKey('new-cart-after-offline-save'),
                      onPressed: c.busy
                          ? null
                          : () => attempt(() async {
                              final accepted = await confirm(
                                context,
                                'Tạo đơn mới?',
                                'Đơn offline trước đã lưu trên máy và vẫn nằm '
                                    'trong danh sách Đơn chờ đồng bộ. '
                                    'Tạo giỏ mới không có nghĩa là đơn cũ '
                                    'đã được Firebase xác nhận.\n'
                                    'Giỏ hiện tại sẽ được làm trống để bán '
                                    'cho khách tiếp theo.',
                              );
                              if (!accepted || !context.mounted) return;
                              await c.startNewCartAfterOfflineSave(
                                outbox: Get.find<OutboxRepository>(),
                              );
                              if (!mounted) return;
                              paid.clear();
                              paymentMode = _PaymentMode.full;
                              shipping.text = '0';
                              discountInput.clear();
                              reason.clear();
                              setState(() {
                                customerId = '';
                                hold = false;
                                showDiscount = false;
                                _checkedRequestId = null;
                                _outboxStatusFuture = null;
                              });
                            }),
                      icon: const Icon(Icons.add_shopping_cart_outlined),
                      label: const Text('Tạo đơn mới'),
                    ),
                    const SizedBox(height: 6),
                    hint('Đơn cũ vẫn ở SQLite và tiếp tục chờ đồng bộ.'),
                  ],
                  FilledButton.icon(
                    onPressed: blocked
                        ? null
                        : () => attempt(() async {
                            final subtotal = c.subtotal;
                            final requestId = c.requestId;
                            final amounts = _saleAmounts(subtotal);
                            if (!await confirm(
                              context,
                              hold
                                  ? 'Xác nhận giữ hàng?'
                                  : 'Xác nhận chốt đơn?',
                              '${_saleSummary(amounts)}'
                              '${exceeds ? '\nBán âm: ${reason.text}' : ''}',
                            )) {
                              return;
                            }
                            if (!context.mounted) return;
                            if (c.subtotal != subtotal ||
                                c.requestId != requestId) {
                              throw StateError(
                                'Giỏ hàng đã thay đổi. Kiểm tra lại trước khi xác nhận.',
                              );
                            }
                            // Checkout performs its own Outbox check again.
                            final order = await c.checkout(
                              customerId: customerId,
                              paid: amounts.paid,
                              ship: amounts.ship,
                              discount: amounts.discount,
                              hold: hold,
                              negativeReason: reason.text.trim(),
                            );
                            if (!mounted) return;
                            paid.clear();
                            paymentMode = _PaymentMode.full;
                            shipping.text = '0';
                            discountInput.clear();
                            setState(() => showDiscount = false);
                            reason.clear();
                            if (context.mounted) {
                              // Keep the order-details dialog visible for existing
                              // flows and tests; offer printing within that dialog.
                              await showOrder(
                                context,
                                order,
                                offerPrint: order['status'] == 'Đã bán',
                              );
                            }
                          }),
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(
                      hold
                          ? 'Xác nhận giữ đơn'
                          : c.isLive
                          ? 'Chốt đơn'
                          : 'Chốt đơn mẫu',
                    ),
                  ),
                  if (c.isLive) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      key: const ValueKey('save-offline-checkout'),
                      onPressed: blocked
                          ? null
                          : () => attempt(() async {
                              if (!Get.isRegistered<OutboxRepository>()) {
                                throw StateError(
                                  'Chưa kết nối Outbox. Không thể lưu đơn offline.',
                                );
                              }
                              final subtotal = c.subtotal;
                              final requestId = c.requestId;
                              final amounts = _saleAmounts(subtotal);

                              final accepted = await confirm(
                                context,
                                'Lưu đơn offline trên máy?',
                                'Đơn sẽ chỉ được lưu vào SQLite trên thiết bị này. '
                                    'Chưa tạo hóa đơn Firebase, chưa trừ tồn kho trên server '
                                    'cho đến khi máy chủ xác nhận. App sẽ thử gửi khi có mạng.\n'
                                    '${_saleSummary(amounts)}',
                              );
                              if (!accepted || !context.mounted) return;
                              if (c.subtotal != subtotal ||
                                  c.requestId != requestId) {
                                throw StateError(
                                  'Giỏ hàng đã thay đổi. Kiểm tra lại trước khi xác nhận.',
                                );
                              }

                              // This controller method atomically guards cart
                              // edits while the Outbox write is in progress.
                              // Never call SyncRuntime.drain() from this UI.
                              // Snapshot for the temporary paper slip before the
                              // cart can change. This is NOT a server invoice.
                              final temporarySlip = <String, dynamic>{
                                'id': 'TAM-$requestId',
                                'status': 'Chờ đồng bộ',
                                'customerId': customerId,
                                ...{
                                  for (final customer in c.data.customers.where(
                                    (entry) => entry['id'] == customerId,
                                  )) ...{
                                    'customerName': customer['name'],
                                    'customerPhone': customer['phone'],
                                    'customerAddress': customer['address'],
                                  },
                                },
                                'at': DateTime.now().toUtc().toIso8601String(),
                                'lines': [
                                  for (final line in c.cart)
                                    <String, dynamic>{
                                      'productId': line.productId,
                                      'name': c.data
                                          .product(line.productId)
                                          .name,
                                      'code': c.data
                                          .product(line.productId)
                                          .code,
                                      'unit': c.data
                                          .product(line.productId)
                                          .unit,
                                      'ratio': c.data
                                          .product(line.productId)
                                          .ratio,
                                      if (line.saleUnit.isNotEmpty)
                                        'saleUnit': line.saleUnit,
                                      if (line.saleQuantity != null) ...{
                                        'saleQuantity': line.saleQuantity,
                                        'salePrice': salePriceSnapshot(
                                          c.data.product(line.productId).price,
                                          c.data
                                              .product(line.productId)
                                              .factorForUnit(line.saleUnit),
                                        ),
                                      },
                                      'area': line.area,
                                      'price': c.data
                                          .product(line.productId)
                                          .price,
                                      'amount': lineMoney(
                                        line.area,
                                        c.data.product(line.productId).price,
                                      ),
                                      'note': line.note,
                                    },
                                ],
                                'subtotal': subtotal - amounts.discount,
                                'discount': amounts.discount,
                                'ship': amounts.ship,
                                'total':
                                    subtotal - amounts.discount + amounts.ship,
                              };
                              // Match checkout's per-product rounding and last-line
                              // remainder without creating a business transaction.
                              final remainingQuantity = <String, int>{};
                              for (final line in c.cart) {
                                remainingQuantity.update(
                                  line.productId,
                                  (value) => value + line.area,
                                  ifAbsent: () => line.area,
                                );
                              }
                              final remainingMoney = <String, int>{
                                for (final entry in remainingQuantity.entries)
                                  entry.key: lineMoney(
                                    entry.value,
                                    c.data.product(entry.key).price,
                                  ),
                              };
                              for (final row
                                  in temporarySlip['lines'] as List) {
                                final id = row['productId'] as String;
                                final quantity = row['area'] as int;
                                row['amount'] =
                                    remainingQuantity[id] == quantity
                                    ? remainingMoney[id]!
                                    : math.min(
                                        remainingMoney[id]!,
                                        row['amount'] as int,
                                      );
                                remainingQuantity[id] =
                                    remainingQuantity[id]! - quantity;
                                remainingMoney[id] =
                                    remainingMoney[id]! -
                                    (row['amount'] as int);
                              }
                              final temporaryCustomer = invoiceCustomer(
                                c.data,
                                temporarySlip,
                              );
                              await c.queueOfflineCheckout(
                                outbox: Get.find<OutboxRepository>(),
                                customerId: customerId,
                                paid: amounts.paid,
                                ship: amounts.ship,
                                discount: amounts.discount,
                                hold: hold,
                                negativeReason: reason.text.trim(),
                              );
                              if (mounted) _refreshOutboxStatus(c);
                              if (context.mounted) {
                                await showCheckoutResult(
                                  context,
                                  temporarySlip,
                                  customerName: temporaryCustomer,
                                  provisional: true,
                                );
                              }
                              if (Get.isRegistered<AutoSyncCoordinator>()) {
                                Get.find<AutoSyncCoordinator>()
                                    .checkNow()
                                    .ignore();
                              }
                            }),
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Lưu đơn offline'),
                    ),
                    const SizedBox(height: 6),
                    hint(
                      'Chỉ lưu trên thiết bị này • Chưa phải hóa đơn đã chốt. '
                      'Cần kiểm tra và đồng bộ sau.',
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// The same user-facing success layout is used for live and offline saves.
// Offline is always labelled temporary; a queued operation is NOT a sale.
Future<void> showCheckoutResult(
  BuildContext context,
  Json order, {
  required String customerName,
  bool provisional = false,
}) => safeDialog<void>(
  context: context,
  builder: (dialogContext) => checkoutResultContent(
    dialogContext,
    order,
    customerName: customerName,
    provisional: provisional,
  ),
);

Widget checkoutResultContent(
  BuildContext dialogContext,
  Json order, {
  required String customerName,
  bool provisional = false,
}) {
  final subtotal = (order['subtotal'] as num).toInt();
  final discount = (order['discount'] as num? ?? 0).toInt();
  final shipping = (order['ship'] as num? ?? 0).toInt();
  final total = (order['total'] as num).toInt();
  final lines = (order['lines'] as List).cast<Map>();
  final totalCount = lines.fold<double>(
    0,
    (accumulated, line) => accumulated + (line['area'] as num) / 10000,
  );
  final width = MediaQuery.sizeOf(dialogContext).width;
  final compact = width < 680;
  Widget labelValue(String label, String value, {Color? valueColor}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: valueColor ?? ink,
          ),
        ),
      ],
    ),
  );

  return Dialog(
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 650,
        maxHeight: MediaQuery.sizeOf(dialogContext).height * .9,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: const Color(0xFF0759BE),
              padding: const EdgeInsets.fromLTRB(20, 12, 10, 12),
              child: Row(
                children: [
                  Icon(
                    provisional ? Icons.cloud_off : Icons.check_circle_outline,
                    color: Colors.white,
                    size: 27,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      provisional
                          ? 'Đã lưu đơn offline'
                          : 'Chốt đơn thành công',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: compact ? 19 : 23,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng',
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: provisional
                          ? const Color(0xFFFFF7E8)
                          : const Color(0xFFF0F7FF),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          provisional
                              ? 'Đã lưu trên thiết bị — đang chờ đồng bộ Firebase'
                              : 'Đơn hàng đã được lưu',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          'Mã đơn: ${order['id']}',
                          style: const TextStyle(
                            color: blue,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Keep the exact label visible for existing widget tests.
                        InvoiceSnapshotWarning(order: order),
                        Text('Khách hàng: $customerName'),
                        if (provisional)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'Đây là phiếu tạm, chưa xác nhận đơn bán và chưa trừ tồn kho trên máy chủ.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF895E16),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (compact) ...[
                    labelValue('Số mặt hàng:', '${lines.length}'),
                    labelValue(
                      'Tổng số lượng:',
                      NumberFormat('0.####', 'vi').format(totalCount),
                    ),
                    const Divider(),
                  ] else
                    Row(
                      children: [
                        Expanded(
                          child: labelValue('Số mặt hàng:', '${lines.length}'),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: labelValue(
                            'Tổng số lượng:',
                            NumberFormat('0.####', 'vi').format(totalCount),
                          ),
                        ),
                      ],
                    ),
                  const Divider(height: 15),
                  labelValue('Tổng tiền hàng:', money(subtotal + discount)),
                  if (discount > 0)
                    labelValue(
                      'Giảm giá:',
                      '-${money(discount)}',
                      valueColor: const Color(0xFFC52931),
                    ),
                  if (shipping > 0)
                    labelValue('Phí vận chuyển:', money(shipping)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3EFFD),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Tổng thanh toán:',
                            style: TextStyle(
                              color: Color(0xFF074CB7),
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Text(
                          money(total),
                          style: TextStyle(
                            color: const Color(0xFF074CB7),
                            fontWeight: FontWeight.w900,
                            fontSize: compact ? 20 : 25,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 9,
                    runSpacing: 9,
                    alignment: WrapAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        key: const ValueKey('checkout-preview-invoice'),
                        icon: const Icon(Icons.preview_outlined),
                        label: const Text('Xem trước hóa đơn'),
                        onPressed: () => Navigator.of(dialogContext).push(
                          MaterialPageRoute<void>(
                            builder: (_) => Scaffold(
                              appBar: AppBar(
                                title: Text(
                                  provisional
                                      ? 'Xem phiếu tạm'
                                      : 'Xem trước hóa đơn',
                                ),
                              ),
                              body: InvoicePrintPreview(
                                order: order,
                                provisional: provisional,
                                demo: !Get.find<ShopController>().isLive,
                              ),
                            ),
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        key: const ValueKey('checkout-confirm-print'),
                        onPressed: () => Navigator.of(dialogContext).push(
                          MaterialPageRoute<void>(
                            builder: (_) => Scaffold(
                              appBar: AppBar(
                                title: Text(
                                  provisional
                                      ? 'Chọn khổ phiếu tạm'
                                      : 'Chọn khổ hóa đơn',
                                ),
                              ),
                              body: InvoicePrintPreview(
                                order: order,
                                provisional: provisional,
                                demo: !Get.find<ShopController>().isLive,
                              ),
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.print_outlined),
                        label: Text(
                          provisional ? 'In phiếu tạm' : 'In hóa đơn',
                        ),
                      ),
                      FilledButton.icon(
                        key: const ValueKey('checkout-skip-print'),
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(Icons.check),
                        label: const Text('Đóng'),
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
  );
}

Future<void> showOrder(
  BuildContext context,
  Json original, {
  bool offerPrint = false,
}) => safeDialog<void>(
  context: context,
  builder: (ctx) => GetBuilder<ShopController>(
    builder: (c) {
      final o = c.data.orders.firstWhere(
        (x) => x['id'] == original['id'],
        orElse: () => original,
      );
      if (offerPrint && o['status'] == 'Đã bán') {
        return checkoutResultContent(
          ctx,
          o,
          customerName: invoiceCustomer(c.data, o),
        );
      }
      return AlertDialog(
        title: Text('Đơn ${o['id']}'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                badge(o['status']),
                if (offerPrint && o['status'] == 'Đã bán') ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Chốt đơn thành công! Bạn có muốn in phiếu bán hàng không?',
                  ),
                ],
                const SizedBox(height: 12),
                Text('Khách hàng: ${invoiceCustomer(c.data, o)}'),
                Text('Ngày bán: ${day(o['soldAt'] ?? o['at'])}'),
                const SizedBox(height: 16),
                ...((o['lines'] as List).map(
                  (l) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l['name']),
                    subtitle: Text(
                      '${l['code']} • ${area(l['area'])} ${l['unit'] ?? 'm²'} × ${money(l['price'])}/${l['unit'] ?? 'm²'}${(l['note'] as String? ?? '').isEmpty ? '' : '\nLưu ý: ${l['note']}'}',
                    ),
                    trailing: Text(money(l['amount'])),
                  ),
                )),
                const Divider(),
                if ((o['discount'] as int? ?? 0) > 0)
                  Text('Giảm giá: ${money(o['discount'])}'),
                Text('Phí giao hàng: ${money(o['ship'] ?? 0)}'),
                Text('Tổng: ${money(o['total'])}'),
                Text('Đã thu: ${money(ShopData.collected(o))}'),
                Text(
                  'Còn nợ: ${money(['Đã hủy', 'Đã trả hàng'].contains(o['status']) ? 0 : (o['total'] as int) - ShopData.collected(o))}',
                ),
                if (['Đã hủy', 'Đã trả hàng'].contains(o['status']))
                  Text('Đã hoàn: ${money(o['refund'] ?? 0)}'),
                const SizedBox(height: 16),
                titleText('Lịch sử thu tiền', size: 16),
                ...(o['payments'] as List).map((raw) {
                  final p = Json.from(raw);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${money(p['amount'])}${p['voided'] == true ? ' • Đã điều chỉnh' : ''}',
                    ),
                    subtitle: Text('${day(p['at'])}\n${p['actor']}'),
                    isThreeLine: true,
                    trailing: p['voided'] == true || o['status'] == 'Đã hủy'
                        ? null
                        : IconButton(
                            tooltip: 'Sửa / hủy lần thu',
                            onPressed: () => correctPaymentDialog(ctx, o, p),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                  );
                }),
                const SizedBox(height: 12),
                hint('Thông báo nội bộ chưa gửi: chưa kết nối Messenger.'),
              ],
            ),
          ),
        ),
        actions: [
          if (offerPrint && o['status'] == 'Đã bán') ...[
            TextButton(
              key: const ValueKey('checkout-skip-print'),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Không in'),
            ),
            FilledButton.icon(
              key: const ValueKey('checkout-confirm-print'),
              onPressed: () async {
                Navigator.of(ctx).pop();
                await printSavedCheckoutInvoice(context, o);
              },
              icon: const Icon(Icons.print_outlined),
              label: const Text('In phiếu'),
            ),
          ],
          if (o['status'] == 'Đã bán' && !offerPrint)
            OutlinedButton.icon(
              onPressed: () => printReceipt80(ctx, o),
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('In 80 mm (KV804)'),
            ),
          if (o['status'] == 'Đã bán' && c.actor?.canAdmin == true)
            OutlinedButton.icon(
              onPressed: () => returnSoldOrderDialog(ctx, o),
              icon: const Icon(Icons.assignment_return_outlined),
              label: const Text('Trả toàn bộ / Hoàn tiền'),
            ),
          if (o['status'] == 'Đã bán' && !offerPrint)
            OutlinedButton.icon(
              onPressed: () => Navigator.of(ctx).push(
                MaterialPageRoute<void>(
                  builder: (_) => InvoicePdfPage(orderId: o['id']),
                ),
              ),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Xem / in PDF'),
            ),
          if (c.data.collectible(o) > 0)
            TextButton(
              onPressed: () => collectPayment(ctx, o),
              child: const Text('Ghi nhận trả tiền'),
            ),
          if (o['status'] == 'Giữ hàng')
            TextButton(
              onPressed: () => cancelHeldDialog(ctx, o),
              child: const Text('Hủy giữ / hoàn cọc'),
            ),
          if (o['status'] == 'Giữ hàng')
            FilledButton(
              onPressed: () => attempt(() async {
                await Get.find<ShopController>().change(
                  (d, a) => d.fulfilHeld(o['id'], a),
                );
                if (ctx.mounted) Navigator.pop(ctx);
              }),
              child: const Text('Xuất hàng đã giữ'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
        ],
      );
    },
  ),
);

/// Owner-only full return with manual refund confirmation.
/// Does not send money through a payment gateway.
Future<void> returnSoldOrderDialog(BuildContext context, Json order) async {
  final controller = Get.find<ShopController>();
  if (controller.actor?.canAdmin != true) {
    throw StateError('Chỉ chủ cửa hàng có thể trả hàng và hoàn tiền.');
  }
  final reason = TextEditingController();
  var confirmedRefund = ShopData.collected(order) == 0;
  try {
    await safeDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text('Trả TOÀN BỘ đơn ${order['id']}?'),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Hàng sẽ nhập lại ĐÚNG lô đã xuất. '
                  'Không xóa chứng từ bán; lưu lịch sử trả hàng.',
                ),
                const SizedBox(height: 12),
                Text('Số tiền đã thu: ${money(ShopData.collected(order))}'),
                const SizedBox(height: 12),
                field(reason, 'Lý do trả hàng (bắt buộc)'),
                CheckboxListTile(
                  value: confirmedRefund,
                  onChanged: (v) => set(() => confirmedRefund = v ?? false),
                  title: const Text('Tôi đã hoàn tiền ngoài phần mềm'),
                  subtitle: const Text('Chỉ đánh dấu khi thật sự đã chi tiền.'),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => attempt(() async {
                await controller.change(
                  (d, a) => d.returnSoldOrder(
                    order['id'] as String,
                    reason.text,
                    a,
                    cashWasReturned: confirmedRefund,
                  ),
                );
                if (ctx.mounted) Navigator.pop(ctx);
              }),
              child: const Text('Xác nhận trả hàng'),
            ),
          ],
        ),
      ),
    );
  } finally {
    reason.dispose();
  }
}

Future<void> printReceipt80(BuildContext context, Json order) async {
  try {
    if (!await confirmInvoiceSnapshot(context, order)) return;
    final controller = Get.find<ShopController>();
    final name = invoiceCustomer(controller.data, order);
    final receipt = await PrintService.receipt80(
      order,
      name,
      demo: !controller.isLive,
    );
    await Printing.layoutPdf(
      name: 'phieu-80mm-${order['id']}.pdf',
      format: receipt.format,
      dynamicLayout: false,
      forceCustomPrintPaper: true,
      onLayout: (_) async => receipt.bytes,
    );
  } catch (e) {
    if (!context.mounted) return;
    await safeDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Không in được phiếu 80 mm'),
        content: Text('$e\nĐơn đã lưu không thay đổi.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }
}

/// Print the already-saved invoice. Never creates a new checkout or mutates data.
Future<void> printSavedCheckoutInvoice(BuildContext context, Json order) async {
  if (order['status'] != 'Đã bán' || !context.mounted) return;
  if (!await confirmInvoiceSnapshot(context, order) || !context.mounted) return;
  final controller = Get.find<ShopController>();
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text('Chọn khổ hóa đơn ${order['id']}')),
        body: InvoicePrintPreview(order: order, demo: !controller.isLive),
      ),
    ),
  );
}
