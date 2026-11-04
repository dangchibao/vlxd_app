import 'package:flutter/foundation.dart';
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
      window.title = 'VLXD Bảy Hải';
    }
  }
  try {
    const demo = bool.fromEnvironment('DEMO_MODE', defaultValue: false);
    if (demo) {
      final repository = DemoRepository(SharedPreferencesAsync());
      Get.put(ShopController(repository, await repository.load()));
    } else {
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
      final app = await Firebase.initializeApp(
        name: emulator ? 'bay-hai-emulator' : null,
        options: options,
      );
      final auth = FirebaseAuth.instanceFor(app: app);
      final firestore = FirebaseFirestore.instanceFor(app: app);
      if (!kIsWeb) {
        firestore.settings = const Settings(persistenceEnabled: false);
      }
      if (emulator) {
        const host = String.fromEnvironment(
          'FIREBASE_EMULATOR_HOST',
          defaultValue: '127.0.0.1',
        );
        await auth.useAuthEmulator(host, 9099);
        firestore.useFirestoreEmulator(host, 8080);
      }
      final shop = Get.put(
        ShopController(FirestoreRepository(firestore), ShopData.empty()),
      );
      Get.put(SessionController(auth, firestore, shop));
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
