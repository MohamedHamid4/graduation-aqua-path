import 'failures.dart';

/// Maps domain [Failure] types to user-facing Arabic messages.
///
/// Keeps error-message concerns out of the UI layer — screens call
/// [FailureMessages.fromFailure] and display whatever string is returned.
abstract final class FailureMessages {
  static String fromFailure(Failure failure) {
    return switch (failure) {
      ServerFailure() =>
        'تعذّر الاتصال بالخادم. تحقق من اتصالك بالإنترنت وحاول مجدداً.',
      NetworkFailure() => 'لا يوجد اتصال بالإنترنت. يتم عرض آخر بيانات متاحة.',
      CacheFailure() => 'تعذّر قراءة البيانات المحفوظة محلياً.',
      LocationFailure() => 'تعذّر تحديد موقعك. تأكد من تفعيل خدمة الموقع.',
      NotFoundFailure() => 'الشاحنة المطلوبة غير موجودة.',
      AuthFailure(:final code) => fromAuthCode(code),
      UnknownFailure() => 'حدث خطأ غير متوقع. حاول مجدداً.',
      _ => failure.message,
    };
  }

  /// Maps Firebase Auth error codes to Arabic messages.
  /// See: https://firebase.google.com/docs/auth/admin/errors
  static String fromAuthCode(String code) {
    return switch (code) {
      'invalid-email' => 'صيغة البريد الإلكتروني غير صحيحة.',
      'user-disabled' => 'تم تعطيل هذا الحساب. تواصل مع الدعم.',
      'user-not-found' => 'لا يوجد حساب بهذا البريد الإلكتروني.',
      'wrong-password' ||
      'invalid-credential' =>
        'كلمة المرور أو البريد الإلكتروني غير صحيح.',
      'email-already-in-use' => 'هذا البريد الإلكتروني مستخدم بالفعل.',
      'weak-password' => 'كلمة المرور ضعيفة جداً. استخدم 8 أحرف على الأقل.',
      'too-many-requests' => 'محاولات كثيرة جداً. حاول مجدداً بعد قليل.',
      'network-request-failed' =>
        'تعذّر الاتصال بالإنترنت. تحقق من الشبكة وحاول مجدداً.',
      'operation-not-allowed' => 'تسجيل الدخول بهذه الطريقة غير مفعّل حالياً.',
      'requires-recent-login' => 'يرجى تسجيل الدخول مجدداً لإتمام هذا الإجراء.',
      _ => 'حدث خطأ أثناء المصادقة. حاول مجدداً.',
    };
  }

  // ── Validation messages (used in registration form) ──────────────────

  static const String areaRequired = 'يرجى اختيار المنطقة السكنية';
  static const String householdSizeTooSmall =
      'يجب أن يكون عدد الأفراد على الأقل 1';
  static const String householdSizeTooLarge = 'يجب أن لا يتجاوز عدد الأفراد 20';

  // ── Validation messages (used in auth forms) ───────────────────────────

  static const String emailRequired = 'يرجى إدخال البريد الإلكتروني';
  static const String emailInvalid = 'صيغة البريد الإلكتروني غير صحيحة';
  static const String passwordRequired = 'يرجى إدخال كلمة المرور';

  // ── Password strength — each names the single rule the password is
  // still missing, checked in this order (see Validators.passwordError).
  static const String passwordTooShort =
      'يجب أن تكون كلمة المرور 8 أحرف على الأقل';
  static const String passwordMissingUppercase =
      'يجب أن تحتوي كلمة المرور على حرف كبير واحد على الأقل (A-Z)';
  static const String passwordMissingLowercase =
      'يجب أن تحتوي كلمة المرور على حرف صغير واحد على الأقل (a-z)';
  static const String passwordMissingNumber =
      'يجب أن تحتوي كلمة المرور على رقم واحد على الأقل (0-9)';
  static const String passwordMissingSymbol =
      'يجب أن تحتوي كلمة المرور على رمز خاص واحد على الأقل (!@#…)';

  static const String nameRequired = 'يرجى إدخال الاسم الكامل';
  static const String passwordsDoNotMatch = 'كلمتا المرور غير متطابقتين';

  // ── Phone — shared by every phone field in the app (see
  // Validators.phoneError) ───────────────────────────────────────────────
  static const String phoneRequired = 'يرجى إدخال رقم الهاتف';
  static const String phoneInvalid = 'يجب أن يتكون رقم الهاتف من 10 أرقام فقط';
}
