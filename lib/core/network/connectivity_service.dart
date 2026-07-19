import 'package:connectivity_plus/connectivity_plus.dart';

/// Wraps connectivity_plus v6 which returns [List<ConnectivityResult>].
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  /// Returns true if any connectivity result is not [ConnectivityResult.none].
  Future<bool> get isConnected async {
    final results = await _connectivity.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }

  /// Emits true whenever at least one connectivity type is available.
  Stream<bool> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged.map(
      (results) => results.any((r) => r != ConnectivityResult.none),
    );
  }
}
