part of 'app.dart';

class SalesPage extends StatelessWidget {
  const SalesPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = Get.find<ShopController>();
    return LayoutBuilder(
      builder: (context, box) {
        final catalogue = Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
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
                      OutlinedButton.icon(
                        onPressed: () => scanProduct(context),
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Quét / nhập mã'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => roomCalculator(context),
                        icon: const Icon(Icons.calculate_outlined),
                        label: const Text('Tính gạch theo phòng'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => c.navigate(9),
                        icon: const Icon(Icons.description_outlined),
                        label: const Text('Hóa đơn đã bán'),
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
                builder: (context, grid) => GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: grid.maxWidth > 750
                        ? 3
                        : grid.maxWidth > 450
                        ? 2
                        : 1,
                    mainAxisExtent: 310,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: c.visibleProducts.length,
                  itemBuilder: (context, i) {
                    final p = c.visibleProducts[i];
                    return panel(
                      InkWell(
                        onTap: () => confirmProduct(context, p),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: ProductPicture(p)),
                            const SizedBox(height: 10),
                            Text(
                              '${p.name} ${p.size}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${money(p.price)} / ${p.unit}',
                              style: const TextStyle(
                                color: blue,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: hint(
                                    'Còn ${area(p.available)} ${p.unit}',
                                  ),
                                ),
                                const Icon(Icons.add_circle, color: blue),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                OutlinedButton.icon(
                                  key: ValueKey('edit-sale-product-${p.id}'),
                                  onPressed: c.busy
                                      ? null
                                      : () => editProduct(context, original: p),
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 17,
                                  ),
                                  label: const Text('Sửa'),
                                ),
                                TextButton.icon(
                                  key: ValueKey('delete-sale-product-${p.id}'),
                                  onPressed: c.busy
                                      ? null
                                      : () => archiveProductDialog(context, p),
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 17,
                                  ),
                                  label: const Text('Xóa'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.all(12),
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
              const SizedBox(width: 410, child: CartPanel(compact: false)),
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

Future<void> confirmProduct(
  BuildContext context,
  Product p, {
  int? suggested,
}) async {
  final c = Get.find<ShopController>();
  final qty = TextEditingController(
    text: suggested == null ? '1' : '${suggested / p.quantityStep}',
  );
  final note = TextEditingController(text: p.note);
  var unit = p.hasPackConversion ? 'thùng' : p.unit;
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
                  'Còn ${area(p.available)} ${p.unit}${p.hasPackConversion ? ' • 1 thùng = ${area(p.ratio)} m²' : ''}',
                ),
                const SizedBox(height: 16),
                if (p.hasPackConversion)
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'thùng', label: Text('Theo thùng')),
                      ButtonSegment(value: 'm²', label: Text('Theo m²')),
                    ],
                    selected: {unit},
                    onSelectionChanged: (v) => set(() => unit = v.first),
                  ),
                const SizedBox(height: 16),
                field(qty, 'Số lượng ($unit)', number: true),
                // Listen to the existing editor; never rewrite its value or
                // wait for submit/focus changes to show the derived amounts.
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: qty,
                  builder: (context, value, _) {
                    final n = decimal(value.text);
                    final scaled = n * (unit == 'thùng' ? p.ratio : 10000);
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
              c.addCart(
                p,
                (n * (unit == 'thùng' ? p.ratio : 10000)).round(),
                note: note.text,
              );
              Navigator.pop(ctx);
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

Future<void> roomCalculator(BuildContext context) async {
  final c = Get.find<ShopController>();
  final products = c.data.products
      .where((p) => p.active && p.hasPackConversion)
      .toList();
  if (products.isEmpty) return;
  var p = products.first;
  final length = TextEditingController(text: '5'),
      width = TextEditingController(text: '4'),
      waste = TextEditingController(text: '5');
  RoomEstimate? estimate;
  await safeDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: const Text('Tính gạch theo diện tích phòng'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: p.id,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Chọn gạch'),
                  items: products
                      .map(
                        (p) => DropdownMenuItem(
                          value: p.id,
                          child: Text(
                            '${p.name} ${p.size}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (id) => set(() {
                    p = products.firstWhere((p) => p.id == id);
                    estimate = null;
                  }),
                ),
                const SizedBox(height: 16),
                field(length, 'Chiều dài (m)', number: true),
                field(width, 'Chiều rộng (m)', number: true),
                field(waste, 'Hao hụt (%)', number: true),
                OutlinedButton(
                  onPressed: () => attempt(
                    () async => set(
                      () => estimate = RoomEstimate.calculate(
                        decimal(length.text),
                        decimal(width.text),
                        decimal(waste.text),
                        p.ratio,
                      ),
                    ),
                  ),
                  child: const Text('Tính số thùng'),
                ),
                if (estimate != null) ...[
                  const SizedBox(height: 16),
                  titleText('${estimate!.cartons} thùng', size: 24),
                  Text(
                    'Cần ${area(estimate!.requiredArea)} m² • Mua ${area(estimate!.purchasedArea)} m²\nDư ${area(estimate!.purchasedArea - estimate!.requiredArea)} m²',
                  ),
                  hint('Đã làm tròn lên thùng nguyên'),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
          FilledButton(
            onPressed: () => attempt(() async {
              final fresh = RoomEstimate.calculate(
                decimal(length.text),
                decimal(width.text),
                decimal(waste.text),
                p.ratio,
              );
              Navigator.pop(ctx);
              await confirmProduct(context, p, suggested: fresh.purchasedArea);
            }),
            child: const Text('Xem và thêm vào giỏ'),
          ),
        ],
      ),
    ),
  );
  length.dispose();
  width.dispose();
  waste.dispose();
}

class CartPanel extends StatefulWidget {
  final bool compact;
  const CartPanel({required this.compact, super.key});
  @override
  State<CartPanel> createState() => _CartPanelState();
}

class _CartPanelState extends State<CartPanel> {
  final paid = TextEditingController(),
      shipping = TextEditingController(text: '0'),
      reason = TextEditingController();
  String customerId = '';
  bool hold = false;
  @override
  void initState() {
    super.initState();
    shipping.addListener(refresh);
  }

  void refresh() {
    setState(() {});
  }

  @override
  void dispose() {
    paid.dispose();
    shipping.dispose();
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      GetBuilder<ShopController>(builder: (c) => _buildCart(context, c));

  Widget _buildCart(BuildContext context, ShopController c) {
    final exceeds = c.cart.any(
      (l) => l.area > c.data.product(l.productId).available,
    );
    final ship = math.max(0, whole(shipping.text));
    return Material(
      color: Colors.white,
      child: ListView(
        padding: const EdgeInsets.all(20),
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
            onChanged: (v) => setState(() => customerId = v!),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: c.busy
                  ? null
                  : () async {
                      final id = await editCustomer(context);
                      if (id != null && mounted) {
                        setState(() => customerId = id);
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
                        onPressed: c.busy
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
                    '${area(l.area)} ${p.unit}${p.hasPackConversion ? ' • ${NumberFormat('0.##', 'vi').format(l.area / p.ratio)} thùng' : ''}',
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
                        tooltip: 'Bớt một ${p.packUnit}',
                        onPressed: c.busy
                            ? null
                            : () {
                                final i = c.cart.indexOf(l);
                                if (l.area <= p.quantityStep) {
                                  c.cart.removeAt(i);
                                } else {
                                  c.cart[i] = CartLine(
                                    p.id,
                                    l.area - p.quantityStep,
                                    note: l.note,
                                  );
                                }
                                c.update();
                              },
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      IconButton(
                        tooltip: 'Thêm một ${p.packUnit}',
                        onPressed: c.busy
                            ? null
                            : () => c.addCart(p, p.quantityStep, note: ''),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                  const Divider(height: 1),
                ],
              ),
            );
          }),
          field(shipping, 'Phí giao hàng (đ)', number: true),
          Row(
            children: [
              const Expanded(child: Text('Tổng thanh toán')),
              Flexible(
                child: Text(
                  money(c.subtotal + ship),
                  style: const TextStyle(
                    color: blue,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          hint('Gợi ý cọc 30%: ${money(((c.subtotal + ship) * .3).round())}'),
          const SizedBox(height: 12),
          field(paid, 'Tiền đã thu (đ) • bỏ trống để thu đủ', number: true),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Giữ hàng / đặt cọc'),
            value: hold,
            onChanged: (v) => setState(() => hold = v),
          ),
          if (exceeds) ...[
            badge('Vượt tồn • cần xác nhận bán âm', warning: true),
            const SizedBox(height: 12),
            field(reason, 'Lý do duyệt bán âm'),
          ],
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: c.busy || c.cart.isEmpty
                ? null
                : () => attempt(() async {
                    final shippingAmount = whole(shipping.text);
                    final amount = paid.text.trim().isEmpty
                        ? c.subtotal + shippingAmount
                        : whole(paid.text);
                    if (!await confirm(
                      context,
                      hold ? 'Xác nhận giữ hàng?' : 'Xác nhận chốt đơn?',
                      'Tổng ${money(c.subtotal + shippingAmount)}\nThu ${money(amount)}${exceeds ? '\nBán âm: ${reason.text}' : ''}',
                    )) {
                      return;
                    }
                    final order = await c.checkout(
                      customerId: customerId,
                      paid: amount,
                      ship: shippingAmount,
                      hold: hold,
                      negativeReason: reason.text.trim(),
                    );
                    paid.clear();
                    reason.clear();
                    if (context.mounted) await showOrder(context, order);
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
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: c.cart.isEmpty
                ? null
                : () => attempt(
                    () => PrintService.quote(
                      c.data,
                      c.cart,
                      ship,
                      demo: !c.isLive,
                    ),
                  ),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Báo giá PDF'),
          ),
        ],
      ),
    );
  }
}

Future<void> showOrder(BuildContext context, Json original) => safeDialog<void>(
  context: context,
  builder: (ctx) => GetBuilder<ShopController>(
    builder: (c) {
      final o = c.data.orders.firstWhere(
        (x) => x['id'] == original['id'],
        orElse: () => original,
      );
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
                Text('Tổng: ${money(o['total'])}'),
                Text('Đã thu: ${money(ShopData.collected(o))}'),
                Text(
                  'Còn nợ: ${money(o['status'] == 'Đã hủy' ? 0 : (o['total'] as int) - ShopData.collected(o))}',
                ),
                if (o['status'] == 'Đã hủy')
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
          if (o['status'] == 'Đã bán')
            OutlinedButton.icon(
              onPressed: () => Navigator.of(ctx).push(
                MaterialPageRoute<void>(
                  builder: (_) => InvoicePdfPage(orderId: o['id']),
                ),
              ),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Xem / in PDF'),
            ),
          if (o['status'] != 'Đã hủy' &&
              ShopData.collected(o) < (o['total'] as int))
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
