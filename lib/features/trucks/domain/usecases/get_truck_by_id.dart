import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/truck.dart';
import '../repositories/truck_repository.dart';

class GetTruckById {
  final TruckRepository repository;

  const GetTruckById(this.repository);

  Future<Either<Failure, Truck>> call(String id) => repository.getTruckById(id);
}
