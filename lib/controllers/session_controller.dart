import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import '../domain/shop.dart';
import '../data/local/shop_snapshot_cache.dart';
import 'shop_controller.dart';

String loginEmail(String input) {
  final value = input.trim().toLowerCase();

  if (value.contains('@')) return value;

  var key = value;

  if (RegExp(r'^(\+84|84|0)\d{9}$').hasMatch(key)) {
    if (key.startsWith('+84')) {
      key = '0${key.substring(3)}';
    } else if (key.startsWith('84')) {
      key = '0${key.substring(2)}';
    }
  }

  if (!RegExp(r'^[a-z0-9_-]{3,40}$').hasMatch(key)) {
    throw ArgumentError('Nhập email, tên tài khoản hoặc số điện thoại hợp lệ.');
  }

  return '$key@accounts.bayhai.invalid';
}

class SessionController extends GetxController {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final ShopController shop;
  final ShopSnapshotCache? cache;

  SessionController(this.auth, this.firestore, this.shop, {this.cache});

  Future<Json?> _readOfflineProfile(String uid) async {
    try {
      return await cache?.loadProfile(uid);
    } catch (_) {
      return null;
    }
  }

  Future<void> _updateCachedProfile(String uid, Json? profile) async {
    try {
      if (profile == null ||
          profile['active'] != true ||
          profile['mustChangePassword'] != false ||
          !['owner', 'sales'].contains(profile['role'])) {
        await cache?.clear(uid);
      } else {
        await cache?.saveProfile(uid, {
          'active': true,
          'mustChangePassword': false,
          'role': profile['role'],
          'displayName': profile['displayName'],
        });
      }
    } catch (_) {
      // Local storage must not prevent an authenticated online session.
    }
  }

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot<Json>>? _profile;

  bool loading = true;
  bool mustChangePassword = false;

  String? error;

  int _generation = 0;
  int _profileEpoch = 0;

  // ============================================================
  // TRẠNG THÁI ĐỒNG BỘ
  // ============================================================

  /// Kiểm tra điều kiện cục bộ để bắt đầu đồng bộ.
  ///
  /// FirebaseCheckoutDispatcher vẫn phải xác minh
  /// quyền truy cập trực tiếp từ server.
  bool get canStartSync {
    final user = auth.currentUser;
    final actor = shop.actor;

    return user != null &&
        actor != null &&
        actor.id == user.uid &&
        !loading &&
        !mustChangePassword &&
        error == null;
  }

  /// Callback thông báo khi điều kiện đồng bộ thay đổi.
  /// Hiện chưa kết nối với SyncRuntime.
  void Function(bool canSync)? onSyncAvailabilityChanged;

  bool _lastSyncAvailability = false;

  void _notifySyncAvailability() {
    final available = canStartSync;

    if (available == _lastSyncAvailability) return;

    _lastSyncAvailability = available;
    onSyncAvailabilityChanged?.call(available);
  }

  /// Cập nhật giao diện và thông báo trạng thái đồng bộ.
  void _notifyStateChanged() {
    update();
    _notifySyncAvailability();
  }

  // ============================================================
  // ĐIỀU HƯỚNG VÀ QUẢN LÝ PHIÊN
  // ============================================================

  void _closeProtectedRoutes() {
    if (Get.key.currentState != null) {
      Get.until((route) => route.isFirst);
    }
  }

  @override
  void onInit() {
    super.onInit();

    _authSubscription = auth.authStateChanges().listen(
      _onAuth,
      onError: (Object e) {
        error = readableError(e);
        loading = false;
        _notifyStateChanged();
      },
    );
  }

  Future<void> _onAuth(User? user) async {
    final generation = ++_generation;
    ++_profileEpoch;

    await _profile?.cancel();

    _closeProtectedRoutes();

    await shop.clearSession();

    if (generation != _generation) return;

    mustChangePassword = false;
    loading = user != null;

    _notifyStateChanged();

    if (user == null) {
      loading = false;
      _notifyStateChanged();
      return;
    }

    _profile = firestore
        .doc('users/${user.uid}')
        .snapshots(includeMetadataChanges: true)
        .listen(
          (snapshot) async {
            if (generation != _generation) return;

            final epoch = ++_profileEpoch;
            final fromCache = snapshot.metadata.isFromCache;
            final p = fromCache
                ? await _readOfflineProfile(user.uid)
                : snapshot.data();
            if (generation != _generation || epoch != _profileEpoch) return;
            if (!fromCache) await _updateCachedProfile(user.uid, p);
            if (generation != _generation || epoch != _profileEpoch) return;

            // Wait for server authorization if no local lease exists.
            if (fromCache && p == null) {
              loading = false;
              error = 'Cần kết nối mạng để xác nhận quyền trên thiết bị này.';
              await shop.clearSession();
              if (generation == _generation && epoch == _profileEpoch) {
                _notifyStateChanged();
              }
              return;
            }

            if (p == null ||
                p['active'] != true ||
                !['owner', 'sales'].contains(p['role'])) {
              mustChangePassword = false;

              _closeProtectedRoutes();

              await shop.clearSession();

              if (epoch != _profileEpoch || generation != _generation) {
                return;
              }

              error =
                  'Tài khoản chưa được cấp quyền, đã bị khóa '
                  'hoặc vị trí chưa được phép truy cập. '
                  'Liên hệ chủ cửa hàng.';

              loading = false;
              _notifyStateChanged();
              return;
            }

            mustChangePassword = p['mustChangePassword'] == true;

            error = null;
            loading = false;

            if (mustChangePassword) {
              _closeProtectedRoutes();

              await shop.clearSession();

              if (epoch != _profileEpoch || generation != _generation) {
                return;
              }
            } else {
              final role = p['role'] == 'owner' ? Role.owner : Role.sales;

              final displayName = (p['displayName'] as String?)?.trim();

              if (shop.actor?.id != user.uid ||
                  shop.actor?.role != role ||
                  shop.actor?.displayName != displayName ||
                  (!fromCache && shop.syncError != null)) {
                _closeProtectedRoutes();

                await shop.connect(
                  Actor(user.uid, role, displayName: displayName),
                );

                if (epoch != _profileEpoch || generation != _generation) {
                  return;
                }
              }
            }

            if (epoch == _profileEpoch && generation == _generation) {
              _notifyStateChanged();
            }
          },
          onError: (Object e) async {
            if (generation != _generation) return;

            mustChangePassword = false;

            final epoch = ++_profileEpoch;

            _closeProtectedRoutes();

            await shop.clearSession();

            if (epoch != _profileEpoch || generation != _generation) {
              return;
            }

            error = readableError(e);
            loading = false;

            _notifyStateChanged();
          },
        );
  }

  // ============================================================
  // ĐĂNG NHẬP
  // ============================================================

  Future<void> signIn(String account, String password) async {
    loading = true;
    error = null;

    _notifyStateChanged();

    try {
      await auth.signInWithEmailAndPassword(
        email: loginEmail(account),
        password: password,
      );
    } catch (e) {
      loading = false;
      error = readableError(e);
      _notifyStateChanged();
    }
  }

  // ============================================================
  // ĐĂNG XUẤT
  // ============================================================

  Future<void> signOut() async {
    _closeProtectedRoutes();

    // Ngăn bắt đầu đồng bộ mới trước khi đăng xuất.
    loading = true;
    _notifyStateChanged();

    try {
      final uid = auth.currentUser?.uid;
      await auth.signOut();
      if (uid != null) await _updateCachedProfile(uid, null);

      error = null;

      await shop.clearSession();
    } finally {
      loading = false;
      _notifyStateChanged();
    }
  }

  // ============================================================
  // ĐỔI MẬT KHẨU
  // ============================================================

  Future<void> changePassword(String current, String next) async {
    if (next.length < 10 || current == next) {
      throw ArgumentError(
        'Mật khẩu mới cần ít nhất 10 ký tự '
        'và khác mật khẩu cũ.',
      );
    }

    final user = auth.currentUser;

    if (user == null || user.email == null) {
      throw StateError('Chưa đăng nhập.');
    }

    await user.reauthenticateWithCredential(
      EmailAuthProvider.credential(email: user.email!, password: current),
    );

    await user.updatePassword(next);

    await firestore.doc('users/${user.uid}').update({
      'mustChangePassword': false,
    });
  }

  // ============================================================
  // XỬ LÝ LỖI FIREBASE
  // ============================================================

  static String readableError(Object e) {
    if (e is FirebaseException) {
      return switch (e.code) {
        'invalid-credential' ||
        'wrong-password' ||
        'user-not-found' => 'Tài khoản hoặc mật khẩu không đúng.',

        'permission-denied' =>
          'Firestore chưa cấp quyền. '
              'Cần hồ sơ users và Security Rules '
              'được chủ xác nhận triển khai.',

        'unavailable' || 'network-request-failed' =>
          'Không kết nối được máy chủ. '
              'Kiểm tra mạng rồi thử lại.',

        'too-many-requests' =>
          'Thử quá nhiều lần. '
              'Vui lòng chờ rồi thử lại.',

        'user-disabled' => 'Tài khoản đã bị khóa.',

        _ =>
          'Firebase: ${e.code}. '
              'Vui lòng kiểm tra cấu hình hoặc liên hệ chủ.',
      };
    }

    return e.toString();
  }

  // ============================================================
  // GIẢI PHÓNG TÀI NGUYÊN
  // ============================================================

  @override
  void onClose() {
    _authSubscription?.cancel();
    _profile?.cancel();

    onSyncAvailabilityChanged = null;

    super.onClose();
  }
}
