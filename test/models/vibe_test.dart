import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ontime/domain/models/activity.dart';
import 'package:ontime/domain/models/vibe.dart';

void main() {
  group('Vibe.isFree', () {
    test('free constant returns true', () {
      expect(Vibe.free.isFree, isTrue);
    });

    test('sleeping returns false', () {
      expect(Vibe.sleeping.isFree, isFalse);
    });

    test('custom vibe returns false', () {
      const v = Vibe(emoji: '📚', label: 'Estudando', color: Colors.blue);
      expect(v.isFree, isFalse);
    });
  });

  group('Vibe.catalog', () {
    test('catalog is not empty', () {
      expect(Vibe.catalog, isNotEmpty);
    });

    test('no entry in catalog has a leading space in label', () {
      for (final vibe in Vibe.catalog) {
        expect(
          vibe.label.trimLeft(),
          vibe.label,
          reason: 'Vibe "${vibe.label}" has a leading space — cosmetic bug',
        );
      }
    });

    test('no duplicate emoji+label pairs in catalog', () {
      final seen = <String>{};
      for (final v in Vibe.catalog) {
        final key = '${v.emoji}|${v.label.trim()}';
        expect(seen.contains(key), isFalse,
            reason: 'Duplicate vibe in catalog: $key');
        seen.add(key);
      }
    });

    test('sleeping is included in catalog', () {
      expect(Vibe.catalog, contains(Vibe.sleeping));
    });

    test('free is the first catalog entry', () {
      expect(Vibe.catalog.first, equals(Vibe.free));
    });
  });

  group('Vibe.customColor', () {
    test('returns a color for index 0', () {
      expect(() => Vibe.customColor(0), returnsNormally);
    });

    test('wraps around palette correctly', () {
      // Call with large index — should not throw
      expect(() => Vibe.customColor(100), returnsNormally);
    });

    test('index 0 and palette-length return same color', () {
      // The palette has 6 colors — index 6 should wrap to index 0
      expect(Vibe.customColor(0), equals(Vibe.customColor(6)));
    });
  });

  group('Vibe.toActivity', () {
    const v = Vibe(emoji: '🎮', label: 'Jogando', color: Color(0xFFBB7AFF));

    test('creates Activity with correct emoji and title', () {
      final a = v.toActivity(id: 'test-1');
      expect(a.emoji, '🎮');
      expect(a.title, 'Jogando');
      expect(a.color, const Color(0xFFBB7AFF));
    });

    test('activity id is set correctly', () {
      final a = v.toActivity(id: 'my-id');
      expect(a.id, 'my-id');
    });

    test('period is passed through when provided', () {
      final a = v.toActivity(id: 'p1', period: RoutinePeriod.afternoon);
      expect(a.period, RoutinePeriod.afternoon);
    });

    test('period is null when not provided', () {
      final a = v.toActivity(id: 'p2');
      expect(a.period, isNull);
    });
  });

  group('Vibe.fromActivity', () {
    test('creates Vibe matching the Activity', () {
      final a = Activity(
        id: 'a1',
        title: 'Estudando',
        emoji: '📚',
        color: Colors.blue,
        date: DateTime.now(),
      );
      final v = Vibe.fromActivity(a);
      expect(v.emoji, '📚');
      expect(v.label, 'Estudando');
      expect(v.color, Colors.blue);
    });
  });

  group('Vibe equality', () {
    test('same emoji and label are equal', () {
      const a = Vibe(emoji: '🎮', label: 'Jogando', color: Colors.purple);
      const b = Vibe(emoji: '🎮', label: 'Jogando', color: Colors.blue);
      expect(a, equals(b));
    });

    test('different label makes them unequal', () {
      const a = Vibe(emoji: '🎮', label: 'Jogando', color: Colors.purple);
      const b = Vibe(emoji: '🎮', label: 'Gaming', color: Colors.purple);
      expect(a, isNot(equals(b)));
    });

    test('different emoji makes them unequal', () {
      const a = Vibe(emoji: '🎮', label: 'Jogando', color: Colors.purple);
      const b = Vibe(emoji: '📚', label: 'Jogando', color: Colors.purple);
      expect(a, isNot(equals(b)));
    });
  });

  group('currentPeriod()', () {
    test('returns a valid RoutinePeriod', () {
      expect(RoutinePeriod.values, contains(currentPeriod()));
    });

    test('result is consistent with current hour', () {
      final hour = DateTime.now().hour;
      final period = currentPeriod();
      if (hour >= 6 && hour < 12) expect(period, RoutinePeriod.morning);
      if (hour >= 12 && hour < 18) expect(period, RoutinePeriod.afternoon);
      if (hour >= 18 && hour < 22) expect(period, RoutinePeriod.evening);
      if (hour >= 22 || hour < 6) expect(period, RoutinePeriod.night);
    });
  });

  group('RoutinePeriodLabel extension', () {
    test('all periods have non-empty label', () {
      for (final p in RoutinePeriod.values) {
        expect(p.label, isNotEmpty);
      }
    });

    test('all periods have non-empty clock', () {
      for (final p in RoutinePeriod.values) {
        expect(p.clock, isNotEmpty);
      }
    });

    test('all periods have non-empty glyph', () {
      for (final p in RoutinePeriod.values) {
        expect(p.glyph, isNotEmpty);
      }
    });

    test('morning label is Manhã', () {
      expect(RoutinePeriod.morning.label, 'Manhã');
    });

    test('night glyph is a star emoji', () {
      expect(RoutinePeriod.night.glyph, '✨');
    });
  });
}
