import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ontime/data/repositories/routine_repository.dart';
import 'package:ontime/data/services/routine_local_service.dart';
import 'package:ontime/domain/models/activity.dart';

void main() {
  late RoutineRepository repo;
  final now = DateTime.now();

  setUp(() {
    repo = RoutineRepository(localService: RoutineLocalService());
  });

  Activity makeActivity({
    required String id,
    bool isLive = false,
    RoutinePeriod? period,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    DateTime? date,
  }) =>
      Activity(
        id: id,
        title: 'Test $id',
        emoji: '🎯',
        color: Colors.blue,
        date: date ?? now,
        isLive: isLive,
        period: period,
        startTime: startTime,
        endTime: endTime,
      );

  group('initial state', () {
    test('currentUser has empty routine', () {
      expect(repo.currentUser.routine, isEmpty);
    });

    test('5 mock friends', () {
      expect(repo.friends.length, 5);
    });

    test('canSeeFriends is false when no activities today', () {
      expect(repo.canSeeFriends, isFalse);
    });
  });

  group('canSeeFriends', () {
    test('true after adding an activity dated today', () {
      repo.addActivity(makeActivity(id: 'a1'));
      expect(repo.canSeeFriends, isTrue);
    });

    test('false when activity is from yesterday', () {
      final yesterday = now.subtract(const Duration(days: 1));
      repo.addActivity(makeActivity(id: 'a1', date: yesterday));
      expect(repo.canSeeFriends, isFalse);
    });
  });

  group('getActivitiesByPeriod', () {
    test('returns empty when no activities', () {
      expect(repo.getActivitiesByPeriod(RoutinePeriod.morning), isEmpty);
    });

    test('returns activity matching its period', () {
      repo.addActivity(makeActivity(id: 'a1', period: RoutinePeriod.morning));
      expect(repo.getActivitiesByPeriod(RoutinePeriod.morning), hasLength(1));
    });

    test('excludes activities from other periods', () {
      repo.addActivity(makeActivity(id: 'a1', period: RoutinePeriod.afternoon));
      expect(repo.getActivitiesByPeriod(RoutinePeriod.morning), isEmpty);
    });

    test('excludes live activities', () {
      repo.addActivity(
        makeActivity(id: 'a1', isLive: true, period: RoutinePeriod.morning),
      );
      expect(repo.getActivitiesByPeriod(RoutinePeriod.morning), isEmpty);
    });

    test('excludes activities from yesterday', () {
      final yesterday = now.subtract(const Duration(days: 1));
      repo.addActivity(
        makeActivity(id: 'a1', period: RoutinePeriod.morning, date: yesterday),
      );
      expect(repo.getActivitiesByPeriod(RoutinePeriod.morning), isEmpty);
    });

    test('morning via startTime 09:00', () {
      repo.addActivity(makeActivity(
        id: 'a1',
        startTime: const TimeOfDay(hour: 9, minute: 0),
        endTime: const TimeOfDay(hour: 10, minute: 0),
      ));
      expect(repo.getActivitiesByPeriod(RoutinePeriod.morning), hasLength(1));
    });

    test('afternoon via startTime 14:00', () {
      repo.addActivity(makeActivity(
        id: 'a1',
        startTime: const TimeOfDay(hour: 14, minute: 0),
        endTime: const TimeOfDay(hour: 15, minute: 0),
      ));
      expect(repo.getActivitiesByPeriod(RoutinePeriod.afternoon), hasLength(1));
    });

    test('evening via startTime 19:00', () {
      repo.addActivity(makeActivity(
        id: 'a1',
        startTime: const TimeOfDay(hour: 19, minute: 0),
        endTime: const TimeOfDay(hour: 20, minute: 0),
      ));
      expect(repo.getActivitiesByPeriod(RoutinePeriod.evening), hasLength(1));
    });

    test('night via startTime 23:00', () {
      repo.addActivity(makeActivity(
        id: 'a1',
        startTime: const TimeOfDay(hour: 23, minute: 0),
        endTime: const TimeOfDay(hour: 23, minute: 59),
      ));
      expect(repo.getActivitiesByPeriod(RoutinePeriod.night), hasLength(1));
    });

    test('multiple activities in same period are all returned', () {
      repo.addActivity(makeActivity(id: 'a1', period: RoutinePeriod.morning));
      repo.addActivity(makeActivity(id: 'a2', period: RoutinePeriod.morning));
      expect(repo.getActivitiesByPeriod(RoutinePeriod.morning), hasLength(2));
    });
  });

  group('addActivity / removeActivity', () {
    test('add then remove leaves empty routine', () {
      repo.addActivity(makeActivity(id: 'a1'));
      repo.removeActivity('a1');
      expect(repo.currentUser.routine, isEmpty);
    });
  });

  group('updateActivity', () {
    test('updated title is reflected', () {
      repo.addActivity(makeActivity(id: 'a1'));
      final updated = Activity(
        id: 'a1',
        title: 'Novo título',
        emoji: '✅',
        color: Colors.green,
        date: now,
      );
      repo.updateActivity('a1', updated);
      expect(repo.currentUser.routine.first.title, 'Novo título');
    });
  });
}
