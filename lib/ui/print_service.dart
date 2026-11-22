import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../domain/shop.dart';
import '../domain/unit_rules.dart';
import '../data/store_profile.dart';

class PrintService {
  static const invoicePageFormat = PdfPageFormat.a4;
  static Future<pw.ThemeData>? _fontTheme;

  /// No catalog fallback: an absent snapshot must remain visibly unknown.
  static String customerSnapshot(Json order) {
    final name = (order['customerName'] as String? ?? '').trim();
    return name.isNotEmpty
        ? name
        : order['customerId'] == ''
        ? 'Khách lẻ'
        : 'Khách hàng';
  }

  static bool _completeLine(Map row) {
    try {
      return (row['saleUnit'] as String? ?? '').trim().isNotEmpty &&
          row['saleQuantity'] is String &&
          row['salePrice'] is String &&
          saleDecimal(row['saleQuantity']) != '0' &&
          saleDecimal(row['salePrice']).isNotEmpty;
    } on FormatException {
      return false;
    }
  }

  static List<String> invoiceWarnings(Json order) {
    final missing = (order['lines'] as List)
        .where((row) => !_completeLine(row as Map))
        .length;
    return [
      if (missing > 0)
        '$missing dòng hàng chưa lưu đủ số lượng, đơn vị và đơn giá bán gốc. Phiếu để trống các ô này, vẫn giữ nguyên thành tiền. Hãy đối chiếu chứng từ gốc.',
      if (order['customerId'] != '' &&
          (order['customerName'] as String? ?? '').trim().isEmpty)
        'Đơn chưa lưu tên khách tại thời điểm bán; không dùng tên khách hiện tại để in lại.',
    ];
  }

  static String _decimalText(String value) {
    final parts = saleDecimal(value).split('.');
    final grouped = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (match) => '${match[1]}.',
    );
    return parts.length == 1 ? grouped : '$grouped,${parts[1]}';
  }

  static String _saleUnit(Map row) =>
      _completeLine(row) ? row['saleUnit'] as String : '';
  static String _saleQuantity(Map row) =>
      _completeLine(row) ? _decimalText(row['saleQuantity']) : '';
  static String _saleUnitPrice(Map row) =>
      _completeLine(row) ? _decimalText(row['salePrice']) : '';

  static String _roundingNote(Map row) {
    if (!_completeLine(row)) return '';
    final difference =
        (row['amount'] as num).toInt() -
        roundedSaleDisplayAmount(row['saleQuantity'], row['salePrice']);
    return difference == 0
        ? ''
        : 'Làm tròn: ${difference > 0 ? '+' : ''}${money(difference)}';
  }

  static void _validateInvoice(Json order, bool provisional) {
    if (order['status'] != (provisional ? 'Chờ đồng bộ' : 'Đã bán')) {
      throw StateError('Chỉ in đơn đã bán hoặc phiếu tạm chờ đồng bộ.');
    }
  }

  static pw.Widget _totals(
    Json order, {
    required bool compact,
    required bool provisional,
  }) {
    final subtotal = (order['subtotal'] as num).toInt();
    final discount = (order['discount'] as num? ?? 0).toInt();
    final ship = (order['ship'] as num? ?? 0).toInt();
    pw.Widget row(String label, int value, {bool bold = false}) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(child: pw.Text(label)),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Text(
              money(value),
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
    return pw.DefaultTextStyle(
      style: pw.TextStyle(fontSize: compact ? 9 : 11),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          row('Tiền hàng', subtotal + discount),
          if (discount > 0) row('Giảm giá', -discount),
          if (ship != 0) row('Phí giao hàng', ship),
          pw.Divider(color: PdfColors.grey600),
          row('TỔNG THANH TOÁN', (order['total'] as num).toInt(), bold: true),
          if (!provisional && order['payments'] is List) ...[
            row('Tổng đã thanh toán', ShopData.collected(order)),
            row(
              'Còn nợ đơn này',
              (order['total'] as int) - ShopData.collected(order),
              bold: true,
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _heading(
    StoreProfile store,
    Json order,
    String customer, {
    required bool compact,
    required bool provisional,
    bool demo = false,
  }) {
    final when = DateFormat('dd/MM/yyyy HH:mm').format(
      DateTime.parse((order['soldAt'] ?? order['at']) as String).toLocal(),
    );
    final address = (order['customerAddress'] as String? ?? '').trim();
    final phone = (order['customerPhone'] as String? ?? '').trim();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Text(
          'VLXD ${store.name}',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: compact ? 15 : 20,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        if (store.address.isNotEmpty)
          pw.Text(
            store.address,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: compact ? 8 : 9),
          ),
        if (store.phone.isNotEmpty)
          pw.Text('Điện thoại: ${store.phone}', textAlign: pw.TextAlign.center),
        pw.SizedBox(height: compact ? 6 : 12),
        pw.Text(
          provisional ? 'PHIẾU TẠM - CHỜ ĐỒNG BỘ' : 'HÓA ĐƠN BÁN HÀNG',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: compact ? 11 : 17,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        if (demo) pw.Text('BẢN THỬ', textAlign: pw.TextAlign.center),
        pw.SizedBox(height: compact ? 6 : 12),
        pw.Text('Mã hóa đơn: ${order['id']}'),
        pw.Text('Ngày bán: $when'),
        pw.SizedBox(height: 5),
        pw.Text(
          'Khách hàng: $customer',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        if (phone.isNotEmpty) pw.Text('Điện thoại: $phone'),
        if (address.isNotEmpty) pw.Text('Địa chỉ: $address'),
        pw.SizedBox(height: compact ? 8 : 14),
      ],
    );
  }

  /// Uses only the saved invoice snapshot; printing never writes business data.
  static Future<Uint8List> invoicePdf(
    Json order,
    String customerName, {
    bool demo = false,
    bool provisional = false,
    pw.ThemeData? fontTheme,
  }) async {
    _validateInvoice(order, provisional);
    final store = StoreProfile.current;
    final lines = (order['lines'] as List).cast<Map>();
    final doc = pw.Document(theme: fontTheme ?? await theme());
    doc.addPage(
      pw.MultiPage(
        pageFormat: invoicePageFormat,
        margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 28),
        theme: (fontTheme ?? await theme()).copyWith(
          defaultTextStyle: const pw.TextStyle(fontSize: 10),
        ),
        header: (context) => context.pageNumber > 1
            ? pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 10),
                child: pw.Text('VLXD ${store.name} - Hóa đơn ${order['id']}'),
              )
            : pw.SizedBox(),
        footer: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8),
          child: pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Trang ${context.pageNumber}/${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ),
        ),
        build: (_) => [
          _heading(
            store,
            order,
            customerSnapshot(order),
            compact: false,
            provisional: provisional,
            demo: demo,
          ),
          pw.TableHelper.fromTextArray(
            headers: [
              'STT',
              'Hàng hóa',
              'SL',
              'ĐVT',
              'Đơn giá',
              'Thành tiền',
            ],
            data: [
              for (var i = 0; i < lines.length; i++)
                [
                  '${i + 1}',
                  '${lines[i]['name']}${_roundingNote(lines[i]).isEmpty ? '' : '\n${_roundingNote(lines[i])}'}',
                  _saleQuantity(lines[i]),
                  _saleUnit(lines[i]),
                  _saleUnitPrice(lines[i]),
                  NumberFormat.decimalPattern('vi').format(lines[i]['amount']),
                ],
            ],
            headerStyle: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: const pw.TextStyle(fontSize: 9.5),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            border: pw.TableBorder.all(color: PdfColors.grey500, width: .5),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 5,
              vertical: 7,
            ),
            columnWidths: {
              0: const pw.FixedColumnWidth(25),
              1: const pw.FlexColumnWidth(),
              2: const pw.FixedColumnWidth(43),
              3: const pw.FixedColumnWidth(44),
              4: const pw.FixedColumnWidth(77),
              5: const pw.FixedColumnWidth(88),
            },
            cellAlignments: {
              0: pw.Alignment.center,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.center,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
            },
          ),
          pw.SizedBox(height: 14),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.SizedBox(
              width: 275,
              child: _totals(order, compact: false, provisional: provisional),
            ),
          ),
          if (provisional)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 8),
              child: pw.Text('Lưu trên thiết bị, chưa xác nhận máy chủ.'),
            ),
        ],
      ),
    );
    return doc.save();
  }

  /// Compatibility entry point for PDF export; printing uses the measured format.
  static Future<Uint8List> receipt80Pdf(
    Json order,
    String customerName, {
    bool demo = false,
    bool provisional = false,
    pw.ThemeData? fontTheme,
  }) async => (await receipt80(
    order,
    customerName,
    demo: demo,
    provisional: provisional,
    fontTheme: fontTheme,
  )).bytes;

  /// Auto-height paper avoids guessing a roll length from the item count.
  static Future<({Uint8List bytes, PdfPageFormat format})> receipt80(
    Json order,
    String customerName, {
    bool demo = false,
    bool provisional = false,
    pw.ThemeData? fontTheme,
  }) async {
    _validateInvoice(order, provisional);
    final store = StoreProfile.current;
    final lines = (order['lines'] as List).cast<Map>();
    final fonts = fontTheme ?? await theme();
    final doc = pw.Document(theme: fonts);
    final page = pw.Page(
      pageFormat: PdfPageFormat.roll80,
      margin: const pw.EdgeInsets.all(4 * PdfPageFormat.mm),
      theme: fonts.copyWith(defaultTextStyle: const pw.TextStyle(fontSize: 9)),
      build: (_) => pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _heading(
            store,
            order,
            customerSnapshot(order),
            compact: true,
            provisional: provisional,
            demo: demo,
          ),
          pw.Divider(color: PdfColors.grey600),
          for (var i = 0; i < lines.length; i++) ...[
            pw.Text(
              '${i + 1}. ${lines[i]['name']}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 3),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    _completeLine(lines[i])
                        ? '${_saleQuantity(lines[i])} ${_saleUnit(lines[i])}\n× ${_saleUnitPrice(lines[i])}'
                        : '',
                  ),
                ),
                pw.SizedBox(width: 6),
                pw.Expanded(
                  child: pw.Text(
                    money((lines[i]['amount'] as num).toInt()),
                    textAlign: pw.TextAlign.right,
                  ),
                ),
              ],
            ),
            if (_roundingNote(lines[i]).isNotEmpty)
              pw.Text(
                _roundingNote(lines[i]),
                style: const pw.TextStyle(fontSize: 8),
              ),
            pw.SizedBox(height: 7),
          ],
          pw.Divider(color: PdfColors.grey600),
          _totals(order, compact: true, provisional: provisional),
          if (provisional)
            pw.Text(
              'Lưu trên thiết bị, chưa xác nhận máy chủ.',
              style: const pw.TextStyle(fontSize: 8),
            ),
        ],
      ),
    );
    doc.addPage(page);
    final bytes = await doc.save();
    return (bytes: bytes, format: page.pageFormat);
  }

  static String money(int n) =>
      '${NumberFormat.decimalPattern('vi').format(n)} đ';
  static Future<pw.ThemeData> theme() => _fontTheme ??= _loadFonts();

  static Future<pw.ThemeData> _loadFonts() async => pw.ThemeData.withFont(
    base: pw.Font.ttf(
      await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
    ),
    bold: pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans-Bold.ttf')),
  );
  static Future<void> barcode(Product p) async {
    final store = StoreProfile.current;
    const format = PdfPageFormat(
      80 * PdfPageFormat.mm,
      100 * PdfPageFormat.mm,
      marginAll: 5 * PdfPageFormat.mm,
    );
    final doc = pw.Document(theme: await theme());
    doc.addPage(
      pw.Page(
        pageFormat: format,
        build: (_) => pw.Column(
          children: [
            pw.Text(
              'VLXD ${store.name}',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            if (store.location.isNotEmpty) pw.Text(store.location),
            pw.SizedBox(height: 12),
            pw.Text('${p.name} ${p.size}', textAlign: pw.TextAlign.center),
            pw.SizedBox(height: 16),
            pw.BarcodeWidget(
              barcode: pw.Barcode.code128(),
              data: p.code,
              width: 65 * PdfPageFormat.mm,
              height: 23 * PdfPageFormat.mm,
            ),
            pw.SizedBox(height: 12),
            pw.Text('${money(p.price)} / ${p.unit}'),
          ],
        ),
      ),
    );
    await Printing.layoutPdf(
      name: 'ma-vach-${p.code}.pdf',
      format: format,
      dynamicLayout: false,
      forceCustomPrintPaper: true,
      onLayout: (_) => doc.save(),
    );
  }
}
