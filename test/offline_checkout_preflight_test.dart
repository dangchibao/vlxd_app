import 'package:flutter_test/flutter_test.dart';
import 'package:vlxd_app/data/sync/offline_checkout_command.dart';
import 'package:vlxd_app/data/sync/offline_checkout_preflight.dart';

void main() {
  OfflineCheckoutCommand make({
    String requestId = 'req-1',
    String actorId = 'staff-1',
    String customerId = 'customer-1',
    List<OfflineCheckoutLine>? lines,
    int paid = 100000,
    int ship = 0,
  }) => OfflineCheckoutCommand(
    requestId: requestId,
    actorId: actorId,
    customerId: customerId,
    lines:
        lines ??
        const [
          OfflineCheckoutLine(
            productId: 'p-1',
            area: 10000,
            note: '',
            quotedPrice: 100000,
            quotedRatio: 10000,
          ),
        ],
    paid: paid,
    ship: ship,
    hold: false,
    negativeReason: '',
    createdAt: DateTime.utc(2026, 11, 8),
  );

  test('valid offline checkout passes local preflight', () {
    expect(OfflineCheckoutPreflight.isValid(make()), isTrue);
  });

  test('invalid request or missing identity is rejected', () {
    expect(OfflineCheckoutPreflight.isValid(make(requestId: 'x/y')), isFalse);
    expect(OfflineCheckoutPreflight.isValid(make(actorId: ' ')), isFalse);
    expect(OfflineCheckoutPreflight.isValid(make(customerId: '')), isTrue);
    expect(
      OfflineCheckoutPreflight.isValid(make(customerId: '', paid: 99999)),
      isFalse,
    );
  });

  test('empty lines or nonpositive area are rejected', () {
    expect(OfflineCheckoutPreflight.isValid(make(lines: [])), isFalse);
    expect(
      OfflineCheckoutPreflight.isValid(
        make(
          lines: const [
            OfflineCheckoutLine(
              productId: 'p-1',
              area: -10000,
              note: '',
              quotedPrice: 100000,
              quotedRatio: 10000,
            ),
          ],
        ),
      ),
      isFalse,
    );
  });

  test('negative money is rejected', () {
    expect(OfflineCheckoutPreflight.isValid(make(paid: -1)), isFalse);
    expect(OfflineCheckoutPreflight.isValid(make(ship: -1)), isFalse);
  });

  test('invalid price and unit ratio are rejected', () {
    expect(
      OfflineCheckoutPreflight.isValid(
        make(
          lines: const [
            OfflineCheckoutLine(
              productId: 'p-1',
              area: 10000,
              note: '',
              quotedPrice: double.nan,
              quotedRatio: 10000,
            ),
          ],
        ),
      ),
      isFalse,
    );
    expect(
      OfflineCheckoutPreflight.isValid(
        make(
          lines: const [
            OfflineCheckoutLine(
              productId: 'p-1',
              area: 10000,
              note: '',
              quotedPrice: 100000,
              quotedRatio: -1,
            ),
          ],
        ),
      ),
      isFalse,
    );
  });
}
