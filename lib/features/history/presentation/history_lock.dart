import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

enum HistoryLockState {
  locked,
  unlocked,

  /// The phone has no screen lock, so we cannot ask for one.
  unprotected,
}

class HistoryLockNotifier extends Notifier<HistoryLockState> {
  final _auth = LocalAuthentication();
  bool _busy = false;

  @override
  HistoryLockState build() => HistoryLockState.locked;

  void lock() {
    if (_busy) return;
    state = HistoryLockState.locked;
  }

  Future<void> unlock() async {
    if (_busy || state != HistoryLockState.locked) return;
    _busy = true;
    try {
      if (!await _auth.isDeviceSupported()) {
        state = HistoryLockState.unprotected;
        return;
      }
      final ok = await _auth.authenticate(
        localizedReason: 'Unlock your scan history',
      );
      state = ok ? HistoryLockState.unlocked : HistoryLockState.locked;
    } catch (_) {
      state = HistoryLockState.locked;
    } finally {
      _busy = false;
    }
  }
}

final historyLockProvider =
NotifierProvider<HistoryLockNotifier, HistoryLockState>(
    HistoryLockNotifier.new);