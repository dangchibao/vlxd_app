import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:integration_test/integration_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vlxd_app/main.dart' as application;
import 'package:vlxd_app/controllers/session_controller.dart';
import 'package:vlxd_app/controllers/shop_controller.dart';
import 'package:vlxd_app/data/store_profile.dart';
import 'package:vlxd_app/data/sync/auto_sync_coordinator.dart';
import 'package:vlxd_app/data/sync/outbox_repository.dart';

const project = 'demo-vlxd-tests';
const password = 'Emulator-only-12345';
const base =
    'http://127.0.0.1:8080/v1/projects/$project/databases/(default)/documents';

dynamic fieldValue(dynamic value) {
  if (value is bool) return {'booleanValue': value};
  if (value is int) return {'integerValue': '$value'};
  if (value is String) return {'stringValue': value};
  if (value is List) {
    return {
      'arrayValue': {'values': value.map(fieldValue).toList()},
    };
  }
  return {
    'mapValue': {'fields': fields(value as Map<String, dynamic>)},
  };
}

Map<String, dynamic> fields(Map<String, dynamic> value) =>
    value.map((key, value) => MapEntry(key, fieldValue(value)));

Future<Map<String, dynamic>> http(
  String url,
  String method,
  Map<String, dynamic> body,
) async {
  final client = HttpClient();
  try {
    final request = await client.openUrl(method, Uri.parse(url));
    request.headers.contentType = ContentType.json;
    if (url.startsWith(base)) {
      request.headers.set('Authorization', 'Bearer owner');
    }
    request.write(jsonEncode(body));
    final response = await request.close();
    final data = await utf8.decoder.bind(response).join();
    if (response.statusCode != 200) {
      throw StateError('Emulator fixture ${response.statusCode}');
    }
    return jsonDecode(data) as Map<String, dynamic>;
  } finally {
    client.close();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'selecting stores isolates data, permissions and pending checkout',
    (tester) async {
      final suffix = DateTime.now().microsecondsSinceEpoch;
      final sharedEmail = 'shared-$suffix@example.test';
      final outsiderEmail = 'bay-only-$suffix@example.test';
      Future<String> account(String email) async =>
          (await http(
                'http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signUp?key=emulator-only-api-key',
                'POST',
                {
                  'email': email,
                  'password': password,
                  'returnSecureToken': true,
                },
              ))['localId']
              as String;
      await tester.runAsync(() async {
        final shared = await account(sharedEmail),
            outsider = await account(outsiderEmail);
        final owner = {
          'role': 'owner',
          'active': true,
          'displayName': 'Shared QA',
          'mustChangePassword': false,
        };
        await http('$base/users/$shared', 'PATCH', {'fields': fields(owner)});
        await http('$base/users/$outsider', 'PATCH', {
          'fields': fields({...owner, 'role': 'sales'}),
        });
        await http('$base/stores/hai-soc/members/$shared', 'PATCH', {
          'fields': fields(owner),
        });
        for (final store in StoreProfile.stores) {
          await http('$base/stores/${store.id}/meta/state', 'PATCH', {
            'fields': fields({'revision': 0}),
          });
          await http('$base/stores/${store.id}/products/SAME', 'PATCH', {
            'fields': fields({
              'value': {
                'id': 'SAME',
                'code': 'SAME',
                'name': 'Product ${store.id}',
                'size': 'm³',
                'supplier': 'QA',
                'price': 100000,
                'ratio': 0,
                'minimum': 0,
                'active': true,
                'images': <String>[],
                'lots': [
                  {
                    'id': 'lot',
                    'date': '2026-11-13T00:00:00Z',
                    'area': 100000,
                    'reserved': 0,
                    'cost': 50000,
                    'ratio': 0,
                  },
                ],
              },
            }),
          });
        }
      });
      debugPrint('Store fixtures created.');

      Future<void> until(bool Function() ready) async {
        for (var i = 0; i < 300; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          if (ready()) return;
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 30)),
          );
        }
        throw StateError(
          'Store UI timed out: ${Get.isRegistered<SessionController>() ? Get.find<SessionController>().error : "no session"}',
        );
      }

      Future<void> open(String name) async {
        debugPrint('Opening $name.');
        await tester.tap(find.text('Cửa hàng $name'));
        await until(
          () =>
              Get.isRegistered<SessionController>() &&
              !Get.find<SessionController>().loading,
        );
      }

      Future<void> login(String email) async {
        debugPrint('Starting emulator login.');
        await tester.runAsync(
          () => Get.find<SessionController>().signIn(email, password),
        );
        await until(
          () =>
              Get.find<ShopController>().actor != null &&
              !Get.find<ShopController>().syncing,
        );
      }

      Future<void> switchStore() async {
        var done = false;
        Object? failure;
        final switching = StoreProfile.chooseAnother!().then<void>(
          (_) {
            done = true;
          },
          onError: (Object error, StackTrace stack) {
            failure = error;
            done = true;
          },
        );
        // Switching deliberately waits for the old widgets to unmount.
        // Keep pumping frames while that future is in flight.
        await until(() => done);
        await switching;
        if (failure != null) throw StateError('Store switch failed: $failure');
        await tester.pumpAndSettle();
      }

      await application.main();
      debugPrint('Store selection mounted.');
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 15),
      );
      await open('Hai Sóc');
      await login(sharedEmail);
      debugPrint('Hai Sóc login verified.');
      var shop = Get.find<ShopController>();
      expect(shop.data.products.single.name, 'Product hai-soc');
      await tester.runAsync(() => Get.find<AutoSyncCoordinator>().stop());
      debugPrint('Automatic sync paused for offline fixture.');
      shop.addCart(shop.data.products.single, 10000);
      final queued = await tester.runAsync(
        () => shop.queueOfflineCheckout(
          outbox: Get.find<OutboxRepository>(),
          customerId: '',
          paid: 100000,
          ship: 0,
        ),
      );
      debugPrint('Offline checkout stored in Hai Sóc.');
      expect(queued, isNotNull);
      debugPrint('Switching away from Hai Sóc.');
      await switchStore();
      debugPrint('Returned to store selection.');
      await open('Bảy Hải');
      await login(sharedEmail);
      shop = Get.find<ShopController>();
      expect(shop.data.products.single.name, 'Product bay-hai');
      debugPrint('Bảy Hải data verified.');
      expect(
        await tester.runAsync(
          () => Get.find<OutboxRepository>().getById(queued!),
        ),
        isNull,
      );
      final firestore = Get.find<SessionController>().firestore;
      expect(
        (await tester.runAsync(
          () => firestore
              .collection('stores/bay-hai/orders')
              .get(const GetOptions(source: Source.server)),
        ))!.docs,
        isEmpty,
      );
      await switchStore();
      await open('Hai Sóc');
      await login(sharedEmail);
      await until(() => Get.find<ShopController>().data.orders.length == 1);
      expect(Get.find<ShopController>().data.products.single.stock, 90000);
      final currentFirestore = Get.find<SessionController>().firestore;
      final bayProduct = await tester.runAsync(
        () => currentFirestore
            .doc('stores/bay-hai/products/SAME')
            .get(const GetOptions(source: Source.server)),
      );
      final bayValue = bayProduct!.data()!['value'] as Map<String, dynamic>;
      expect((bayValue['lots'] as List).single['area'], 100000);
      expect(
        (await tester.runAsync(
          () => currentFirestore
              .collection('stores/bay-hai/orders')
              .get(const GetOptions(source: Source.server)),
        ))!.docs,
        isEmpty,
      );
      await switchStore();
      await open('Hai Sóc');
      await tester.runAsync(
        () => Get.find<SessionController>().signIn(outsiderEmail, password),
      );
      await until(() => Get.find<SessionController>().error != null);
      expect(Get.find<ShopController>().actor, isNull);
      await switchStore();
    },
  );
}
