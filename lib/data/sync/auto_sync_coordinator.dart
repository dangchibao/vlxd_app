import 'dart:async';

import 'package:drift/drift.dart';

import 'package:firebase_auth/firebase_auth.dart';

import '../../controllers/shop_controller.dart';
import 'firebase_request_verifier.dart';
import 'auto_recovery_service.dart';
import 'offline_checkout_command.dart';
import 'offline_checkout_preflight.dart';
import 'offline_book_operation.dart';
import 'outbox_reconciler.dart';
import 'outbox_repository.dart';
import 'sync_engine.dart';
import 'sync_runtime.dart';

/// A conservative foreground-only synchronizer for checkout.v1.
///
/// - May retry a confirmed-absent temporary failure, max 3 attempts.
/// - Never retries uncertain/permanent results or without server verification.
/// - Never automatically approves an order flagged for negative stock.
/// - Requires the same logged-in user AND loaded shop session as the creator.
/// - Requires an authoritative server read saying requestId is absent.
/// - Never converts failed -> pending.
/// - Stops on any unverified response or failed dispatch.
///
/// Enable only after emulator / integration testing with
/// --dart-define=AUTO_SYNC_OUTBOX=true.
class AutoSyncCoordinator {
  final FirebaseAuth auth;
  final ShopController shop;
  final OutboxRepository outbox;
  final FirebaseRequestVerifier verifier;
  final OutboxReconciler reconciler;
  final SyncEngine engine;
  final SyncRuntime runtime;

  Timer? _timer;
  StreamSubscription<User?>? _authSubscription;
  bool _running = false;
  bool _initialized = false;
  late final AutoRecoveryService _recovery = AutoRecoveryService(
    outbox: outbox,
    reconciler: reconciler,
  );

  AutoSyncCoordinator({
    required this.auth,
    required this.shop,
    required this.outbox,
    required this.verifier,
    required this.reconciler,
    required this.engine,
    required this.runtime,
  });

  static bool canRetryTemporary({
    required OfflineCheckoutCommand command,
    required String operationId,
    required String status,
    required String? lastError,
    required int attempts,
    required String actorId,
  }) {
    return status == 'failed' &&
        attempts >= 1 &&
        attempts < 3 &&
        (lastError?.startsWith('temporary:') ?? false) &&
        command.requestId == operationId &&
        command.actorId == actorId &&
        OfflineCheckoutPreflight.isValid(command) &&
        command.negativeReason.trim().isEmpty;
  }

  static bool canAttempt({
    required OfflineCheckoutCommand command,
    required String operationId,
    required String status,
    required int attempts,
    required String actorId,
    String? lastError,
  }) {
    return status == 'pending' &&
        (attempts == 0 ||
            lastError == 'manual-retry-verified' ||
            (attempts >= 1 &&
                attempts < 3 &&
                lastError == 'auto-retry-verified')) &&
        command.requestId == operationId &&
        command.actorId == actorId &&
        OfflineCheckoutPreflight.isValid(command) &&
        command.negativeReason.trim().isEmpty;
  }

  void start() {
    if (_timer != null) return;
    _authSubscription = auth.authStateChanges().listen((_) {
      unawaited(checkNow());
    });
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      unawaited(checkNow());
    });
    unawaited(checkNow());
  }

  Future<String> reviewAndRetry(String id) async {
    final uid = auth.currentUser?.uid;
    if (uid == null || shop.actor?.id != uid) {
      throw StateError('Phiên đồng bộ không hợp lệ.');
    }
    final row = await outbox.getById(id);
    if (row == null ||
        row.status != 'failed' ||
        offlineOperationOwner(row) != uid) {
      throw StateError('Giao dịch đã thay đổi. Hãy mở lại danh sách.');
    }
    if (row.operationType == 'checkout.v1' &&
        OfflineCheckoutCommand.decode(row.payloadJson).negativeReason
            .trim()
            .isNotEmpty) {
      throw StateError('Đơn có yêu cầu bán âm cần đối chiếu với chủ cửa hàng.');
    }
    final result = await reconciler.reconcile(id);
    if (result == ReconcileResult.confirmed) {
      return 'Máy chủ đã xác nhận giao dịch.';
    }
    if (result != ReconcileResult.notFound) {
      throw StateError(
        'Chưa xác minh được trên máy chủ. Hãy thử lại khi có mạng.',
      );
    }
    if (auth.currentUser?.uid != uid ||
        shop.actor?.id != uid ||
        !await outbox.requeueReviewed(row)) {
      throw StateError('Giao dịch hoặc phiên đăng nhập đã thay đổi.');
    }
    await checkNow();
    return 'Đã đưa giao dịch vào hàng đợi.';
  }

  Future<void> cancelReviewed(String id) async {
    final uid = auth.currentUser?.uid;
    final row = await outbox.getById(id);
    if (uid == null ||
        shop.actor?.id != uid ||
        row == null ||
        offlineOperationOwner(row) != uid ||
        !OutboxRepository.canCancel(row)) {
      throw StateError('Giao dịch đã thay đổi hoặc chưa thể bỏ an toàn.');
    }
    if (row.attempts > 0 &&
        await reconciler.reconcile(id) != ReconcileResult.notFound) {
      throw StateError('Chưa xác minh được giao dịch vắng mặt trên máy chủ.');
    }
    if (auth.currentUser?.uid != uid ||
        shop.actor?.id != uid ||
        !await outbox.cancelReviewed(row)) {
      throw StateError('Giao dịch hoặc phiên đăng nhập đã thay đổi.');
    }
  }

  Future<void> checkNow() async {
    if (_running) return;
    final user = auth.currentUser;
    if (user == null || !shop.isLive || shop.actor?.id != user.uid) return;

    _running = true;
    try {
      // Initialize once per app process. Interrupted 'syncing' becomes
      // quarantined 'failed', never pending.
      if (!_initialized) {
        await runtime.initialize(
          actorId: user.uid,
          staleAfter: const Duration(minutes: 3),
        );
        _initialized = true;
      } else {
        await outbox.quarantineInterrupted(
          staleAfter: const Duration(minutes: 3),
        );
      }

      // Read-only automatic recovery for interrupted and uncertain checkouts.
      // Does not dispatch, retry or approve any order.
      await _recovery.sweep(actorId: user.uid);

      // Bound a single sweep to avoid monopolizing the app.
      for (var count = 0; count < 20; count++) {
        final current = auth.currentUser;
        if (current == null ||
            current.uid != user.uid ||
            shop.actor?.id != user.uid) {
          return;
        }

        final pending = (await outbox.getPending()).where((row) {
          if (offlineOperationOwner(row) != user.uid) return false;
          if (OfflineBookOperation.supports(row.operationType)) {
            return row.attempts == 0 ||
                row.lastError == 'auto-retry-verified' ||
                row.lastError == 'manual-retry-verified';
          }
          return canAttempt(
            command: OfflineCheckoutCommand.decode(row.payloadJson),
            operationId: row.id,
            status: row.status,
            attempts: row.attempts,
            actorId: user.uid,
            lastError: row.lastError,
          );
        }).firstOrNull;
        if (pending == null) {
          // Chỉ xử lý bản ghi failed do LỖI MẠNG tạm thời.
          // Đọc server trước khi thay đổi trạng thái. Mỗi nhịp tối đa
          // một lần khôi phục; uncertain/permanent không bao giờ retry.
          await _recoverOneTemporaryFailure(user.uid);
          return;
        }
        final next = pending;

        // Don't auto-send if the server cannot AUTHORITATIVELY confirm
        // that this request doesn't exist. Firebase cache is not enough.
        final verification = await reconciler.verifyOperation(next);
        if (verification.status == RequestVerificationStatus.confirmed) {
          await reconciler.reconcile(next.id);
          continue;
        }
        if (verification.status != RequestVerificationStatus.notFound) return;

        // The dispatcher checks identity, price, permissions and server
        // requestId again within its own protected transaction path.
        if (auth.currentUser?.uid != user.uid || shop.actor?.id != user.uid) {
          return;
        }
        final result = await engine.processNext(expectedId: next.id);
        if (result != SyncAttemptResult.synced) return;
      }
    } catch (_) {
      // Never retry within this tick after a local/server error.
      // Pending orders stay pending; next poll must verify on server first.
    } finally {
      _running = false;
    }
  }

  Future<void> _recoverOneTemporaryFailure(String actorId) async {
    final table = outbox.db.pendingOperations;
    final failed =
        await (outbox.db.select(table)
              ..where(
                (t) =>
                    t.status.equals('failed') & t.lastError.like('temporary:%'),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
              ..limit(20))
            .get();
    for (final row in failed) {
      if (offlineOperationOwner(row) != actorId ||
          row.attempts < 1 ||
          row.attempts >= 3) {
        continue;
      }
      if (row.operationType == 'checkout.v1' &&
          !canRetryTemporary(
            command: OfflineCheckoutCommand.decode(row.payloadJson),
            operationId: row.id,
            status: row.status,
            lastError: row.lastError,
            attempts: row.attempts,
            actorId: actorId,
          )) {
        continue;
      }
      if (auth.currentUser?.uid != actorId ||
          shop.actor?.id != actorId ||
          !shop.isLive) {
        return;
      }
      final verification = await reconciler.verifyOperation(row);
      if (verification.status == RequestVerificationStatus.confirmed) {
        await reconciler.reconcile(row.id);
        return;
      }
      if (verification.status != RequestVerificationStatus.notFound) return;
      await outbox.requeueVerifiedTemporary(
        id: row.id,
        expectedAttempts: row.attempts,
        expectedError: row.lastError!,
      );
      return;
    }
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    await _authSubscription?.cancel();
    _authSubscription = null;
  }
}
