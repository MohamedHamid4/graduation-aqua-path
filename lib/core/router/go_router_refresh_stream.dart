import 'dart:async';

import 'package:flutter/foundation.dart';

/// Bridges a [Stream] to a [Listenable] so [GoRouter]'s `refreshListenable`
/// re-evaluates the `redirect` callback whenever the stream emits.
///
/// Used with [AuthRepository.authStateChanges] so navigation reacts
/// immediately to sign-in / sign-out events.
class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;

  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
          (_) => notifyListeners(),
        );
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
