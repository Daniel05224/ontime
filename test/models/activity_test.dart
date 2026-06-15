import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ontime/domain/models/activity.dart';

void main() {
  final now = DateTime.now();

  Activity makeActivity({
    String id = 'a1',
    bool isLive = false,
    DateTime? endsAt,
    RoutinePeriod? period,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
  }) =>
      Activity(
        id: id,
        title: 'Test',
        emoji: '🎯',
        color: Colors.blue,
        date: now,
        isLive: isLive,
        endsAt: endsAt,
        period: period,
        startTime: startTime,
        endTime: endTime,
      );

  group('isExpired', () {
    test('false when endsAt is null', () {
      expect(makeActivity().isExpired, isFalse);
    });

    test('false when endsAt is in the future', () {
      final a = makeActivity(endsAt: now.add(const Duration(minutes: 30)));
      expect(a.isExpired, isFalse);
    });

    test('true when endsAt is in the past', () {
      final a = makeActivity(endsAt: now.subtract(const Duration(seconds: 1)));
      expect(a.isExpired, isTrue);
    });
  });

  group('endsAtLabel', () {
    test('empty string when endsAt is null', () {
      expect(makeActivity().endsAtLabel, '');
    });

    test('"encerrado" when already expired', () {
      final a = makeActivity(endsAt: now.subtract(const Duration(minutes: 5)));
      expect(a.endsAtLabel, 'encerrado');
    });

    test('shows remaining minutes when < 10 min left', () {
      final a = makeActivity(endsAt: now.add(const Duration(minutes: 7)));
      expect(a.endsAtLabel, startsWith('acaba em'));
      expect(a.endsAtLabel, matches(RegExp(r'acaba em \d+min')));
    });

    test('shows clock time when >= 10 min left', () {
      final endsAt = now.add(const Duration(minutes: 45));
      final a = makeActivity(endsAt: endsAt);
      final label = a.endsAtLabel;
      expect(label, startsWith('até'));
      final hh = endsAt.hour.toString().padLeft(2, '0');
      final mm = endsAt.minute.toString().padLeft(2, '0');
      expect(label, contains('$hh:$mm'));
    });
  });

  group('isActiveNow — by period', () {
    final hour = now.hour;

    test('morning period active between 06–11h', () {
      final a = makeActivity(period: RoutinePeriod.morning);
      expect(a.isActiveNow, hour >= 6 && hour < 12);
    });

    test('afternoon period active between 12–17h', () {
      final a = makeActivity(period: RoutinePeriod.afternoon);
      expect(a.isActiveNow, hour >= 12 && hour < 18);
    });

    test('evening period active between 18–21h', () {
      final a = makeActivity(period: RoutinePeriod.evening);
      expect(a.isActiveNow, hour >= 18 && hour < 22);
    });

    test('night period active between 22–05h', () {
      final a = makeActivity(period: RoutinePeriod.night);
      expect(a.isActiveNow, hour >= 22 || hour < 6);
    });

    test('false when no period and no startTime', () {
      expect(makeActivity().isActiveNow, isFalse);
    });
  });

  group('isActiveNow — by startTime/endTime', () {
    test('active when current time is within range', () {
      final start = TimeOfDay(hour: now.hour, minute: 0);
      final end = TimeOfDay(hour: (now.hour + 1) % 24, minute: 0);
      final a = makeActivity(startTime: start, endTime: end);
      // Only valid if the end time is not midnight wrap (simpler case)
      if (now.hour < 23) {
        expect(a.isActiveNow, isTrue);
      }
    });

    test('inactive when current time is before range', () {
      final start = TimeOfDay(hour: (now.hour + 2) % 24, minute: 0);
      final end = TimeOfDay(hour: (now.hour + 3) % 24, minute: 0);
      final a = makeActivity(startTime: start, endTime: end);
      if (now.hour < 21) {
        expect(a.isActiveNow, isFalse);
      }
    });

    test('inactive when current time is after range', () {
      // Range was in the past (at least 2h ago)
      final h = now.hour;
      if (h >= 2) {
        final start = TimeOfDay(hour: h - 2, minute: 0);
        final end = TimeOfDay(hour: h - 1, minute: 0);
        final a = makeActivity(startTime: start, endTime: end);
        expect(a.isActiveNow, isFalse);
      }
    });

    test('startTime takes priority over period when both set', () {
      // startTime range 1h in future → inactive, regardless of period = morning
      if (now.hour < 22) {
        final start = TimeOfDay(hour: now.hour + 1, minute: 0);
        final end = TimeOfDay(hour: now.hour + 2, minute: 0);
        final a = makeActivity(
          startTime: start,
          endTime: end,
          period: RoutinePeriod.morning,
        );
        // startTime/endTime block is entered first when both are non-null
        expect(a.isActiveNow, isFalse);
      }
    });
  });
}
