part of 'app.dart';

String invoiceCustomer(ShopData data, Json order) =>
    data.customers
        .where((c) => c['id'] == order['customerId'])
        .map((c) => c['name'] as String)
        .firstOrNull ??
    (order['customerId'] == '' ? 'Khách lẻ' : 'Khách ${order['customerId']}');

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
        TextField(
          controller: search,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: 'Tìm mã hóa đơn hoặc tên khách',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, box) {
            final width = box.maxWidth < 540
                ? box.maxWidth
                : (box.maxWidth - 12) / 2;
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
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          titleText('Hóa đơn bán hàng'),
          const SizedBox(height: 8),
          hint(
            'Lấy trực tiếp từ đơn đã bán • Bấm một hóa đơn để xem sản phẩm và in PDF',
          ),
          const SizedBox(height: 12),
          filters(),
          if (!filter.valid)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Nhập số tiền nguyên không âm; mức từ phải nhỏ hơn hoặc bằng mức đến.',
                style: TextStyle(color: Colors.red),
              ),
            ),
          const SizedBox(height: 16),
          panel(
            LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: box.maxWidth),
                  child: DataTable(
                    showCheckboxColumn: false,
                    horizontalMargin: 12,
                    columnSpacing: 28,
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
                                  o['id'],
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
                                    (o['total'] as int) - ShopData.collected(o),
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
            : PdfPreview(
                key: ValueKey(jsonEncode(order)),
                pdfFileName: 'hoa-don-$orderId.pdf',
                // The PDF preview toolbar must contrast with its action icons.
                // Keep native Print/Share behavior unchanged across platforms.
                actionBarTheme: const PdfActionBarTheme(
                  backgroundColor: Color(0xFFF2F6FC),
                  iconColor: Color(0xFF0759BE),
                  height: 58,
                  elevation: 1,
                ),
                canChangeOrientation: false,
                canChangePageFormat: false,
                canDebug: false,
                allowPrinting: true,
                allowSharing: true,
                build: (_) => PrintService.invoicePdf(
                  order,
                  invoiceCustomer(c.data, order),
                  demo: !c.isLive,
                ),
                onError: (context, error) => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Chưa tạo được PDF. Kiểm tra mạng để tải phông chữ rồi mở lại hóa đơn.',
                    ),
                  ),
                ),
              ),
      );
    },
  );
}
