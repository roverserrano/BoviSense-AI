import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/utils/formatters.dart';

void main() {
  group('formatDateTime', () {
    test('formats a valid date correctly', () {
      final date = DateTime(2023, 10, 27, 14, 30);
      expect(formatDateTime(date), '27/10/2023 14:30');
    });

    test('pads single digits with zeros', () {
      final date = DateTime(2023, 1, 5, 9, 3);
      expect(formatDateTime(date), '05/01/2023 09:03');
    });

    test('returns "Sin fecha" for null', () {
      expect(formatDateTime(null), 'Sin fecha');
    });
  });

  group('formatDate', () {
    test('formats a valid date correctly', () {
      final date = DateTime(2023, 10, 27);
      expect(formatDate(date), '27/10/2023');
    });

    test('returns "Sin fecha" for null', () {
      expect(formatDate(null), 'Sin fecha');
    });
  });

  group('formatSignedInt', () {
    test('adds + for positive numbers', () {
      expect(formatSignedInt(5), '+5');
      expect(formatSignedInt(100), '+100');
    });

    test('does not add + for zero', () {
      expect(formatSignedInt(0), '0');
    });

    test('keeps - for negative numbers', () {
      expect(formatSignedInt(-5), '-5');
      expect(formatSignedInt(-100), '-100');
    });
  });
}
