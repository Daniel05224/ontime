import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ontime/data/services/day_history_service.dart';
import 'package:ontime/domain/models/activity.dart';
import 'package:ontime/domain/models/vibe.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('DayHistoryService save/load round-trip', () {
    test('load returns null when nothing was saved', () async {
      final result = await DayHistoryService.instance.load(1);
      expect(result, isNull);
    });

    test('saves and loads morning plan', () async {
      final plan = <RoutinePeriod, Vibe?>{
        RoutinePeriod.morning: const Vibe(
          emoji: '☕',
          label: 'Café',
          color: Color(0xFF795548),
        ),
      };
      await DayHistoryService.instance.save(1, plan);
      final loaded = await DayHistoryService.instance.load(1);

      expect(loaded, isNotNull);
      expect(loaded![RoutinePeriod.morning]?.emoji, '☕');
      expect(loaded[RoutinePeriod.morning]?.label, 'Café');
    });

    test('saves and loads multi-period plan', () async {
      final plan = <RoutinePeriod, Vibe?>{
        RoutinePeriod.morning: Vibe.free,
        RoutinePeriod.afternoon: Vibe.sleeping,
        RoutinePeriod.evening: null,
        RoutinePeriod.night: null,
      };
      await DayHistoryService.instance.save(3, plan);
      final loaded = await DayHistoryService.instance.load(3);

      expect(loaded, isNotNull);
      expect(loaded![RoutinePeriod.morning], isNotNull);
      expect(loaded[RoutinePeriod.afternoon], isNotNull);
      // null vibes are not persisted
      expect(loaded.containsKey(RoutinePeriod.evening), isFalse);
    });

    test('different weekdays are stored independently', () async {
      final mon = <RoutinePeriod, Vibe?>{
        RoutinePeriod.morning: Vibe.free,
      };
      final tue = <RoutinePeriod, Vibe?>{
        RoutinePeriod.morning: Vibe.sleeping,
      };
      await DayHistoryService.instance.save(1, mon);
      await DayHistoryService.instance.save(2, tue);

      final loadedMon = await DayHistoryService.instance.load(1);
      final loadedTue = await DayHistoryService.instance.load(2);

      expect(loadedMon![RoutinePeriod.morning]?.label, Vibe.free.label);
      expect(loadedTue![RoutinePeriod.morning]?.label, Vibe.sleeping.label);
    });

    test('saving again replaces previous plan for same weekday', () async {
      final planA = <RoutinePeriod, Vibe?>{
        RoutinePeriod.morning: Vibe.free,
      };
      final planB = <RoutinePeriod, Vibe?>{
        RoutinePeriod.morning: Vibe.sleeping,
      };
      await DayHistoryService.instance.save(5, planA);
      await DayHistoryService.instance.save(5, planB);
      final loaded = await DayHistoryService.instance.load(5);

      expect(loaded![RoutinePeriod.morning]?.label, Vibe.sleeping.label);
    });

    test('load returns null when plan is all-null vibes', () async {
      final plan = <RoutinePeriod, Vibe?>{
        RoutinePeriod.morning: null,
        RoutinePeriod.afternoon: null,
      };
      await DayHistoryService.instance.save(7, plan);
      final loaded = await DayHistoryService.instance.load(7);
      // All nulls → nothing saved → load returns null (empty map → null)
      expect(loaded, isNull);
    });

    test('color is preserved correctly through round-trip', () async {
      const testColor = Color(0xFFBB7AFF);
      final plan = <RoutinePeriod, Vibe?>{
        RoutinePeriod.evening: const Vibe(
          emoji: '🎮',
          label: 'Jogando',
          color: testColor,
        ),
      };
      await DayHistoryService.instance.save(4, plan);
      final loaded = await DayHistoryService.instance.load(4);
      expect(loaded![RoutinePeriod.evening]?.color, testColor);
    });
  });
}
