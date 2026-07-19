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
}
