import 'package:flutter_test/flutter_test.dart';

import 'package:vlxd_app/data/sync/sync_failure.dart';

void main() {
  test('Nhận diện lỗi tạm thời', () {
    const error = SyncFailure(
      SyncFailureKind.temporary,
      'Không kết nối được máy chủ',
    );

    expect(SyncFailureClassifier.classify(error), SyncFailureKind.temporary);
  });

  test('Nhận diện lỗi vĩnh viễn', () {
    const error = SyncFailure(
      SyncFailureKind.permanent,
      'Không đủ quyền thực hiện',
    );

    expect(SyncFailureClassifier.classify(error), SyncFailureKind.permanent);
  });

  test('Lỗi không rõ kết quả được giữ ở trạng thái uncertain', () {
    final error = StateError('Không nhận được phản hồi');

    expect(SyncFailureClassifier.classify(error), SyncFailureKind.uncertain);
  });
}
