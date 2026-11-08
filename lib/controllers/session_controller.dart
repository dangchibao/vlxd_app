import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import '../domain/shop.dart';
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

  SessionController(this.auth, this.firestore, this.shop);

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot<Json>>? _profile;

  bool loading = true;
  bool mustChangePassword = false;

  String? error;

  int _generation = 0;
  int _profileEpoch = 0;

  // ============================================================
  // KIỂM TRA ĐIỀU KIỆN ĐỒNG BỘ
  // ============================================================

  /// Chỉ cho phép bắt đầu đồng bộ khi:
  /// - Có tài khoản Firebase đang đăng nhập.
  /// - ShopController đã kết nối đúng tài khoản.
  /// - Không trong quá trình tải phiên đăng nhập.
  /// - Không yêu cầu đổi mật khẩu.
  /// - Không có lỗi phiên đăng nhập.
  ///
  /// Lưu ý:
  /// Getter này chỉ kiểm tra trạng thái cục bộ.
  /// FirebaseCheckoutDispatcher vẫn phải kiểm tra
  /// quyền trực tiếp từ server trước khi gửi giao dịch.
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
        update();
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

    update();

    if (user == null) {
      loading = false;
      update();
      return;
    }

    _profile = firestore
        .doc('users/${user.uid}')
        .snapshots()
        .listen(
          (snapshot) async {
            if (generation != _generation) return;

            final epoch = ++_profileEpoch;
            final p = snapshot.data();

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
              update();
              return;
            }

            mustChangePassword = p['mustChangePassword'] == true;

            error = null;
            loading = false;

            if (mustChangePassword) {
              _closeProtectedRoutes();
              await shop.clearSession();
            } else {
              final role = p['role'] == 'owner' ? Role.owner : Role.sales;

              final displayName = (p['displayName'] as String?)?.trim();

              if (shop.actor?.id != user.uid ||
                  shop.actor?.role != role ||
                  shop.actor?.displayName != displayName) {
                _closeProtectedRoutes();

                await shop.connect(
                  Actor(user.uid, role, displayName: displayName),
                );
              }
            }

            if (epoch == _profileEpoch && generation == _generation) {
              update();
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

            update();
          },
        );
  }

  // ============================================================
  // ĐĂNG NHẬP
  // ============================================================

  Future<void> signIn(String account, String password) async {
    loading = true;
    error = null;

    update();

    try {
      await auth.signInWithEmailAndPassword(
        email: loginEmail(account),
        password: password,
      );
    } catch (e) {
      loading = false;
      error = readableError(e);
      update();
    }
  }

  // ============================================================
  // ĐĂNG XUẤT
  // ============================================================

  Future<void> signOut() async {
    _closeProtectedRoutes();

    await auth.signOut();

    error = null;

    await shop.clearSession();

    update();
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
  // XỬ LÝ THÔNG BÁO LỖI FIREBASE
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

    super.onClose();
  }
}
