import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/registration/domain/repositories/household_repository.dart';
import '../models/household_model.dart';

/// Live view of the signed-in resident's own `households/{uid}` document —
/// the single source of truth for area, household size, and priority
/// score anywhere in the resident UI. Screens that used to read this via
/// a one-off `getHousehold` future (or, worse, not at all) should watch
/// this instead so an edit in one screen (e.g. registration_screen) is
/// immediately reflected everywhere else without a manual refresh.
final currentHouseholdProvider = StreamProvider<HouseholdModel?>((ref) {
  final uid = GetIt.I<AuthRepository>().currentUser?.uid;
  if (uid == null) return Stream.value(null);

  return GetIt.I<HouseholdRepository>().watchHousehold(uid).map(
        (either) => either.fold((_) => null, (household) => household),
      );
});
