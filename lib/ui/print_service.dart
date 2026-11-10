import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../domain/shop.dart';

class PrintService {
  // Order lines retain the price/name/amount at sale time. Never recalculate
  // an invoice from today's product catalog or write a second sales record.
  static Future<Uint8List> invoicePdf(
    Json order,
    String customerName, {
    bool demo = false,
    pw.ThemeData? fontTheme,
  }) async {
    if (order['status'] != 'Đã bán') {
      throw StateError('Chỉ in hóa đơn từ đơn đã bán.');
    }
    final doc = pw.Document(theme: fontTheme ?? await theme());
    final date = DateFormat('dd/MM/yyyy HH:mm')
        .format(DateTime.parse(order['soldAt'] ?? order['at']).toLocal());
    final paid = ShopData.collected(order);
    final lines = (order['lines'] as List).cast<Map>();
    final heading = pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold);
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        footer: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Phiếu bán hàng • Không phải hóa đơn thuế.',
              style: const pw.TextStyle(fontSize: 9),
            ),
            pw.Text(
              '${ctx.pageNumber}/${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ],
        ),
        build: (_) => [
          pw.Text('VLXD Bảy Hải', style: heading),
          pw.Text('Gò Dầu • Tây Ninh'),
          pw.SizedBox(height: 20),
          pw.Text('HÓA ĐƠN BÁN HÀNG', style: heading),
          if (demo) pw.Text('DỮ LIỆU MẪU'),
          pw.SizedBox(height: 12),
          pw.Text('Mã hóa đơn: ${order['id']}'),
          pw.Text('Khách hàng: $customerName'),
          pw.Text('Ngày bán: $date'),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: [
              'Mã hàng / Sản phẩm',
              'Số lượng / ĐVT',
              'Đơn giá',
              'Thành tiền',
            ],
            data: lines
                .map(
                  (l) => [
                    '${l['code']}\n${l['name']}${(l['note'] as String? ?? '').isEmpty ? '' : '\nLưu ý: ${l['note']}'}',
                    '${NumberFormat('0.####', 'vi').format((l['area'] as int) / 10000)} ${l['unit'] ?? 'm²'}',
                    money(l['price']),
                    money(l['amount']),
                  ],
                )
                .toList(),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            ),
            cellStyle: const pw.TextStyle(fontSize: 10),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellPadding: const pw.EdgeInsets.all(8),
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(1.2),
              2: const pw.FlexColumnWidth(1.6),
              3: const pw.FlexColumnWidth(1.6),
            },
            cellAlignments: {
              1: pw.Alignment.centerRight,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
            },
          ),
          pw.SizedBox(height: 18),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'Tiền hàng: ${money((order['subtotal'] as int) + (order['discount'] as int? ?? 0))}',
                ),
                if ((order['discount'] as int? ?? 0) > 0)
                  pw.Text('Giảm giá: ${money(order['discount'])}'),
                pw.Text('Vận chuyển: ${money(order['ship'])}'),
                pw.SizedBox(height: 6),
                pw.Text(
                  'Tổng tiền: ${money(order['total'])}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.Text('Đã trả: ${money(paid)}'),
                pw.Text(
                  'Còn nợ: ${money((order['total'] as int) - paid)}',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 28),
          pw.Text('Cảm ơn quý khách!'),
        ],
      ),
    );
    return doc.save();
  }

  static String money(int n) =>
      '${NumberFormat.decimalPattern('vi').format(n)} đ';
  static Future<pw.ThemeData> theme() async => pw.ThemeData.withFont(
    base: await PdfGoogleFonts.notoSansRegular(),
    bold: await PdfGoogleFonts.notoSansBold(),
  );
  static Future<void> barcode(Product p) async {
    final doc = pw.Document(theme: await theme());
    doc.addPage(
      pw.Page(
        pageFormat: const PdfPageFormat(
          80 * PdfPageFormat.mm,
          100 * PdfPageFormat.mm,
          marginAll: 5 * PdfPageFormat.mm,
        ),
        build: (_) => pw.Column(
          children: [
            pw.Text(
              'VLXD Bảy Hải',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text('Gò Dầu • Tây Ninh'),
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
      onLayout: (_) => doc.save(),
    );
  }
}
