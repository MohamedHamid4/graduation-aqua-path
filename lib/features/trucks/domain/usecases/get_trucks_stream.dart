import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/truck.dart';
import '../repositories/truck_repository.dart';

class GetTrucksStream {
  final TruckRepository repository;

  const GetTrucksStream(this.repository);

  Stream<Either<Failure, List<Truck>>> call() => repository.getTrucksStream();
}
