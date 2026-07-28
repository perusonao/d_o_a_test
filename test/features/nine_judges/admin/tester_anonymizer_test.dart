import 'package:dead_or_alive/features/nine_judges/admin/services/tester_anonymizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TesterAnonymizer', () {
    test('同じtesterIdは常に同じラベルを返す', () {
      final anonymizer = TesterAnonymizer();
      final first = anonymizer.label('abc-123');
      final second = anonymizer.label('abc-123');
      expect(first, second);
    });

    test('異なるtesterIdには出現順で連番のラベルを割り当てる', () {
      final anonymizer = TesterAnonymizer();
      expect(anonymizer.label('a'), 'Player 001');
      expect(anonymizer.label('b'), 'Player 002');
      expect(anonymizer.label('a'), 'Player 001');
      expect(anonymizer.label('c'), 'Player 003');
    });

    test('nullや空文字は"unknown"として一貫したラベルになる', () {
      final anonymizer = TesterAnonymizer();
      final a = anonymizer.label(null);
      final b = anonymizer.label('');
      expect(a, b);
    });

    test('shortIdは生のtesterIdを短縮するが完全な値は表示しない', () {
      const raw = '0123456789abcdef';
      final short = TesterAnonymizer.shortId(raw);
      expect(short, isNot(raw));
      expect(short.startsWith('01234567'), isTrue);
    });
  });
}
