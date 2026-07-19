import 'package:flutter_test/flutter_test.dart';

import 'package:aquapath/core/errors/failure_messages.dart';
import 'package:aquapath/core/errors/failures.dart';

void main() {
  group('FailureMessages.fromAuthCode', () {
    test('wrong-password maps to Arabic credential error', () {
      expect(FailureMessages.fromAuthCode('wrong-password'),
          contains('كلمة المرور'));
    });

    test('invalid-credential maps to the same message as wrong-password', () {
      expect(
        FailureMessages.fromAuthCode('invalid-credential'),
        FailureMessages.fromAuthCode('wrong-password'),
      );
    });

    test('user-not-found maps to Arabic no-account message', () {
      expect(FailureMessages.fromAuthCode('user-not-found'), contains('حساب'));
    });

    test('email-already-in-use maps to Arabic duplicate-email message', () {
      expect(
        FailureMessages.fromAuthCode('email-already-in-use'),
        contains('مستخدم'),
      );
    });

    test('weak-password maps to Arabic weak-password message', () {
      expect(FailureMessages.fromAuthCode('weak-password'), contains('ضعيفة'));
    });

    test('network-request-failed maps to Arabic network message', () {
      expect(
        FailureMessages.fromAuthCode('network-request-failed'),
        contains('إنترنت'),
      );
    });

    test('too-many-requests maps to Arabic rate-limit message', () {
      expect(
        FailureMessages.fromAuthCode('too-many-requests'),
        isNotEmpty,
      );
    });

    test('unknown code falls back to a generic Arabic message', () {
      expect(FailureMessages.fromAuthCode('some-unmapped-code'), isNotEmpty);
    });
  });

  group('FailureMessages.fromFailure — AuthFailure routing', () {
    test('AuthFailure is routed through fromAuthCode', () {
      const failure = AuthFailure('user-disabled', 'ignored');
      final msg = FailureMessages.fromFailure(failure);
      expect(msg, FailureMessages.fromAuthCode('user-disabled'));
    });
  });

  group('FailureMessages — auth validation constants', () {
    test('all auth validation strings are non-empty', () {
      expect(FailureMessages.emailRequired, isNotEmpty);
      expect(FailureMessages.emailInvalid, isNotEmpty);
      expect(FailureMessages.passwordRequired, isNotEmpty);
      expect(FailureMessages.passwordTooShort, isNotEmpty);
      expect(FailureMessages.nameRequired, isNotEmpty);
      expect(FailureMessages.passwordsDoNotMatch, isNotEmpty);
    });
  });
}
