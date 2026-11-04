import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:vlxd_app/controllers/shop_controller.dart';
import 'package:vlxd_app/domain/shop.dart';
import 'package:vlxd_app/ui/app.dart';

import 'shop_test.dart' show MemoryRepository;

Finder shippingField() => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == 'Phí giao hàng (đ)',
);

void main() {
  tearDown(() => Get.reset());
  testWidgets(
    'Confirming a product updates the desktop cart total immediately and retains entered shipping',
    (tester) async {
      Get.testMode = true;
      tester.view.physicalSize = const Size(1700, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = Get.put(ShopController(MemoryRepository(), ShopData.sample()))
        ..enterDemo(Role.owner);
      c.navigate(2);
      c.query = 'PR6060VD';
      final p = c.data.product('PR6060VD');
      final cartonTotal = lineMoney(p.ratio, p.price);
      await tester.pumpWidget(const BayHaiApp());
      await tester.pumpAndSettle();
      await tester.enterText(shippingField(), '50000');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add_circle).first);
      await tester.pumpAndSettle();
      expect(c.cart, isEmpty);
      await tester.tap(find.text('Thêm vào giỏ hàng'));
      await tester.pumpAndSettle();
      expect(c.cart, hasLength(1));
      expect(find.text(money(cartonTotal + 50000)), findsOneWidget);
      expect(
        tester.widget<TextField>(shippingField()).controller!.text,
        '50000',
      );
      await tester.tap(find.byTooltip('Thêm một thùng'));
      await tester.pumpAndSettle();
      expect(find.text(money(cartonTotal * 2 + 50000)), findsOneWidget);
      await tester.tap(find.byTooltip('Bớt một thùng'));
      await tester.pumpAndSettle();
      expect(find.text(money(cartonTotal + 50000)), findsOneWidget);
      await tester.tap(find.byTooltip('Bỏ khỏi giỏ'));
      await tester.pumpAndSettle();
      expect(find.text(money(50000)), findsOneWidget);
      expect(find.text('Giỏ hàng trống'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Compact cart refreshes quantity and total after changing a line',
    (tester) async {
      Get.testMode = true;
      tester.view.physicalSize = const Size(390, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = Get.put(ShopController(MemoryRepository(), ShopData.sample()))
        ..enterDemo(Role.owner);
      final p = c.data.product('PR6060VD');
      final cartonTotal = lineMoney(p.ratio, p.price);
      c.addCart(p, p.ratio);
      await tester.pumpWidget(
        const GetMaterialApp(home: Scaffold(body: CartPanel(compact: true))),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Thêm một thùng'));
      await tester.pumpAndSettle();
      expect(c.cart.first.area, p.ratio * 2);
      // Both the line and the total display the updated amount.
      expect(find.text(money(cartonTotal * 2)), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );
}
