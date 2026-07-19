import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../shared/models/household_model.dart';

/// Contract for persisting and reading household registration data.
///
/// Every household is stored one-per-user, keyed by the Firebase Auth UID
/// (`households/{uid}`) — this is what makes editing an existing
/// registration update the same record instead of creating a duplicate.
abstract class HouseholdRepository {
  Future<Either<Failure, Unit>> saveHousehold({
    required String uid,
    required HouseholdModel household,
  });

  Future<Either<Failure, HouseholdModel?>> getHousehold(String uid);

  /// Live stream of the same document `getHousehold` reads once — the
  /// source for any UI that must stay in sync with edits or an
  /// organization-side priority recalculation without a manual refresh.
  Stream<Either<Failure, HouseholdModel?>> watchHousehold(String uid);
}
