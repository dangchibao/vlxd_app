import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:vlxd_app/controllers/shop_controller.dart';
import 'package:vlxd_app/domain/shop.dart';
import 'package:vlxd_app/ui/app.dart';

import 'shop_test.dart' show MemoryRepository;

void main() {
  tearDown(() => Get.reset());
  test('Optional notes and unknown packing ratio survive serialization and do not change pricing', () {
    const owner = Actor('owner', Role.owner);
    final d = ShopData.empty();
    final p = Product(
      id: 'P',
      code: 'P',
      name: 'Đá tấm',
      size: '',
      supplier: '',
      price: 150000,
      ratio: 0,
      minimum: 0,
      note: 'Người bán tự tính; kích thước bổ sung sau.',
    );
    d.saveProduct(p, owner);
    d.receive('P', 40000, 100000, DateTime.now(), owner, 'lot');
    final restored = ShopData.fromJson(d.toJson());
    expect(restored.product('P').note, p.note);
    expect(restored.product('P').hasPackConversion, isFalse);
    expect(restored.product('P').quantityStep, 10000);
    final legacy = p.toJson()..remove('note');
    expect(Product.fromJson(legacy).note, '');
    final order = restored.checkout(
      requestId: 'manual',
      lines: [const CartLine('P', 36000, note: '5 tấm; tự ước tính 3,6 m²')],
      customerId: '',
      paid: 540000,
      ship: 0,
      hold: false,
      actor: owner,
    );
    expect(order['total'], 540000);
    expect(restored.product('P').stock, 4000);
    expect(
      (order['lines'] as List).single['note'],
      '5 tấm; tự ước tính 3,6 m²',
    );
    restored.product('P').note = 'Đổi lưu ý sản phẩm sau bán';
    expect(
      (order['lines'] as List).single['note'],
      '5 tấm; tự ước tính 3,6 m²',
    );
  });
  test('Merging cart notes preserves distinct notes without duplicating default text', () {
    Get.testMode = true;
    final d = ShopData.sample();
    final p = d.products.first..note = 'Tự tính kích thước';
    final c = Get.put(ShopController(MemoryRepository(), d))
      ..enterDemo(Role.owner);
    c.addCart(p, 10000);
    c.addCart(p, 10000);
    expect(c.cart.single.note, 'Tự tính kích thước');
    c.addCart(p, 5000, note: 'Thêm 2 tấm nhỏ');
    expect(c.cart.single.note, 'Tự tính kích thước\nThêm 2 tấm nhỏ');
    expect(c.cart.single.area, 25000);
    expect(() => c.addCart(p, 10000, note: 'x' * 1001), throwsArgumentError);
    expect(c.cart.single.area, 25000);
  });
  for (final width in [390.0, 1440.0]) {
    testWidgets(
      'Unknown conversion accepts manual quantity and note at $width',
      (tester) async {
        Get.testMode = true;
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final data = ShopData.sample();
        final p = data.product('PR6060VD')
          ..ratio = 0
          ..note = 'Tự tính diện tích';
        final c = Get.put(ShopController(MemoryRepository(), data))
          ..enterDemo(Role.owner);
        c.navigate(2);
        c.query = p.code;
        await tester.pumpWidget(const BayHaiApp());
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.add_circle).first);
        await tester.pumpAndSettle();
        expect(find.text('Theo thùng'), findsNothing);
        final quantity = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == 'Số lượng (m²)',
        );
        final note = find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.labelText == 'Lưu ý cho lần bán này (tùy chọn)',
        );
        await tester.ensureVisible(quantity);
        await tester.enterText(quantity, '3,6');
        await tester.enterText(note, '5 tấm, diện tích tự tính 3,6 m²');
        await tester.tap(find.text('Thêm vào giỏ hàng'));
        await tester.pumpAndSettle();
        expect(c.cart.single.area, 36000);
        expect(c.cart.single.note, '5 tấm, diện tích tự tính 3,6 m²');
        expect(c.subtotal, lineMoney(36000, p.price));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
