import '../errors/failure_messages.dart';

/// Shared client-side form validation — email format and password
/// strength — used by every account-creation/sign-in surface (resident
/// and driver sign-up share one form; the organization login screen only
/// needs the email check for its own sign-in and for password reset).
abstract final class Validators {
  /// A practical email-format check: local-part@domain.tld. Not full
  /// RFC 5322 (nothing short of a send-and-confirm loop truly is), but a
  /// solid improvement over a bare `.contains('@')` check.
  static final RegExp _emailRegex = RegExp(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+$",
  );

  static bool isValidEmail(String email) => _emailRegex.hasMatch(email.trim());

  static final RegExp _uppercase = RegExp(r'[A-Z]');
  static final RegExp _lowercase = RegExp(r'[a-z]');
  static final RegExp _digit = RegExp(r'[0-9]');
  static final RegExp _symbol = RegExp(r'[^A-Za-z0-9]');

  /// Returns the Arabic message for the first password rule violated —
  /// minimum length 8, at least one uppercase letter, one lowercase
  /// letter, one digit, and one symbol — or `null` if the password
  /// satisfies all of them. Checked in a fixed order so the user always
  /// sees one specific, actionable message rather than a combined list.
  static String? passwordError(String password) {
    if (password.length < 8) return FailureMessages.passwordTooShort;
    if (!_uppercase.hasMatch(password)) {
      return FailureMessages.passwordMissingUppercase;
    }
    if (!_lowercase.hasMatch(password)) {
      return FailureMessages.passwordMissingLowercase;
    }
    if (!_digit.hasMatch(password)) {
      return FailureMessages.passwordMissingNumber;
    }
    if (!_symbol.hasMatch(password)) {
      return FailureMessages.passwordMissingSymbol;
    }
    return null;
  }
}
