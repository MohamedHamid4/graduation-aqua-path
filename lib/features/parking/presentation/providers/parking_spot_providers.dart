import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/parking_spot.dart';
import '../../domain/repositories/parking_spot_repository.dart';

/// Live stream of verified truck-parking spots, shown as dedicated
/// markers on every user's map. Deliberately falls back to an empty list
/// on error (rather than propagating it) so a Firestore hiccup here never
/// breaks the rest of the map screen — this is supplementary overlay
/// data, not the screen's primary content. Still logged so a real error
/// is diagnosable instead of just silently vanishing.
final verifiedParkingSpotsProvider = StreamProvider<List<ParkingSpot>>((ref) {
  return GetIt.I<ParkingSpotRepository>().watchVerifiedSpots().map(
        (either) => either.fold(
          (failure) {
            AppLogger.warning(
              'verifiedParkingSpotsProvider: falling back to empty — '
              '${failure.message}',
              tag: 'ParkingSpot',
            );
            return <ParkingSpot>[];
          },
          (spots) => spots,
        ),
      );
});

/// Organization-only: every parking spot regardless of approval state,
/// for the management list where an operator approves/edits/disables
/// auto-detected clusters. Unlike the map overlay above, this IS the
/// screen's primary content, so a real failure must propagate rather than
/// look identical to "no spots yet".
final allParkingSpotsProvider = StreamProvider<List<ParkingSpot>>((ref) {
  return GetIt.I<ParkingSpotRepository>().watchAllSpots().map(
        (either) => either.fold((failure) => throw failure, (spots) => spots),
      );
});
