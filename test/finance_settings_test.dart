// Match the Material widgets rendered by lib/ui/app.dart.
// ignore: deprecated_member_use
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

Future<ShopController> open(
  WidgetTester tester, {
  Role role = Role.sales,
}) async {
  Get.testMode = true;
  tester.view.physicalSize = const Size(1600, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final c = Get.put(ShopController(MemoryRepository(), ShopData.sample()))
    ..enterDemo(role);
  c.navigate(5);
  await tester.pumpWidget(const BayHaiApp());
  await tester.pumpAndSettle();
  return c;
}

void main() {
  tearDown(() => Get.reset());

  testWidgets(
    'Sales directly edit debt totals through settings without password',
    (tester) async {
      final c = await open(tester);
      await tester.tap(find.byTooltip('Cài đặt sổ công nợ'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.textContaining('${c.data.customers.first['name']} • Còn nợ'),
      );
      await tester.pumpAndSettle();
      await tester.enterText(input('Phải thu (đ)'), '1000000');
      await tester.enterText(input('Đã thu (đ)'), '200000');
      await tester.enterText(
        input('Lý do điều chỉnh (bắt buộc)'),
        'Nhập nợ cũ',
      );
      await tester.tap(find.text('Lưu điều chỉnh'));
      await tester.pumpAndSettle();
      expect(c.data.debt(c.data.customers.first['id']), 800000);
      expect(c.data.orders, isEmpty);
      expect(c.actor!.role, Role.sales);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Sales can open payroll settings without a password', (
    tester,
  ) async {
    final c = await open(tester);
    final salaryBefore = c.data.payroll.first['salary'];
    final advanceBefore = c.data.payroll.first['advance'];
    await tester.tap(find.widgetWithText(ChoiceChip, 'Lương nhân viên'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Cài đặt lương'), findsOneWidget);
    expect(find.text('Tạo kỳ lương'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Cài đặt lương'));
    await tester.tap(find.byTooltip('Cài đặt lương'));
    await tester.pumpAndSettle();
    expect(find.text('Quản lý lương nhân viên'), findsOneWidget);
    expect(c.data.payroll.first['salary'], salaryBefore);
    expect(c.data.payroll.first['advance'], advanceBefore);
    expect(tester.takeException(), isNull);
  });

  for (final role in [Role.owner, Role.sales]) {
    testWidgets('$role can edit payroll through settings', (tester) async {
      final c = await open(tester, role: role);
      final p = c.data.payroll.first;
      await tester.tap(find.widgetWithText(ChoiceChip, 'Lương nhân viên'));
      await tester.pumpAndSettle();
      final gear = find.byTooltip('Cài đặt lương');
      expect(gear, findsOneWidget);
      await tester.ensureVisible(gear);
      await tester.tap(gear);
      await tester.pumpAndSettle();
      await tester.tap(find.text('${p['name']} • ${p['period']}'));
      await tester.pumpAndSettle();
      await tester.enterText(input('Lương kỳ này (đ)'), '9000000');
      await tester.enterText(input('Tổng đã ứng / đã trả (đ)'), '1000000');
      await tester.tap(find.text('Lưu'));
      await tester.pumpAndSettle();
      expect(c.data.payroll.first['salary'], 9000000);
      expect(c.data.payroll.first['advance'], 1000000);
      expect(c.actor!.role, role);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Red X requires confirmation and archives a customer', (
    tester,
  ) async {
    final c = await open(tester);
    final x = find.byTooltip('Xóa khách hàng').first;
    await tester.ensureVisible(x);
    await tester.tap(x);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(c.data.customers.first['active'], isNot(false));
    await tester.tap(x);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xác nhận'));
    await tester.pumpAndSettle();
    expect(c.data.customers.first['active'], isFalse);
    expect(tester.takeException(), isNull);
  });
}
