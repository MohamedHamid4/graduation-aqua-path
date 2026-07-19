import 'package:equatable/equatable.dart';

/// A period-scoped aggregation over trucks/drivers/deliveries, computed
/// client-side from existing Firestore streams (see
/// [OrganizationRepository.buildReport]). This is a v1: correct numbers,
/// no server-side aggregation yet. If the driver/truck collections grow
/// large enough that this becomes slow, the next step is a scheduled
/// Cloud Function that writes pre-aggregated `reports/{period}` documents
/// instead of scanning client-side — noted in the roadmap, not built here.
class OperationsReport extends Equatable {
  final DateTime periodStart;
  final DateTime periodEnd;
  final int activeDrivers;
  final int totalDrivers;
  final int activeTrucks;
  final int totalTrucks;
  final int completedTrips;
  final double totalLitersDelivered;
  final Map<String, int> deliveriesByArea;
  final Map<String, double> litersByDriver;
  final Map<String, double> litersByArea;
  final Map<String, String> driverNames;

  const OperationsReport({
    required this.periodStart,
    required this.periodEnd,
    required this.activeDrivers,
    required this.totalDrivers,
    required this.activeTrucks,
    required this.totalTrucks,
    required this.completedTrips,
    required this.totalLitersDelivered,
    this.deliveriesByArea = const {},
    this.litersByDriver = const {},
    this.litersByArea = const {},
    this.driverNames = const {},
  });

  /// A simple CSV representation — the current "export" mechanism. PDF and
  /// styled Excel (.xlsx) export are Phase-4 follow-ups: they need new
  /// dependencies (`pdf`, `excel`) added to pubspec.yaml and platform
  /// testing that couldn't be done in this pass. CSV opens directly in
  /// Excel/Sheets today with zero new dependencies, so it's the correct
  /// v1 to ship rather than leaving export non-functional.
  String toCsv() {
    final buffer = StringBuffer();
    buffer.writeln('AquaPath Operations Report');
    buffer.writeln(
        'Period,${periodStart.toIso8601String()} - ${periodEnd.toIso8601String()}');
    buffer.writeln();
    buffer.writeln('Metric,Value');
    buffer.writeln('Active Drivers,$activeDrivers');
    buffer.writeln('Total Drivers,$totalDrivers');
    buffer.writeln('Active Trucks,$activeTrucks');
    buffer.writeln('Total Trucks,$totalTrucks');
    buffer.writeln('Completed Trips,$completedTrips');
    buffer.writeln('Total Liters Delivered,$totalLitersDelivered');
    buffer.writeln();
    buffer.writeln('Area,Deliveries,Liters');
    for (final entry in deliveriesByArea.entries) {
      final liters = litersByArea[entry.key] ?? 0;
      buffer.writeln('${entry.key},${entry.value},$liters');
    }
    buffer.writeln();
    buffer.writeln('Driver,Liters Delivered');
    for (final entry in litersByDriver.entries) {
      final name = driverNames[entry.key] ?? entry.key;
      buffer.writeln('$name,${entry.value}');
    }
    return buffer.toString();
  }

  @override
  List<Object?> get props => [
        periodStart,
        periodEnd,
        activeDrivers,
        totalDrivers,
        activeTrucks,
        totalTrucks,
        completedTrips,
        totalLitersDelivered,
      ];
}
