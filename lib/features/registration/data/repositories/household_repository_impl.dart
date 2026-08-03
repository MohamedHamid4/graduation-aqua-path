import 'dart:async';

import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/offline/offline_write_queue_service.dart';
import '../../../../shared/models/household_model.dart';
import '../../domain/repositories/household_repository.dart';
import '../datasources/household_firebase_source.dart';

const _tag = 'Household';

class HouseholdRepositoryImpl implements HouseholdRepository {
  final HouseholdFirebaseSource _source;
  final OfflineWriteQueueService _offlineQueue;

  HouseholdRepositoryImpl(
    this._source, {
    required OfflineWriteQueueService offlineQueue,
  }) : _offlineQueue = offlineQueue;

  @override
  Future<Either<Failure, Unit>> saveHousehold({
    required String uid,
    required HouseholdModel household,
  }) async {
    // Attempt the real write first rather than pre-checking
    // connectivity_plus — that check only reflects whether a network
    // *interface* is up, not whether Firestore is actually reachable, and
    // has been seen to misreport "offline" on a real device with working
    // internet. Trusting it as a gate meant a working connection could
    // silently take the "queue it for later" branch below and return
    // Right(unit) (success!) without ever writing to Firestore — the
    // exact "shows تم الحفظ but the data isn't there" bug. Only a Firestore
    // operation that itself fails for a genuine connectivity reason
    // (FailureMapper classifies it as NetworkFailure) should be queued;
    // anything else (permission-denied, validation, etc.) must be
    // reported as a real failure, never queued and never reported as
    // success.
    try {
      await _source.saveHousehold(uid, household);
      AppLogger.info('Household saved for uid=$uid', tag: _tag);
      return const Right(unit);
    } catch (e, st) {
      final failure = FailureMapper.map(e, st, tag: _tag);
      if (failure is NetworkFailure) {
        await _offlineQueue.enqueue(
          collection: 'households',
          docId: uid,
          data: household.toMap(),
        );
        AppLogger.info(
          'Household save queued offline for uid=$uid (no connectivity)',
          tag: _tag,
        );
        return const Right(unit);
      }
      return Left(failure);
    }
  }

  @override
  Future<Either<Failure, HouseholdModel?>> getHousehold(String uid) async {
    try {
      final household = await _source.getHousehold(uid);
      return Right(household);
    } catch (e, st) {
      return Left(FailureMapper.map(e, st, tag: _tag));
    }
  }

  @override
  Stream<Either<Failure, HouseholdModel?>> watchHousehold(String uid) {
    return _source.watchHousehold(uid).transform(
          StreamTransformer.fromHandlers(
            handleData: (household, sink) => sink.add(Right(household)),
            handleError: (error, stackTrace, sink) => sink
                .add(Left(FailureMapper.map(error, stackTrace, tag: _tag))),
          ),
        );
  }
}
