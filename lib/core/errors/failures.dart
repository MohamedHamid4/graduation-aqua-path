import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  const Failure(this.message);
  @override
  List<Object> get props => [message];
}

class ServerFailure extends Failure {
  const ServerFailure([super.message = 'خطأ في الخادم']);
}

class CacheFailure extends Failure {
  const CacheFailure([super.message = 'خطأ في التخزين']);
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'لا يوجد اتصال']);
}

class LocationFailure extends Failure {
  const LocationFailure([super.message = 'تعذّر تحديد الموقع']);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'غير موجود']);
}

class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'خطأ غير معروف']);
}

/// Authentication-specific failure. Carries the original Firebase Auth
/// error code (e.g. 'wrong-password', 'email-already-in-use') so
/// [FailureMessages] can map it to a precise Arabic message.
class AuthFailure extends Failure {
  final String code;
  const AuthFailure(this.code, [super.message = 'خطأ في المصادقة']);

  @override
  List<Object> get props => [message, code];
}
