import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:vlxd_app/controllers/shop_controller.dart';
import 'package:vlxd_app/domain/shop.dart';
import 'package:vlxd_app/domain/invoice_filter.dart';
import 'package:vlxd_app/ui/app.dart';
import 'package:vlxd_app/ui/print_service.dart';

import 'shop_test.dart' show MemoryRepository;

const invoiceOwner = Actor('admin', Role.owner);
Json sale(ShopData data, String id, {bool hold = false}) => data.checkout(
  requestId: id,
  lines: [const CartLine('PR6060VD', 144000)],
  customerId: 'KH001',
  paid: 1000000,
  ship: 0,
  hold: hold,
  actor: invoiceOwner,
);

void main() {
  tearDown(() => Get.reset());
  testWidgets(
    'Payment and amount filters combine and reset restores the list',
    (tester) async {
      Get.testMode = true;
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final data = ShopData.sample();
      final owing = sale(data, 'filter-owing');
      final paid = sale(data, 'filter-paid');
      data.recordPayment(
        paid['id'],
        (paid['total'] as int) - ShopData.collected(paid),
        'finish-paid',
        invoiceOwner,
      );
      final c = Get.put(ShopController(MemoryRepository(), data))
        ..enterDemo(Role.owner);
      c.navigate(9);
      await tester.pumpWidget(const BayHaiApp());
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<InvoicePayment>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Còn nợ').last);
      await tester.pumpAndSettle();
      expect(find.text(owing['id']), findsOneWidget);
      expect(find.text(paid['id']), findsNothing);
      await tester.enterText(find.byType(TextField).at(1), '4000000');
      await tester.pumpAndSettle();
      expect(find.text(owing['id']), findsNothing);
      await tester.tap(find.text('Xóa bộ lọc'));
      await tester.pumpAndSettle();
      expect(find.text(owing['id']), findsOneWidget);
      expect(find.text(paid['id']), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final width in [320.0, 390.0, 1440.0]) {
    testWidgets(
      'Invoices show completed sales, customer, balance, detail and PDF at $width',
      (tester) async {
        Get.testMode = true;
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final data = ShopData.sample();
        final order = sale(data, 'invoice');
        final held = sale(data, 'held', hold: true);
        final before = jsonEncode(order);
        // Changing today's price must not affect a historical invoice.
        data.product('PR6060VD').price = 990000;
        final c = Get.put(ShopController(MemoryRepository(), data))
          ..enterDemo(Role.owner);
        c.navigate(9);
        await tester.pumpWidget(const BayHaiApp());
        await tester.pumpAndSettle();
        expect(find.text('Hóa đơn bán hàng'), findsOneWidget);
        expect(find.text(order['id']), findsOneWidget);
        expect(find.text(held['id']), findsNothing);
        expect(find.text(invoiceCustomer(data, order)), findsOneWidget);
        expect(find.text(money(2456000)), findsOneWidget);
        await tester.tap(find.text(order['id']));
        await tester.pumpAndSettle();
        expect(find.text('Xem / in PDF'), findsOneWidget);
        expect(find.text('Tổng: ${money(3456000)}'), findsOneWidget);
        expect(find.text('Còn nợ: ${money(2456000)}'), findsOneWidget);
        expect(jsonEncode(order), before);
        expect(tester.takeException(), isNull);
      },
    );
  }

  test(
    'Invoice PDF generates without catalog access or mutating the order',
    () async {
      final data = ShopData.sample();
      final order = sale(data, 'pdf');
      data.correctPayment(
        order['id'],
        'pdf-first',
        700000,
        'Correction',
        'fix-pdf',
        invoiceOwner,
      );
      (order['lines'] as List).first['note'] =
          '5 tấm đá, người bán tự tính diện tích';
      final before = jsonEncode(order);
      final fontFile = File('C:/Windows/Fonts/segoeui.ttf');
      final theme = await fontFile.exists()
          ? pw.ThemeData.withFont(
              base: pw.Font.ttf(
                ByteData.sublistView(await fontFile.readAsBytes()),
              ),
              bold: pw.Font.ttf(
                ByteData.sublistView(await fontFile.readAsBytes()),
              ),
            )
          : pw.ThemeData.base();
      final bytes = await PrintService.invoicePdf(
        order,
        invoiceCustomer(data, order),
        demo: true,
        fontTheme: theme,
      );
      expect(ascii.decode(bytes.take(5).toList()), '%PDF-');
      expect(bytes.length, greaterThan(1000));
      expect(jsonEncode(order), before);
      expect(ShopData.collected(order), 700000);
      order['status'] = 'Giữ hàng';
      await expectLater(
        PrintService.invoicePdf(order, 'Test', fontTheme: theme),
        throwsStateError,
      );
    },
  );
}
