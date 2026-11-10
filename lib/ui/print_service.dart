import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../domain/shop.dart';

class PrintService {
  // Order lines retain the price/name/amount at sale time. Never recalculate
  // an invoice from today's product catalog or write a second sales record.
  /// Prints the saved sale, or a clearly labelled local-only temporary slip.
  /// Never creates or changes a sale, inventory, debt or sync operation.
  static Future<Uint8List> invoicePdf(
    Json order,
    String customerName, {
    bool demo = false,
    bool provisional = false,
    pw.ThemeData? fontTheme,
  }) async {
    // Chỉ đọc dữ liệu trên chứng từ đã lưu, KHÔNG tạo lại giao dịch.
    if (!provisional && order['status'] != 'Đã bán') {
      throw StateError('Chỉ in hóa đơn từ đơn đã bán.');
    }
    if (provisional && order['status'] != 'Chờ đồng bộ') {
      throw StateError('Phiếu tạm chỉ dành cho đơn chờ đồng bộ.');
    }

    final doc = pw.Document(theme: fontTheme ?? await theme());
    final at = (order['soldAt'] ?? order['at']) as String;
    final date = DateFormat('dd/MM/yyyy HH:mm')
        .format(DateTime.parse(at).toLocal());
    final lines = (order['lines'] as List).cast<Map>();
    final subtotal = (order['subtotal'] as num).toInt();
    final discount = (order['discount'] as num? ?? 0).toInt();
    final ship = (order['ship'] as num? ?? 0).toInt();
    final total = (order['total'] as num).toInt();

    final regular = pw.TextStyle(fontSize: 11);
    final bold = pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold);

    pw.Widget summaryRow(String label, String value) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: regular),
          pw.Text(value, style: regular),
        ],
      ),
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(24, 26, 24, 24),
        build: (_) => [
          // Phần đầu chỉ dùng CHỮ để in ổn định trên máy in đen trắng.
          pw.Center(
            child: pw.Column(
              children: [
                pw.Text(
                  'VLXD Bảy Hải',
                  style: pw.TextStyle(
                    fontSize: 25,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  'Vật liệu xây dựng – Gạch – Xi măng – Sắt thép',
                  style: pw.TextStyle(fontSize: 11),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Ấp Bàu Vừng, Xã Phước Trạch, Huyện Gò Dầu, Tỉnh Tây Ninh',
                  style: pw.TextStyle(fontSize: 10),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 4),
                pw.Text('0343 744 091', style: pw.TextStyle(fontSize: 11)),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Divider(thickness: 1.1, color: PdfColors.black),
          pw.SizedBox(height: 6),
          pw.Center(
            child: pw.Text(
              provisional ? 'PHIẾU TẠM - CHỜ ĐỒNG BỘ' : 'HÓA ĐƠN BÁN HÀNG',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 15),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Mã đơn: ${order['id']}', style: regular),
              pw.Text('Ngày: $date', style: regular),
            ],
          ),
          pw.SizedBox(height: 13),
          // Khung khách hàng CỐ ĐỊNH, kéo dài hết phần ngang sử dụng của giấy.
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.black, width: 0.7),
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(6),
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Khách hàng: $customerName', style: bold),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        'Địa chỉ: ${(order['customerAddress'] as String? ?? '').trim()}',
                        style: regular,
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        'ĐT: ${(order['customerPhone'] as String? ?? '').trim()}',
                        style: regular,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.TableHelper.fromTextArray(
            headers: ['STT', 'Tên hàng hóa', 'SL', 'Đơn giá', 'Thành tiền'],
            data: [
              for (var i = 0; i < lines.length; i++)
                [
                  '${i + 1}',
                  '${lines[i]['name']}${(lines[i]['note'] as String? ?? '').isEmpty ? '' : '\n${lines[i]['note']}'}',
                  NumberFormat(
                    '0.####',
                    'vi',
                  ).format((lines[i]['area'] as num) / 10000),
                  NumberFormat.decimalPattern('vi').format(lines[i]['price']),
                  NumberFormat.decimalPattern('vi').format(lines[i]['amount']),
                ],
            ],
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            ),
            cellStyle: const pw.TextStyle(fontSize: 10),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            border: pw.TableBorder.all(color: PdfColors.black, width: 0.55),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 7,
              vertical: 9,
            ),
            columnWidths: {
              0: const pw.FlexColumnWidth(0.6),
              1: const pw.FlexColumnWidth(3.2),
              2: const pw.FlexColumnWidth(1.35),
              3: const pw.FlexColumnWidth(1.45),
              4: const pw.FlexColumnWidth(1.6),
            },
            cellAlignments: {
              0: pw.Alignment.center,
              2: pw.Alignment.centerLeft, // Chừa phần bên phải để viết ĐVT.
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
            },
          ),
          // Khoảng trống cố ý để viết tay, không thêm ô hoặc đường kẻ.
          pw.SizedBox(height: 76),
          pw.Row(
            children: [
              pw.Spacer(flex: 2),
              pw.Expanded(
                flex: 3,
                child: pw.Column(
                  children: [
                    summaryRow('Tổng tiền hàng:', money(subtotal + discount)),
                    summaryRow(
                      'Giảm giá:',
                      discount == 0 ? money(0) : '-${money(discount)}',
                    ),
                    summaryRow('Phí vận chuyển:', money(ship)),
                    pw.Divider(thickness: 0.7, color: PdfColors.black),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 10,
                      ),
                      color: PdfColors.grey200,
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Tổng thanh toán:', style: bold),
                          pw.Text(money(total), style: bold),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Không in câu "Cảm ơn quý khách!", logo, mã vạch hoặc chữ ký.
          // Phiếu tạm cần có dấu hiệu nhận biết để không nhầm với hóa đơn
          // đã được máy chủ xác nhận.
          if (provisional) ...[
            pw.SizedBox(height: 12),
            pw.Text(
              'Đơn đang lưu trên thiết bị, chờ đồng bộ.',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ],
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
