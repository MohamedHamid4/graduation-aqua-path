import 'package:flutter_test/flutter_test.dart';

import 'package:aquapath/core/errors/failure_messages.dart';
import 'package:aquapath/core/utils/validators.dart';

void main() {
  group('Validators.phoneError', () {
    test('accepts exactly 10 digits', () {
      expect(Validators.phoneError('0591234567'), isNull);
    });

    test('rejects fewer than 10 digits', () {
      expect(Validators.phoneError('059123456'), FailureMessages.phoneInvalid);
    });

    test('rejects more than 10 digits', () {
      expect(
        Validators.phoneError('05912345678'),
        FailureMessages.phoneInvalid,
      );
    });

    test('rejects non-digit characters', () {
      expect(
        Validators.phoneError('059-123-456'),
        FailureMessages.phoneInvalid,
      );
    });

    test('rejects a leading country-code plus sign', () {
      expect(
        Validators.phoneError('+970591234567'),
        FailureMessages.phoneInvalid,
      );
    });

    test('rejects an empty value with the required message', () {
      expect(Validators.phoneError(''), FailureMessages.phoneRequired);
    });

    test('trims surrounding whitespace before checking', () {
      expect(Validators.phoneError('  0591234567  '), isNull);
    });
  });
}
