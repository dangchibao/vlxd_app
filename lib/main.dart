import 'package:flutter/foundation.dart';
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'controllers/shop_controller.dart';
import 'data/demo_repository.dart';
import 'data/firestore_repository.dart';
import 'controllers/session_controller.dart';
import 'firebase_options.dart';
import 'domain/shop.dart';
import 'ui/app.dart';
import 'ui/store_selection.dart';
import 'data/store_profile.dart';

import 'data/local/app_database.dart';
import 'data/local/cart_draft_repository.dart';
import 'data/local/shop_snapshot_cache.dart';
import 'data/sync/outbox_repository.dart';
import 'data/sync/sync_engine.dart';
import 'data/sync/sync_runtime.dart';
import 'data/sync/firebase_checkout_dispatcher.dart';
import 'data/sync/firebase_request_verifier.dart';
import 'data/sync/outbox_reconciler.dart';
import 'data/sync/auto_sync_coordinator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb &&
      [
        TargetPlatform.windows,
        TargetPlatform.macOS,
      ].contains(defaultTargetPlatform)) {
    final window = WindowManager.instance.getCurrent();
    if (window != null) {
      window.minimumSize = const Size(1000, 700).toNative();
      window.title = 'Quản lý cửa hàng VLXD';
    }
  }
  try {
    const demo = bool.fromEnvironment('DEMO_MODE', defaultValue: false);
    if (demo) {
      final repository = DemoRepository(SharedPreferencesAsync());
      Get.put(ShopController(repository, await repository.load()));
    } else {
      _showStoreSelection();
      runApp(BayHaiApp(homeChanges: _storeHome));
      return;
    }
    runApp(const BayHaiApp());
  } catch (error) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SelectableText(
                'Không khởi động được ứng dụng. Không có dữ liệu nào bị ghi đè.\n$error\nBạn có thể chạy bản thử với --dart-define=DEMO_MODE=true.',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

bool _switchingStore = false;
final _configuredFirebaseApps = <String>{};
final _storeHome = ValueNotifier<Widget?>(null);

void _showStoreSelection() {
  _storeHome.value = StoreSelectionPage(onSelected: _openStore);
}

Future<void> _chooseAnotherStore() async {
  if (_switchingStore) return;
  _switchingStore = true;
  try {
    if (Get.isRegistered<AutoSyncCoordinator>()) {
      await Get.find<AutoSyncCoordinator>().stop();
    }
    if (Get.isRegistered<SessionController>()) {
      final session = Get.find<SessionController>();
      await session.signOut();
      await session.shutdown();
    }
    _storeHome.value = const SizedBox.shrink();
    await WidgetsBinding.instance.endOfFrame;
    if (Get.isRegistered<AppDatabase>()) {
      await Get.find<AppDatabase>().close();
    }
    Get.delete<SessionController>(force: true);
    Get.delete<ShopController>(force: true);
    Get.delete<AutoSyncCoordinator>(force: true);
    Get.delete<SyncRuntime>(force: true);
    Get.delete<OutboxReconciler>(force: true);
    Get.delete<OutboxRepository>(force: true);
    Get.delete<CartDraftRepository>(force: true);
    Get.delete<AppDatabase>(force: true);
    _showStoreSelection();
  } finally {
    _switchingStore = false;
  }
}

Future<void> _openStore(StoreProfile store) async {
  StoreProfile.current = store;
  StoreProfile.chooseAnother = _chooseAnotherStore;
  if (!kIsWeb &&
      [
        TargetPlatform.windows,
        TargetPlatform.macOS,
      ].contains(defaultTargetPlatform)) {
    final window = WindowManager.instance.getCurrent();
    if (window != null) window.title = 'VLXD ${store.name}';
  }
  try {
    const emulator = bool.fromEnvironment('USE_FIREBASE_EMULATOR');
    final options = emulator
        ? const FirebaseOptions(
            apiKey: 'emulator-only-api-key',
            appId: '1:123:web:emulator',
            messagingSenderId: '123',
            projectId: 'demo-vlxd-tests',
          )
        : DefaultFirebaseOptions.currentPlatform;
    if (!emulator && options.projectId != 'vlxd-bay-hai') {
      throw StateError('Firebase project ID không khớp vlxd-bay-hai.');
    }
    // Use the default Firebase app in both modes. Some Firebase plugins
    // resolve [DEFAULT] internally even when auth/firestore are passed an
    // explicit app, so a named-only emulator app can fail at startup.
    // USE_FIREBASE_EMULATOR still selects isolated demo credentials and
    // routes Auth/Firestore to localhost below.
    final defaultApp = Firebase.apps.isEmpty
        ? await Firebase.initializeApp(options: options)
        : Firebase.app();
    final appName = 'store-${store.id}';
    final app = store.id == StoreProfile.bayHai.id
        ? defaultApp
        : Firebase.apps.any((app) => app.name == appName)
        ? Firebase.app(appName)
        : await Firebase.initializeApp(name: appName, options: options);
    // Separate Auth persistence and SDK caches as well as Firestore paths.
    // Keep DEFAULT configured for plugins that resolve it internally.
    for (final target in {defaultApp.name: defaultApp, app.name: app}.values) {
      if (_configuredFirebaseApps.contains(target.name)) continue;
      final targetFirestore = FirebaseFirestore.instanceFor(app: target);
      if (!kIsWeb) {
        targetFirestore.settings = const Settings(persistenceEnabled: false);
      }
      if (emulator) {
        const host = String.fromEnvironment(
          'FIREBASE_EMULATOR_HOST',
          defaultValue: '127.0.0.1',
        );
        await FirebaseAuth.instanceFor(app: target).useAuthEmulator(host, 9099);
        targetFirestore.useFirestoreEmulator(host, 8080);
      }
      _configuredFirebaseApps.add(target.name);
    }
    final auth = FirebaseAuth.instanceFor(app: app);
    final firestore = FirebaseFirestore.instanceFor(app: app);

    final repository = FirestoreRepository(firestore, storeId: store.id);

    final shop = Get.put(ShopController(repository, ShopData.empty()));

    // Database cục bộ.
    final localDb = Get.put(
      emulator
          ? AppDatabase.forEmulator(storeId: store.id)
          : AppDatabase(storeId: store.id),
      permanent: true,
    );

    // Hàng đợi thao tác offline.
    final outbox = Get.put(OutboxRepository(localDb), permanent: true);
    shop.attachCheckoutOutbox(outbox);
    final snapshotCache = ShopSnapshotCache(localDb);
    shop.attachShopSnapshotCache(snapshotCache);

    shop.attachCartDrafts(
      Get.put(CartDraftRepository(localDb), permanent: true),
    );

    // Xác minh hóa đơn với Firebase.
    final verifier = FirebaseRequestVerifier(firestore, storeId: store.id);

    // Dispatcher xử lý checkout.v1.
    final checkoutDispatcher = FirebaseCheckoutDispatcher(
      auth: auth,
      repository: repository,
      verifier: verifier,
    );

    // Bộ máy đồng bộ.
    final syncEngine = SyncEngine(
      outbox: outbox,
      dispatcher: checkoutDispatcher.dispatch,
    );

    // Điều phối đồng bộ.

    final reconciler = Get.put(
      OutboxReconciler(
        outbox: outbox,
        verifyRequest: verifier.verify,
        verifyBook: verifier.verifyBook,
      ),
      permanent: true,
    );

    final syncRuntime = Get.put(
      SyncRuntime(outbox: outbox, reconciler: reconciler, engine: syncEngine),
      permanent: true,
    );

    // Automatic foreground sync approved with generation-isolated local data.
    // Emulator testing: --dart-define=USE_FIREBASE_EMULATOR=true
    //                   --dart-define=AUTO_SYNC_OUTBOX=true
    const autoSyncEnabled = bool.fromEnvironment(
      'AUTO_SYNC_OUTBOX',
      defaultValue: true,
    );
    // Both flags can still disable sync for a diagnostic build.
    const allowProductionAutoSync = bool.fromEnvironment(
      'ALLOW_PRODUCTION_AUTO_SYNC',
      defaultValue: true,
    );
    if (autoSyncEnabled && (emulator || allowProductionAutoSync)) {
      final autoSync = Get.put(
        AutoSyncCoordinator(
          auth: auth,
          shop: shop,
          outbox: outbox,
          verifier: verifier,
          reconciler: reconciler,
          engine: syncEngine,
          runtime: syncRuntime,
        ),
        permanent: true,
      );
      autoSync.start();
    }

    // Giữ nguyên cơ chế đăng nhập hiện có.
    Get.put(
      SessionController(
        auth,
        firestore,
        shop,
        cache: snapshotCache,
        storeId: store.id,
      ),
    );

    _storeHome.value = null;
  } catch (error) {
    await _chooseAnotherStore();
    Get.snackbar(
      'Chưa mở được cửa hàng',
      SessionController.readableError(error),
    );
  }
}
