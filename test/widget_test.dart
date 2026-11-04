import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:vlxd_app/controllers/shop_controller.dart';
import 'package:vlxd_app/ui/app.dart';
import 'package:vlxd_app/domain/shop.dart';
import 'package:vlxd_app/controllers/session_controller.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'shop_test.dart' show MemoryRepository;

class PreviewAuth extends Fake implements FirebaseAuth {
  @override
  User? get currentUser => null;
  @override
  Stream<User?> authStateChanges() => const Stream<User?>.empty();
}

class PreviewFirestore extends Fake implements FirebaseFirestore {}

class PreviewSession extends SessionController {
  PreviewSession(ShopController shop)
    : super(PreviewAuth(), PreviewFirestore(), shop);
  @override
  void onInit() {
    super.onInit();
    loading = false;
  }
}

void main() {
  setUp(() {
    Get.testMode = true;
  });
  tearDown(() => Get.reset());
  for (final width in [320.0, 390.0, 768.0, 1440.0]) {
    testWidgets('Firebase login and mandatory password form fit $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = Get.put(ShopController(MemoryRepository(), ShopData.empty()));
      final session = Get.put<SessionController>(PreviewSession(c));
      await tester.pumpWidget(const BayHaiApp());
      await tester.pumpAndSettle();
      expect(find.text('Tài khoản / SĐT / Email'), findsOneWidget);
      expect(find.text('Dùng thử với vai trò Chủ'), findsNothing);
      expect(tester.takeException(), isNull);
      session.mustChangePassword = true;
      session.update();
      await tester.pumpAndSettle();
      expect(find.text('Đổi mật khẩu tạm'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    testWidgets('login and every main page fit width $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final c = Get.put(ShopController(MemoryRepository(), ShopData.sample()));
      await tester.pumpWidget(const BayHaiApp());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      c.enterDemo(Role.owner);
      for (var i = 0; i < 9; i++) {
        c.navigate(i);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'page $i at $width');
      }
    });
  }
  testWidgets(
    'scan requires explicit confirmation and unknown codes do not add',
    (tester) async {
      final c = Get.put(ShopController(MemoryRepository(), ShopData.sample()))
        ..enterDemo(Role.sales);
      c.navigate(2);
      await tester.pumpWidget(const BayHaiApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quét / nhập mã'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'PR6060VD');
      await tester.tap(find.text('Tìm sản phẩm'));
      await tester.pumpAndSettle();
      expect(c.cart, isEmpty);
      expect(find.text('Thêm sản phẩm vào giỏ?'), findsOneWidget);
      await tester.tap(find.text('Thêm vào giỏ hàng'));
      await tester.pumpAndSettle();
      expect(c.cart, hasLength(1));
      expect(c.cart.first.area, 14400);
    },
  );
}
