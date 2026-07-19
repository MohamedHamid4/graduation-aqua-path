import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../../domain/entities/parking_spot.dart';
import '../../domain/repositories/parking_spot_repository.dart';

/// Live stream of verified truck-parking spots, shown as dedicated
/// markers on every user's map. Falls back to an empty list on error so
/// a Firestore hiccup here never breaks the rest of the map screen.
final verifiedParkingSpotsProvider = StreamProvider<List<ParkingSpot>>((ref) {
  return GetIt.I<ParkingSpotRepository>().watchVerifiedSpots().map(
        (either) => either.fold(
          (failure) => <ParkingSpot>[],
          (spots) => spots,
        ),
      );
});

/// Organization-only: every parking spot regardless of approval state,
/// for the management list where an operator approves/edits/disables
/// auto-detected clusters.
final allParkingSpotsProvider = StreamProvider<List<ParkingSpot>>((ref) {
  return GetIt.I<ParkingSpotRepository>().watchAllSpots().map(
        (either) => either.fold(
          (failure) => <ParkingSpot>[],
          (spots) => spots,
        ),
      );
});
