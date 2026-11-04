import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:get/get.dart';
import 'package:vlxd_app/controllers/session_controller.dart';
import 'package:vlxd_app/controllers/shop_controller.dart';
import 'package:vlxd_app/data/firestore_repository.dart';
import 'package:vlxd_app/domain/shop.dart';

// Emulator-only fixture setup. Never import the production Firebase options.
const options = FirebaseOptions(
  apiKey: 'emulator-only-api-key',
  appId: '1:123:web:emulator',
  messagingSenderId: '123',
  projectId: 'demo-vlxd-tests',
);
Future<void> provision(String uid, String role) async {
  final client = HttpClient();
  try {
    final request = await client.patchUrl(
      Uri.parse(
        'http://127.0.0.1:8080/v1/projects/demo-vlxd-tests/databases/(default)/documents/users/$uid',
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
      throw StateError('Emulator fixture failed: ${response.statusCode} $body');
    }
  } finally {
    client.close();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'two Firebase clients sync, retry checkout once, and allow staff payroll writes',
    (tester) async {
      final first = await Firebase.initializeApp(options: options);
      final second = await Firebase.initializeApp(
        name: 'emulator-second',
        options: options,
      );
      final authA = FirebaseAuth.instanceFor(app: first),
          authB = FirebaseAuth.instanceFor(app: second);
      await authA.useAuthEmulator('127.0.0.1', 9099);
      await authB.useAuthEmulator('127.0.0.1', 9099);
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
      final dbA = FirebaseFirestore.instanceFor(app: first),
          dbB = FirebaseFirestore.instanceFor(app: second);
      dbA.useFirestoreEmulator('127.0.0.1', 8080);
      dbB.useFirestoreEmulator('127.0.0.1', 8080);
      final repoA = FirestoreRepository(dbA), repoB = FirestoreRepository(dbB);
      final a = Actor(userA.uid, Role.owner), b = Actor(userB.uid, Role.sales);
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
      final broadcast = repoB
          .watch()
          .firstWhere((d) => d.orders.length == 1)
          .timeout(const Duration(seconds: 30));
      Json sell(ShopData d, Actor actor) => d.checkout(
        requestId: 'same-request',
        lines: [const CartLine('P1', 144000)],
        customerId: '',
        paid: 3456000,
        ship: 0,
        hold: false,
        actor: actor,
      );
      await Future.wait([repoA.transact(sell, a), repoB.transact(sell, b)]);
      final synced = await broadcast;
      expect(synced.orders, hasLength(1));
      expect(synced.product('P1').stock, 1296000);
      expect(ShopData.collected(synced.orders.first), 3456000);
      // Two different actions must rebase instead of overwriting each other.
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
      Get.testMode = true;
      await authB.signOut();
      final shop = Get.put(ShopController(repoB, ShopData.empty()));
      final session = Get.put(SessionController(authB, dbB, shop));
      Future<void> waitUntil(bool Function() done) async {
        final deadline = DateTime.now().add(const Duration(seconds: 20));
        while (!done()) {
          if (DateTime.now().isAfter(deadline)) {
            throw StateError(
              'Session did not reach expected state: ${session.error} / ${shop.syncError}',
            );
          }
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      }

      await session.signIn(userB.email!, 'Emulator-only-12345');
      await waitUntil(() => shop.actor?.id == userB.uid && !shop.syncing);
      expect(shop.actor!.role, Role.sales);
      shop.addCart(shop.data.product('P1'), 14400);
      await dbA.doc('users/${userB.uid}').update({'active': false});
      await waitUntil(() => shop.actor == null);
      expect(shop.data.products, isEmpty);
      expect(shop.cart, isEmpty);
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
      await session.signOut();
      await waitUntil(() => shop.actor == null);
      await Get.delete<SessionController>(force: true);
      await Get.delete<ShopController>(force: true);
      await authA.signOut();
      await authB.signOut();
      await second.delete();
    },
  );
}
