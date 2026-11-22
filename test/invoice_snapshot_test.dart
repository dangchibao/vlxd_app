import 'dart:convert';

// Match the Material widgets in app.dart.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vlxd_app/controllers/shop_controller.dart';
import 'package:vlxd_app/data/sync/offline_checkout_command.dart';
import 'package:vlxd_app/domain/shop.dart';
import 'package:vlxd_app/domain/unit_rules.dart';
import 'package:vlxd_app/ui/app.dart';
import 'package:vlxd_app/ui/print_service.dart';

import 'shop_test.dart' show MemoryRepository;

void main() {
  const owner = Actor('owner', Role.owner);
  ShopData shop({int ratio = 14400}) {
    final data = ShopData.sample();
    data.product('PR6060VD')
      ..price = 185001
      ..ratio = ratio;
    return data;
  }

  Json checkout(ShopData data, List<CartLine> lines, String request) =>
      data.checkout(
        requestId: request,
        lines: lines,
        customerId: 'KH001',
        paid: 0,
        ship: 50000,
        hold: false,
        actor: owner,
      );

  test(
    'exact decimal snapshots support comma, exponent and repeated input',
    () {
      expect(saleDecimal(',500'), '0.5');
      expect(saleDecimal('+1.2500e-2'), '0.0125');
      expect(addSaleQuantities('0.1', '0.2'), '0.3');
      expect(addSaleQuantities('1.5', '1', subtract: true), '0.5');
      expect(() => saleDecimal('NaN'), throwsFormatException);
      expect(() => saleDecimal('1e999'), throwsFormatException);
      expect(salePriceSnapshot(185001, 14400), '266401.44');
      expect(roundedSaleDisplayAmount('5', '266401.44'), 1332007);
    },
  );

  test(
    'fractional sale input survives stock quantization and catalog edits',
    () {
      final data = shop(ratio: 3333);
      final order = checkout(data, const [
        CartLine('PR6060VD', 5000, saleUnit: 'thùng', saleQuantity: '1.5'),
      ], 'fraction');
      final before = jsonEncode(order);
      final line = (order['lines'] as List).single as Map;
      expect(line['saleQuantity'], '1.5'); // Not 5000 / 3333.
      expect(line['salePrice'], '61660.8333');
      expect(
        line['amount'],
        92501,
      ); // Existing stock-based money rule unchanged.
      expect(order['total'], 142501);
      data.product('PR6060VD')
        ..price = 999999
        ..ratio = 25000;
      data.customers.firstWhere((c) => c['id'] == 'KH001')['name'] = 'Tên mới';
      expect(PrintService.customerSnapshot(order), isNot('Tên mới'));
      expect(PrintService.invoiceWarnings(order), isEmpty);
      expect(jsonEncode(order), before);
      // Idempotent retry keeps the first snapshot and does not deduct stock again.
      final stock = data.product('PR6060VD').stock;
      final retry = checkout(data, const [
        CartLine('PR6060VD', 5000, saleUnit: 'thùng', saleQuantity: '1.5'),
      ], 'fraction');
      expect(jsonEncode(retry), before);
      expect(data.product('PR6060VD').stock, stock);
    },
  );

  test('mixed units retain separate rows and checkout rounding remainder', () {
    final data = shop();
    final order = checkout(data, const [
      CartLine('PR6060VD', 1000, saleUnit: 'm²', saleQuantity: '0.1'),
      CartLine('PR6060VD', 14400, saleUnit: 'thùng', saleQuantity: '1'),
    ], 'mixed');
    final lines = (order['lines'] as List).cast<Map>();
    expect(lines.map((line) => line['saleUnit']), ['m²', 'thùng']);
    expect(lines.first['salePrice'], '185001');
    expect(lines.last['salePrice'], '266401.44');
    expect(lines.map((line) => line['amount']), [18500, 266402]);
    expect(order['subtotal'], 284902);
    expect(order['total'], 334902);
    expect(PrintService.invoiceWarnings(order), isEmpty);
  });

  test(
    'invalid optional quantity is rejected before changing stock or history',
    () {
      final data = shop();
      final before = jsonEncode(data.toJson());
      for (final quantity in ['0', '-1', 'NaN', '1e999']) {
        expect(
          () => checkout(data, [
            CartLine(
              'PR6060VD',
              14400,
              saleUnit: 'thùng',
              saleQuantity: quantity,
            ),
          ], 'invalid-$quantity'),
          throwsA(anyOf(isA<ArgumentError>(), isA<FormatException>())),
        );
        expect(jsonEncode(data.toJson()), before);
      }
    },
  );

  test('cart combines exact entered quantities only within the same unit', () {
    final data = shop(ratio: 3333);
    final controller = ShopController(MemoryRepository(), data)
      ..enterDemo(Role.owner);
    addTearDown(controller.onClose);
    final p = data.product('PR6060VD');
    controller.addCart(p, 333, saleUnit: 'thùng', saleQuantity: '0.1');
    controller.addCart(p, 667, saleUnit: 'thùng', saleQuantity: '0.2');
    controller.addCart(p, 1000, saleUnit: 'm²', saleQuantity: '0.1');
    expect(controller.cart.length, 2);
    expect(controller.cart.first.saleQuantity, '0.3');
    expect(controller.cart.first.area, 1000);
    expect(controller.cart.last.saleQuantity, '0.1');
  });

  test(
    'optional outbox snapshot roundtrips; legacy payload stays identical',
    () {
      const legacy = OfflineCheckoutLine(
        productId: 'P',
        area: 5000,
        note: '',
        quotedPrice: 1000,
        quotedRatio: 3333,
      );
      final oldJson = legacy.toJson();
      expect(oldJson.containsKey('saleQuantity'), isFalse);
      expect(
        jsonEncode(OfflineCheckoutLine.fromJson(oldJson).toJson()),
        jsonEncode(oldJson),
      );
      final command = OfflineCheckoutCommand(
        requestId: 'pending',
        actorId: 'owner',
        customerId: '',
        lines: const [
          OfflineCheckoutLine(
            productId: 'P',
            area: 5000,
            note: '',
            saleUnit: 'tấm',
            saleQuantity: '1.5',
            quotedPrice: 1000,
            quotedRatio: 3333,
          ),
        ],
        paid: 0,
        ship: 0,
        hold: false,
        negativeReason: '',
        createdAt: DateTime.utc(2026, 11, 22),
      );
      final restored = OfflineCheckoutCommand.decode(command.encode());
      expect(restored.lines.single.saleQuantity, '1.5');
      expect(restored.encode(), command.encode());
    },
  );

  testWidgets(
    'legacy warning is visible at small and large widths without guessing',
    (tester) async {
      final data = shop();
      final order = checkout(data, const [
        CartLine('PR6060VD', 14400),
      ], 'legacy');
      order.remove('customerName');
      expect(invoiceCustomer(data, order), 'Khách hàng');
      expect(PrintService.invoiceWarnings(order), hasLength(2));
      final before = jsonEncode(order);
      for (final width in [320.0, 1440.0]) {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: InvoiceSnapshotWarning(order: order)),
          ),
        );
        expect(find.textContaining('chưa lưu đủ'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      expect(jsonEncode(order), before);
    },
  );
}
