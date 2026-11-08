part of 'app.dart';

class ProductPicture extends StatelessWidget {
  final Product product;
  const ProductPicture(this.product, {super.key});
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: product.images.isNotEmpty
        ? Image.memory(
            base64Decode(product.images.first),
            fit: BoxFit.cover,
            width: double.infinity,
            errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
          )
        : Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: product.supplier == 'Prime'
                    ? [const Color(0xFFE8E9E8), const Color(0xFFB5C0C5)]
                    : product.supplier == 'Đồng Tâm'
                    ? [const Color(0xFF8E969D), const Color(0xFFD8DDE1)]
                    : [const Color(0xFFF1E9D9), const Color(0xFFD0BEA6)],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.grid_on, size: 32, color: Colors.white70),
                  Text(
                    product.size,
                    style: const TextStyle(
                      color: ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
  );
}

/// Giá vốn đã ghi trong lô có ngày nhập mới nhất.
/// KHÔNG coi đây là giá nhập hóa đơn hay giá vốn bình quân gia quyền.
/// Không có lô hợp lệ => trả về null, không tự điền giá 0.
int? latestRecordedLotCost(Product product) {
  DateTime? newestDate;
  int? newestCost;
  for (final lot in product.lots) {
    final date = DateTime.tryParse(lot['date']?.toString() ?? '');
    final rawCost = lot['cost'];
    if (date == null || rawCost is! num || !rawCost.isFinite || rawCost <= 0) {
      continue;
    }
    if (newestDate == null || date.isAfter(newestDate)) {
      newestDate = date;
      newestCost = rawCost.round();
    }
  }
  return newestCost;
}

/// Nhãn màu vàng phân biệt giá vốn ghi theo lô và giá bán thực tế.
/// Chỉ dùng cho nhân viên trong app, không đưa lên hóa đơn khách hàng.
Widget productLotCostBadge(Product product) {
  final cost = latestRecordedLotCost(product);
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF2D6),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'GIÁ VỐN LÔ GẦN NHẤT',
          style: TextStyle(
            color: Color(0xFF805500),
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          cost == null ? 'Chưa có dữ liệu' : '${money(cost)} / ${product.unit}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF493000),
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class ProductsPage extends StatelessWidget {
  const ProductsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = Get.find<ShopController>();
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: math.min(420, MediaQuery.sizeOf(context).width - 48),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Tìm mã, tên gạch, nhà cung cấp',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) {
                  c.query = v;
                  c.update();
                },
              ),
            ),
            FilledButton.icon(
              onPressed: () => editProduct(context),
              icon: const Icon(Icons.add),
              label: const Text('Thêm sản phẩm'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['Tất cả', '30×60', '60×60', '80×80', 'm³']
              .map(
                (g) => ChoiceChip(
                  label: Text(g),
                  selected: c.group == g,
                  onSelected: (_) {
                    c.group = g;
                    c.update();
                  },
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 20),
        if (c.visibleProducts.isEmpty)
          const EmptyState(
            'Không tìm thấy sản phẩm',
            'Thử mã hoặc tên khác.',
            Icons.search_off,
          ),
        ...c.visibleProducts.map(
          (p) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: panel(
              LayoutBuilder(
                builder: (context, box) => Column(
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 64,
                          height: 72,
                          child: ProductPicture(p),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                              hint('${p.code} • ${p.size} • ${p.supplier}'),
                              const SizedBox(height: 8),
                              productLotCostBadge(p),
                              const SizedBox(height: 8),
                              const Text(
                                'GIÁ BÁN',
                                style: TextStyle(
                                  color: blue,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '${money(p.price)} / ${p.unit}',
                                style: const TextStyle(
                                  color: blue,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              hint(
                                'Còn ${area(p.available)} ${p.unit}${p.hasPackConversion ? ' • ${NumberFormat('0.##', 'vi').format(p.available / p.ratio)} thùng' : ''}',
                              ),
                              if (p.note.isNotEmpty)
                                Text(
                                  'Lưu ý: ${p.note}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF657993),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (box.maxWidth > 700) actions(context, p),
                      ],
                    ),
                    if (box.maxWidth <= 700)
                      Align(
                        alignment: Alignment.centerRight,
                        child: actions(context, p),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget actions(BuildContext context, Product p) => Wrap(
    spacing: 2,
    children: [
      IconButton(
        tooltip: 'Chi tiết và sửa sản phẩm',
        onPressed: () => editProduct(context, original: p),
        icon: const Icon(Icons.edit_outlined),
      ),
      IconButton(
        tooltip: 'Mã vạch và in',
        onPressed: () => showBarcode(context, p),
        icon: const Icon(Icons.qr_code_2),
      ),
      IconButton(
        tooltip: 'Xóa / ngừng kinh doanh',
        color: Colors.red,
        onPressed: () => archiveProductDialog(context, p),
        icon: const Icon(Icons.delete_outline),
      ),
    ],
  );
}

Future<void> archiveProductDialog(BuildContext context, Product p) async {
  final c = Get.find<ShopController>();
  if (c.busy) return;

  // Không tự động làm thay đổi giỏ hàng đã chuẩn bị hoặc đã lưu Outbox.
  if (c.cart.any((line) => line.productId == p.id)) {
    await attempt(() async {
      throw StateError(
        'Sản phẩm đang nằm trong giỏ hàng. '
        'Kiểm tra và xử lý đơn hàng trước khi ngừng kinh doanh.',
      );
    });
    return;
  }

  if (!await confirm(
    context,
    'Xóa / ngừng bán ${p.name}?',
    'Sản phẩm sẽ ẩn khỏi danh sách bán hàng. '
        'Tồn kho và hóa đơn cũ vẫn được giữ. '
        'Sản phẩm đang được giữ cho khách phải giải phóng trước.',
  )) {
    return;
  }
  if (!context.mounted) return;

  await attempt(() async {
    // Kiểm tra lại sau khi người dùng xác nhận và ngay trước khi ghi.
    await c.change((d, a) {
      if (c.cart.any((line) => line.productId == p.id)) {
        throw StateError(
          'Sản phẩm vừa có trong giỏ hàng. '
          'Không thể ngừng kinh doanh lúc này.',
        );
      }
      return d.archiveProduct(p.id, a);
    });
    // Không dùng c.cart.removeWhere(): không thay đổi giỏ hàng ngầm.
  });
}

Future<void> editProduct(BuildContext context, {Product? original}) async {
  final c = Get.find<ShopController>();
  final p = original == null
      ? Product(
          id: newId(),
          code: 'BH${DateTime.now().millisecondsSinceEpoch}',
          name: '',
          size: '',
          supplier: '',
          price: 240000,
          ratio: 0,
          minimum: 0,
        )
      : Product.fromJson(jsonDecode(jsonEncode(original.toJson())));
  final code = TextEditingController(text: p.code),
      name = TextEditingController(text: p.name),
      size = TextEditingController(text: p.size),
      supplier = TextEditingController(text: p.supplier),
      price = TextEditingController(text: '${p.price}'),
      ratio = TextEditingController(
        text: p.ratio == 0 ? '' : '${p.ratio / 10000}',
      ),
      minimum = TextEditingController(
        text: p.minimum == 0 ? '' : '${p.minimum / 10000}',
      ),
      note = TextEditingController(text: p.note);
  var saving = false;
  await safeDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text(original == null ? 'Thêm sản phẩm' : 'Chi tiết sản phẩm'),
        content: SizedBox(
          width: 650,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                field(code, 'Mã sản phẩm / mã vạch'),
                field(name, 'Tên sản phẩm'),
                field(size, 'Kích thước (tùy chọn; nhập m³ nếu bán theo khối)'),
                field(supplier, 'Nhà cung cấp (tùy chọn)'),
                field(price, 'Giá bán đ/đơn vị (m² hoặc m³)', moneyInput: true),
                field(
                  ratio,
                  'm² trong 1 thùng (không rõ thì để trống)',
                  number: true,
                ),
                field(minimum, 'Ngưỡng sắp hết (tùy chọn)', number: true),
                TextField(
                  controller: note,
                  minLines: 2,
                  maxLines: 5,
                  maxLength: 1000,
                  decoration: const InputDecoration(
                    labelText: 'Lưu ý (tùy chọn)',
                    hintText: 'Ví dụ: 5 tấm đá, người bán tự tính tổng 3,6 m². Kích thước chưa rõ có thể bổ sung sau.',
                    helperText: 'Thông tin để đối chiếu; app không tự tính từ nội dung lưu ý.',
                    helperMaxLines: 3,
                  ),
                ),
                const SizedBox(height: 12),
                hint(
                  'Số lượng mua do người bán tự tính và nhập khi bán. Bỏ trống quy đổi thì nhập trực tiếp theo m² hoặc m³.',
                ),
                const SizedBox(height: 12),
                hint(
                  'Ảnh đầu là đại diện • Tối đa 11 ảnh • Bấm ảnh để đổi hoặc xóa',
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (int i = 0; i < p.images.length; i++)
                      InkWell(
                        onTap: saving
                            ? null
                            : () => attempt(() async {
                                final action = await safeDialog<String>(
                                  context: ctx,
                                  builder: (dctx) => SimpleDialog(
                                    title: const Text('Chỉnh ảnh'),
                                    children: [
                                      SimpleDialogOption(
                                        onPressed: () =>
                                            Navigator.pop(dctx, 'replace'),
                                        child: const Text('Đổi ảnh'),
                                      ),
                                      SimpleDialogOption(
                                        onPressed: () =>
                                            Navigator.pop(dctx, 'primary'),
                                        child: const Text(
                                          'Chọn làm ảnh đại diện',
                                        ),
                                      ),
                                      SimpleDialogOption(
                                        onPressed: () =>
                                            Navigator.pop(dctx, 'delete'),
                                        child: const Text('Xóa ảnh'),
                                      ),
                                    ],
                                  ),
                                );
                                if (action == 'delete') {
                                  set(() => p.images.removeAt(i));
                                }
                                if (action == 'primary') {
                                  set(() {
                                    final img = p.images.removeAt(i);
                                    p.images.insert(0, img);
                                  });
                                }
                                if (action == 'replace') {
                                  final image = await pickImage();
                                  if (image != null && ctx.mounted) {
                                    set(() => p.images[i] = image);
                                  }
                                }
                              }),
                        child: SizedBox(
                          width: 82,
                          height: 82,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              base64Decode(p.images[i]),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    if (p.images.length < 11)
                      IconButton.filledTonal(
                        onPressed: saving
                            ? null
                            : () => attempt(() async {
                                final image = await pickImage();
                                if (image != null && ctx.mounted) {
                                  set(() => p.images.add(image));
                                }
                              }),
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (p.lots.isNotEmpty) ...[
                  titleText('Lô hàng và ngày nhập', size: 16),
                  ...p.lots.map(
                    (l) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l['id']),
                      subtitle: Text(
                        '${day(l['date'])}\nTồn ${area(l['area'])} ${p.unit} • Giá vốn ${money(l['cost'])}/${p.unit}',
                      ),
                      isThreeLine: true,
                      trailing: IconButton(
                        tooltip: 'Sửa ngày nhập lô',
                        icon: const Icon(Icons.edit_calendar_outlined),
                        onPressed: saving
                            ? null
                            : () async {
                                final date = await showDatePicker(
                                  context: ctx,
                                  initialDate: DateTime.parse(l['date']),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime.now(),
                                );
                                if (date != null) {
                                  set(() => l['date'] = date.toIso8601String());
                                }
                              },
                      ),
                    ),
                  ),
                  hint(
                    'Nhập hàng ở mục Kho. Chứng từ cũ giữ nguyên quy đổi tại lúc lập đơn.',
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: saving ? null : () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: saving
                ? null
                : () => attempt(() async {
                    final r = ratio.text.trim().isEmpty
                            ? 0.0
                            : decimal(ratio.text),
                        m = minimum.text.trim().isEmpty
                            ? 0.0
                            : decimal(minimum.text);
                    if (!r.isFinite || !m.isFinite) {
                      throw ArgumentError(
                        'Quy đổi hoặc ngưỡng tồn không hợp lệ.',
                      );
                    }
                    p.code = code.text.trim();
                    p.name = name.text.trim();
                    p.size = size.text.trim();
                    p.supplier = supplier.text.trim();
                    p.note = note.text.trim();
                    p.price = whole(price.text);
                    p.ratio = areaUnits(r);
                    if (p.isBulk) p.ratio = 10000;
                    p.minimum = areaUnits(m);
                    set(() => saving = true);
                    try {
                      await c.change(
                        (d, a) => d.saveProduct(p, a, expected: original),
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                    } finally {
                      if (ctx.mounted) set(() => saving = false);
                    }
                  }),
            child: const Text('Lưu thay đổi'),
          ),
        ],
      ),
    ),
  );
  for (final controller in [
    code,
    name,
    size,
    supplier,
    price,
    ratio,
    minimum,
    note,
  ]) {
    controller.dispose();
  }
}

Future<String?> pickImage() async {
  final live = Get.find<ShopController>().isLive;
  final image = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: live ? 480 : 1200,
    maxHeight: live ? 480 : 1200,
    imageQuality: live ? 45 : 75,
  );
  if (image == null) return null;
  final bytes = await image.readAsBytes();
  if (bytes.length > (live ? 40000 : 600000)) {
    throw StateError(
      live
          ? 'Ảnh cần dưới 40 KB sau khi nén để đồng bộ Firestore miễn phí. Chọn ảnh nhỏ hơn; ảnh gốc lớn cần cấu hình Cloudinary.'
          : 'Ảnh quá lớn cho bản thử. Vui lòng chọn ảnh dưới 600 KB.',
    );
  }
  return base64Encode(bytes);
}

Future<void> showBarcode(BuildContext context, Product p) => safeDialog<void>(
  context: context,
  builder: (ctx) => AlertDialog(
    title: const Text('Mã vạch sản phẩm'),
    content: SizedBox(
      width: 320,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          BarcodeWidget(
            barcode: Barcode.code128(),
            data: p.code,
            width: 280,
            height: 100,
          ),
          const SizedBox(height: 18),
          Text('${money(p.price)} / ${p.unit}'),
          const SizedBox(height: 12),
          hint(
            'KV804 • Giấy cuộn 80 mm\nChọn máy in trong hộp thoại hệ thống. Mã được tạo thật theo Code 128.',
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(ctx),
        child: const Text('Đóng'),
      ),
      FilledButton.icon(
        onPressed: () => attempt(() => PrintService.barcode(p)),
        icon: const Icon(Icons.print_outlined),
        label: const Text('In mã vạch'),
      ),
    ],
  ),
);
