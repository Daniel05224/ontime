import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ontime/domain/models/activity.dart';
import 'package:ontime/domain/models/user_profile.dart';

void main() {
  final now = DateTime.now();
  final hour = now.hour;

  Activity planActivity({RoutinePeriod period = RoutinePeriod.morning}) =>
      Activity(
        id: 'plan',
        title: 'Estudando',
        emoji: '📚',
        color: Colors.blue,
        date: now,
        period: period,
      );

  UserProfile makeUser(List<Activity> routine) => UserProfile(
        id: 'u1',
        name: 'Test',
        avatarUrl: '',
        routine: routine,
      );

  group('currentActivity', () {
    test('null when routine is empty', () {
      expect(makeUser([]).currentActivity, isNull);
    });

    test('live activity returned when active', () {
      // For a live activity with no period/time, isActiveNow returns false.
      // We need to set an active period or time range.
      final activeHour = hour;
      RoutinePeriod activePeriod;
      if (activeHour >= 6 && activeHour < 12) {
        activePeriod = RoutinePeriod.morning;
      } else if (activeHour >= 12 && activeHour < 18) {
        activePeriod = RoutinePeriod.afternoon;
      } else if (activeHour >= 18 && activeHour < 22) {
        activePeriod = RoutinePeriod.evening;
      } else {
        activePeriod = RoutinePeriod.night;
      }

      final liveWithPeriod = Activity(
        id: 'live',
        title: 'Jogando',
        emoji: '🎮',
        color: Colors.purple,
        date: now,
        isLive: true,
        period: activePeriod,
        endsAt: now.add(const Duration(hours: 1)),
      );

      expect(makeUser([liveWithPeriod]).currentActivity, isNotNull);
      expect(makeUser([liveWithPeriod]).currentActivity!.isLive, isTrue);
    });

    test('day plan returned when no live status is active', () {
      // Use a period that is currently active
      RoutinePeriod activePeriod;
      if (hour >= 6 && hour < 12) {
        activePeriod = RoutinePeriod.morning;
      } else if (hour >= 12 && hour < 18) {
        activePeriod = RoutinePeriod.afternoon;
      } else if (hour >= 18 && hour < 22) {
        activePeriod = RoutinePeriod.evening;
      } else {
        activePeriod = RoutinePeriod.night;
      }
      final plan = planActivity(period: activePeriod);
      final result = makeUser([plan]).currentActivity;
      expect(result, isNotNull);
      expect(result!.isLive, isFalse);
    });

    test('live takes priority over plan in same period', () {
      RoutinePeriod activePeriod;
      if (hour >= 6 && hour < 12) {
        activePeriod = RoutinePeriod.morning;
      } else if (hour >= 12 && hour < 18) {
        activePeriod = RoutinePeriod.afternoon;
      } else if (hour >= 18 && hour < 22) {
        activePeriod = RoutinePeriod.evening;
      } else {
        activePeriod = RoutinePeriod.night;
      }

      final live = Activity(
        id: 'live',
        title: 'Ao vivo',
        emoji: '🔴',
        color: Colors.red,
        date: now,
        isLive: true,
        period: activePeriod,
        endsAt: now.add(const Duration(hours: 1)),
      );
      final plan = planActivity(period: activePeriod);
      final result = makeUser([plan, live]).currentActivity;
      expect(result?.isLive, isTrue);
    });

    test('null when period is not currently active', () {
      // Use a period that is definitely not active right now
      RoutinePeriod inactivePeriod;
      if (hour >= 6 && hour < 12) {
        inactivePeriod = RoutinePeriod.evening; // not morning
      } else if (hour >= 18) {
        inactivePeriod = RoutinePeriod.morning; // not evening
      } else {
        inactivePeriod = RoutinePeriod.morning; // probably not active
      }
      // Only run if we can guarantee the period is inactive
      if (!(hour >= 6 && hour < 12 && inactivePeriod == RoutinePeriod.morning)) {
        final plan = planActivity(period: inactivePeriod);
        expect(makeUser([plan]).currentActivity, isNull);
      }
    });
  });

  group('copyWith', () {
    final original = UserProfile(
      id: 'orig',
      name: 'Original',
      avatarUrl: 'url',
      routine: [],
      streak: 5,
    );

    test('unchanged fields are preserved', () {
      final copy = original.copyWith(name: 'New Name');
      expect(copy.id, 'orig');
      expect(copy.avatarUrl, 'url');
      expect(copy.streak, 5);
    });

    test('changed field is updated', () {
      final copy = original.copyWith(name: 'New Name');
      expect(copy.name, 'New Name');
    });

    test('streak can be updated', () {
      final copy = original.copyWith(streak: 10);
      expect(copy.streak, 10);
    });

    test('original is not mutated', () {
      original.copyWith(name: 'X');
      expect(original.name, 'Original');
    });
  });
}
