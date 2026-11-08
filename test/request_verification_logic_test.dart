import 'package:flutter_test/flutter_test.dart';

import 'package:vlxd_app/data/sync/request_verification_logic.dart';

void main() {
  test('Request và hóa đơn khớp nhau', () {
    final result = RequestVerificationLogic.check(
      requestId: 'request-001',
      requestValue: {'id': 'request-001', 'orderId': 'DH-1'},
      orderValue: {'id': 'DH-1', 'requestId': 'request-001'},
    );

    expect(result, RequestCheckResult.confirmed);
  });

  test('Không tìm thấy request', () {
    final result = RequestVerificationLogic.check(
      requestId: 'request-002',
      requestValue: null,
      orderValue: null,
    );

    expect(result, RequestCheckResult.notFound);
  });

  test('Request có nhưng thiếu hóa đơn', () {
    final result = RequestVerificationLogic.check(
      requestId: 'request-003',
      requestValue: {'id': 'request-003', 'orderId': 'DH-3'},
      orderValue: null,
    );

    expect(result, RequestCheckResult.uncertain);
  });

  test('Request trỏ sai hóa đơn', () {
    final result = RequestVerificationLogic.check(
      requestId: 'request-004',
      requestValue: {'id': 'request-004', 'orderId': 'DH-4'},
      orderValue: {'id': 'DH-5', 'requestId': 'request-004'},
    );

    expect(result, RequestCheckResult.uncertain);
  });
}
