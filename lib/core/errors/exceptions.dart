class ServerException implements Exception {
  final String message;
  const ServerException([this.message = 'Server Error']);
  @override
  String toString() => 'ServerException: $message';
}

class CacheException implements Exception {
  final String message;
  const CacheException([this.message = 'Cache Error']);
  @override
  String toString() => 'CacheException: $message';
}

class NetworkException implements Exception {
  final String message;
  const NetworkException([this.message = 'Network Error']);
  @override
  String toString() => 'NetworkException: $message';
}
