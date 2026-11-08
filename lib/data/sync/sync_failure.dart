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

    // Lỗi chưa xác định phải được xử lý thận trọng.
    return SyncFailureKind.uncertain;
  }
}
