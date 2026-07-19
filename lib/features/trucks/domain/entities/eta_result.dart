class EtaResult {
  final double distanceKm;
  final int etaMinutes;
  final double trafficFactor;
  final bool isNearby;

  const EtaResult({
    required this.distanceKm,
    required this.etaMinutes,
    required this.trafficFactor,
    required this.isNearby,
  });
}
