import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

// Match app.dart's Material widgets.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:vlxd_app/controllers/shop_controller.dart';
import 'package:vlxd_app/domain/shop.dart';
import 'package:vlxd_app/ui/app.dart';

import 'shop_test.dart' show MemoryRepository;

Finder input(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final previews = Platform.environment['VLXD_UI_PREVIEW'] == '1';
  final capture = GlobalKey();
  setUpAll(() async {
    if (previews) {
      await (FontLoader('Roboto')..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'))).load();
    }
  });
  tearDown(() => Get.reset());

  void viewport(WidgetTester tester, double width) {
    tester.view.physicalSize = Size(width, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> screenshot(WidgetTester tester, String name) async {
    if (!previews) return;
    await tester.runAsync(() async {
      final boundary = capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final folder = Directory('.qa/ui-ux-preview')..createSync(recursive: true);
      await File('${folder.path}/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  test('sales ranking separates identical names, joins renamed SKU and excludes unsold/non-m²', () {
    Json line(String id, String name, int quantity, {String unit = 'm²'}) => {
      if (id.isNotEmpty) 'productId': id,
      'code': id, 'name': name, 'area': quantity, 'unit': unit,
    };
    final rows = bestSellingTiles([
      {'status': 'Đã bán', 'lines': [line('A', 'Cùng tên', 10000), line('B', 'Cùng tên', 20000)]},
      {'status': 'Đã bán', 'lines': [line('A', 'Tên đã đổi', 30000), line('C', 'Cát', 999999, unit: 'm³')]},
      {'status': 'Giữ hàng', 'lines': [line('B', 'Cùng tên', 999999)]},
      {'status': 'Đã hủy', 'lines': [line('B', 'Cùng tên', 999999)]},
      {'status': 'Đã trả hàng', 'lines': [line('B', 'Cùng tên', 999999)]},
      {'status': 'Đã bán', 'lines': [line('', 'Hàng cũ', 100), line('', 'Hàng cũ', 200)]},
    ]);
    expect(rows, hasLength(4));
    expect(rows.first.code, 'A');
    expect(rows.first.quantity, 40000);
    expect(rows[1].code, 'B');
    expect(rows[1].quantity, 20000);
    expect(rows.where((row) => row.code.isEmpty), hasLength(2));
  });

  test('availability labels distinguish physical and reserved quantities without mutation', () {
    final p = ShopData.sample().products.first;
    p.lots = [{'area': 10000, 'reserved': 10000}];
    expect(productAvailability(p), 'Đã giữ hết');
    p.lots.single['reserved'] = 20000;
    expect(productAvailability(p), 'Giữ vượt tồn');
    p.lots.single['area'] = -10000;
    expect(productAvailability(p), 'Tồn âm');
    p.lots = [{'area': 0, 'reserved': 0}];
    expect(productAvailability(p), 'Hết tồn');
    p.lots = [{'area': 10000, 'reserved': 0}];
    p.minimum = 10000;
    final before = jsonEncode(p.toJson());
    expect(productAvailability(p), 'Sắp hết khả dụng');
    expect(jsonEncode(p.toJson()), before);
  });

  for (final width in [390.0, 1440.0]) {
    testWidgets('payment modes, quick amounts and edits stay immediate at $width', (tester) async {
      viewport(tester, width);
      Get.testMode = true;
      final shop = Get.put(ShopController(MemoryRepository(), ShopData.sample()))..enterDemo(Role.sales);
      shop.addCart(shop.data.products.first, 144000);
      await tester.pumpWidget(RepaintBoundary(key: capture, child: const GetMaterialApp(home: Scaffold(body: CartPanel(compact: false)))));
      await tester.pumpAndSettle();
      final partial = find.byKey(const ValueKey('payment-partial'));
      await tester.ensureVisible(partial);
      await tester.tap(partial);
      await tester.pumpAndSettle();
      final paid = input('Số tiền thu lần này (đ)');
      await tester.ensureVisible(paid);
      await tester.enterText(paid, '150000');
      await tester.pump();
      final editable = find.descendant(of: paid, matching: find.byType(EditableText));
      expect(tester.widget<EditableText>(editable).focusNode.hasFocus, isTrue);
      final editing = tester.widget<TextField>(paid).controller!.value;
      expect(find.text('Còn phải thu: ${money(shop.subtotal - 150000)}'), findsOneWidget);
      shop.addCart(shop.data.products.first, 14400);
      await tester.pump();
      expect(tester.widget<TextField>(paid).controller!.value, editing);
      expect(tester.widget<EditableText>(editable).focusNode.hasFocus, isTrue);
      expect(find.text('Còn phải thu: ${money(shop.subtotal - 150000)}'), findsOneWidget);
      final quick = find.widgetWithText(ActionChip, money(500000));
      await tester.ensureVisible(quick);
      await tester.tap(quick);
      await tester.pump();
      expect(find.text('Còn phải thu: ${money(shop.subtotal - 500000)}'), findsOneWidget);
      final shipping = input('Phí giao hàng (đ)');
      await tester.ensureVisible(shipping);
      await tester.enterText(shipping, '50000');
      await tester.pump();
      expect(find.text('Còn phải thu: ${money(shop.subtotal + 50000 - 500000)}'), findsOneWidget);
      final full = find.byKey(const ValueKey('payment-full'));
      await tester.ensureVisible(full);
      await tester.tap(full);
      await tester.pumpAndSettle();
      expect(paid, findsNothing);
      expect(find.text('Còn phải thu: 0 đ'), findsOneWidget);
      final debt = find.byKey(const ValueKey('payment-debt'));
      await tester.tap(debt);
      await tester.pumpAndSettle();
      expect(find.text('Còn phải thu: ${money(shop.subtotal + 50000)}'), findsOneWidget);
      await screenshot(tester, 'payment-$width');
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [320.0, 390.0, 1440.0]) {
    testWidgets('compact pages preserve data and fit at $width', (tester) async {
      viewport(tester, width);
      Get.testMode = true;
      final shop = Get.put(ShopController(MemoryRepository(), ShopData.sample()))..enterDemo(Role.owner);
      final before = jsonEncode(shop.data.toJson());
      for (final page in [0, 1, 2, 3, 5, 6, 9]) {
        shop.navigate(page);
        await tester.pumpWidget(RepaintBoundary(key: capture, child: const BayHaiApp()));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'page $page at $width');
        if (width != 320) await screenshot(tester, 'page-$page-$width');
      }
      expect(jsonEncode(shop.data.toJson()), before);
    });
  }
}
