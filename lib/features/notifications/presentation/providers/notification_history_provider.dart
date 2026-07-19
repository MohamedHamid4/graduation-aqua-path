import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../../../auth/domain/repositories/auth_repository.dart';
import '../../domain/entities/notification_item.dart';
import '../../domain/repositories/notification_history_repository.dart';

/// Live list of push notifications actually received by the signed-in
/// user, newest first — the real data source for NotificationsScreen.
final notificationHistoryProvider =
    StreamProvider.autoDispose<List<NotificationItem>>((ref) {
  final uid = GetIt.I<AuthRepository>().currentUser?.uid;
  if (uid == null) return Stream.value(const []);

  return GetIt.I<NotificationHistoryRepository>().watchNotifications(uid).map(
        (either) =>
            either.fold((_) => const <NotificationItem>[], (items) => items),
      );
});

class NotificationActionsNotifier extends AutoDisposeNotifier<bool> {
  @override
  bool build() => false;

  Future<void> markRead(String itemId) async {
    final uid = GetIt.I<AuthRepository>().currentUser?.uid;
    if (uid == null) return;
    await GetIt.I<NotificationHistoryRepository>().markRead(
      uid: uid,
      itemId: itemId,
    );
  }

  Future<void> markAllRead() async {
    final uid = GetIt.I<AuthRepository>().currentUser?.uid;
    if (uid == null) return;
    state = true;
    await GetIt.I<NotificationHistoryRepository>().markAllRead(uid);
    state = false;
  }
}

final notificationActionsProvider =
    NotifierProvider.autoDispose<NotificationActionsNotifier, bool>(
  NotificationActionsNotifier.new,
);
