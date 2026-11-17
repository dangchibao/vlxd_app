part of 'app.dart';

// UUID vẫn là khóa lưu trữ; nhãn cũ phải ổn định khi đổi thứ tự lô.
// Chỉ khi người quản lý đánh số thì các lô cũ có số 001, 002, ... cố định.
String _legacyLotCode(Object? id) {
  final source = id?.toString() ?? '';
  var hash = 0x811c9dc5;
  for (final code in source.codeUnits) {
    hash = ((hash ^ code) * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).toUpperCase().padLeft(8, '0');
}

List<Json> _visibleInventoryLots(Product product) => product.lots
    .where((lot) => lot['hiddenFromInventory'] != true ||
        (lot['area'] as int? ?? 0) != 0 ||
        (lot['reserved'] as int? ?? 0) != 0)
    .toList();

String _inventoryLotLabel(Product product, Json lot) {
  final index = product.lots.indexWhere((item) => item['id'] == lot['id']);
  if (index < 0) return 'Lô không xác định';
  final rawNumber = lot['lotNumber'];
  if (rawNumber is int && rawNumber > 0) {
    return '${product.code} – Lô ${rawNumber.toString().padLeft(3, '0')}';
  }
  // Chưa cấp số: một mã ổn định lấy từ UUID, không phụ thuộc thứ tự list.
  return '${product.code} – Lô cũ ${_legacyLotCode(lot['id'])}';
}

Future<void> hideEmptyInventoryLot(
  BuildContext context, Product product, Json lot,
) async {
  final quantity = lot['area'] as int? ?? 0;
  final reserved = lot['reserved'] as int? ?? 0;
  if (quantity != 0 || reserved != 0) {
    await safeDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Không thể ẩn lô đang có hàng'),
        content: const Text('Chỉ ẩn khi tồn và giữ đều bằng 0. '
            'Nếu cần thay đổi số lượng, hãy dùng Kiểm kê / ảnh kho.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx),
          child: const Text('Đã hiểu'))],
      ),
    );
    return;
  }
  final label = _inventoryLotLabel(product, lot);
  final confirmed = await safeDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Ẩn $label khỏi Kho?'),
      content: const Text('Lô hết hàng sẽ được ẩn khỏi màn hình Kho. '
          'Mã gốc, lịch sử và chứng từ không bị xóa.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Hủy')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Ẩn lô')),
      ],
    ),
  );
  if (confirmed != true) return;
  await attempt(() async {
    final shop = Get.find<ShopController>();
    await shop.change((data, actor) {
      actor.requireAdmin();
      final currentProduct = data.product(product.id);
      final matches = currentProduct.lots.where((item) => item['id'] == lot['id']);
      if (matches.length != 1) {
        throw StateError('Lô đã thay đổi. Vui lòng tải lại danh sách Kho.');
      }
      final current = matches.single;
      if (current['hiddenFromInventory'] == true ||
          current['area'] != 0 ||
          (current['reserved'] as int? ?? 0) != 0) {
        throw StateError('Lô đã thay đổi hoặc vẫn còn tồn. Vui lòng tải lại.');
      }
      current['hiddenFromInventory'] = true;
      data.log(actor, 'Ẩn lô hết hàng', currentProduct.code,
          '$label (${current['id']}) được ẩn khỏi Kho; giữ lịch sử.');
    });
  });
}

Future<void> showHiddenInventoryLots(
    BuildContext context, Product product) async {
  final hidden = product.lots.where((l) => l['hiddenFromInventory'] == true &&
      (l['area'] as int? ?? 0) == 0 &&
      (l['reserved'] as int? ?? 0) == 0).toList();
  if (hidden.isEmpty) return;
  await safeDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Lô đã ẩn • ${product.code}'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final lot in hidden)
              ListTile(
                title: Text(_inventoryLotLabel(product, lot)),
                subtitle: Text('Ngày nhập ${day(lot['date'])}'),
                trailing: TextButton(
                  onPressed: () => attempt(() async {
                    await Get.find<ShopController>().change((data, actor) {
                      actor.requireAdmin();
                      final current = data.product(product.id).lots
                          .firstWhere((l) => l['id'] == lot['id']);
                      if (current['hiddenFromInventory'] != true) return;
                      current['hiddenFromInventory'] = false;
                      data.log(actor, 'Hiện lô hàng', product.code,
                          'Khôi phục lô ${lot['id']} lên màn hình Kho.');
                    });
                    if (ctx.mounted) Navigator.pop(ctx);
                  }),
                  child: const Text('Hiện lại'),
                ),
              ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx),
          child: const Text('Đóng'))],
    ),
  );
}

class InventoryPage extends StatelessWidget {
  const InventoryPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = Get.find<ShopController>();
    return ListView(
      padding: vlxdPagePadding(context),
      children: [
        titleText('Kho và lô hàng'),
        const SizedBox(height: 8),
        hint('Theo dõi tồn thực tế, lượng đang giữ và giá vốn từng lô.'),
        const SizedBox(height: 12),
        VlxdPagedList<Product>(
          items: c.data.products.where((p) => !p.deleted && !p.archivedFromLists).toList(),
          pageSize: 10,
          itemBuilder: (p) => Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: panel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      titleText('${p.name} ${p.size}', size: 18),
                      hint('SKU: ${p.code}'),
                      if (!p.active) badge('Ngừng kinh doanh'),
                      if (p.available <= 0)
                        badge('Hết hàng', warning: true)
                      else if (p.minimum > 0 && p.available <= p.minimum)
                        badge('Sắp hết hàng', warning: true),
                      if (p.isOld(DateTime.now()))
                        badge('Có lô tồn trên 60 ngày', warning: true),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Tồn ${area(p.stock)} ${p.unit} • Giữ ${area(p.reserved)} ${p.unit} • Khả dụng ${area(p.available)} ${p.unit}',
                  ),
                  hint(p.minimum > 0 ? 'Cảnh báo khi tồn kho còn: ${area(p.minimum)} ${p.unit}' : 'Chưa đặt ngưỡng cảnh báo'),
                  const SizedBox(height: 4),
                  if (_visibleInventoryLots(p).isNotEmpty)
                    ExpansionTile(
                      key: PageStorageKey('lots-${p.id}'),
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: EdgeInsets.zero,
                      dense: true,
                      initiallyExpanded: false,
                      leading: const Icon(
                        Icons.layers_outlined,
                        size: 19,
                        color: blue,
                      ),
                      title: Text(
                        'Xem ${_visibleInventoryLots(p).length} lô hàng',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      children: [
                        for (final l in _visibleInventoryLots(p))
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text('${_inventoryLotLabel(p, l)} • ${day(l['date'])}'),
                            subtitle: Text(
                              '${area(l['area'])} ${p.unit} • Vốn ${money(l['cost'])}/${p.unit}',
                            ),
                            trailing: Tooltip(
                              message: (l['area'] == 0 &&
                                      (l['reserved'] as int? ?? 0) == 0)
                                  ? 'Ẩn lô hết hàng (giữ lịch sử)'
                                  : 'Lô đang có tồn hoặc giữ: không thể ẩn',
                              child: IconButton(
                                icon: const Icon(Icons.visibility_off_outlined, color: Colors.orange),
                                onPressed: c.busy ? null :
                                    () => hideEmptyInventoryLot(context, p, l),
                              ),
                            ),
                          ),
                      ],
                    ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => receiveStock(context, p),
                        icon: const Icon(Icons.add_box_outlined),
                        label: const Text('Nhập hàng'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => inspectStock(context, p),
                        icon: const Icon(Icons.fact_check_outlined),
                        label: const Text('Kiểm kê / ảnh kho'),
                      ),
                      if (c.actor?.canAdmin == true &&
                          p.lots.any((l) => l['hiddenFromInventory'] == true &&
                              (l['area'] as int? ?? 0) == 0 &&
                              (l['reserved'] as int? ?? 0) == 0))
                        TextButton.icon(
                          icon: const Icon(Icons.visibility_outlined),
                          label: const Text('Xem lô đã ẩn'),
                          onPressed: () => showHiddenInventoryLots(context, p),
                        ),
                      if (c.actor?.canAdmin == true &&
                          p.lots.any((l) => l['lotNumber'] is! int || (l['lotNumber'] as int) <= 0))
                        TextButton.icon(
                          icon: const Icon(Icons.push_pin_outlined),
                          label: const Text('Đánh số lô cũ'),
                          onPressed: () => attempt(() async {
                            await c.change((d, a) =>
                                d.assignMissingLotNumbers(p.id, a));
                          }),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        if (c.data.stockMoves.isNotEmpty)
          panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleText('Biến động gần đây', size: 18),
                ...c.data.stockMoves
                    .take(20)
                    .map(
                      (m) => ListTile(
                        title: Text('${m['type']} • ${m['product']}'),
                        subtitle: Text(day(m['at'])),
                        trailing: Text(
                          '${area(m['area'])} ${c.data.products.where((p) => p.code == m['product']).firstOrNull?.unit ?? 'm²'}',
                        ),
                      ),
                    ),
              ],
            ),
          ),
      ],
    );
  }
}

Future<void> receiveStock(BuildContext context, Product p) async {
  final shop = Get.find<ShopController>();
  final operationId = newId();
  final qty = TextEditingController(text: '10'),
      cost = TextEditingController(text: '${(p.price * .7).round()}');
  var date = DateTime.now();
  await safeDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: const Text('Nhập hàng theo lô'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${p.name} ${p.size}'),
                const SizedBox(height: 16),
                field(
                  qty,
                  p.hasPackConversion ? 'Số thùng' : 'Số lượng (${p.unit})',
                  number: true,
                ),
                field(cost, 'Giá nhập đ/${p.unit}', moneyInput: true),
                TextButton.icon(
                  onPressed: () async {
                    final selected = await showDatePicker(
                      context: ctx,
                      initialDate: date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (selected != null) set(() => date = selected);
                  },
                  icon: const Icon(Icons.calendar_month),
                  label: Text(DateFormat('dd/MM/yyyy').format(date)),
                ),
                hint(
                  'Nhà cung cấp: ${p.supplier}\n${p.hasPackConversion ? '1 thùng = ${area(p.ratio)} m²' : 'Nhập số lượng đã tự tính theo ${p.unit}'}',
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
                throw ArgumentError('Số lượng nhập không hợp lệ.');
              }
              final units = (n * p.quantityStep).round();
              final unitCost = whole(cost.text);
              if (shop.isLive) {
                await _queueBookOperation(
                  shop,
                  OfflineBookOperation(
                    type: OfflineBookOperation.receipt,
                    id: operationId,
                    actorId: shop.actor!.id,
                    target: p.id,
                    amount: units,
                    cost: unitCost,
                    ratio: p.ratio,
                    unit: p.unit,
                    date: date,
                  ),
                );
              } else {
                await shop.change(
                  (d, a) => d.receive(
                    p.id,
                    units,
                    unitCost,
                    date,
                    a,
                    'LO-$operationId',
                  ),
                );
              }
              if (ctx.mounted) Navigator.pop(ctx);
            }),
            child: Text(
              shop.isLive ? 'Lưu phiếu nhập chờ đồng bộ' : 'Ghi phiếu nhập',
            ),
          ),
        ],
      ),
    ),
  );
  qty.dispose();
  cost.dispose();
}

Future<void> inspectStock(BuildContext context, Product p) async {
  if (p.lots.isEmpty) return;
  var lot = p.lots.first;
  final actual = TextEditingController(text: '${(lot['area'] as int) / 10000}'),
      reason = TextEditingController();
  String? image;
  await safeDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: const Text('Kiểm kê và ảnh kho'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: lot['id'],
                  decoration: const InputDecoration(labelText: 'Lô hàng'),
                  items: p.lots
                      .map(
                        (l) => DropdownMenuItem<String>(
                          value: l['id'],
                          child: Text(_inventoryLotLabel(p, l)),
                        ),
                      )
                      .toList(),
                  onChanged: (id) => set(() {
                    lot = p.lots.firstWhere((l) => l['id'] == id);
                    actual.text = '${(lot['area'] as int) / 10000}';
                  }),
                ),
                const SizedBox(height: 16),
                Text('Sổ kho: ${area(lot['area'])} ${p.unit}'),
                const SizedBox(height: 12),
                field(actual, 'Tồn thực tế (${p.unit})', number: true),
                field(reason, 'Lý do / ghi chú kiểm kê'),
                if (image != null)
                  SizedBox(
                    height: 140,
                    child: Image.memory(
                      base64Decode(image!),
                      fit: BoxFit.cover,
                    ),
                  ),
                Wrap(
                  children: [
                    TextButton.icon(
                      onPressed: () => attempt(() async {
                        final img = await pickImage();
                        if (img != null && ctx.mounted) set(() => image = img);
                      }),
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: Text(image == null ? 'Thêm ảnh kho' : 'Đổi ảnh'),
                    ),
                    if (image != null)
                      TextButton(
                        onPressed: () => set(() => image = null),
                        child: const Text('Xóa ảnh'),
                      ),
                  ],
                ),
                hint(
                  'Chênh lệch được lưu thành phiếu điều chỉnh, không xóa lịch sử kho.',
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
              final n = decimal(actual.text);
              if (!n.isFinite || n < 0 || reason.text.trim().isEmpty) {
                throw ArgumentError('Nhập tồn không âm và lý do kiểm kê.');
              }
              await Get.find<ShopController>().change((d, a) {
                final current = d
                    .product(p.id)
                    .lots
                    .firstWhere((l) => l['id'] == lot['id']);
                if (current['area'] != lot['area'] ||
                    current['reserved'] != lot['reserved']) {
                  throw StateError(
                    'Tồn kho vừa thay đổi trên máy khác. Mở lại phiếu kiểm kê trước khi lưu.',
                  );
                }
                final target = areaUnits(n);
                if (target < (current['reserved'] as int)) {
                  throw StateError(
                    'Tồn thực tế thấp hơn lượng đang giữ, cần xử lý đơn giữ trước.',
                  );
                }
                final delta = target - (current['area'] as int);
                current['area'] = target;
                if (target != 0) current['hiddenFromInventory'] = false;
                final at = DateTime.now().toUtc().toIso8601String();
                d.stockMoves.insert(0, {
                  'product': p.code,
                  'area': delta,
                  'type': 'Kiểm kê',
                  'lot': lot['id'],
                  'actor': a.id,
                  'at': at,
                  'reason': reason.text.trim(),
                  'image': image,
                });
                d.log(
                  a,
                  'Kiểm kê',
                  p.code,
                  'Lô ${lot['id']}: chênh ${delta / 10000} ${p.unit}. ${reason.text.trim()}',
                );
              });
              if (ctx.mounted) Navigator.pop(ctx);
            }),
            child: const Text('Lưu kiểm kê'),
          ),
        ],
      ),
    ),
  );
  actual.dispose();
  reason.dispose();
}

class DeliveriesPage extends StatelessWidget {
  const DeliveriesPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = Get.find<ShopController>();
    return ListView(
      padding: vlxdPagePadding(context),
      children: [
        Wrap(
          spacing: 20,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            titleText('Chuyến giao hàng'),
            FilledButton.icon(
              onPressed: () => editDelivery(context),
              icon: const Icon(Icons.add),
              label: const Text('Tạo chuyến'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        hint(
          'Chủ và nhân viên được xác nhận hoàn tất theo phân quyền đã chốt.',
        ),
        const SizedBox(height: 12),
        if (c.data.deliveries.isEmpty)
          const EmptyState(
            'Chưa có chuyến giao hàng',
            'Tạo đơn đã bán, sau đó gán đơn vào chuyến.',
            Icons.local_shipping_outlined,
          ),
        VlxdPagedList<Json>(
          items: c.data.deliveries,
          pageSize: 10,
          itemBuilder: (d) => Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: panel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      titleText(d['orderId'], size: 20),
                      badge(d['status']),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tài xế: ${d['driver']}\n${d['vehicle']} • ${d['address']}\nPhí thu khách: ${money(d['fee'])} • Chi tài xế: ${money(d['cost'] ?? 0)}',
                  ),
                  if ((d['images'] as List).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Wrap(
                        spacing: 8,
                        children: (d['images'] as List)
                            .map(
                              (img) => SizedBox(
                                width: 100,
                                height: 90,
                                child: Image.memory(
                                  base64Decode(img),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (d['status'] == 'Đang giao')
                      OutlinedButton.icon(
                        onPressed: () => editDelivery(context, original: d),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Sửa / ảnh giao hàng'),
                      ),
                      if (d['status'] == 'Đang giao')
                        FilledButton.icon(
                          onPressed: () => attempt(() async {
                            if (!await confirm(
                              context,
                              'Xác nhận chuyến đã xong?',
                              'Ghi nhận người hoàn tất và tạo sự kiện thông báo nội bộ.',
                            )) {
                              return;
                            }
                            await c.change(
                              (db, a) => db.finishDelivery(d['id'], a),
                            );
                          }),
                          icon: const Icon(Icons.check),
                          label: const Text('Xác nhận đã xong'),
                        ),
                      if (d['status'] == 'Đang giao')
                        TextButton.icon(
                          icon: const Icon(Icons.cancel_outlined),
                          label: const Text('Hủy chuyến'),
                          onPressed: () => cancelDeliveryDialog(context, d),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Future<void> cancelDeliveryDialog(BuildContext context, Json delivery) async {
  final reason = TextEditingController();
  await safeDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Hủy chuyến ${delivery['id']}?'),
      content: SizedBox(width: 420,
        child: TextField(controller: reason,
          decoration: const InputDecoration(labelText: 'Lý do hủy (ít nhất 5 ký tự)'))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Quay lại')),
        FilledButton(onPressed: () => attempt(() async {
          await Get.find<ShopController>().change((d, a) =>
              d.cancelDelivery(delivery['id'] as String, reason.text, a));
          if (ctx.mounted) Navigator.pop(ctx);
        }), child: const Text('Xác nhận hủy chuyến')),
      ],
    ),
  );
  reason.dispose();
}

Future<void> editDelivery(BuildContext context, {Json? original}) async {
  final c = Get.find<ShopController>();
  final available = c.data.orders
      .where((o) => o['status'] == 'Đã bán')
      .toList();
  if (available.isEmpty) {
    await attempt(
      () async => throw StateError('Cần có đơn đã bán trước khi tạo chuyến.'),
    );
    return;
  }
  var orderId = original?['orderId'] ?? available.first['id'];
  final driver = TextEditingController(text: original?['driver'] ?? ''),
      vehicle = TextEditingController(
        text: original?['vehicle'] ?? 'Xe tải 1,5 tấn',
      ),
      address = TextEditingController(text: original?['address'] ?? ''),
      fee = TextEditingController(text: '${original?['fee'] ?? 0}'),
      cost = TextEditingController(text: '${original?['cost'] ?? 0}');
  final images = List<String>.from(original?['images'] ?? []);
  await safeDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: const Text('Thông tin chuyến giao'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: orderId,
                  decoration: const InputDecoration(labelText: 'Đơn hàng'),
                  items: available
                      .map(
                        (o) => DropdownMenuItem<String>(
                          value: o['id'],
                          child: Text(o['id']),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => orderId = v,
                ),
                const SizedBox(height: 16),
                field(driver, 'Tài xế'),
                field(vehicle, 'Xe'),
                field(address, 'Địa chỉ giao'),
                field(
                  fee,
                  'Phí thu khách đã chốt trên đơn (đ)',
                  moneyInput: true,
                ),
                field(cost, 'Chi phí trả tài xế (đ)', moneyInput: true),
                hint(
                  'Phí chuyến lưu riêng để đối chiếu; không cộng thu khách lần nữa.',
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    for (int i = 0; i < images.length; i++)
                      InkWell(
                        onTap: () => set(() => images.removeAt(i)),
                        child: SizedBox(
                          width: 90,
                          height: 80,
                          child: Image.memory(
                            base64Decode(images[i]),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                  ],
                ),
                TextButton.icon(
                  onPressed: images.length >= 10
                      ? null
                      : () => attempt(() async {
                          final image = await pickImage();
                          if (image != null && ctx.mounted) {
                            set(() => images.add(image));
                          }
                        }),
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('Thêm ảnh • Bấm ảnh để xóa'),
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
              if ([
                    driver.text,
                    vehicle.text,
                    address.text,
                  ].any((v) => v.trim().isEmpty) ||
                  whole(fee.text) < 0 ||
                  whole(cost.text) < 0) {
                throw ArgumentError(
                  'Điền đủ tài xế, xe, địa chỉ và phí không âm.',
                );
              }
              await c.change((db, a) {
                final id = original?['id'] ?? 'GH-${newId().substring(0, 8)}';
                final d = <String, dynamic>{
                  ...?original,
                  'id': id,
                  'orderId': orderId,
                  'driver': driver.text.trim(),
                  'vehicle': vehicle.text.trim(),
                  'address': address.text.trim(),
                  'fee': whole(fee.text),
                  'cost': whole(cost.text),
                  'status': original?['status'] ?? 'Đang giao',
                  'images': images,
                };
                final i = db.deliveries.indexWhere((x) => x['id'] == id);
                if (original != null && i >= 0 &&
                    db.deliveries[i]['status'] != 'Đang giao') {
                  throw StateError('Chuyến đã hoàn tất/hủy không thể sửa trực tiếp.');
                }
                if (original != null &&
                    (i < 0 ||
                        jsonEncode(db.deliveries[i]) != jsonEncode(original))) {
                  throw StateError(
                    'Chuyến vừa thay đổi. Mở lại thông tin để không ghi đè xác nhận giao hàng.',
                  );
                }
                if (i < 0) {
                  db.deliveries.insert(0, d);
                } else {
                  db.deliveries[i] = d;
                }
                db.log(
                  a,
                  original == null ? 'Tạo chuyến' : 'Sửa chuyến',
                  id,
                  '${driver.text} • $orderId',
                );
              });
              if (ctx.mounted) Navigator.pop(ctx);
            }),
            child: const Text('Lưu chuyến'),
          ),
        ],
      ),
    ),
  );
  for (final t in [driver, vehicle, address, fee, cost]) {
    t.dispose();
  }
}

Future<String?> editCustomer(BuildContext context, {Json? original}) async {
  final id = original?['id'] as String? ?? newId();
  final name = TextEditingController(text: original?['name'] ?? ''),
      phone = TextEditingController(text: original?['phone'] ?? ''),
      address = TextEditingController(text: original?['address'] ?? '');
  final result = await safeDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Thông tin khách hàng'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              field(name, 'Họ tên / công trình'),
              field(phone, 'Số điện thoại'),
              const SizedBox(height: 12),
              TextField(
                controller: address,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Địa chỉ khách hàng',
                  hintText: 'Có thể xuống dòng khi nhập địa chỉ',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.sentences,
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
            if (name.text.trim().isEmpty || address.text.length > 500) {
              throw ArgumentError('Nhập tên và địa chỉ tối đa 500 ký tự.');
            }
            final customers = Get.find<ShopController>().data.customers;
            final contact = phone.text.replaceAll(RegExp(r'[^0-9]'), '');
            final similar = customers.where((c) => c['id'] != id &&
                ((contact.isNotEmpty &&
                  (c['phone'] as String? ?? '').replaceAll(RegExp(r'[^0-9]'), '') == contact)
                  || (ShopData.normalizeProductText(c['name'] as String? ?? '') ==
                        ShopData.normalizeProductText(name.text) &&
                      ShopData.normalizeProductText(c['address'] as String? ?? '') ==
                        ShopData.normalizeProductText(address.text)))).toList();
            if (similar.isNotEmpty) {
              final existing = similar.first;
              final proceed = await confirm(ctx, 'Khách hàng có thể bị trùng',
                  'Đã có ${existing['name']} • ${existing['phone']} '
                  '(mã ${existing['id']}). Kiểm tra công nợ trước khi tạo mới. '
                  'Bạn vẫn muốn lưu hồ sơ riêng?');
              if (!proceed || !ctx.mounted) return;
            }
            void save(ShopData d, Actor a) {
              final value = <String, dynamic>{
                ...?original,
                'id': id,
                'name': name.text.trim(),
                'phone': phone.text.trim(),
                'address': address.text.trim(),
              };
              final i = d.customers.indexWhere((p) => p['id'] == id);
              if (original != null &&
                  (i < 0 ||
                      jsonEncode(d.customers[i]) != jsonEncode(original))) {
                throw StateError(
                  'Thông tin khách vừa thay đổi. Mở lại trước khi sửa.',
                );
              }
              if (i < 0) {
                d.customers.add(value);
              } else {
                d.customers[i] = value;
              }
              d.log(a, 'Lưu khách hàng', id, name.text.trim());
            }

            await Get.find<ShopController>().change(save);
            if (ctx.mounted) Navigator.pop(ctx, id);
          }),
          child: const Text('Lưu'),
        ),
      ],
    ),
  );
  name.dispose();
  phone.dispose();
  address.dispose();
  return result;
}

Future<void> collectPayment(BuildContext context, Json o) async {
  final shop = Get.find<ShopController>();
  final current = shop.data.orders
      .where((row) => row['id'] == o['id'])
      .firstOrNull;
  if (current == null || current['status'] == 'Đã hủy') return;
  final remaining = shop.data.collectible(current);
  if (remaining <= 0) {
    await attempt(
      () async =>
          throw StateError('Đơn hoặc sổ công nợ đã hết số tiền cần thu.'),
    );
    return;
  }

  final amount = TextEditingController(
    text: NumberFormat.decimalPattern('vi').format(remaining),
  );

  final paymentId = newId();

  await safeDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Thu tiền ${o['id']}'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Tổng đơn: ${money(current['total'])} • Phí giao hàng đã tính: ${money(current['ship'] ?? 0)}',
            ),
            Text(
              'Đã thu: ${money(ShopData.collected(current))} • Có thể thu: ${money(remaining)}',
            ),
            const SizedBox(height: 12),
            field(amount, 'Số tiền khách trả (đ)', moneyInput: true),
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
            final paymentAmount = whole(amount.text.replaceAll('.', ''));

            if (shop.isLive) {
              await _queueBookOperation(
                shop,
                OfflineBookOperation(
                  type: OfflineBookOperation.payment,
                  id: paymentId,
                  actorId: shop.actor!.id,
                  target: o['id'] as String,
                  amount: paymentAmount,
                  expectedCollected: ShopData.collected(current),
                ),
              );
            } else {
              await shop.change(
                (d, a) => d.recordPayment(o['id'], paymentAmount, paymentId, a),
              );
            }

            if (ctx.mounted) {
              Navigator.pop(ctx);
            }
          }),
          child: Text(
            shop.isLive ? 'Lưu khoản thu chờ đồng bộ' : 'Xác nhận đã thu',
          ),
        ),
      ],
    ),
  );

  amount.dispose();
}

Future<void> _queueBookOperation(
  ShopController shop,
  OfflineBookOperation command,
) async {
  await shop.queueBookOperation(command);
  Get.snackbar(
    'Đã lưu trên thiết bị',
    'Xem trạng thái trong Đơn chờ đồng bộ ở Bán hàng.',
  );
  if (Get.isRegistered<AutoSyncCoordinator>()) {
    Get.find<AutoSyncCoordinator>().checkNow().ignore();
  }
}

Future<void> editSalary(BuildContext context, Json p) async {
  final salary = TextEditingController(text: '${p['salary']}'),
      advance = TextEditingController(text: '${p['advance']}');
  await safeDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Lương ${p['name']}'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            field(salary, 'Lương kỳ này (đ)', moneyInput: true),
            field(advance, 'Tổng đã ứng / đã trả (đ)', moneyInput: true),
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
            await Get.find<ShopController>().change((d, a) {
              if (jsonEncode(d.payroll.firstWhere((x) => x['id'] == p['id'])) !=
                  jsonEncode(p)) {
                throw StateError('Lương vừa thay đổi. Mở lại trước khi sửa.');
              }
              return d.setSalary(
                p['id'],
                whole(salary.text),
                whole(advance.text),
                a,
              );
            });
            if (ctx.mounted) Navigator.pop(ctx);
          }),
          child: const Text('Lưu'),
        ),
      ],
    ),
  );
  salary.dispose();
  advance.dispose();
}

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = Get.find<ShopController>();
    final ranked = [...c.data.customers]
      ..sort((a, b) => c.data.debt(b['id']).compareTo(c.data.debt(a['id'])));
    final totals = <String, int>{};
    for (final o in c.data.orders.where((o) => o['status'] == 'Đã bán')) {
      for (final line in o['lines']) {
        if ((line['unit'] ?? 'm²') != 'm²') continue;
        totals.update(
          line['name'],
          (v) => v + (line['area'] as int),
          ifAbsent: () => line['area'],
        );
      }
    }
    final top = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return ListView(
      padding: vlxdPagePadding(context),
      children: [
        titleText(c.isLive ? 'Báo cáo cửa hàng' : 'Báo cáo từ dữ liệu mẫu'),
        const SizedBox(height: 8),
        hint(
          'Toàn bộ thời gian • Chưa có bộ lọc ngày/tuần/tháng và lãi lỗ hoàn chỉnh.',
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, reportBox) => Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: reportBox.maxWidth >= 850
                    ? (reportBox.maxWidth - 12) / 2
                    : reportBox.maxWidth,
                child: panel(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleText('Top 10 gạch bán chạy', size: 18),
                      if (top.isEmpty)
                        const EmptyState(
                          'Chưa có doanh số',
                          'Chốt một đơn đã bán để xem báo cáo.',
                          Icons.bar_chart,
                        ),
                      ...top
                          .take(10)
                          .map(
                            (p) => ListTile(
                              title: Text(p.key),
                              trailing: Text('${area(p.value)} m²'),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: reportBox.maxWidth >= 850
                    ? (reportBox.maxWidth - 12) / 2
                    : reportBox.maxWidth,
                child: panel(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleText('Top 10 khách còn nợ', size: 18),
                      ...ranked
                          .where((p) => c.data.debt(p['id']) > 0)
                          .take(10)
                          .map(
                            (p) => ListTile(
                              title: Text(p['name']),
                              trailing: Text(money(c.data.debt(p['id']))),
                            ),
                          ),
                      if (!ranked.any((p) => c.data.debt(p['id']) > 0))
                        const EmptyState(
                          'Chưa có công nợ',
                          'Các khoản còn phải thu sẽ xuất hiện tại đây.',
                          Icons.account_balance_wallet_outlined,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: () => exportData(context),
          icon: const Icon(Icons.download_outlined),
          label: const Text('Xuất dữ liệu sao lưu'),
        ),
      ],
    );
  }
}

class AuditPage extends StatefulWidget {
  const AuditPage({super.key});
  @override
  State<AuditPage> createState() => _AuditPageState();
}

class _AuditPageState extends State<AuditPage> {
  String query = '';
  int page = 0;
  @override
  Widget build(BuildContext context) {
    final c = Get.find<ShopController>();
    final rows = c.data.audit
        .where(
          (a) =>
              '${auditPresentation(c.data, a, actor: c.actor)} ${a['actor']} ${a['action']} ${a['target']}'
                  .toLowerCase()
                  .contains(query.toLowerCase()),
        )
        .toList();
    final pages = math.max(1, (rows.length / 10).ceil());
    page = math.min(page, pages - 1);
    return ListView(
      padding: vlxdPagePadding(context),
      children: [
        titleText('Nhật ký thao tác'),
        const SizedBox(height: 8),
        hint(
          Get.find<ShopController>().isLive
              ? 'Lịch sử các thao tác đã thực hiện. Nhật ký được giữ lại, không sửa hoặc xóa.'
              : 'Không có nút sửa hoặc xóa. Đây là nhật ký dữ liệu mẫu cục bộ.',
        ),
        const SizedBox(height: 16),
        TextField(
          decoration: const InputDecoration(
            hintText: 'Tìm người, thao tác hoặc mã',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: (v) => setState(() {
            query = v;
            page = 0;
          }),
        ),
        const SizedBox(height: 16),
        if (rows.isEmpty)
          const EmptyState(
            'Chưa có nhật ký',
            'Thử tạo đơn hoặc sửa sản phẩm.',
            Icons.history,
          ),
        ...rows
            .skip(page * 10)
            .take(10)
            .map(
              (a) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: panel(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        auditPresentation(c.data, a, actor: c.actor).title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      hint(
                        '${auditPresentation(c.data, a, actor: c.actor).person} • ${day(a['at'])}',
                      ),
                      const SizedBox(height: 3),
                      Text(auditPresentation(c.data, a, actor: c.actor).detail),
                    ],
                  ),
                ),
              ),
            ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: page == 0 ? null : () => setState(() => page--),
              icon: const Icon(Icons.chevron_left),
            ),
            Text('${page + 1} / $pages'),
            IconButton(
              onPressed: page + 1 >= pages
                  ? null
                  : () => setState(() => page++),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ],
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = Get.find<ShopController>();
    return ListView(
      padding: vlxdPagePadding(context),
      children: [
        titleText('Cài đặt cửa hàng'),
        const SizedBox(height: 12),
        const VlxdDisplayPreferencesPanel(),
        const SizedBox(height: 12),
        panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleText('Tài khoản và phân quyền', size: 18),
              const SizedBox(height: 12),
              Text(
                'Vai trò: ${c.actor!.canAdmin ? 'Chủ / admin' : 'Nhân viên bán hàng'}',
              ),
              const SizedBox(height: 8),
              const Text(
                'Nhân viên thao tác như chủ, trừ sửa lương, cấp quyền và khóa tài khoản khác. Tài xế / vị trí khác chưa được truy cập.',
              ),
              const SizedBox(height: 12),
              if (!c.isLive)
                badge(
                  c.actor!.canAdmin
                      ? 'Chờ kết nối Firebase để quản lý tài khoản'
                      : 'Chỉ chủ được quản lý tài khoản',
                  warning: true,
                ),
              if (c.isLive) ...[
                OutlinedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => const PasswordPage(),
                    ),
                  ),
                  child: const Text('Đổi mật khẩu của tôi'),
                ),
                if (c.actor!.canAdmin) ...[
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const AccountsPage(),
                      ),
                    ),
                    child: const Text('Quản lý tài khoản và quyền'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => attempt(() => importLocalDemo(context)),
                    child: const Text('Nhập dữ liệu mẫu đã lưu vào kho trống'),
                  ),
                ],
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleText('Thông báo nội bộ', size: 18),
              const SizedBox(height: 12),
              Text(
                'Fanpage VLXD ${StoreProfile.current.name}\nNhóm Đơn mới — Ai cũng đọc',
              ),
              const SizedBox(height: 12),
              badge('Chưa kết nối • chưa xác minh API nhóm', warning: true),
              const SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: true,
                onChanged: null,
                title: Text('Đơn mới và chuyến vận chuyển đã xong'),
                subtitle: Text('Sự kiện được lưu nội bộ, chưa được gửi'),
              ),
              const SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: false,
                onChanged: null,
                title: Text('Tự gửi tin cho khách'),
                subtitle: Text('Luôn tắt theo yêu cầu cửa hàng'),
              ),
              VlxdPagedList<Json>(
                items: c.data.notifications,
                pageSize: 5,
                itemBuilder: (n) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(n['event']),
                  subtitle: Text('${day(n['at'])}\n${n['status']}'),
                  isThreeLine: true,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleText('Máy in và sao lưu', size: 18),
              const SizedBox(height: 12),
              const Text(
                'KiotViet KV804 • Giấy 80 mm • USB / LAN\nBản thử dùng hộp thoại in của hệ thống. Chưa có cầu nối in từ iPhone qua máy quầy.',
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => exportData(context),
                icon: const Icon(Icons.download),
                label: const Text('Xuất dữ liệu'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String csvValue(Object? value) {
  var s = value?.toString() ?? '';
  if (RegExp(r'^[=+@\-\t\r]').hasMatch(s)) s = "'$s";
  return '"${s.replaceAll('"', '""')}"';
}

Future<void> exportData(BuildContext context) async {
  final c = Get.find<ShopController>();
  final types = [
    'Sản phẩm',
    'Lô hàng',
    'Đơn hàng',
    'Khách hàng và công nợ',
    'Các lần thu tiền',
    'Nhật ký',
    'Lương nhân viên',
    'Bản JSON dữ liệu',
  ];
  final type = await safeDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: const Text('Chọn dữ liệu xuất'),
      children: types
          .map(
            (t) => SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, t),
              child: Padding(padding: const EdgeInsets.all(8), child: Text(t)),
            ),
          )
          .toList(),
    ),
  );
  if (type == null) return;
  await attempt(() async {
    if (!kIsWeb &&
        [
          TargetPlatform.android,
          TargetPlatform.iOS,
        ].contains(defaultTargetPlatform)) {
      throw StateError(
        'Bản thử hiện hỗ trợ tải CSV trên web và máy tính. Trên điện thoại hãy dùng bản web.',
      );
    }
    List<List<Object?>> rows;
    switch (type) {
      case 'Sản phẩm':
        rows = [
          [
            'Mã',
            'Tên',
            'Kích thước',
            'NCC',
            'Đơn vị',
            'Giá đ/đơn vị',
            'Quy đổi thùng/khối',
            'Tồn',
            'Giữ',
            'Đang bán',
            'Lưu ý',
          ],
          ...c.data.products.map(
            (p) => [
              p.code,
              p.name,
              p.size,
              p.supplier,
              p.unit,
              p.price,
              p.ratio / 10000,
              p.stock / 10000,
              p.reserved / 10000,
              p.active,
              p.note,
            ],
          ),
        ];
      case 'Lô hàng':
        rows = [
          [
            'Mã hàng',
            'Mã lô',
            'Ngày nhập',
            'Đơn vị',
            'Tồn',
            'Giữ',
            'Giá vốn đ/đơn vị',
          ],
          ...c.data.products.expand(
            (p) => p.lots.map(
              (l) => [
                p.code,
                l['id'],
                l['date'],
                p.unit,
                (l['area'] as int) / 10000,
                (l['reserved'] as int) / 10000,
                l['cost'],
              ],
            ),
          ),
        ];
      case 'Đơn hàng':
        rows = [
          [
            'Mã đơn',
            'Mã chống trùng',
            'Khách',
            'Ngày',
            'Trạng thái',
            'Tổng đ',
            'Đã thu đ',
            'Hoàn cọc đ',
            'Thu ròng đ',
            'Chi tiết JSON',
          ],
          ...c.data.orders.map(
            (o) => [
              o['id'],
              o['requestId'],
              o['customerId'],
              o['at'],
              o['status'],
              o['total'],
              ShopData.collected(o),
              o['refund'] ?? 0,
              ShopData.netCollected(o),
              jsonEncode(o['lines']),
            ],
          ),
        ];
      case 'Khách hàng và công nợ':
        rows = [
          [
            'Mã khách',
            'Tên',
            'Điện thoại',
            'Phải thu đ',
            'Đã thu đ',
            'Còn nợ đ',
            'Đang sử dụng',
            'Điều chỉnh phải thu đ',
            'Điều chỉnh đã thu đ',
          ],
          ...c.data.customers.map(
            (p) => [
              p['id'],
              p['name'],
              p['phone'],
              c.data.customerBook(p['id']).receivable,
              c.data.customerBook(p['id']).received,
              c.data.debt(p['id']),
              p['active'] != false,
              p['receivableAdjustment'] ?? 0,
              p['receivedAdjustment'] ?? 0,
            ],
          ),
        ];
      case 'Các lần thu tiền':
        rows = [
          [
            'Mã đơn',
            'Mã lần thu',
            'Ngày',
            'Người thu',
            'Số tiền đ',
            'Hiệu lực',
            'Thay thế lần thu',
            'Mã điều chỉnh',
            'Lý do hủy lần thu',
          ],
          ...c.data.orders.expand(
            (o) => (o['payments'] as List).map(
              (p) => [
                o['id'],
                p['id'],
                p['at'],
                p['actor'],
                p['amount'],
                p['voided'] == true ? 'Đã điều chỉnh' : 'Hiệu lực',
                p['replaces'] ?? '',
                p['correctionId'] ?? '',
                p['voidReason'] ?? '',
              ],
            ),
          ),
        ];
      case 'Nhật ký':
        rows = [
          ['Thời điểm', 'Người', 'Thao tác', 'Đối tượng', 'Chi tiết'],
          ...c.data.audit.map(
            (a) => [a['at'], a['actor'], a['action'], a['target'], a['detail']],
          ),
        ];
      case 'Lương nhân viên':
        c.actor!.requireAccess();
        rows = [
          ['Mã', 'Tên', 'Kỳ', 'Lương đ', 'Đã trả đ'],
          ...c.data.payroll.map(
            (p) => [p['id'], p['name'], p['period'], p['salary'], p['advance']],
          ),
        ];
      default:
        rows = [];
    }
    final json = type == 'Bản JSON dữ liệu';
    final exported = c.data.toJson();
    final text = json
        ? const JsonEncoder.withIndent('  ').convert(exported)
        : '\uFEFF${rows.map((r) => r.map(csvValue).join(',')).join('\r\n')}';
    final filename =
        '${StoreProfile.current.id}-${DateTime.now().millisecondsSinceEpoch}.${json ? 'json' : 'csv'}';
    final target = await getSaveLocation(suggestedName: filename);
    if (target == null) return;
    await XFile.fromData(
      utf8.encode(text),
      name: filename,
      mimeType: json ? 'application/json' : 'text/csv',
    ).saveTo(target.path);
  });
}
