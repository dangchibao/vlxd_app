import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import '../../controllers/shop_controller.dart';
import 'firebase_request_verifier.dart';
import 'offline_checkout_command.dart';
import 'outbox_reconciler.dart';
import 'outbox_repository.dart';
import 'sync_engine.dart';
import 'sync_runtime.dart';

/// A conservative foreground-only synchronizer for checkout.v1.
///
/// - Never retries a previously claimed operation (attempts > 0).
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

  AutoSyncCoordinator({
    required this.auth,
    required this.shop,
    required this.outbox,
    required this.verifier,
    required this.reconciler,
    required this.engine,
    required this.runtime,
  });

  static bool canAttempt({
    required OfflineCheckoutCommand command,
    required String operationId,
    required String status,
    required int attempts,
    required String actorId,
  }) {
    return status == 'pending' &&
        attempts == 0 &&
        command.requestId == operationId &&
        command.actorId == actorId &&
        command.lines.isNotEmpty &&
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

  Future<void> checkNow() async {
    if (_running) return;
    final user = auth.currentUser;
    if (user == null || !shop.isLive || shop.actor?.id != user.uid) return;

    _running = true;
    try {
      // Initialize once per app process. Interrupted 'syncing' becomes
      // quarantined 'failed', never pending.
      if (!_initialized) {
        await runtime.initialize();
        _initialized = true;
      }

      // Bound a single sweep to avoid monopolizing the app.
      for (var count = 0; count < 20; count++) {
        final current = auth.currentUser;
        if (current == null ||
            current.uid != user.uid ||
            shop.actor?.id != user.uid) {
          return;
        }

        final pending = await outbox.getPending();
        if (pending.isEmpty) return;
        final next = pending.first;

        // Strictly check the *oldest* operation because SyncEngine
        // claims that same operation. Don't skip another user's order.
        if (next.operationType != 'checkout.v1' || next.attempts != 0) return;
        late final OfflineCheckoutCommand command;
        try {
          command = OfflineCheckoutCommand.decode(next.payloadJson);
        } catch (_) {
          return;
        }
        if (!canAttempt(
          command: command,
          operationId: next.id,
          status: next.status,
          attempts: next.attempts,
          actorId: user.uid,
        )) {
          return;
        }

        // Don't auto-send if the server cannot AUTHORITATIVELY confirm
        // that this request doesn't exist. Firebase cache is not enough.
        final verification = await verifier.verify(next.id);
        if (verification.status == RequestVerificationStatus.confirmed) {
          await reconciler.reconcile(next.id);
          continue;
        }
        if (verification.status != RequestVerificationStatus.notFound) return;

        // The dispatcher checks identity, price, permissions and server
        // requestId again within its own protected transaction path.
        final result = await engine.processNext();
        if (result != SyncAttemptResult.synced) return;
      }
    } catch (_) {
      // Never retry within this tick after a local/server error.
      // Pending orders stay pending; next poll must verify on server first.
    } finally {
      _running = false;
    }
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    await _authSubscription?.cancel();
    _authSubscription = null;
  }
}
