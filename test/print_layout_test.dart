import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:vlxd_app/domain/shop.dart';
import 'package:vlxd_app/data/store_profile.dart';
import 'package:vlxd_app/ui/print_service.dart';

Json exampleInvoice({int count = 3}) {
  final lines = <Json>[
    {
      'name': 'Gạch ốp tường vân đá trắng 30×60 cao cấp',
      'note': 'Giao đúng mẫu đã chọn, kiểm tra vân gạch trước khi nhận.',
      'unit': 'm²',
      'saleUnit': 'thùng',
      'saleQuantity': '5',
      'salePrice': '266400',
      'ratio': 14400,
      'area': 72000,
      'price': 185000,
      'amount': 1332000,
    },
    {
      'name': 'Đá xây dựng 1×2',
      'note': '',
      'unit': 'm³',
      'saleUnit': 'm³',
      'saleQuantity': '3.5',
      'salePrice': '420000',
      'area': 35000,
      'price': 420000,
      'amount': 1470000,
    },
    {
      'name': 'Xi măng Hà Tiên đa dụng',
      'note': '2 bao × 50 kg',
      'unit': 'kg',
      'saleUnit': 'bao',
      'saleQuantity': '2',
      'salePrice': '90000',
      'ratio': 500000,
      'area': 1000000,
      'price': 1800,
      'amount': 180000,
    },
  ];
  final selected = [
    for (var i = 0; i < count; i++)
      Map<String, dynamic>.from(lines[i % lines.length]),
  ];
  final goods = selected.fold<int>(
    0,
    (sum, row) => sum + (row['amount'] as int),
  );
  return {
    'id': 'DH-MAU-1024',
    'status': 'Đã bán',
    'at': '2026-11-22T03:15:00Z',
    'customerName': 'Nguyễn Văn Khách (mẫu)',
    'customerPhone': '0900 000 000',
    'customerAddress':
        'Công trình nhà ở, đường Nguyễn Văn Linh, Gò Dầu, Tây Ninh',
    'lines': selected,
    'subtotal': goods - 25000,
    'discount': 25000,
    'ship': 50000,
    'total': goods + 25000,
    'payments': [
      {'id': 'paid', 'amount': 2000000},
      {'id': 'voided', 'amount': 100000, 'voided': true},
    ],
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> preview(String name, List<int> bytes) async {
    if (Platform.environment['VLXD_PDF_PREVIEW'] != '1') return;
    final directory = Directory('output/pdf')..createSync(recursive: true);
    await File('${directory.path}/$name.pdf').writeAsBytes(bytes);
  }

  test(
    'A4 and 80mm use bundled Vietnamese fonts without network or data writes',
    () async {
      final order = exampleInvoice();
      final before = jsonEncode(order);
      await HttpOverrides.runZoned(
        () async {
          final a4 = await PrintService.invoicePdf(
            order,
            order['customerName'],
            demo: true,
          );
          final roll = await PrintService.receipt80(
            order,
            order['customerName'],
          );
          expect(ascii.decode(a4.take(5).toList()), '%PDF-');
          expect(roll.format.width / PdfPageFormat.mm, closeTo(80, .01));
          expect(roll.format.height.isFinite, isTrue);
          expect(
            roll.format.height / PdfPageFormat.mm,
            inInclusiveRange(80, 240),
          );
          await preview('hoa-don-a4', a4);
          await preview('phieu-80mm', roll.bytes);
        },
        createHttpClient: (_) =>
            throw StateError('Network is forbidden in PDF test'),
      );
      expect(jsonEncode(order), before);
      expect(ShopData.collected(order), 2000000);
    },
  );

  test(
    'long invoices paginate while roll height follows the actual content',
    () async {
      final order = exampleInvoice(count: 60);
      final before = jsonEncode(order);
      final a4 = await PrintService.invoicePdf(
        order,
        order['customerName'],
        demo: true,
      );
      final roll = await PrintService.receipt80(order, order['customerName']);
      expect(roll.format.width / PdfPageFormat.mm, closeTo(80, .01));
      expect(roll.format.height / PdfPageFormat.mm, greaterThan(240));
      expect(jsonEncode(order), before);
      await preview('hoa-don-nhieu-trang', a4);
    },
  );

  test('fractional price, row rounding and legacy omissions print without rewriting history', () async {
    final order = exampleInvoice();
    final rows = (order['lines'] as List).cast<Map>();
    rows[0]
      ..['price'] = 185001
      ..['area'] = 14400
      ..['saleQuantity'] = '1'
      ..['salePrice'] = '266401.44'
      ..['amount'] = 266402; // Remainder from grouped checkout of 1.54 m².
    rows[1]
      ..['name'] = rows[0]['name']
      ..['unit'] = 'm²'
      ..['area'] = 1000
      ..['price'] = 185001
      ..['saleQuantity'] = '0.1'
      ..['salePrice'] = '185001'
      ..['saleUnit'] = 'm²'
      ..['amount'] = 18500;
    rows[2]
      ..remove('saleUnit')
      ..remove('saleQuantity')
      ..remove('salePrice');
    order['subtotal'] = 439902;
    order['total'] = 489902;
    order['payments'] = [
      {'amount': 200000},
    ];
    final before = jsonEncode(order);
    expect(PrintService.invoiceWarnings(order), hasLength(1));
    await preview(
      'snapshot-a4',
      await PrintService.invoicePdf(order, 'Tên mới không được in'),
    );
    await preview(
      'snapshot-k80',
      await PrintService.receipt80Pdf(order, 'Tên mới không được in'),
    );
    expect(jsonEncode(order), before);
  });

  test('temporary slip remains labelled provisional and held orders cannot print as sold', () async {
    final order = exampleInvoice()..['status'] = 'Giữ hàng';
    await expectLater(
      PrintService.receipt80Pdf(order, 'Khách mẫu'),
      throwsStateError,
    );
    order['status'] = 'Chờ đồng bộ';
    order.remove('payments');
    final receipt = await PrintService.receipt80Pdf(
      order,
      'Khách mẫu',
      provisional: true,
    );
    expect(receipt, isNotEmpty);
  });

  test(
    'both formats use the selected Hai Soc store, not Bay Hai contact data',
    () async {
      final previous = StoreProfile.current;
      StoreProfile.current = StoreProfile.haiSoc;
      try {
        final order = exampleInvoice();
        await preview(
          'hai-soc-a4',
          await PrintService.invoicePdf(order, order['customerName']),
        );
        await preview(
          'hai-soc-k80',
          await PrintService.receipt80Pdf(order, order['customerName']),
        );
      } finally {
        StoreProfile.current = previous;
      }
    },
  );
}
