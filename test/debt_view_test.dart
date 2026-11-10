import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:vlxd_app/controllers/shop_controller.dart';
import 'package:vlxd_app/domain/shop.dart';
import 'package:vlxd_app/ui/app.dart';

import 'shop_test.dart' show MemoryRepository;

void main() {
  setUpAll(() async {
    if (const bool.fromEnvironment('UI_SCREENSHOTS')) {
      for (final entry in {
        'Roboto': 'C:/Windows/Fonts/segoeui.ttf',
        'Ahem': 'C:/Windows/Fonts/segoeui.ttf',
        'MaterialIcons': 'C:/src/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      }.entries) {
        final loader = FontLoader(entry.key);
        loader.addFont(
          File(entry.value)
              .readAsBytes()
              .then((bytes) => ByteData.sublistView(bytes)),
        );
        await loader.load();
      }
    }
  });
  tearDown(() => Get.reset());
  for (final width in [390.0, 1000.0, 1600.0]) {
    testWidgets(
      'Empty debt page keeps tables and explains missing data at $width',
      (tester) async {
        Get.testMode = true;
        tester.view.physicalSize = Size(width, 960);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final c = Get.put(ShopController(MemoryRepository(), ShopData.empty()))
          ..enterDemo(Role.owner);
        c.navigate(5);
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(key: key, child: const BayHaiApp()),
        );
        await tester.pumpAndSettle();
        expect(find.text('Sổ công nợ khách hàng'), findsOneWidget);
        expect(find.text('Chưa có khách hàng phù hợp'), findsOneWidget);
        if (width < 650) {
          await tester.scrollUntilVisible(
            find.text('Chưa chọn khách hàng'),
            240,
            scrollable: find
                .descendant(
                  of: find.byType(ListView).last,
                  matching: find.byType(Scrollable),
                )
                .first,
          );
        }
        expect(find.text('Chưa chọn khách hàng'), findsOneWidget);
        expect(c.data.customers, isEmpty);
        expect(tester.takeException(), isNull);
        if (width == 1600 && const bool.fromEnvironment('UI_SCREENSHOTS')) {
          await tester.runAsync(() async {
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File('design/07-cong-no-flutter-thuc-te.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      },
    );
  }
  testWidgets(
    'Sales can directly create and edit payroll without an admin password',
    (tester) async {
      Get.testMode = true;
      final c = Get.put(ShopController(MemoryRepository(), ShopData.sample()))
        ..enterDemo(Role.sales);
      c.navigate(5);
      await tester.pumpWidget(const BayHaiApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lương nhân viên'));
      await tester.pumpAndSettle();
      expect(find.text('Tạo kỳ lương'), findsOneWidget);
      expect(
        find.text('Nhân viên chỉ xem • không được sửa lương'),
        findsNothing,
      );
      for (final button in tester.widgetList<IconButton>(
        find.byType(IconButton),
      )) {
        if (button.tooltip == 'Sửa lương / ghi chi') {
          expect(button.onPressed, isNotNull);
        }
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Collecting the remaining shipping charge clears the order and customer debt',
    (tester) async {
      Get.testMode = true;
      tester.view.physicalSize = const Size(1600, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final data = ShopData.sample();
      data.checkout(
        requestId: 'debt-view',
        lines: [const CartLine('PR6060VD', 144000)],
        customerId: 'KH001',
        paid: 3456000,
        ship: 50000,
        hold: false,
        actor: const Actor('admin', Role.owner),
      );
      final c = Get.put(ShopController(MemoryRepository(), data))
        ..enterDemo(Role.owner);
      c.navigate(5);
      await tester.pumpWidget(const BayHaiApp());
      await tester.pumpAndSettle();
      expect(find.text('Lịch sử thanh toán'), findsOneWidget);
      expect(find.text('Ghi nhận trả tiền'), findsOneWidget);
      expect(c.data.debt('KH001'), 50000);
      final collect = find.text('Ghi nhận trả tiền');
      await tester.ensureVisible(collect);
      await tester.tap(collect);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Phí giao hàng đã tính: 50.000 đ'),
        findsOneWidget,
      );
      await tester.tap(find.text('Xác nhận đã thu'));
      await tester.pumpAndSettle();
      expect(c.data.debt('KH001'), 0);
      expect(find.text('Đã trả'), findsWidgets);
      expect(collect, findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Customer detail lists have independent pages', (tester) async {
    Get.testMode = true;
    tester.view.physicalSize = const Size(1600, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final data = ShopData.sample();
    const actor = Actor('admin', Role.owner);
    for (var i = 1; i <= 11; i++) {
      data.checkout(
        requestId: 'paged-$i',
        lines: [const CartLine('PR6060VD', 14400)],
        customerId: 'KH001',
        paid: 345600,
        ship: 0,
        hold: false,
        actor: actor,
      );
      data.log(actor, 'Điều chỉnh sổ công nợ', 'KH001', 'Lý do số $i');
    }
    Get.put(ShopController(MemoryRepository(), data))
      ..enterDemo(Role.owner)
      ..navigate(5);
    await tester.pumpWidget(const BayHaiApp());
    await tester.pumpAndSettle();

    Future<void> next(String label) async {
      final button = find.byTooltip('$label — Trang sau');
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
    }

    await next('Lịch sử thanh toán');
    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.text('DH-1 • Đã bán'), findsNothing);
    await next('Đơn hàng của khách');
    expect(find.text('DH-1 • Đã bán'), findsOneWidget);
    expect(find.text('Lý do số 1'), findsNothing);
    await next('Điều chỉnh sổ công nợ');
    expect(find.text('Lý do số 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
