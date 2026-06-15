import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ontime/data/repositories/routine_repository.dart';
import 'package:ontime/data/services/routine_local_service.dart';
import 'package:ontime/domain/models/activity.dart';
import 'package:ontime/ui/features/routine/view_models/routine_view_model.dart';

void main() {
  late RoutineRepository repository;
  late RoutineViewModel viewModel;

  setUp(() {
    repository = RoutineRepository(localService: RoutineLocalService());
    viewModel = RoutineViewModel(repository: repository);
  });

  test('current user starts with no activities', () {
    expect(repository.currentUser.routine, isEmpty);
    expect(repository.canSeeFriends, isFalse);
  });

  test('addActivity updates view model and unlocks friends feed', () {
    final now = DateTime.now();
    viewModel.addActivity(
      Activity(
        id: 'test-1',
        title: 'Coding',
        startTime: TimeOfDay(hour: now.hour, minute: now.minute),
        endTime: TimeOfDay(hour: (now.hour + 1) % 24, minute: now.minute),
        emoji: '💻',
        color: Colors.blue,
        date: now,
      ),
    );

    expect(viewModel.currentUser.routine, hasLength(1));
    expect(viewModel.canSeeFriends, isTrue);
  });

  test('getActivitiesByPeriod filters morning activities', () {
    viewModel.addActivity(
      Activity(
        id: 'morning-1',
        title: 'Breakfast',
        startTime: const TimeOfDay(hour: 8, minute: 0),
        endTime: const TimeOfDay(hour: 9, minute: 0),
        emoji: '☕',
        color: Colors.brown,
        date: DateTime.now(),
      ),
    );

    final morning = viewModel.getActivitiesByPeriod(RoutinePeriod.morning);
    expect(morning, hasLength(1));
    expect(morning.first.title, 'Breakfast');
  });
}
