import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../../core/network/connectivity_service.dart';

final connectivityProvider = StreamProvider<bool>((ref) async* {
  final service = GetIt.I<ConnectivityService>();
  yield await service.isConnected;
  yield* service.onConnectivityChanged;
});

final isOnlineProvider = Provider<bool>((ref) {
  return ref.watch(connectivityProvider).valueOrNull ?? true;
});
