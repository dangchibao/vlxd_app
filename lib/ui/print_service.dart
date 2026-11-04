import 'dart:convert';
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
                pw.Text('Tiền hàng: ${money(order['subtotal'])}'),
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

  static Future<void> quote(
    ShopData data,
    List<CartLine> lines,
    int ship, {
    bool demo = true,
  }) async {
    final doc = pw.Document(theme: await theme());
    final total =
        lines.fold<int>(
          0,
          (v, l) => v + lineMoney(l.area, data.product(l.productId).price),
        ) +
        ship;
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (_) => [
          pw.Text(
            'VLXD Bảy Hải',
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text('Gò Dầu • Tây Ninh'),
          pw.SizedBox(height: 20),
          pw.Text(
            'BÁO GIÁ THAM KHẢO',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text('Ngày ${DateFormat('dd/MM/yyyy').format(DateTime.now())}'),
          pw.SizedBox(height: 20),
          ...lines.map((l) {
            final p = data.product(l.productId);
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 16),
              child: pw.Row(
                children: [
                  if (p.images.isNotEmpty)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(right: 12),
                      child: pw.Image(
                        pw.MemoryImage(base64Decode(p.images.first)),
                        width: 55,
                        height: 55,
                        fit: pw.BoxFit.cover,
                      ),
                    ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('${p.name} ${p.size}'),
                        if (l.note.isNotEmpty) pw.Text('Lưu ý: ${l.note}'),
                        pw.Text(
                          '${l.area / 10000} ${p.unit} • ${money(p.price)}/${p.unit}',
                        ),
                      ],
                    ),
                  ),
                  pw.Text(money(lineMoney(l.area, p.price))),
                ],
              ),
            );
          }),
          pw.Divider(),
          pw.Text('Vận chuyển: ${money(ship)}'),
          pw.Text(
            'Tổng cộng: ${money(total)}',
            style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 24),
          pw.Text(
            demo
                ? 'Dữ liệu mẫu • Chưa phải hóa đơn thuế.'
                : 'Báo giá tham khảo • Không phải hóa đơn thuế.',
          ),
        ],
      ),
    );
    await Printing.layoutPdf(
      name: 'bao-gia-bay-hai.pdf',
      onLayout: (_) => doc.save(),
    );
  }
}
