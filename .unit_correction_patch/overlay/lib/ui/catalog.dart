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
              // Anh dai dien thu gon 66x66: co gian noi dung de tranh
              // RenderFlex overflow khi ten kich thuoc dai.
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.grid_on,
                        size: 32,
                        color: Colors.white70,
                      ),
                      Text(
                        product.size,
                        maxLines: 1,
                        style: const TextStyle(
                          color: ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
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
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
    if (MediaQuery.sizeOf(context).width < 600) {
      return VlxdMobileProductsView();
    }
    return ListView(
      padding: vlxdPagePadding(context),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: math.min(420, MediaQuery.sizeOf(context).width - 32),
              child: TextField(
                decoration: const InputDecoration(
                  hintText:
                      'Tìm mã, tên, quy cách, nhà cung cấp (có hoặc không dấu)',
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
        hint('Nhóm hàng gợi ý (tự nhận diện; chưa thay đổi phân loại đã lưu)'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: c.catalogCategories
              .map(
                (category) => ChoiceChip(
                  label: Text(category),
                  selected: c.catalogCategory == category,
                  onSelected: (_) {
                    c.catalogCategory = category;
                    c.group = 'Tất cả';
                    c.update();
                  },
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 12),
        hint('Lọc quy cách / kích thước thực tế'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: c.catalogSpecifications
              .map(
                (specification) => ChoiceChip(
                  label: Text(specification),
                  selected: c.group == specification,
                  onSelected: (_) {
                    c.group = specification;
                    c.update();
                  },
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['Đang bán', 'Ngừng bán', 'Đã ẩn', 'Xóa nhầm', 'Tất cả']
              .map(
                (value) => ChoiceChip(
                  label: Text(value),
                  selected: c.catalogStatus == value,
                  onSelected: (_) {
                    c.catalogStatus = value;
                    c.update();
                  },
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 12),
        if (c.catalogProducts.isEmpty)
          const EmptyState(
            'Không tìm thấy sản phẩm',
            'Thử mã hoặc tên khác.',
            Icons.search_off,
          ),
        VlxdPagedList<Product>(
          key: ValueKey(
            'catalog-${c.query}-${c.catalogCategory}-${c.group}-${c.catalogStatus}',
          ),
          items: c.catalogProducts,
          pageSize: 10,
          itemBuilder: (p) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: panel(
              LayoutBuilder(
                builder: (context, box) => Column(
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 66,
                          height: 66,
                          child: ProductPicture(p),
                        ),
                        const SizedBox(width: 12),
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
                              if (p.deleted)
                                hint('Đã xóa mềm • giữ mã SKU')
                              else if (p.archivedFromLists)
                                hint('Đã ẩn khỏi danh sách')
                              else if (!p.active)
                                hint('Ngừng kinh doanh'),
                              const SizedBox(height: 6),
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 12,
                                runSpacing: 6,
                                children: [
                                  productLotCostBadge(p),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
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
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              hint(
                                'Còn ${area(p.available)} ${p.unit}${p.hasPackConversion ? ' • ${NumberFormat('0.##', 'vi').format(p.available / p.ratio)} ${p.secondaryUnit} (${conversionHint(p)})' : ''}',
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
      if (p.active && !p.deleted && !p.archivedFromLists) ...[
        IconButton(
          tooltip: 'Chi tiết và sửa sản phẩm',
          onPressed: () => editProduct(context, original: p),
          icon: const Icon(Icons.edit_outlined),
        ),
        if (Get.find<ShopController>().actor?.canAdmin == true && p.lots.isNotEmpty)
          IconButton(
            tooltip: 'Đính chính đơn vị nhập nhầm (chỉ khi chưa bán/xuất)',
            onPressed: () => correctReceivedUnitDialog(context, p),
            icon: const Icon(Icons.edit_note_outlined),
          ),
        IconButton(
          tooltip: 'Mã vạch và in',
          onPressed: () => showBarcode(context, p),
          icon: const Icon(Icons.qr_code_2),
        ),
        IconButton(
          tooltip: 'Ngừng kinh doanh (không xóa dữ liệu)',
          color: Colors.red,
          onPressed: () => archiveProductDialog(context, p),
          icon: const Icon(Icons.block_outlined),
        ),
      ] else if (p.deleted) ...[
        if (Get.find<ShopController>().actor?.canAdmin == true)
          TextButton.icon(
            icon: const Icon(Icons.restore),
            label: const Text('Khôi phục xóa nhầm'),
            onPressed: () => restoreCatalogProduct(context, p, 'deleted'),
          ),
      ] else ...[
        if (p.archivedFromLists)
          TextButton.icon(
            icon: const Icon(Icons.unarchive_outlined),
            label: const Text('Hiện lại'),
            onPressed: () => restoreCatalogProduct(context, p, 'archived'),
          )
        else
          TextButton.icon(
            icon: const Icon(Icons.restore),
            label: const Text('Kinh doanh lại'),
            onPressed: () => restoreCatalogProduct(context, p, 'inactive'),
          ),
      ],
    ],
  );
}

Future<void> restoreCatalogProduct(
  BuildContext context,
  Product p,
  String status,
) async {
  if (!await confirm(
    context,
    'Khôi phục ${p.name}?',
    'Dùng lại đúng mã SKU ${p.code}, giữ nguyên lịch sử và lô cũ.',
  )) {
    return;
  }
  await attempt(() async {
    final controller = Get.find<ShopController>();
    await controller.change((d, a) {
      if (status == 'deleted') {
        d.restoreDeletedProduct(p.id, a);
      } else if (status == 'archived') {
        d.unarchiveDiscontinuedProduct(p.id, a);
      } else {
        d.restoreProduct(p.id, a);
      }
    });
  });
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
  final reverseInitially = p.hasPackConversion && p.ratio < productUnitScale;
  final code = TextEditingController(text: p.code),
      name = TextEditingController(text: p.name),
      size = TextEditingController(text: p.size.trim() == 'm³' ? '' : p.size),
      unit = TextEditingController(text: p.unit),
      secondaryUnit = TextEditingController(
        text: p.secondaryUnitLabel.isNotEmpty
            ? p.secondaryUnitLabel
            : (p.isBulk ? '' : 'thùng'),
      ),
      supplier = TextEditingController(text: p.supplier),
      price = TextEditingController(text: '${p.price}'),
      ratio = TextEditingController(
        text: p.ratio == 0
            ? ''
            : reverseInitially
            ? '${productUnitScale / p.ratio}'
            : '${p.ratio / productUnitScale}',
      ),
      minimum = TextEditingController(
        text: p.minimum == 0 ? '' : '${p.minimum / 10000}',
      ),
      note = TextEditingController(text: p.note);
  var reverseConversion = reverseInitially;
  var saving = false;
  String? reuseId;
  String? reuseAction;
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
                field(
                  code,
                  'Mã sản phẩm / mã vạch',
                  onChanged: (_) => set(() {}),
                  helperText: 'Mã gợi ý tự động; có thể sửa nếu cần. Không tạo mã khác cho một sản phẩm đã tồn tại.',
                ),
                field(name, 'Tên sản phẩm', onChanged: (_) => set(() {})),
                field(
                  size,
                  'Kích thước / quy cách (tùy chọn)',
                  onChanged: (_) => set(() {}),
                ),
                field(
                  unit,
                  'Đơn vị (ví dụ: cái, viên, m², m³)',
                  onChanged: (_) => set(() {}),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: saving
                          ? null
                          : () => set(() => unit.text = 'm²'),
                      child: const Text('Chọn m²'),
                    ),
                    TextButton(
                      onPressed: saving
                          ? null
                          : () => set(() => unit.text = 'm³'),
                      child: const Text('Chọn m³'),
                    ),
                    const Text('Có thể gõ m2 hoặc m3 trên bàn phím.'),
                  ],
                ),
                field(
                  supplier,
                  'Nhà cung cấp (tùy chọn)',
                  onChanged: (_) => set(() {}),
                ),
                if (original == null) ...[
                  Builder(
                    builder: (ctx) {
                      final suggestions = ProductDiscovery.suggest(
                        products: c.data.products,
                        name: name.text,
                        code: code.text,
                        specification: size.text,
                        unit: unit.text,
                        supplier: supplier.text,
                        excludeId: p.id,
                      );
                      if (suggestions.isEmpty) return const SizedBox.shrink();
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7E5),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Có thể sản phẩm đã tồn tại:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 5),
                            const Text(
                              'Hãy đối chiếu tên, quy cách, đơn vị và nhà cung cấp. '
                              'Nhà cung cấp khác chưa chắc là hàng khác hãng.',
                            ),
                            for (final suggestion in suggestions) ...[
                              const Divider(height: 14),
                              Text(
                                suggestion.product.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Mã: ${suggestion.product.code} • '
                                '${suggestion.product.size} • ${suggestion.product.unit}',
                              ),
                              Text(
                                'Nhà cung cấp: ${suggestion.product.supplier.isEmpty ? 'Chưa ghi' : suggestion.product.supplier} '
                                '• Tồn: ${area(suggestion.product.stock)} ${suggestion.product.unit}',
                              ),
                              Text(
                                suggestion.explanation,
                                style: const TextStyle(
                                  color: Color(0xFF76500B),
                                ),
                              ),
                              if (suggestion.product.deleted ||
                                  suggestion.product.archivedFromLists ||
                                  !suggestion.product.active)
                                const Text(
                                  'Sản phẩm đã ngừng/ẩn/xóa mềm. '
                                  'Hãy khôi phục trước khi nhập hàng.',
                                ),
                              Wrap(
                                spacing: 8,
                                children: [
                                  TextButton.icon(
                                    onPressed: saving
                                        ? null
                                        : () {
                                            reuseId = suggestion.product.id;
                                            reuseAction = 'view';
                                            Navigator.pop(ctx);
                                          },
                                    icon: const Icon(
                                      Icons.open_in_new_outlined,
                                    ),
                                    label: const Text('Mở sản phẩm cũ'),
                                  ),
                                  if (!suggestion.product.active ||
                                      suggestion.product.deleted ||
                                      suggestion.product.archivedFromLists)
                                    TextButton.icon(
                                      onPressed: saving
                                          ? null
                                          : () {
                                              reuseId = suggestion.product.id;
                                              reuseAction = 'restore';
                                              Navigator.pop(ctx);
                                            },
                                      icon: const Icon(Icons.restore_outlined),
                                      label: const Text('Khôi phục mã cũ'),
                                    ),
                                  if (suggestion.product.active &&
                                      !suggestion.product.deleted &&
                                      !suggestion.product.archivedFromLists)
                                    TextButton.icon(
                                      onPressed: saving
                                          ? null
                                          : () {
                                              reuseId = suggestion.product.id;
                                              reuseAction = 'receive';
                                              Navigator.pop(ctx);
                                            },
                                      icon: const Icon(Icons.add_box_outlined),
                                      label: const Text('Dùng lại & nhập kho'),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ],
                field(
                  price,
                  'Giá bán đ/${canonicalProductUnit(unit.text)}',
                  moneyInput: true,
                ),
                field(
                  secondaryUnit,
                  'Đơn vị phụ (thùng, hộp, bao, kg, xe...)',
                  onChanged: (_) => set(() {}),
                ),
                field(
                  ratio,
                  reverseConversion
                      ? '1 ${canonicalProductUnit(unit.text).isEmpty ? 'đơn vị chính' : canonicalProductUnit(unit.text)} = bao nhiêu ${canonicalProductUnit(secondaryUnit.text).isEmpty ? 'đơn vị phụ' : canonicalProductUnit(secondaryUnit.text)}?'
                      : '1 ${canonicalProductUnit(secondaryUnit.text).isEmpty ? 'đơn vị phụ' : canonicalProductUnit(secondaryUnit.text)} = bao nhiêu ${canonicalProductUnit(unit.text).isEmpty ? 'đơn vị chính' : canonicalProductUnit(unit.text)}?',
                  number: true,
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text(
                    'Nhập quy đổi chiều ngược (ví dụ 1 bao = 25 kg)',
                  ),
                  value: reverseConversion,
                  onChanged: (v) {
                    final current = decimal(ratio.text);
                    if (current.isFinite && current > 0) {
                      ratio.text = (1 / current).toString();
                    }
                    set(() => reverseConversion = v ?? false);
                  },
                ),
                hint(
                  'Ví dụ: bán cái, nhập thùng: chính cái, phụ thùng, hệ số 5. '
                  'Nếu đang dùng bao làm đơn vị chính: phụ kg, bật chiều ngược, nhập 25 (1 bao = 25 kg). '
                  'Để trống hệ số nếu chỉ dùng một đơn vị. '
                  'Không tự quy đổi các chứng từ cũ.',
                ),
                field(
                  minimum,
                  'Cảnh báo khi tồn kho còn (tùy chọn)',
                  number: true,
                ),
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
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    alignLabelWithHint: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                hint(
                  'Số lượng mua do người bán tự tính và nhập theo đơn vị đã điền. Thay tên đơn vị không tự quy đổi tồn kho.',
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
                      title: Text(_inventoryLotLabel(p, l)),
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
                    final enteredRatio = ratio.text.trim().isEmpty
                            ? 0.0
                            : decimal(ratio.text),
                        m = minimum.text.trim().isEmpty
                            ? 0.0
                            : decimal(minimum.text);
                    final r = reverseConversion && enteredRatio > 0
                        ? 1 / enteredRatio
                        : enteredRatio;
                    if (!r.isFinite || !m.isFinite || enteredRatio < 0) {
                      throw ArgumentError(
                        'Quy đổi hoặc ngưỡng tồn không hợp lệ.',
                      );
                    }
                    p.code = code.text.trim();
                    p.name = name.text.trim();
                    p.size = size.text.trim();
                    if (unit.text.trim().isEmpty ||
                        unit.text.trim().length > 40) {
                      throw ArgumentError('Nhập đơn vị từ 1 đến 40 ký tự.');
                    }
                    p.unitLabel = canonicalProductUnit(unit.text);
                    final secondary = canonicalProductUnit(secondaryUnit.text);
                    if (r > 0 &&
                        (secondary.isEmpty ||
                            secondary == p.unit ||
                            secondary.length > 40 ||
                            areaUnits(r) <= 0)) {
                      throw ArgumentError(
                        'Nhập đơn vị phụ khác đơn vị chính và hệ số lớn hơn 0.',
                      );
                    }
                    p.secondaryUnitLabel = r > 0 ? secondary : '';
                    p.supplier = supplier.text.trim();
                    p.note = note.text.trim();
                    p.price = whole(price.text);
                    p.ratio = areaUnits(r);
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
    unit,
    secondaryUnit,
    supplier,
    price,
    ratio,
    minimum,
    note,
  ]) {
    controller.dispose();
  }
  if (reuseId != null && context.mounted) {
    // Use the latest product snapshot; never create a new SKU on reuse.
    final selected = c.data.products
        .where((item) => item.id == reuseId)
        .firstOrNull;
    if (selected == null) return;
    if (reuseAction == 'restore') {
      final status = selected.deleted
          ? 'deleted'
          : selected.archivedFromLists
          ? 'archived'
          : 'inactive';
      await restoreCatalogProduct(context, selected, status);
    } else if (reuseAction == 'receive') {
      if (!selected.active || selected.deleted || selected.archivedFromLists) {
        await attempt(() async {
          throw StateError(
            'Sản phẩm cũ đã ngừng bán hoặc bị ẩn. '
            'Hãy khôi phục trước khi nhập kho.',
          );
        });
      } else {
        await receiveStock(context, selected);
      }
    } else {
      await editProduct(context, original: selected);
    }
  }
}

/// Standalone, intentional correction workflow. Normal product editing
/// continues to lock unit changes once stock history exists.
Future<void> correctReceivedUnitDialog(BuildContext context, Product original) async {
  final c = Get.find<ShopController>();
  if (c.actor?.canAdmin != true) return;
  final openingJson = jsonEncode(original.toJson());
  final newUnit = TextEditingController(text: ''),
      secondary = TextEditingController(text: original.unit),
      ratio = TextEditingController(),
      newPrice = TextEditingController(),
      reason = TextEditingController();
  final lotQuantities = <String, TextEditingController>{
    for (final lot in original.lots)
      (lot['id'] as String): TextEditingController(),
  };
  var confirmed = false;
  var saving = false;
  try {
    await safeDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('Đính chính đơn vị nhập nhầm'),
          content: SizedBox(
            width: 640,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sản phẩm: ${original.code} • ${original.name}'),
                  const SizedBox(height: 8),
                  Text('Đơn vị đã nhập sai: ${original.unit}'),
                  const SizedBox(height: 8),
                  const Text(
                    'CHỈ DÙNG nếu sản phẩm mới có phiếu nhập, chưa bán/xuất, '
                    'chưa giữ hàng. Các thiết bị khác phải đồng bộ xong.',
                    style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  field(newUnit, 'Đơn vị chính đúng (ví dụ m²)'),
                  field(secondary, 'Đơn vị phụ (ví dụ thùng; để trống nếu không dùng)'),
                  field(ratio, '1 đơn vị phụ = bao nhiêu đơn vị chính?', number: true),
                  field(newPrice, 'Giá bán mới / đơn vị chính (đ)', moneyInput: true),
                  const SizedBox(height: 12),
                  const Text('Nhập số lượng THỰC TẾ của từng lô theo đơn vị chính mới:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  for (final lot in original.lots) ...[
                    const SizedBox(height: 10),
                    Text('${_inventoryLotLabel(original, lot)} — '
                        'đã ghi ${area(lot['area'])} ${original.unit}; '
                        'giá vốn ${money(lot['cost'])}/${original.unit}'),
                    field(lotQuantities[lot['id'] as String]!,
                        'Số lượng đúng (${lot['id']})', number: true),
                  ],
                  const SizedBox(height: 12),
                  const Text('Giá vốn mỗi lô được quy đổi để giữ tổng tiền vốn cũ '
                      '(có thể làm tròn đến đồng). Ngưỡng cảnh báo tồn sẽ đặt lại 0.'),
                  field(reason, 'Lý do sửa sai (tối thiểu 10 ký tự)'),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Tôi đã đối chiếu phiếu nhập, tồn thực tế và các thiết bị khác; '
                        'sản phẩm chưa từng bán/xuất/giữ hàng.'),
                    value: confirmed,
                    onChanged: saving ? null : (v) => set(() => confirmed = v ?? false),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('Hủy')),
            FilledButton(
              onPressed: saving || !confirmed ? null : () => attempt(() async {
                final canonical = canonicalProductUnit(newUnit.text);
                final second = canonicalProductUnit(secondary.text);
                final rawFactor = ratio.text.trim().isEmpty
                    ? 0.0 : decimal(ratio.text);
                if (canonical.isEmpty || !rawFactor.isFinite || rawFactor < 0 ||
                    (second.isNotEmpty && rawFactor <= 0) ||
                    (second.isEmpty && rawFactor > 0)) {
                  throw ArgumentError('Nhập đúng đơn vị và hệ số quy đổi.');
                }
                final adjusted = <String, int>{};
                for (final lot in original.lots) {
                  final id = lot['id'] as String;
                  final amount = decimal(lotQuantities[id]!.text);
                  if (!amount.isFinite || amount <= 0) {
                    throw ArgumentError('Phải nhập số lượng thực tế của lô $id.');
                  }
                  adjusted[id] = areaUnits(amount);
                }
                final price = whole(newPrice.text);
                if (price <= 0) {
                  throw ArgumentError('Cần xác nhận giá bán theo đơn vị mới.');
                }
                set(() => saving = true);
                try {
                  await c.verifyUnitCorrectionReady();
                  await c.change((d, a) => d.correctReceivedProductUnit(
                    productId: original.id,
                    expectedProductJson: openingJson,
                    newUnit: canonical,
                    secondaryUnit: second,
                    newRatio: areaUnits(rawFactor),
                    newSalePrice: price,
                    actualLotQuantities: adjusted,
                    reason: reason.text,
                    actor: a,
                  ));
                  if (ctx.mounted) Navigator.pop(ctx);
                } finally {
                  if (ctx.mounted) set(() => saving = false);
                }
              }),
              child: const Text('Xác nhận đính chính'),
            ),
          ],
        ),
      ),
    );
  } finally {
    for (final controller in [newUnit, secondary, ratio, newPrice, reason, ...lotQuantities.values]) {
      controller.dispose();
    }
  }
}

Future<String?> pickImage() async {
  final live = Get.find<ShopController>().isLive;
  final image = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    // Browser/iOS pickers may ignore resize options. The second-stage
    // adaptive compressor below is the actual 40 KB safeguard.
    maxWidth: live ? 640 : 1200,
    maxHeight: live ? 640 : 1200,
    imageQuality: live ? 80 : 75,
  );
  if (image == null) return null;
  final bytes = await image.readAsBytes();
  if (live) {
    // No Cloudinary, no change to Firestore schema or existing photos.
    return encodeProductPhotoForFirestore(bytes);
  }
  if (bytes.length > 600000) {
    throw StateError('Ảnh quá lớn cho bản thử. Vui lòng chọn ảnh dưới 600 KB.');
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
