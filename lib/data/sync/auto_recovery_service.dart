import 'package:drift/drift.dart';

import 'outbox_reconciler.dart';
import 'outbox_repository.dart';

/// Foreground-only, verification-only recovery for interrupted checkouts.
///
/// An authoritative server confirmation may mark a local item as synced.
/// notFound/uncertain NEVER cause a retry, pending reset, dispatch or deletion.
/// The authenticated actor must be checked by the caller before calling sweep.
class AutoRecoveryService {
  final OutboxRepository outbox;
  final OutboxReconciler reconciler;
  final int batchSize;

  int _cursor = 0;
  bool _running = false;

  AutoRecoveryService({
    required this.outbox,
    required this.reconciler,
    this.batchSize = 20,
  }) : assert(batchSize > 0);

  /// Only checkout commands created by this account may be verified.
  /// This method is deliberately read-only with respect to Firebase.
  Future<int> sweep({required String actorId}) async {
    if (_running || actorId.trim().isEmpty) return 0;
    _running = true;
    try {
      final table = outbox.db.pendingOperations;
      final rows =
          await (outbox.db.select(table)
                ..where(
                  (t) =>
                      t.status.equals('failed') |
                      (t.status.equals('pending') &
                          t.attempts.isBiggerThanValue(0)),
                )
                ..orderBy([
                  (t) => OrderingTerm.asc(t.createdAt),
                  (t) => OrderingTerm.asc(t.id),
                ]))
              .get();

      final eligible = rows
          .where((row) => offlineOperationOwner(row) == actorId)
          .toList(growable: false);

      if (eligible.isEmpty) {
        _cursor = 0;
        return 0;
      }

      // Round-robin batches avoid starving newer orders when old ones remain
      // unconfirmed over many polling cycles.
      final start = _cursor % eligible.length;
      final take = batchSize < eligible.length ? batchSize : eligible.length;
      _cursor = (start + take) % eligible.length;
      var confirmed = 0;
      for (var i = 0; i < take; i++) {
        final row = eligible[(start + i) % eligible.length];
        try {
          final result = await reconciler.reconcile(row.id);
          if (result == ReconcileResult.confirmed) confirmed++;
        } catch (_) {
          // Keep the operation untouched. A later sweep may verify again.
        }
      }
      return confirmed;
    } finally {
      _running = false;
    }
  }
}
