part of 'app.dart';

String invoiceCustomer(ShopData data, Json order) {
  return PrintService.customerSnapshot(order);
}

class InvoicesPage extends StatefulWidget {
  const InvoicesPage({super.key});
  @override
  State<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends State<InvoicesPage> {
  final search = TextEditingController(),
      minimum = TextEditingController(),
      maximum = TextEditingController();
  InvoicePayment payment = InvoicePayment.all;
  String period = 'Toàn bộ', sort = 'Mới nhất';
  DateTimeRange? range;
  int invoicePage = 0;
  bool advancedFiltersExpanded = false;

  @override
  void dispose() {
    for (final c in [search, minimum, maximum]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> selectPeriod(String value) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTimeRange? next;
    if (value == 'Tùy chọn') {
      next = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime(now.year + 10),
        initialDateRange: range,
      );
      if (next == null || !mounted) return;
    } else if (value == 'Hôm nay') {
      next = DateTimeRange(start: today, end: today);
    } else if (value == '7 ngày qua') {
      next = DateTimeRange(
        start: today.subtract(const Duration(days: 6)),
        end: today,
      );
    } else if (value == 'Tháng này') {
      next = DateTimeRange(start: DateTime(now.year, now.month), end: today);
    }
    setState(() {
      period = value;
      range = next;
    });
  }

  void reset() => setState(() {
    search.clear();
    minimum.clear();
    maximum.clear();
    payment = InvoicePayment.all;
    period = 'Toàn bộ';
    sort = 'Mới nhất';
    range = null;
    invoicePage = 0;
  });

  Widget filters() => panel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, box) {
            final columns = box.maxWidth >= 1000
                ? 4
                : box.maxWidth >= 540
                ? 2
                : 1;
            final width = (box.maxWidth - (columns - 1) * 12) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: width,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    key: ValueKey('period-$period'),
                    initialValue: period,
                    decoration: const InputDecoration(labelText: 'Ngày bán'),
                    items:
                        [
                              'Toàn bộ',
                              'Hôm nay',
                              '7 ngày qua',
                              'Tháng này',
                              'Tùy chọn',
                            ]
                            .map(
                              (v) => DropdownMenuItem(value: v, child: Text(v)),
                            )
                            .toList(),
                    onChanged: (v) {
                      if (v != null) selectPeriod(v);
                    },
                  ),
                ),
                SizedBox(
                  width: width,
                  child: DropdownButtonFormField<InvoicePayment>(
                    isExpanded: true,
                    key: ValueKey(payment),
                    initialValue: payment,
                    decoration: const InputDecoration(labelText: 'Thanh toán'),
                    items: const [
                      DropdownMenuItem(
                        value: InvoicePayment.all,
                        child: Text('Tất cả thanh toán'),
                      ),
                      DropdownMenuItem(
                        value: InvoicePayment.owing,
                        child: Text('Còn nợ'),
                      ),
                      DropdownMenuItem(
                        value: InvoicePayment.unpaid,
                        child: Text('Chưa trả'),
                      ),
                      DropdownMenuItem(
                        value: InvoicePayment.partial,
                        child: Text('Trả một phần'),
                      ),
                      DropdownMenuItem(
                        value: InvoicePayment.paid,
                        child: Text('Đã trả hết'),
                      ),
                    ],
                    onChanged: (v) => setState(() => payment = v!),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: TextField(
                    controller: minimum,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Tổng tiền từ (đ)',
                      hintText: 'Không giới hạn',
                    ),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: TextField(
                    controller: maximum,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Tổng tiền đến (đ)',
                      hintText: 'Không giới hạn',
                    ),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    key: ValueKey('sort-$sort'),
                    initialValue: sort,
                    decoration: const InputDecoration(labelText: 'Sắp xếp'),
                    items:
                        [
                              'Mới nhất',
                              'Cũ nhất',
                              'Tổng tiền cao nhất',
                              'Còn nợ nhiều nhất',
                            ]
                            .map(
                              (v) => DropdownMenuItem(value: v, child: Text(v)),
                            )
                            .toList(),
                    onChanged: (v) => setState(() => sort = v!),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: reset,
                  icon: const Icon(Icons.filter_alt_off_outlined),
                  label: const Text('Xóa bộ lọc'),
                ),
                if (range != null)
                  TextButton.icon(
                    onPressed: () => selectPeriod('Tùy chọn'),
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      '${DateFormat('dd/MM/yyyy').format(range!.start)} – ${DateFormat('dd/MM/yyyy').format(range!.end)}',
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    ),
    padding: const EdgeInsets.all(16),
  );
  @override
  Widget build(BuildContext context) => GetBuilder<ShopController>(
    builder: (c) {
      final filter = InvoiceFilter(
        query: search.text,
        payment: payment,
        from: range?.start,
        through: range?.end,
        minimum: minimum.text.trim().isEmpty
            ? null
            : int.tryParse(minimum.text.trim()) ?? -1,
        maximum: maximum.text.trim().isEmpty
            ? null
            : int.tryParse(maximum.text.trim()) ?? -1,
      );
      final invoices =
          c.data.orders
              .where((o) => filter.matches(o, invoiceCustomer(c.data, o)))
              .toList()
            ..sort(
              (a, b) => switch (sort) {
                'Cũ nhất' => '${a['soldAt'] ?? a['at']}'.compareTo(
                  '${b['soldAt'] ?? b['at']}',
                ),
                'Tổng tiền cao nhất' => (b['total'] as int).compareTo(
                  a['total'] as int,
                ),
                'Còn nợ nhiều nhất' =>
                  ((b['total'] as int) - ShopData.collected(b)).compareTo(
                    (a['total'] as int) - ShopData.collected(a),
                  ),
                _ => '${b['soldAt'] ?? b['at']}'.compareTo(
                  '${a['soldAt'] ?? a['at']}',
                ),
              },
            );
      final compact = MediaQuery.sizeOf(context).width < 600;
      return ListView(
        padding: vlxdPagePadding(context),
        children: [
          titleText('Hóa đơn bán hàng'),
          const SizedBox(height: 8),
          hint(
            'Lấy trực tiếp từ đơn đã bán • Bấm một hóa đơn để xem sản phẩm và in PDF',
          ),
          const SizedBox(height: 12),
          panel(
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('invoice-search'),
                    controller: search,
                    onChanged: (_) => setState(() {
                      invoicePage = 0;
                    }),
                    decoration: const InputDecoration(
                      hintText: 'Tìm mã hóa đơn hoặc tên khách',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  key: const ValueKey('invoice-filter-toggle'),
                  onPressed: () => setState(
                    () => advancedFiltersExpanded = !advancedFiltersExpanded,
                  ),
                  icon: Icon(advancedFiltersExpanded
                      ? Icons.expand_less
                      : Icons.tune),
                  label: Text(advancedFiltersExpanded
                      ? 'Ẩn lọc'
                      : (compact ? 'Lọc' : 'Bộ lọc')),
                ),
              ],
            ),
            padding: const EdgeInsets.all(10),
          ),
          if (advancedFiltersExpanded) ...[
            const SizedBox(height: 8),
            filters(),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              '${invoices.length} hóa đơn • $period',
              style: const TextStyle(color: Color(0xFF657993)),
            ),
          ),
          if (!filter.valid)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Nhập số tiền nguyên không âm; mức từ phải nhỏ hơn hoặc bằng mức đến.',
                style: TextStyle(color: Colors.red),
              ),
            ),
          const SizedBox(height: 8),
          if (compact)
            ...invoices
                .skip(
                  math.min(
                        invoicePage,
                        math.max(0, (invoices.length - 1) ~/ 10),
                      ) *
                      10,
                )
                .take(10)
                .map(
                  (invoice) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${invoice['id']}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: blue,
                                ),
                              ),
                            ),
                            Text(
                              money(invoice['total']),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              invoiceCustomer(c.data, invoice),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              day(invoice['soldAt'] ?? invoice['at']),
                              style: const TextStyle(fontSize: 12),
                            ),
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
                          ],
                        ),
                        onTap: () => showOrder(context, invoice),
                      ),
                    ),
                  ),
                ),
          if (!compact)
            panel(
              LayoutBuilder(
                builder: (context, box) => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: box.maxWidth),
                    child: DataTable(
                      showCheckboxColumn: false,
                      horizontalMargin: 12,
                      columnSpacing: 20,
                      headingRowColor: const WidgetStatePropertyAll(
                        Color(0xFFF0F4FA),
                      ),
                      columns: const [
                        DataColumn(label: Text('Mã hóa đơn')),
                        DataColumn(label: Text('Tên khách')),
                        DataColumn(label: Text('Ngày bán')),
                        DataColumn(label: Text('Tổng tiền'), numeric: true),
                        DataColumn(label: Text('Đã trả'), numeric: true),
                        DataColumn(label: Text('Còn nợ'), numeric: true),
                        DataColumn(label: Text('Chi tiết')),
                      ],
                      dataRowMinHeight: 42,
                      dataRowMaxHeight: 60,
                      rows: invoices
                          .skip(
                            math.min(
                                  invoicePage,
                                  math.max(0, (invoices.length - 1) ~/ 10),
                                ) *
                                10,
                          )
                          .take(10)
                          .map(
                            (o) => DataRow(
                              onSelectChanged: (_) => showOrder(context, o),
                              cells: [
                                DataCell(
                                  Text(
                                    o['status'] == 'Đã trả hàng'
                                        ? '${o['id']} • Đã trả hàng'
                                        : o['id'],
                                    style: const TextStyle(
                                      color: blue,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                DataCell(Text(invoiceCustomer(c.data, o))),
                                DataCell(Text(day(o['soldAt'] ?? o['at']))),
                                DataCell(Text(money(o['total']))),
                                DataCell(Text(money(ShopData.collected(o)))),
                                DataCell(
                                  Text(
                                    money(
                                      o['status'] == 'Đã trả hàng'
                                          ? 0
                                          : (o['total'] as int) -
                                                ShopData.collected(o),
                                    ),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  IconButton(
                                    tooltip: 'Xem chi tiết hóa đơn',
                                    icon: const Icon(
                                      Icons.visibility_outlined,
                                      color: blue,
                                    ),
                                    onPressed: () => showOrder(context, o),
                                  ),
                                ),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ),
              padding: const EdgeInsets.all(12),
            ),
          VlxdPager(
            total: invoices.length,
            page: math.min(
              invoicePage,
              math.max(0, (invoices.length - 1) ~/ 10),
            ),
            pageSize: 10,
            onChanged: (v) => setState(() => invoicePage = v),
          ),
          if (invoices.isEmpty)
            const EmptyState(
              'Chưa có hóa đơn phù hợp',
              'Đơn hoàn tất bán hàng sẽ tự xuất hiện ở đây. Đơn giữ hàng hoặc đã hủy chưa tính là hóa đơn bán hàng.',
              Icons.receipt_long_outlined,
            ),
          const SizedBox(height: 12),
          hint(
            '${invoices.length} hóa đơn • Tổng ${money(invoices.fold<int>(0, (s, o) => s + (o['total'] as int)))} • Còn nợ ${money(invoices.fold<int>(0, (s, o) => s + (o['total'] as int) - ShopData.collected(o)))}',
          ),
        ],
      );
    },
  );
}

class InvoicePdfPage extends StatelessWidget {
  final String orderId;
  const InvoicePdfPage({super.key, required this.orderId});
  @override
  Widget build(BuildContext context) => GetBuilder<ShopController>(
    builder: (c) {
      final order = c.data.orders
          .where((o) => o['id'] == orderId && o['status'] == 'Đã bán')
          .firstOrNull;
      return Scaffold(
        appBar: AppBar(title: Text('Hóa đơn $orderId • PDF')),
        body: order == null
            ? const Center(
                child: Text('Hóa đơn không còn khả dụng trong phiên này.'),
              )
            : InvoicePrintPreview(order: order, demo: !c.isLive),
      );
    },
  );
}

/// Shared preview and application-only warning, outside the customer PDF.
class InvoicePrintPreview extends StatefulWidget {
  final Json order;
  final bool demo;
  final bool provisional;
  const InvoicePrintPreview({
    super.key,
    required this.order,
    this.demo = false,
    this.provisional = false,
  });
  @override
  State<InvoicePrintPreview> createState() => _InvoicePrintPreviewState();
}

// Two separate views: paper selection first, PDF preview only after choosing.
enum _InvoicePaper { k80, a4 }

class _InvoicePaperSelector extends StatelessWidget {
  final ValueChanged<_InvoicePaper> onSelect;
  const _InvoicePaperSelector({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    Widget option({
      required String keyName,
      required _InvoicePaper paper,
      required IconData icon,
      required String title,
      required String description,
      bool primary = false,
    }) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: OutlinedButton(
        key: ValueKey(keyName),
        onPressed: () => onSelect(paper),
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          foregroundColor: const Color(0xFF142D50),
          backgroundColor: primary
              ? const Color(0xFFEAF3FF)
              : Colors.white,
          side: BorderSide(
            color: primary ? const Color(0xFF086EEB) : const Color(0xFFD4E0F0),
            width: primary ? 1.5 : 1,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 14 : 20,
            vertical: compact ? 15 : 20,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: compact ? 28 : 32, color: const Color(0xFF0759BE)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF57718F),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 22),
          ],
        ),
      ),
    );

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.print_outlined,
                size: 34,
                color: Color(0xFF0759BE),
              ),
              const SizedBox(height: 12),
              const Text(
                'Chọn khổ giấy',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              const Text(
                'Chọn một mẫu để xem trước, sau đó in hoặc chia sẻ.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF57718F)),
              ),
              const SizedBox(height: 22),
              option(
                keyName: 'invoice-select-k80',
                paper: _InvoicePaper.k80,
                icon: Icons.receipt_long_outlined,
                title: 'K80 · In nhiệt (ưu tiên)',
                description: 'Giấy cuộn 80 mm · Máy in KV804 · Tiết kiệm giấy',
                primary: true,
              ),
              option(
                keyName: 'invoice-select-a4',
                paper: _InvoicePaper.a4,
                icon: Icons.description_outlined,
                title: 'A4 · In giấy thường',
                description: 'Khổ A4 · Bảng hàng hóa đầy đủ',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InvoicePrintPreviewState extends State<InvoicePrintPreview> {
  _InvoicePaper? selectedPaper;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final paper = selectedPaper;
    return Column(
      children: [
        InvoiceSnapshotWarning(order: widget.order),
        if (paper == null)
          Expanded(
            child: _InvoicePaperSelector(
              onSelect: (value) => setState(() => selectedPaper = value),
            ),
          )
        else ...[
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 6 : 16,
              vertical: 6,
            ),
            color: const Color(0xFFF2F6FC),
            child: Row(
              children: [
                TextButton.icon(
                  key: const ValueKey('invoice-back-to-paper'),
                  onPressed: () => setState(() => selectedPaper = null),
                  icon: const Icon(Icons.arrow_back, size: 19),
                  label: Text(compact ? 'Đổi khổ' : 'Quay lại chọn khổ giấy'),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    paper == _InvoicePaper.k80
                        ? 'Xem trước · K80'
                        : 'Xem trước · A4',
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, limits) {
                // Printing's maxPageWidth limits only the on-screen preview.
                // It does not change the generated PDF or printer paper size.
                final available = math.max(200.0, limits.maxWidth - 24);
                // Keep the receipt readable without stretching it across the window.
                // Rendering DPI is independent of the PDF page size and print layout.
                final maxPageWidth = paper == _InvoicePaper.k80
                    ? math.min(380.0, available)
                    : math.min(640.0, available);
                final previewDpi = paper == _InvoicePaper.k80 ? 216.0 : 160.0;
                return PdfPreview(
                  key: ValueKey(
                    'invoice-pdf-${paper.name}-${jsonEncode(widget.order)}',
                  ),
                  maxPageWidth: maxPageWidth,
                  dpi: previewDpi,
                  pdfFileName:
                      'hoa-don-${widget.order['id']}-${paper == _InvoicePaper.k80 ? 'K80' : 'A4'}.pdf',
                  actionBarTheme: const PdfActionBarTheme(
                    backgroundColor: Color(0xFFF2F6FC),
                    iconColor: Color(0xFF0759BE),
                    height: 52,
                    elevation: 1,
                  ),
                  canChangeOrientation: false,
                  canChangePageFormat: false,
                  dynamicLayout: false,
                  canDebug: false,
                  build: (_) => paper == _InvoicePaper.k80
                      ? PrintService.receipt80Pdf(
                          widget.order,
                          PrintService.customerSnapshot(widget.order),
                          provisional: widget.provisional,
                          demo: widget.demo,
                        )
                      : PrintService.invoicePdf(
                          widget.order,
                          PrintService.customerSnapshot(widget.order),
                          demo: widget.demo,
                          provisional: widget.provisional,
                        ),
                  onError: (context, error) => const Center(
                    child: Text(
                      'Chưa tạo được PDF. Kiểm tra dữ liệu hóa đơn và thử mở lại.',
                    ),
                  ),
                );
              },
            ),
          ),
          if (compact)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: Text(
                'Chạm hai lần hoặc dùng hai ngón để phóng to khi đọc.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Color(0xFF57718F)),
              ),
            ),
        ],
      ],
    );
  }
}

class InvoiceSnapshotWarning extends StatelessWidget {
  final Json order;
  const InvoiceSnapshotWarning({super.key, required this.order});
  @override
  Widget build(BuildContext context) {
    final warnings = PrintService.invoiceWarnings(order);
    if (warnings.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(12),
      color: const Color(0xFFFFF3CD),
      child: Text(warnings.join('\n')),
    );
  }
}

Future<bool> confirmInvoiceSnapshot(BuildContext context, Json order) async {
  if (PrintService.invoiceWarnings(order).isEmpty) return true;
  return await safeDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Kiểm tra chứng từ cũ trước khi in'),
          content: SingleChildScrollView(
            child: InvoiceSnapshotWarning(order: order),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('In phần dữ liệu đã lưu'),
            ),
          ],
        ),
      ) ??
      false;
}
