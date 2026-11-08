import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:vlxd_app/controllers/shop_controller.dart';
import 'package:vlxd_app/domain/shop.dart';
import 'package:vlxd_app/ui/app.dart';

import 'shop_test.dart' show MemoryRepository;

Finder quantity(String unit) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == 'Số lượng ($unit)',
);

Future<ShopController> openProduct(
  WidgetTester tester, {
  double width = 1440,
  bool loose = false,
}) async {
  Get.testMode = true;
  tester.view.physicalSize = Size(width, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final data = ShopData.sample();
  if (loose) data.products.first.ratio = 0;
  final c = Get.put(ShopController(MemoryRepository(), data))
    ..enterDemo(Role.sales);
  await tester.pumpWidget(
    GetMaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => TextButton(
            onPressed: () => confirmProduct(ctx, data.products.first),
            child: const Text('Chọn sản phẩm'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Chọn sản phẩm'));
  await tester.pumpAndSettle();
  return c;
}

void main() {
  tearDown(() => Get.reset());
  for (final width in [390.0, 1440.0]) {
    testWidgets(
      'Quantity changes update amount before blur and preserve cursor at $width',
      (tester) async {
        final c = await openProduct(tester, width: width);
        final p = c.data.products.first;
        final field = quantity('thùng');
        await tester.ensureVisible(field);
        await tester.showKeyboard(field);
        final controller = tester.widget<TextField>(field).controller!;
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: '2',
            selection: TextSelection.collapsed(offset: 1),
          ),
        );
        await tester.pump();
        expect(
          find.text('Thành tiền: ${money(lineMoney(p.ratio * 2, p.price))}'),
          findsOneWidget,
        );
        final editable = find.descendant(
          of: field,
          matching: find.byType(EditableText),
        );
        expect(
          tester.widget<EditableText>(editable).focusNode.hasFocus,
          isTrue,
        );
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: '2,5',
            selection: TextSelection.collapsed(offset: 1),
          ),
        );
        await tester.pump();
        expect(
          find.text(
            'Thành tiền: ${money(lineMoney((p.ratio * 2.5).round(), p.price))}',
          ),
          findsOneWidget,
        );
        expect(
          identical(tester.widget<TextField>(field).controller, controller),
          isTrue,
        );
        expect(controller.text, '2,5');
        expect(controller.selection, const TextSelection.collapsed(offset: 1));
        expect(
          tester.widget<EditableText>(editable).focusNode.hasFocus,
          isTrue,
        );
        expect(c.cart, isEmpty);
        await tester.ensureVisible(find.text('Thêm vào giỏ hàng'));
        await tester.tap(find.text('Thêm vào giỏ hàng'));
        await tester.pumpAndSettle();
        expect(c.cart.single.area, (p.ratio * 2.5).round());
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'Manual m² quantity handles partial text without resetting notes, selection or composition',
    (tester) async {
      final c = await openProduct(tester, loose: true);
      final note = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.labelText == 'Lưu ý cho lần bán này (tùy chọn)',
      );
      await tester.enterText(note, 'Giao buổi sáng');
      final field = quantity('m²');
      await tester.showKeyboard(field);
      final editor = tester.widget<TextField>(field).controller!;
      for (final partial in ['', ',', '0', '-2', 'abc']) {
        tester.testTextInput.updateEditingValue(
          TextEditingValue(
            text: partial,
            selection: TextSelection.collapsed(offset: partial.length),
          ),
        );
        await tester.pump();
        expect(find.text('Nhập số lượng hợp lệ để tính tiền.'), findsOneWidget);
        expect(editor.text, partial);
        expect(c.cart, isEmpty);
      }
      const composing = TextEditingValue(
        text: '3,6',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 0, end: 3),
      );
      tester.testTextInput.updateEditingValue(composing);
      await tester.pump();
      expect(editor.value, composing);
      expect(tester.widget<TextField>(note).controller!.text, 'Giao buổi sáng');
      expect(
        find.text(
          'Thành tiền: ${money(lineMoney(36000, c.data.products.first.price))}',
        ),
        findsOneWidget,
      );
      expect(find.text('Số lượng quy đổi: 3,6 m²'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Changing unit refreshes preview immediately and preserves typed quantity',
    (tester) async {
      final c = await openProduct(tester);
      await tester.enterText(quantity('thùng'), '2');
      await tester.pump();
      final editor = tester.widget<TextField>(quantity('thùng')).controller!;
      await tester.tap(find.text('Theo m²'));
      await tester.pump();
      expect(tester.widget<TextField>(quantity('m²')).controller, same(editor));
      expect(editor.text, '2');
      expect(
        find.text(
          'Thành tiền: ${money(lineMoney(20000, c.data.products.first.price))}',
        ),
        findsOneWidget,
      );
      expect(c.cart, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Cart recalculates shipping and product totals while the shipping editor stays focused',
    (tester) async {
      Get.testMode = true;
      final c = Get.put(ShopController(MemoryRepository(), ShopData.sample()))
        ..enterDemo(Role.sales);
      final p = c.data.products.first;
      c.addCart(p, p.ratio);
      await tester.pumpWidget(
        const GetMaterialApp(home: Scaffold(body: CartPanel(compact: true))),
      );
      await tester.pumpAndSettle();
      final field = find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == 'Phí giao hàng (đ)',
      );
      await tester.showKeyboard(field);
      const value = TextEditingValue(
        text: '50 000',
        selection: TextSelection.collapsed(offset: 2),
      );
      tester.testTextInput.updateEditingValue(value);
      await tester.pump();
      expect(find.text(money(c.subtotal + 50000)), findsOneWidget);
      // A separate GetX update must not require a click or reset this editor.
      c.addCart(p, p.ratio);
      await tester.pump();
      expect(find.text(money(c.subtotal + 50000)), findsOneWidget);
      expect(tester.widget<TextField>(field).controller!.value, value);
      expect(
        tester
            .widget<EditableText>(
              find.descendant(of: field, matching: find.byType(EditableText)),
            )
            .focusNode
            .hasFocus,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
