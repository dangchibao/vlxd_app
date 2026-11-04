import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:vlxd_app/controllers/shop_controller.dart';
import 'package:vlxd_app/domain/shop.dart';
import 'package:vlxd_app/ui/app.dart';

import 'shop_test.dart' show MemoryRepository;

Finder input(String label) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == label,
);

void main() {
  tearDown(() => Get.reset());
  testWidgets(
    'Sales staff can create and edit prices from the sales catalog without rewriting old invoices',
    (tester) async {
      Get.testMode = true;
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final data = ShopData.sample();
      final order = data.checkout(
        requestId: 'old-price',
        lines: [const CartLine('PR6060VD', 14400)],
        customerId: 'KH001',
        paid: 0,
        ship: 0,
        hold: false,
        actor: const Actor('owner', Role.owner),
      );
      final originalTotal = order['total'];
      final c = Get.put(ShopController(MemoryRepository(), data))
        ..enterDemo(Role.sales);
      c.navigate(2);
      c.query = 'PR6060VD';
      await tester.pumpWidget(const BayHaiApp());
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('edit-sale-product-PR6060VD')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Thêm sản phẩm vào giỏ?'), findsNothing);
      await tester.enterText(input('Giá bán đ/đơn vị (m² hoặc m³)'), '199000');
      await tester.tap(find.text('Lưu thay đổi'));
      await tester.pumpAndSettle();
      expect(c.data.product('PR6060VD').price, 199000);
      expect(find.text('${money(199000)} / m²'), findsOneWidget);
      expect(c.data.orders.first['total'], originalTotal);
      await tester.tap(find.text('Tạo sản phẩm'));
      await tester.pumpAndSettle();
      await tester.enterText(input('Mã sản phẩm / mã vạch'), 'NEW-TEST');
      await tester.enterText(input('Tên sản phẩm'), 'Gạch mới');
      await tester.tap(find.text('Lưu thay đổi'));
      await tester.pumpAndSettle();
      expect(c.data.products.where((p) => p.code == 'NEW-TEST'), hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Confirmed delete archives a sales card and removes its draft cart line, preserving stock and invoices',
    (tester) async {
      Get.testMode = true;
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = Get.put(ShopController(MemoryRepository(), ShopData.sample()))
        ..enterDemo(Role.owner);
      c.navigate(2);
      c.query = 'PR6060VD';
      final stock = c.data.product('PR6060VD').stock;
      c.addCart(c.data.product('PR6060VD'), 14400);
      await tester.pumpWidget(const BayHaiApp());
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('delete-sale-product-PR6060VD')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(c.data.product('PR6060VD').active, isTrue);
      await tester.tap(
        find.byKey(const ValueKey('delete-sale-product-PR6060VD')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xác nhận'));
      await tester.pumpAndSettle();
      expect(c.data.product('PR6060VD').active, isFalse);
      expect(c.data.product('PR6060VD').stock, stock);
      expect(c.cart, isEmpty);
      expect(
        find.byKey(const ValueKey('delete-sale-product-PR6060VD')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
