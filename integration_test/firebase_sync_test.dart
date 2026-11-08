import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';

import 'package:vlxd_app/controllers/session_controller.dart';
import 'package:vlxd_app/controllers/shop_controller.dart';
import 'package:vlxd_app/data/firestore_repository.dart';
import 'package:vlxd_app/data/sync/firebase_request_verifier.dart';
import 'package:vlxd_app/domain/shop.dart';

// Chỉ sử dụng Firebase Emulator.
// Tuyệt đối không import FirebaseOptions production.
const options = FirebaseOptions(
  apiKey: 'emulator-only-api-key',
  appId: '1:123:web:emulator',
  messagingSenderId: '123',
  projectId: 'demo-vlxd-tests',
);

// Tạo hồ sơ nhân viên thử nghiệm trong Firestore Emulator.
Future<void> provision(String uid, String role) async {
  final client = HttpClient();

  try {
    final request = await client.patchUrl(
      Uri.parse(
        'http://127.0.0.1:8080/v1/projects/'
        'demo-vlxd-tests/databases/(default)/documents/users/$uid',
      ),
    );

    request.headers.set('Authorization', 'Bearer owner');
    request.headers.contentType = ContentType.json;

    request.write(
      jsonEncode({
        'fields': {
          'role': {'stringValue': role},
          'active': {'booleanValue': true},
          'displayName': {'stringValue': uid},
          'mustChangePassword': {'booleanValue': false},
        },
      }),
    );

    final response = await request.close();
    final body = await utf8.decoder.bind(response).join();

    if (response.statusCode != 200) {
      throw StateError(
        'Emulator fixture failed: '
        '${response.statusCode} $body',
      );
    }
  } finally {
    client.close();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('two Firebase clients sync, retry checkout once, '
      'and allow staff payroll writes', (tester) async {
    // 1. Khởi tạo hai Firebase client thử nghiệm.
    final first = await Firebase.initializeApp(options: options);

    final second = await Firebase.initializeApp(
      name: 'emulator-second',
      options: options,
    );

    final authA = FirebaseAuth.instanceFor(app: first);
    final authB = FirebaseAuth.instanceFor(app: second);

    await authA.useAuthEmulator('127.0.0.1', 9099);
    await authB.useAuthEmulator('127.0.0.1', 9099);

    // 2. Tạo tài khoản thử nghiệm.
    final suffix = DateTime.now().microsecondsSinceEpoch;

    final userA = (await authA.createUserWithEmailAndPassword(
      email: 'owner-$suffix@example.test',
      password: 'Emulator-only-12345',
    )).user!;

    final userB = (await authB.createUserWithEmailAndPassword(
      email: 'sales-$suffix@example.test',
      password: 'Emulator-only-12345',
    )).user!;

    await provision(userA.uid, 'owner');
    await provision(userB.uid, 'sales');

    // 3. Kết nối Firestore Emulator.
    final dbA = FirebaseFirestore.instanceFor(app: first);
    final dbB = FirebaseFirestore.instanceFor(app: second);

    dbA.useFirestoreEmulator('127.0.0.1', 8080);
    dbB.useFirestoreEmulator('127.0.0.1', 8080);

    final repoA = FirestoreRepository(dbA);
    final repoB = FirestoreRepository(dbB);

    final a = Actor(userA.uid, Role.owner);
    final b = Actor(userB.uid, Role.sales);

    // 4. Tạo sản phẩm và nhập tồn kho.
    await repoA.transact((d, actor) {
      d.saveProduct(
        Product(
          id: 'P1',
          code: 'P1',
          name: 'Gạch test',
          size: '60×60',
          supplier: 'Prime',
          price: 240000,
          ratio: 14400,
        ),
        actor,
      );

      d.receive('P1', 1440000, 150000, DateTime.now(), actor, 'L1');
    }, a);

    // 5. Kiểm tra dữ liệu trước khi bán.
    final beforeCheckout = await repoA.load();

    debugPrint(
      'BEFORE CHECKOUT orders: '
      '${beforeCheckout.orders.length}',
    );

    debugPrint(
      'BEFORE CHECKOUT stock: '
      '${beforeCheckout.product('P1').stock}',
    );

    debugPrint(
      'BEFORE CHECKOUT requestIds: '
      '${beforeCheckout.orders.map((o) => o['requestId']).toList()}',
    );

    // 6. Theo dõi đồng bộ hóa đơn.
    final broadcast = repoB
        .watch()
        .firstWhere((d) => d.orders.length == 1)
        .timeout(const Duration(seconds: 30));

    // Giữ cùng requestId để kiểm tra chống tạo đơn trùng.
    Json sell(ShopData d, Actor actor) => d.checkout(
      requestId: 'same-request',
      lines: [const CartLine('P1', 144000)],
      customerId: '',
      paid: 3456000,
      ship: 0,
      hold: false,
      actor: actor,
    );

    // Hai client đồng thời thực hiện cùng một giao dịch.
    await Future.wait([repoA.transact(sell, a), repoB.transact(sell, b)]);

    final afterCheckout = await repoA.load();

    debugPrint(
      'AFTER CHECKOUT orders: '
      '${afterCheckout.orders.length}',
    );

    debugPrint(
      'AFTER CHECKOUT stock: '
      '${afterCheckout.product('P1').stock}',
    );

    // 7. Kiểm tra dữ liệu đồng bộ và server.
    final synced = await broadcast;
    final serverData = await repoA.load();

    debugPrint('WATCH orders: ${synced.orders.length}');

    debugPrint('WATCH stock: ${synced.product('P1').stock}');

    debugPrint('SERVER orders: ${serverData.orders.length}');

    debugPrint('SERVER stock: ${serverData.product('P1').stock}');

    expect(synced.orders, hasLength(1));

    expect(synced.product('P1').stock, 1296000);

    expect(ShopData.collected(synced.orders.first), 3456000);

    // 8. Xác minh requestId qua FirebaseRequestVerifier.
    final verifier = FirebaseRequestVerifier(dbB);

    final confirmed = await verifier.verify('same-request');

    expect(confirmed.status, RequestVerificationStatus.confirmed);

    expect(confirmed.orderId, synced.orders.first['id']);

    // Request không tồn tại phải trả về notFound.
    final missing = await verifier.verify('missing-request-$suffix');

    expect(missing.status, RequestVerificationStatus.notFound);

    // 9. Kiểm tra hai client nhập kho đồng thời.
    await Future.wait([
      repoA.transact(
        (d, actor) =>
            d.receive('P1', 14400, 150000, DateTime.now(), actor, 'L2'),
        a,
      ),
      repoB.transact(
        (d, actor) =>
            d.receive('P1', 28800, 150000, DateTime.now(), actor, 'L3'),
        b,
      ),
    ]);

    final finalData = await repoA.load();

    expect(finalData.product('P1').stock, 1339200);

    expect(finalData.product('P1').lots, hasLength(3));

    // 10. Kiểm tra ghi dữ liệu lương.
    await repoB.transact((d, actor) {
      d.payroll.add({
        'id': 'N1',
        'name': 'Nhân viên',
        'salary': 9999999,
        'advance': 0,
      });

      d.log(actor, 'Tạo kỳ lương', 'N1', 'Nhân viên được phép chỉnh lương');
    }, b);

    expect((await repoA.load()).payroll.single['salary'], 9999999);

    // 11. Kiểm tra quyền truy cập và phiên đăng nhập.
    Get.testMode = true;

    await authB.signOut();

    final shop = Get.put(ShopController(repoB, ShopData.empty()));

    final session = Get.put(SessionController(authB, dbB, shop));

    Future<void> waitUntil(bool Function() done) async {
      final deadline = DateTime.now().add(const Duration(seconds: 20));

      while (!done()) {
        if (DateTime.now().isAfter(deadline)) {
          throw StateError(
            'Session did not reach expected state: '
            '${session.error} / ${shop.syncError}',
          );
        }

        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }

    // Đăng nhập với vai trò sales.
    await session.signIn(userB.email!, 'Emulator-only-12345');

    await waitUntil(() => shop.actor?.id == userB.uid && !shop.syncing);

    expect(shop.actor!.role, Role.sales);

    shop.addCart(shop.data.product('P1'), 14400);

    // 12. Thu hồi quyền nhân viên.
    await dbA.doc('users/${userB.uid}').update({'active': false});

    await waitUntil(() => shop.actor == null);

    expect(shop.data.products, isEmpty);
    expect(shop.cart, isEmpty);

    // 13. Kích hoạt lại và yêu cầu đổi mật khẩu.
    await dbA.doc('users/${userB.uid}').update({
      'active': true,
      'mustChangePassword': true,
    });

    await waitUntil(() => session.mustChangePassword);

    expect(shop.actor, isNull);

    await session.changePassword('Emulator-only-12345', 'Emulator-New-54321');

    await waitUntil(
      () =>
          !session.mustChangePassword &&
          shop.actor?.id == userB.uid &&
          !shop.syncing,
    );

    // 14. Đăng xuất và dọn tài nguyên.
    await session.signOut();

    await waitUntil(() => shop.actor == null);

    await Get.delete<SessionController>(force: true);

    await Get.delete<ShopController>(force: true);

    await authA.signOut();
    await authB.signOut();

    await second.delete();
  });
}
