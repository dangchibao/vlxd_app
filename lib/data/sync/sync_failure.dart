import 'package:firebase_core/firebase_core.dart';

enum SyncFailureKind { temporary, permanent, uncertain }

class SyncFailure implements Exception {
  final SyncFailureKind kind;
  final String message;

  const SyncFailure(this.kind, this.message);

  @override
  String toString() => message;
}

class SyncFailureClassifier {
  static SyncFailureKind classify(Object error) {
    if (error is SyncFailure) {
      return error.kind;
    }

    if (error is FirebaseException) {
      // Chỉ phân loại lỗi kết nối rõ ràng là tạm thời. Kết quả ghi
      // có thể chưa rõ nên bộ retry vẫn PHẢI đọc server trước khi gửi lại.
      if (error.code == 'unavailable' || error.code == 'deadline-exceeded') {
        return SyncFailureKind.temporary;
      }
      if (error.code == 'permission-denied' ||
          error.code == 'unauthenticated' ||
          error.code == 'invalid-argument') {
        return SyncFailureKind.permanent;
      }
    }
    // Lỗi chưa xác định phải được xử lý thận trọng.
    return SyncFailureKind.uncertain;
  }
}
