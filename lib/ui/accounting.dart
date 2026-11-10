part of 'app.dart';

// VLXD Bảy Hải – accounting workspace.
// This workspace is read-only against ShopData. Working notes are stored locally
// per installation and never alter invoices, receipts, stock or tax records.

class _AccLine {
  final String id, date, type, customer, description, status;
  final int amount, collected;
  final bool confirmed;
  const _AccLine(
    this.id,
    this.date,
    this.type,
    this.customer,
    this.description,
    this.status,
    this.amount,
    this.collected,
    this.confirmed,
  );
  int get due => amount - collected;
}

class _AccDraft {
  final String key, reason, note, author, created, reference;
  final bool reviewed;
  const _AccDraft(
    this.key,
    this.reason,
    this.note,
    this.author,
    this.created,
    this.reference,
    this.reviewed,
  );
  Map<String, dynamic> toJson() => {
    'key': key,
    'reason': reason,
    'note': note,
    'author': author,
    'created': created,
    'reference': reference,
    'reviewed': reviewed,
  };
  factory _AccDraft.fromJson(Map<String, dynamic> v) => _AccDraft(
    '${v['key'] ?? ''}',
    '${v['reason'] ?? ''}',
    '${v['note'] ?? ''}',
    '${v['author'] ?? ''}',
    '${v['created'] ?? ''}',
    '${v['reference'] ?? ''}',
    v['reviewed'] == true,
  );
}

String _accString(Object? value) => value?.toString() ?? '';
int _accInt(Object? value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;
String _accDate(Object? value) {
  final d = DateTime.tryParse(_accString(value));
  return d == null ? '' : DateFormat('yyyy-MM-dd').format(d.toLocal());
}

String _accDateDisplay(String date) {
  final d = DateTime.tryParse(date);
  return d == null ? date : DateFormat('dd/MM/yyyy').format(d);
}

String _accCustomer(ShopData data, Map<String, dynamic> order) {
  final id = _accString(order['customerId']);
  for (final c in data.customers) {
    if (_accString(c['id']) == id) return _accString(c['name']);
  }
  return id.isEmpty ? 'Khách lẻ' : id;
}

List<_AccLine> _accSales(ShopData data) {
  final list = <_AccLine>[];
  for (final o in data.orders) {
    final status = _accString(o['status']);
    if (status != 'Đã bán') continue;
    final raw = <String, dynamic>{...o};
    list.add(
      _AccLine(
        _accString(o['id']),
        _accDate(o['soldAt'] ?? o['at']),
        'Bán hàng',
        _accCustomer(data, raw),
        (o['lines'] is List)
            ? (o['lines'] as List)
                  .map((e) => _accString(e is Map ? e['name'] : e))
                  .take(3)
                  .join(', ')
            : '',
        status,
        _accInt(o['total']),
        ShopData.netCollected(raw),
        true,
      ),
    );
  }
  list.sort((a, b) => b.date.compareTo(a.date));
  return list;
}

List<List<Object?>> _accPaymentRows(ShopData data) {
  final rows = <List<Object?>>[
    [
      'Mã đơn',
      'Mã thu',
      'Ngày thu',
      'Khách hàng',
      'Số tiền',
      'Đã hủy',
      'Người thu',
      'Lý do điều chỉnh',
    ],
  ];
  for (final o in data.orders) {
    final order = <String, dynamic>{...o};
    final payments = o['payments'];
    if (payments is! List) continue;
    for (final p in payments) {
      if (p is! Map) continue;
      rows.add([
        _accString(o['id']),
        _accString(p['id']),
        _accDate(p['at']),
        _accCustomer(data, order),
        _accInt(p['amount']),
        p['voided'] == true ? 'Có' : 'Không',
        _accString(p['actor']),
        _accString(p['voidReason']),
      ]);
    }
  }
  return rows;
}

List<List<Object?>> _accStockRows(ShopData data) => [
  [
    'Mã hàng',
    'Tên hàng',
    'Đơn vị',
    'Tồn',
    'Giữ',
    'Khả dụng',
    'Giá bán niêm yết',
    'Cảnh báo',
  ],
  for (final p in data.products)
    [
      p.code,
      p.name,
      p.unit,
      p.stock / 10000,
      p.reserved / 10000,
      p.available / 10000,
      p.price,
      p.available <= p.minimum ? 'Tồn thấp' : '',
    ],
];

List<List<Object?>> _accLotsRows(ShopData data) => [
  [
    'Mã hàng',
    'Mã lô',
    'Ngày nhập',
    'Đơn vị',
    'Tồn lô',
    'Giữ lô',
    'Giá vốn lô/đơn vị',
    'SL nhập gốc (ước tính nếu thiếu chứng từ)',
    'Tiền nhập',
    'Nguồn số liệu',
  ],
  for (final p in data.products)
    for (final l in p.lots)
      if (!_accString(l['id']).startsWith('AM-'))
        (() {
          final item = _accResolveLot(data, p, l);
          return <Object?>[
            p.code,
            _accString(l['id']),
            _accDate(l['date']),
            p.unit,
            _accInt(l['area']) / 10000,
            _accInt(l['reserved']) / 10000,
            _accInt(l['cost']),
            item.units == null ? '' : item.units! / 10000,
            item.amount ?? '',
            item.source,
          ];
        })(),
];

List<List<Object?>> _accMovesRows(ShopData data) => [
  [
    'Ngày',
    'Loại biến động',
    'Mã hàng',
    'Số lượng gốc (1/10000)',
    'Mã tham chiếu',
  ],
  for (final m in data.stockMoves)
    [
      _accDate(m['at']),
      _accString(m['type']),
      _accString(m['product']),
      _accInt(m['area']),
      _accString(m['reference'] ?? m['id']),
    ],
];

List<List<Object?>> _accDebtRows(ShopData data) => [
  [
    'Mã khách',
    'Khách hàng',
    'Điện thoại',
    'Phải thu',
    'Đã nhận',
    'Còn nợ',
    'Điều chỉnh phải thu',
    'Điều chỉnh đã thu',
  ],
  for (final p in data.customers)
    [
      _accString(p['id']),
      _accString(p['name']),
      _accString(p['phone']),
      data.customerBook(_accString(p['id'])).receivable,
      data.customerBook(_accString(p['id'])).received,
      data.debt(_accString(p['id'])),
      _accInt(p['receivableAdjustment']),
      _accInt(p['receivedAdjustment']),
    ],
];

// Recover quantities for old lots without modifying persisted transactions.
// A stored original receipt or uniquely matched stock receipt is preferable.
// Only when those are absent, estimate the original lot quantity from current
// stock + confirmed sold allocations. Other stock adjustments may make the
// estimate differ from the original purchase, so never label it verified.
class _AccLotResolution {
  final int? units;
  final int? amount;
  final bool estimated;
  final String source;
  const _AccLotResolution(this.units, this.amount, this.estimated, this.source);
}

_AccLotResolution _accResolveLot(ShopData data, Product product, Json lot) {
  final lotId = _accString(lot['id']);
  final price = lot['cost'];
  if (lotId.startsWith('AM-') || price is! num || price < 0) {
    return const _AccLotResolution(null, null, false, 'Chưa đủ dữ liệu');
  }

  final original =
      lot['initialArea'] ?? lot['receivedArea'] ?? lot['originalArea'];
  if (original is num && original >= 0) {
    final units = original.toInt();
    return _AccLotResolution(
      units,
      lineMoney(units, price.toInt()),
      false,
      'Số lượng nhập gốc',
    );
  }

  final matchingLots = product.lots
      .where((v) => _accString(v['id']) == lotId)
      .length;
  final receiptMoves = data.stockMoves
      .where(
        (move) =>
            _accString(move['type']) == 'Nhập kho' &&
            _accString(move['product']) == product.code &&
            _accString(move['lot']) == lotId &&
            _accInt(move['area']) > 0,
      )
      .toList();
  if (matchingLots == 1 && receiptMoves.length == 1) {
    final units = _accInt(receiptMoves.single['area']);
    final historicalCost = receiptMoves.single['cost'];
    final unitPrice = historicalCost is num
        ? historicalCost.toInt()
        : price.toInt();
    return _AccLotResolution(
      units,
      lineMoney(units, unitPrice),
      historicalCost is! num,
      historicalCost is num
          ? 'Lịch sử nhập kho'
          : 'Lịch sử nhập · giá lô hiện tại',
    );
  }

  // Legacy sample/import lots can predate stockMoves. Rebuild conservatively
  // from sold order allocations; held orders are not deducted from lot area.
  if (matchingLots == 1 && receiptMoves.isEmpty) {
    final remaining = lot['area'];
    if (remaining is num && remaining >= 0) {
      var soldUnits = 0;
      for (final order in data.orders) {
        if (_accString(order['status']) != 'Đã bán') continue;
        final lines = order['lines'];
        if (lines is! List) continue;
        for (final line in lines) {
          if (line is! Map || _accString(line['productId']) != product.id)
            continue;
          final allocations = line['allocations'];
          if (allocations is! List) continue;
          for (final allocation in allocations) {
            if (allocation is Map && _accString(allocation['lot']) == lotId) {
              soldUnits += _accInt(allocation['area']);
            }
          }
        }
      }
      final units = remaining.toInt() + soldUnits;
      return _AccLotResolution(
        units,
        lineMoney(units, price.toInt()),
        true,
        'Tạm tính từ tồn + đã bán',
      );
    }
  }
  return const _AccLotResolution(null, null, false, 'Cần đối chiếu chứng từ');
}

class _AccPurchaseSummary {
  final int? amount;
  final int lotCount;
  final int completeLots;
  final int estimatedLots;
  const _AccPurchaseSummary(
    this.amount,
    this.lotCount,
    this.completeLots,
    this.estimatedLots,
  );
  bool get complete =>
      amount != null && completeLots == lotCount && estimatedLots == 0;
  bool get partial => completeLots < lotCount;
  bool get estimated => estimatedLots > 0;
  String get status => amount == null
      ? 'Chưa đủ dữ liệu'
      : partial
      ? 'Chưa đủ dữ liệu · tổng phần tính được'
      : estimated
      ? 'Tạm tính · đối chiếu phiếu nhập'
      : 'Đã đối chiếu';
}

_AccPurchaseSummary _accPurchaseSummary(
  ShopData data,
  bool Function(String) inPeriod,
) {
  var total = 0;
  var count = 0;
  var resolved = 0;
  var estimated = 0;
  for (final p in data.products) {
    for (final lot in p.lots) {
      if (_accString(lot['id']).startsWith('AM-')) continue;
      if (!inPeriod(_accDate(lot['date']))) continue;
      count++;
      final value = _accResolveLot(data, p, lot);
      if (value.amount != null) {
        total += value.amount!;
        resolved++;
        if (value.estimated) estimated++;
      }
    }
  }
  return _AccPurchaseSummary(
    count == 0 || resolved == 0 ? null : total,
    count,
    resolved,
    estimated,
  );
}

class AccountingPage extends StatefulWidget {
  const AccountingPage({super.key});
  @override
  State<AccountingPage> createState() => _AccountingPageState();
}

class _AccountingPageState extends State<AccountingPage> {
  String tab = 'Tổng hợp', period = 'Tháng', keyword = '';
  String overviewType = 'Tất cả các sổ';
  String paymentFilter = 'Tất cả trạng thái';
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  bool exporting = false;
  final Set<String> _temporarilyExcluded = <String>{};
  final Set<String> _temporaryLots = <String>{};
  int _page = 0;
  static const int _pageSize = 12;
  void _setTab(String next) => setState(() {
    tab = next;
    _page = 0;
  });
  String _lotKey(List<Object?> row) =>
      'LOT:${_accString(row[0])}:${_accString(row[1])}';
  String _ledgerRowKey(String ledger, List<Object?> row) {
    // Stable identity: payment ID, customer ID, or product code.
    final index = ledger == 'Sổ thu chi' && row.length > 1 ? 1 : 0;
    return 'LEDGER:$ledger:${_accString(row[index])}';
  }

  final Map<String, _AccDraft> drafts = {};
  static const _prefsKey = 'vlxd_accounting_working_notes_v1';
  static const _tabs = [
    'Tổng hợp',
    'Sổ bán hàng',
    'Sổ nhập hàng',
    'Sổ thu chi',
    'Công nợ',
    'Tồn kho',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_prefsKey);
      if (raw == null) return;
      final value = jsonDecode(raw);
      if (value is List && mounted) {
        setState(() {
          for (final item in value) {
            if (item is Map) {
              final note = _AccDraft.fromJson(Map<String, dynamic>.from(item));
              if (note.key.isNotEmpty) drafts[note.key] = note;
            }
          }
        });
      }
    } catch (_) {
      /* No edits to transactional data on read failure. */
    }
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _prefsKey,
      jsonEncode(drafts.values.map((e) => e.toJson()).toList()),
    );
  }

  bool _inPeriod(String value) {
    final d = DateTime.tryParse(value);
    if (d == null) return false;
    if (period == 'Tất cả') return true;
    if (period == 'Năm') return d.year == month.year;
    if (period == 'Quý')
      return d.year == month.year &&
          ((d.month - 1) ~/ 3) == ((month.month - 1) ~/ 3);
    if (period == 'Ngày')
      return d.year == month.year &&
          d.month == month.month &&
          d.day == month.day;
    return d.year == month.year && d.month == month.month;
  }

  bool _matches(_AccLine item) =>
      _inPeriod(item.date) &&
      ('${item.id} ${item.customer} ${item.description} ${item.status}'
          .toLowerCase()
          .contains(keyword.toLowerCase())) &&
      (paymentFilter != 'Đã thanh toán' || item.due <= 0) &&
      (paymentFilter != 'Còn nợ' || item.due > 0);

  // A unified, read-only timeline. Snapshot books (stock and receivables)
  // are displayed separately: summing them with sales would double-count.
  List<List<Object?>> _overviewRows(ShopData data) {
    final entries = <List<Object?>>[];
    void add(
      String date,
      String type,
      String id,
      String who,
      String summary,
      Object? value,
      String status,
    ) {
      if (!_inPeriod(date)) return;
      if (overviewType != 'Tất cả các sổ' && overviewType != type) return;
      final query = keyword.trim().toLowerCase();
      if (query.isNotEmpty &&
          !('$type $id $who $summary $status'.toLowerCase().contains(query))) {
        return;
      }
      entries.add([date, type, id, who, summary, value ?? '', status]);
    }

    for (final sale in _accSales(data)) {
      if (paymentFilter == 'Còn nợ' && sale.due <= 0) continue;
      if (paymentFilter == 'Đã thanh toán' && sale.due > 0) continue;
      add(
        sale.date,
        'Sổ bán hàng',
        sale.id,
        sale.customer,
        sale.description,
        sale.amount,
        sale.due > 0 ? 'Còn nợ' : 'Đã thanh toán',
      );
    }
    if (paymentFilter == 'Tất cả trạng thái') {
      final payment = _accPaymentRows(data);
      for (final row in payment.skip(1)) {
        if (row.length < 8) continue;
        add(
          _accString(row[2]),
          'Sổ thu chi',
          _accString(row[1]),
          _accString(row[3]),
          'Thu từ đơn ${_accString(row[0])}',
          row[4],
          _accString(row[5]) == 'Có' ? 'Đã hủy' : 'Đã thu',
        );
      }
      for (final p in data.products) {
        for (final l in p.lots) {
          add(
            _accDate(l['date']),
            'Sổ nhập hàng',
            _accString(l['id']),
            p.name,
            'Nhập lô · ${p.code}',
            _accInt(l['area']) / 10000,
            'Số lượng ${p.unit}',
          );
        }
      }
      for (final m in data.stockMoves) {
        add(
          _accDate(m['at']),
          'Biến động kho',
          _accString(m['reference'] ?? m['id']),
          _accString(m['product']),
          _accString(m['type']),
          _accInt(m['area']) / 10000,
          'Số lượng gốc',
        );
      }
    }
    entries.sort((a, b) => _accString(b[0]).compareTo(_accString(a[0])));
    return [
      [
        'Ngày',
        'Loại sổ',
        'Mã',
        'Khách / hàng hóa',
        'Nội dung',
        'Giá trị / số lượng',
        'Trạng thái',
      ],
      ...entries,
    ];
  }

  List<List<Object?>> _filteredRows(
    List<List<Object?>> rows, {
    int? dateColumn,
  }) {
    if (rows.isEmpty) return rows;
    final search = keyword.trim().toLowerCase();
    return [
      rows.first,
      for (final row in rows.skip(1))
        if ((dateColumn == null ||
                (dateColumn < row.length &&
                    _inPeriod(_accString(row[dateColumn])))) &&
            (search.isEmpty || row.join(' ').toLowerCase().contains(search)))
          row,
    ];
  }

  Future<void> _editNote(
    String key, {
    String? lotLabel,
    bool allowTemporary = true,
  }) async {
    final existing = drafts[key];
    final controller = Get.find<ShopController>();
    final matches = _accSales(controller.data).where((r) => r.id == key);
    final sale = matches.isEmpty ? null : matches.first;
    final isLot = lotLabel != null;
    final noteCtrl = TextEditingController(text: existing?.note ?? '');
    final referenceCtrl = TextEditingController(
      text: existing?.reference ?? '',
    );
    const reasons = <String>[
      'Thanh toán / công nợ',
      'Thông tin cần sửa',
      'Hủy / trả hàng cần xử lý',
      'Chứng từ trùng cần kiểm tra',
      'Khác',
    ];
    var reason = reasons.contains(existing?.reason)
        ? existing!.reason
        : reasons.first;
    var agreed = false;
    var marked = isLot
        ? _temporaryLots.contains(key)
        : _temporarilyExcluded.contains(key);
    try {
      await safeDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, update) => AlertDialog(
            title: Text('Điều chỉnh · ${lotLabel ?? key}'),
            content: SizedBox(
              width: 450,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (sale != null) ...[
                      Text('Tổng đơn: ${money(sale.amount)}'),
                      Text('Đã thu: ${money(sale.collected)}'),
                      Text('Còn nợ: ${money(sale.due)}'),
                      const SizedBox(height: 12),
                    ],
                    if (isLot) ...[
                      Text('Lô nhập: $lotLabel'),
                      const SizedBox(height: 12),
                    ],
                    DropdownButtonFormField<String>(
                      initialValue: reason,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Lý do'),
                      items: reasons
                          .map(
                            (r) => DropdownMenuItem(value: r, child: Text(r)),
                          )
                          .toList(),
                      onChanged: (v) => update(() => reason = v ?? reason),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Ghi chú'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: referenceCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Mã chứng từ (nếu có)',
                      ),
                    ),
                    if (allowTemporary)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: marked,
                        title: const Text('Gạch tạm trong bản xem thử'),
                        subtitle: const Text(
                          'Có thể khôi phục; không xóa dữ liệu gốc.',
                        ),
                        onChanged: (v) => update(() => marked = v ?? marked),
                      ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: agreed,
                      title: const Text('Đồng ý lưu thay đổi'),
                      onChanged: (v) => update(() => agreed = v ?? false),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              if (existing != null)
                TextButton(
                  onPressed: agreed
                      ? () async {
                          setState(() => drafts.remove(key));
                          await _save();
                          if (ctx.mounted) Navigator.pop(ctx);
                        }
                      : null,
                  child: const Text('Xóa ghi chú'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: agreed
                    ? () async {
                        setState(() {
                          if (allowTemporary) {
                            if (isLot) {
                              if (marked) {
                                _temporaryLots.add(key);
                              } else {
                                _temporaryLots.remove(key);
                              }
                            } else {
                              if (marked) {
                                _temporarilyExcluded.add(key);
                              } else {
                                _temporarilyExcluded.remove(key);
                              }
                            }
                          }
                          drafts[key] = _AccDraft(
                            key,
                            reason,
                            noteCtrl.text.trim(),
                            _accString(controller.actor?.id ?? 'Người dùng'),
                            DateTime.now().toIso8601String(),
                            referenceCtrl.text.trim(),
                            false,
                          );
                        });
                        await _save();
                        if (ctx.mounted) Navigator.pop(ctx);
                      }
                    : null,
                child: const Text('Lưu thay đổi'),
              ),
            ],
          ),
        ),
      );
    } finally {
      noteCtrl.dispose();
      referenceCtrl.dispose();
    }
  }

  Future<void> _export(ShopController c) async {
    if (exporting) return;
    setState(() => exporting = true);
    try {
      final workbook = Excel.createExcel();
      void sheet(String title, List<List<Object?>> data) {
        final target = workbook[title];
        for (final row in data) {
          target.appendRow(
            row.map<CellValue?>((value) {
              if (value is int) return IntCellValue(value);
              if (value is double) return DoubleCellValue(value);
              if (value is bool) return TextCellValue(value ? 'Có' : 'Không');
              return TextCellValue(_accString(value));
            }).toList(),
          );
        }
      }

      final sales = _accSales(c.data).where(_matches).toList();
      final salesRows = <List<Object?>>[
        [
          'Ngày bán',
          'Mã đơn',
          'Khách hàng',
          'Sản phẩm',
          'Tổng tiền bán',
          'Đã thu',
          'Còn nợ',
          'Trạng thái xem thử',
          'Ghi chú',
        ],
        for (final r in sales)
          [
            r.date,
            r.id,
            r.customer,
            r.description,
            r.amount,
            r.collected,
            r.due,
            _temporarilyExcluded.contains(r.id) ? 'Gạch tạm' : 'Giữ',
            drafts[r.id]?.note ?? '',
          ],
      ];
      final salesSum = sales.fold<int>(0, (a, r) => a + r.amount);
      final receivedSum = sales.fold<int>(0, (a, r) => a + r.collected);
      final markedSum = sales
          .where((r) => _temporarilyExcluded.contains(r.id))
          .fold<int>(0, (a, r) => a + r.amount);
      final overview = _overviewRows(c.data);
      final purchaseSource = _filteredRows(_accLotsRows(c.data), dateColumn: 2);
      final purchases = <List<Object?>>[
        [...purchaseSource.first, 'Xem thử', 'Ghi chú'],
        for (final row in purchaseSource.skip(1))
          [
            ...row,
            _temporaryLots.contains(_lotKey(row)) ? 'Gạch tạm' : 'Giữ',
            drafts[_lotKey(row)]?.note ?? '',
          ],
      ];
      final receipts = _filteredRows(_accPaymentRows(c.data), dateColumn: 2);
      final debts = _filteredRows(_accDebtRows(c.data));
      final stock = _filteredRows(_accStockRows(c.data));
      final stockMoves = _filteredRows(_accMovesRows(c.data), dateColumn: 0);
      final purchaseSummary = _accPurchaseSummary(c.data, _inPeriod);
      final meta = <List<Object?>>[
        ['VLXD Bảy Hải', 'SỔ QUẢN LÝ KINH DOANH'],
        ['Kỳ xem', period],
        ['Ngày đang chọn', DateFormat('dd/MM/yyyy').format(month)],
        ['Tìm kiếm', keyword],
        ['Loại sổ', overviewType],
        ['Trạng thái thanh toán', paymentFilter],
        ['Số hóa đơn đang lọc', sales.length],
        ['Tổng tiền bán hàng (gốc)', salesSum],
        [
          'Tổng tiền nhập hàng (phần tính được)',
          purchaseSummary.amount ?? 'Chưa đủ dữ liệu',
        ],
        ['Mức độ tin cậy tiền nhập', purchaseSummary.status],
        [
          'Số lô đã tính / tổng số lô',
          '${purchaseSummary.completeLots}/${purchaseSummary.lotCount}',
        ],
        [
          'Tổng giá trị bán và nhập (phần tính được)',
          purchaseSummary.amount == null
              ? 'Chưa đủ dữ liệu'
              : salesSum + purchaseSummary.amount!,
        ],
        ['Đã thu theo các hóa đơn đang lọc', receivedSum],
        ['Còn nợ theo các hóa đơn đang lọc', salesSum - receivedSum],
        [
          'Hóa đơn gạch tạm khi xem thử',
          sales.where((r) => _temporarilyExcluded.contains(r.id)).length,
        ],
        ['Giá trị đánh dấu tạm', markedSum],
        ['Tổng xem thử nội bộ', salesSum - markedSum],
        ['Lưu ý', 'Gạch tạm chỉ là thao tác xem thử; không sửa chứng từ gốc.'],
        [
          'Lưu ý',
          'Tổng giá trị bán và nhập là chỉ tiêu quản trị, không phải doanh thu tính thuế.',
        ],
        [
          'Lưu ý',
          'Một số lô cũ được tạm tính từ tồn còn lại và lượng đã bán; phải đối chiếu chứng từ trước khi dùng cho báo cáo chính thức.',
        ],
      ];
      if (tab == 'Tổng hợp') {
        sheet('Tong_hop', meta);
        sheet('Giao_dich', overview);
        sheet('So_ban_hang', salesRows);
        sheet('So_nhap_hang', purchases);
        sheet('Thu_chi', receipts);
        sheet('Cong_no', debts);
        sheet('Ton_kho', stock);
        sheet('Bien_dong_kho', stockMoves);
      } else if (tab == 'Sổ bán hàng') {
        sheet('So_ban_hang', salesRows);
      } else if (tab == 'Sổ nhập hàng') {
        sheet('So_nhap_hang', purchases);
      } else if (tab == 'Sổ thu chi') {
        sheet('Thu_chi', receipts);
      } else if (tab == 'Công nợ') {
        sheet('Cong_no', debts);
      } else if (tab == 'Tồn kho') {
        sheet('Ton_kho', stock);
      }
      sheet('Ghi_chu', [
        ['Mã tham chiếu', 'Lý do', 'Ghi chú', 'Người viết', 'Thời gian'],
        for (final n in drafts.values)
          [n.key, n.reason, n.note, n.author, n.created],
      ]);
      final bytes = workbook.encode();
      if (bytes == null) throw StateError('Không tạo được file Excel.');
      final fileName =
          'VLXD_${tab.replaceAll(' ', '_')}_'
          '${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx';
      final location = await getSaveLocation(
        suggestedName: fileName,
        acceptedTypeGroups: [
          const XTypeGroup(label: 'Excel', extensions: ['xlsx']),
        ],
      );
      if (location == null) return;
      await XFile.fromData(
        Uint8List.fromList(bytes),
        name: fileName,
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      ).saveTo(location.path);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Đã xuất Excel: $tab')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Chưa xuất được Excel: $e')));
      }
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  Widget _summaryCard(
    String label,
    String value,
    IconData icon,
    Color tint, {
    bool primary = false,
    String? detail,
  }) => Container(
    width: double.infinity,
    constraints: const BoxConstraints(minHeight: 112),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    decoration: BoxDecoration(
      color: tint,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: primary ? const Color(0xFF83B5FA) : const Color(0xFFDCE7F5),
        width: primary ? 1.5 : 1,
      ),
      boxShadow: primary
          ? const [
              BoxShadow(
                color: Color(0x160066CC),
                blurRadius: 12,
                offset: Offset(0, 3),
              ),
            ]
          : null,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: blue, size: primary ? 22 : 19),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: primary ? 15 : 14,
                  fontWeight: FontWeight.w700,
                  color: ink,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: primary ? 22 : 19,
            fontWeight: FontWeight.w800,
            color: ink,
          ),
        ),
        if (detail != null) ...[
          const SizedBox(height: 5),
          Text(
            detail,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Color(0xFF5B6E86)),
          ),
        ],
      ],
    ),
  );

  void _toggleTemporary(String id) {
    setState(() {
      if (!_temporarilyExcluded.add(id)) {
        _temporarilyExcluded.remove(id);
      }
    });
  }

  Widget _pager(int itemCount) {
    final pageCount = itemCount == 0
        ? 1
        : (itemCount + _pageSize - 1) ~/ _pageSize;
    final current = _page.clamp(0, pageCount - 1).toInt();
    if (pageCount <= 1) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(
          '$itemCount dòng',
          style: const TextStyle(color: Color(0xFF61758D)),
        ),
      );
    }
    final first = (current - 2)
        .clamp(0, (pageCount - 5).clamp(0, pageCount))
        .toInt();
    final last = (first + 5).clamp(0, pageCount).toInt();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            '$itemCount dòng · Trang ${current + 1}/$pageCount',
            style: const TextStyle(fontSize: 14, color: Color(0xFF435C78)),
          ),
          IconButton(
            tooltip: 'Trang trước',
            onPressed: current == 0
                ? null
                : () => setState(() => _page = current - 1),
            icon: const Icon(Icons.chevron_left),
          ),
          for (var i = first; i < last; i++)
            SizedBox(
              width: 42,
              child: i == current
                  ? FilledButton(
                      style: FilledButton.styleFrom(padding: EdgeInsets.zero),
                      onPressed: () {},
                      child: Text('${i + 1}'),
                    )
                  : OutlinedButton(
                      style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                      onPressed: () => setState(() => _page = i),
                      child: Text('${i + 1}'),
                    ),
            ),
          IconButton(
            tooltip: 'Trang sau',
            onPressed: current >= pageCount - 1
                ? null
                : () => setState(() => _page = current + 1),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  int _rowCount(ShopController c, List<_AccLine> sales) {
    switch (tab) {
      case 'Tổng hợp':
        return _overviewRows(c.data).length - 1;
      case 'Sổ bán hàng':
        return sales.length;
      case 'Sổ nhập hàng':
        return _filteredRows(_accLotsRows(c.data), dateColumn: 2).length - 1;
      case 'Sổ thu chi':
        return _filteredRows(_accPaymentRows(c.data), dateColumn: 2).length - 1;
      case 'Công nợ':
        return _filteredRows(_accDebtRows(c.data)).length - 1;
      case 'Tồn kho':
        return _filteredRows(_accStockRows(c.data)).length - 1;
      default:
        return 0;
    }
  }

  Widget _listTable(List<_AccLine> sales) {
    if (sales.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: Text('Chưa có hóa đơn phù hợp bộ lọc.')),
      );
    }
    final start = _page * _pageSize;
    final pageRows = sales.skip(start).take(_pageSize).toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 780) {
          return Column(
            children: [
              for (final r in pageRows)
                Builder(
                  builder: (context) {
                    final marked = _temporarilyExcluded.contains(r.id);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                          '${r.id} · ${money(r.amount)}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            decoration: marked
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: Colors.red,
                            decorationThickness: 2.4,
                          ),
                        ),
                        subtitle: Text(
                          '${_accDateDisplay(r.date)} · ${r.customer}\n'
                          'Đã thu: ${money(r.collected)} · Còn nợ: ${money(r.due)}',
                          style: TextStyle(
                            fontSize: 14,
                            decoration: marked
                                ? TextDecoration.lineThrough
                                : null,
                            decorationColor: Colors.red,
                            decorationThickness: 2.4,
                          ),
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Điều chỉnh',
                              onPressed: () => _editNote(r.id),
                              icon: const Icon(
                                Icons.edit_note_outlined,
                                color: blue,
                              ),
                            ),
                            IconButton(
                              tooltip: marked ? 'Khôi phục' : 'Gạch tạm',
                              onPressed: () => _toggleTemporary(r.id),
                              icon: Icon(
                                marked
                                    ? Icons.add_circle_outline
                                    : Icons.remove_circle_outline,
                                color: marked ? Colors.green : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          );
        }
        return SizedBox(
          width: double.infinity,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                headingRowHeight: 46,
                dataRowMinHeight: 52,
                dataRowMaxHeight: 64,
                horizontalMargin: 16,
                columnSpacing: 24,
                headingRowColor: const WidgetStatePropertyAll(
                  Color(0xFFE9F1FC),
                ),
                columns: const [
                  DataColumn(label: Text('Ngày bán')),
                  DataColumn(label: Text('Mã đơn')),
                  DataColumn(label: Text('Khách hàng')),
                  DataColumn(label: Text('Tiền bán'), numeric: true),
                  DataColumn(label: Text('Đã thu'), numeric: true),
                  DataColumn(label: Text('Còn nợ'), numeric: true),
                  DataColumn(label: Text('Ghi chú')),
                  DataColumn(label: Text('Tạm loại')),
                ],
                rows: [
                  for (final r in pageRows)
                    DataRow(
                      color: _temporarilyExcluded.contains(r.id)
                          ? const WidgetStatePropertyAll(Color(0xFFFFF2F1))
                          : null,
                      cells: [
                        for (final value in <String>[
                          _accDateDisplay(r.date),
                          r.id,
                          r.customer,
                          money(r.amount),
                          money(r.collected),
                          money(r.due),
                        ])
                          DataCell(
                            Text(
                              value,
                              style: TextStyle(
                                fontSize: 14.5,
                                color: _temporarilyExcluded.contains(r.id)
                                    ? const Color(0xFFAD5555)
                                    : null,
                                decoration: _temporarilyExcluded.contains(r.id)
                                    ? TextDecoration.lineThrough
                                    : null,
                                decorationColor: Colors.red,
                                decorationThickness: 2.6,
                              ),
                            ),
                          ),
                        DataCell(
                          IconButton(
                            tooltip: 'Ghi chú / Điều chỉnh',
                            icon: Icon(
                              drafts.containsKey(r.id)
                                  ? Icons.sticky_note_2_outlined
                                  : Icons.edit_note_outlined,
                              color: blue,
                            ),
                            onPressed: () => _editNote(r.id),
                          ),
                        ),
                        DataCell(
                          IconButton(
                            tooltip: _temporarilyExcluded.contains(r.id)
                                ? 'Khôi phục'
                                : 'Gạch tạm',
                            icon: Icon(
                              _temporarilyExcluded.contains(r.id)
                                  ? Icons.add_circle_outline
                                  : Icons.remove_circle_outline,
                              color: _temporarilyExcluded.contains(r.id)
                                  ? Colors.green
                                  : Colors.red,
                            ),
                            onPressed: () => _toggleTemporary(r.id),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _previewTotals(List<_AccLine> sales) {
    final original = sales.fold<int>(0, (a, r) => a + r.amount);
    final temporarilyMarked = sales
        .where((r) => _temporarilyExcluded.contains(r.id))
        .fold<int>(0, (a, r) => a + r.amount);
    final count = sales
        .where((r) => _temporarilyExcluded.contains(r.id))
        .length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F7FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDCE7F5)),
      ),
      child: Wrap(
        spacing: 22,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Tổng tiền bán gốc: ${money(original)}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Text('Đánh dấu tạm ($count): ${money(temporarilyMarked)}'),
          Text(
            'Tổng bản xem thử: ${money(original - temporarilyMarked)}',
            style: const TextStyle(fontWeight: FontWeight.w800, color: blue),
          ),
          if (count > 0)
            TextButton.icon(
              onPressed: () => setState(() => _temporarilyExcluded.clear()),
              icon: const Icon(Icons.restore),
              label: const Text('Bỏ tất cả dấu gạch'),
            ),
        ],
      ),
    );
  }

  // Full-width overview: wrap long description instead of stretching the page.
  Widget _overviewTable(List<List<Object?>> rows) => LayoutBuilder(
    builder: (context, constraints) {
      if (rows.length < 2) {
        return const Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: Text('Chưa có giao dịch phù hợp.')),
        );
      }
      const widths = <int, TableColumnWidth>{
        0: FlexColumnWidth(1.05),
        1: FlexColumnWidth(1.2),
        2: FlexColumnWidth(1.2),
        3: FlexColumnWidth(1.45),
        4: FlexColumnWidth(2.8),
        5: FlexColumnWidth(1.4),
        6: FlexColumnWidth(1.15),
      };
      Widget cell(Object? value, {bool header = false, bool wrap = false}) {
        final content = _accString(value);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
          child: Tooltip(
            message: content,
            child: Text(
              content,
              softWrap: wrap,
              maxLines: wrap ? null : 2,
              overflow: wrap ? null : TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                height: 1.35,
                fontWeight: header ? FontWeight.w700 : FontWeight.w400,
                color: const Color(0xFF183453),
              ),
            ),
          ),
        );
      }

      final visible = rows.skip(1 + _page * _pageSize).take(_pageSize);
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: constraints.maxWidth < 980 ? 980 : constraints.maxWidth,
          child: Table(
            columnWidths: widths,
            border: const TableBorder(
              horizontalInside: BorderSide(color: Color(0xFFE0E9F4)),
            ),
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              TableRow(
                decoration: const BoxDecoration(color: Color(0xFFE7F0FC)),
                children: [
                  for (final title in rows.first) cell(title, header: true),
                ],
              ),
              for (final row in visible)
                TableRow(
                  children: [
                    for (var i = 0; i < 7; i++)
                      cell(i < row.length ? row[i] : '', wrap: i == 4),
                  ],
                ),
            ],
          ),
        ),
      );
    },
  );

  Widget _ledgerTable(
    List<List<Object?>> rows, {
    bool purchases = false,
    String? ledgerName,
  }) => LayoutBuilder(
    builder: (ctx, layout) {
      if (rows.length < 2) {
        return const Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: Text('Chưa có dữ liệu trong sổ này.')),
        );
      }
      final columns = rows.first;
      final visible = rows.skip(1 + _page * _pageSize).take(_pageSize).toList();
      return SizedBox(
        width: double.infinity,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: layout.maxWidth),
            child: DataTable(
              headingRowColor: const WidgetStatePropertyAll(Color(0xFFE9F1FC)),
              headingRowHeight: 46,
              dataRowMinHeight: 50,
              dataRowMaxHeight: 58,
              horizontalMargin: 16,
              columnSpacing: 22,
              columns: [
                for (final col in columns)
                  DataColumn(label: Text(_accString(col))),
                const DataColumn(label: Text('Điều chỉnh')),
                if (purchases) const DataColumn(label: Text('Tạm loại')),
              ],
              rows: [
                for (final row in visible)
                  DataRow(
                    color: purchases && _temporaryLots.contains(_lotKey(row))
                        ? const WidgetStatePropertyAll(Color(0xFFFFF2F1))
                        : null,
                    cells: [
                      for (var i = 0; i < columns.length; i++)
                        DataCell(
                          Text(
                            i < row.length ? _accString(row[i]) : '',
                            style: TextStyle(
                              fontSize: 14,
                              decoration:
                                  purchases &&
                                      _temporaryLots.contains(_lotKey(row))
                                  ? TextDecoration.lineThrough
                                  : null,
                              decorationColor: Colors.red,
                              decorationThickness: 2.6,
                            ),
                          ),
                        ),
                      DataCell(
                        IconButton(
                          tooltip: 'Điều chỉnh',
                          onPressed: () {
                            final key = purchases
                                ? _lotKey(row)
                                : _ledgerRowKey(ledgerName ?? tab, row);
                            _editNote(
                              key,
                              lotLabel: purchases
                                  ? '${_accString(row[0])} · ${_accString(row[1])}'
                                  : null,
                              allowTemporary: purchases,
                            );
                          },
                          icon: Icon(
                            drafts.containsKey(
                                  purchases
                                      ? _lotKey(row)
                                      : _ledgerRowKey(ledgerName ?? tab, row),
                                )
                                ? Icons.sticky_note_2_outlined
                                : Icons.edit_note_outlined,
                            color: blue,
                          ),
                        ),
                      ),
                      if (purchases)
                        DataCell(
                          IconButton(
                            tooltip: _temporaryLots.contains(_lotKey(row))
                                ? 'Khôi phục'
                                : 'Gạch tạm',
                            onPressed: () => setState(() {
                              final key = _lotKey(row);
                              if (!_temporaryLots.add(key))
                                _temporaryLots.remove(key);
                            }),
                            icon: Icon(
                              _temporaryLots.contains(_lotKey(row))
                                  ? Icons.add_circle_outline
                                  : Icons.remove_circle_outline,
                              color: _temporaryLots.contains(_lotKey(row))
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _content(ShopController c, List<_AccLine> sales) {
    switch (tab) {
      case 'Tổng hợp':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Giao dịch từ các sổ · công nợ và tồn kho xem ở tab riêng',
              style: TextStyle(color: Color(0xFF61758D), fontSize: 12),
            ),
            const SizedBox(height: 8),
            _overviewTable(_overviewRows(c.data)),
          ],
        );
      case 'Sổ bán hàng':
        return _listTable(sales);
      case 'Sổ nhập hàng':
        return _ledgerTable(
          _filteredRows(_accLotsRows(c.data), dateColumn: 2),
          purchases: true,
          ledgerName: 'Sổ nhập hàng',
        );
      case 'Sổ thu chi':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Các lần thu tiền; chưa có đủ chứng từ chi phí.',
              style: TextStyle(fontSize: 12, color: Color(0xFF61758D)),
            ),
            const SizedBox(height: 8),
            _ledgerTable(
              _filteredRows(_accPaymentRows(c.data), dateColumn: 2),
              ledgerName: 'Sổ thu chi',
            ),
          ],
        );
      case 'Công nợ':
        return _ledgerTable(
          _filteredRows(_accDebtRows(c.data)),
          ledgerName: 'Công nợ',
        );
      case 'Tồn kho':
        return _ledgerTable(
          _filteredRows(_accStockRows(c.data)),
          ledgerName: 'Tồn kho',
        );
      default:
        return _listTable(sales);
    }
  }

  @override
  Widget build(BuildContext context) => GetBuilder<ShopController>(
    builder: (c) {
      if (c.actor?.canAdmin != true) {
        return const Center(
          child: Text('Chỉ chủ cửa hàng được xem sổ kế toán và xuất dữ liệu.'),
        );
      }
      final all = _accSales(c.data);
      final sales = all.where(_matches).toList();
      final gross = sales.fold<int>(0, (total, r) => total + r.amount);
      final collected = sales.fold<int>(0, (total, r) => total + r.collected);
      final purchaseSummary = _accPurchaseSummary(c.data, _inPeriod);
      final purchaseTotal = purchaseSummary.amount;
      final combinedTotal = purchaseTotal == null
          ? null
          : gross + purchaseTotal;
      final width = MediaQuery.sizeOf(context).width;
      final compact = width < 1100;
      return ListView(
        padding: EdgeInsets.all(compact ? 12 : 18),
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              titleText('Sổ kinh doanh', size: 24),
              const Text(
                'Sổ quản lý nội bộ · Dữ liệu cửa hàng',
                style: TextStyle(fontSize: 12, color: Color(0xFF61758D)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final t in _tabs)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(t),
                      selected: tab == t,
                      onSelected: (_) => _setTab(t),
                    ),
                  ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: exporting ? null : () => _export(c),
                  icon: const Icon(Icons.file_download_outlined),
                  label: const Text('Excel · Sổ đang xem'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          panel(
            Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 130,
                  child: DropdownButtonFormField<String>(
                    initialValue: period,
                    decoration: const InputDecoration(
                      labelText: 'Kỳ báo cáo',
                      isDense: true,
                    ),
                    items: ['Ngày', 'Tháng', 'Quý', 'Năm', 'Tất cả']
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: (v) => setState(() {
                      period = v ?? period;
                      _page = 0;
                    }),
                  ),
                ),
                if (period != 'Tất cả')
                  OutlinedButton.icon(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: month,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (d != null)
                        setState(() {
                          month = DateTime(d.year, d.month);
                          _page = 0;
                        });
                    },
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text(
                      period == 'Năm'
                          ? '${month.year}'
                          : period == 'Ngày'
                          ? DateFormat('dd/MM/yyyy').format(month)
                          : DateFormat('MM/yyyy').format(month),
                    ),
                  ),
                SizedBox(
                  width: compact ? 230 : 310,
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Tìm mã đơn hoặc khách hàng',
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() {
                      keyword = v;
                      _page = 0;
                    }),
                  ),
                ),
                if (tab == 'Tổng hợp')
                  SizedBox(
                    width: 190,
                    child: DropdownButtonFormField<String>(
                      key: ValueKey(overviewType),
                      initialValue: overviewType,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Loại sổ',
                        isDense: true,
                      ),
                      items:
                          const [
                                'Tất cả các sổ',
                                'Sổ bán hàng',
                                'Sổ nhập hàng',
                                'Sổ thu chi',
                                'Biến động kho',
                              ]
                              .map(
                                (v) =>
                                    DropdownMenuItem(value: v, child: Text(v)),
                              )
                              .toList(),
                      onChanged: (v) => setState(() {
                        overviewType = v ?? overviewType;
                        _page = 0;
                      }),
                    ),
                  ),
                SizedBox(
                  width: 185,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(paymentFilter),
                    initialValue: paymentFilter,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Thanh toán',
                      isDense: true,
                    ),
                    items:
                        const ['Tất cả trạng thái', 'Đã thanh toán', 'Còn nợ']
                            .map(
                              (v) => DropdownMenuItem(value: v, child: Text(v)),
                            )
                            .toList(),
                    onChanged: (v) => setState(() {
                      paymentFilter = v ?? paymentFilter;
                      _page = 0;
                    }),
                  ),
                ),
              ],
            ),
            padding: const EdgeInsets.all(12),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              // All summary tiles share one width; allow fewer columns on small screens.
              const spacing = 10.0;
              final available = constraints.maxWidth;
              final columns = available >= 1320
                  ? 6
                  : available >= 780
                  ? 3
                  : available >= 440
                  ? 2
                  : 1;
              final tileWidth = (available - spacing * (columns - 1)) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  SizedBox(
                    width: tileWidth,
                    child: _summaryCard(
                      'Tổng giá trị bán & nhập',
                      combinedTotal == null
                          ? 'Chưa đủ dữ liệu'
                          : money(combinedTotal),
                      Icons.analytics_outlined,
                      const Color(0xFFDCEEFF),
                      primary: true,
                      detail:
                          purchaseSummary.status +
                          ' · Không phải doanh thu tính thuế',
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: _summaryCard(
                      'Tổng tiền bán hàng',
                      money(gross),
                      Icons.shopping_cart_outlined,
                      const Color(0xFFE9F3FF),
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: _summaryCard(
                      'Tổng tiền nhập hàng',
                      purchaseTotal == null
                          ? 'Chưa đủ dữ liệu'
                          : money(purchaseTotal),
                      Icons.local_shipping_outlined,
                      const Color(0xFFFFF2E4),
                      detail: purchaseSummary.status == 'Đã đối chiếu'
                          ? null
                          : purchaseSummary.status,
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: _summaryCard(
                      'Đã thu từ khách',
                      money(collected),
                      Icons.payments_outlined,
                      const Color(0xFFE7F8EF),
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: _summaryCard(
                      'Khách còn nợ',
                      money(gross - collected),
                      Icons.account_balance_wallet_outlined,
                      const Color(0xFFFFEFF0),
                    ),
                  ),
                  SizedBox(
                    width: tileWidth,
                    child: _summaryCard(
                      'Số hóa đơn đã bán',
                      '${sales.length}',
                      Icons.receipt_long_outlined,
                      const Color(0xFFF1EEFF),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tab == 'Tổng hợp' ? 'Tổng hợp giao dịch các sổ' : tab,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, child: _content(c, sales)),
                _pager(_rowCount(c, sales)),
                if (tab == 'Sổ nhập hàng') ...[
                  const SizedBox(height: 12),
                  Builder(
                    builder: (context) {
                      final source = _filteredRows(
                        _accLotsRows(c.data),
                        dateColumn: 2,
                      );
                      final marked = source
                          .skip(1)
                          .where((row) => _temporaryLots.contains(_lotKey(row)))
                          .length;
                      final summary = _accPurchaseSummary(c.data, _inPeriod);
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF6EB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFF0DFCB)),
                        ),
                        child: Wrap(
                          spacing: 22,
                          runSpacing: 8,
                          children: [
                            Text(
                              'Tổng tiền nhập hàng: ${summary.amount == null ? 'Chưa đủ dữ liệu' : money(summary.amount!)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '${source.length - 1} lô đang lọc · Gạch tạm: $marked lô',
                              style: const TextStyle(fontSize: 14),
                            ),
                            if (!summary.complete)
                              Text(
                                '${summary.status}. Đã tính ${summary.completeLots}/${summary.lotCount} lô; ${summary.estimatedLots} lô dùng ước tính từ lịch sử bán. Cần đối chiếu phiếu nhập gốc.',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF98651A),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
                if (tab == 'Sổ bán hàng') ...[
                  const SizedBox(height: 14),
                  _previewTotals(sales),
                ],
              ],
            ),
            padding: const EdgeInsets.all(16),
          ),
        ],
      );
    },
  );
}
