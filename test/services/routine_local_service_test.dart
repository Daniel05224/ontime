import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ontime/data/services/routine_local_service.dart';
import 'package:ontime/domain/models/activity.dart';
import 'package:ontime/domain/models/quick_suggestion.dart';

void main() {
  late RoutineLocalService service;

  setUp(() => service = RoutineLocalService());

  Activity makeActivity(String id) => Activity(
        id: id,
        title: 'Test $id',
        emoji: '🎯',
        color: Colors.blue,
        date: DateTime.now(),
      );

  group('initial state', () {
    test('currentUser has empty routine', () {
      expect(service.currentUser.routine, isEmpty);
    });

    test('friends list has 5 entries', () {
      expect(service.friends.length, 5);
    });

    test('friends list is unmodifiable', () {
      expect(() => service.friends.add(service.friends.first),
          throwsUnsupportedError);
    });

    test('emojis list is not empty', () {
      expect(service.emojis, isNotEmpty);
    });

    test('quickSuggestions is not empty', () {
      expect(service.quickSuggestions, isNotEmpty);
    });

    test('quickSuggestions has no leading/trailing spaces in titles', () {
      for (final s in service.quickSuggestions) {
        expect(s.title.trim(), s.title,
            reason:
                'QuickSuggestion "${s.title}" has leading/trailing spaces');
      }
    });
  });

  group('addActivity', () {
    test('adds activity to routine', () {
      service.addActivity(makeActivity('a1'));
      expect(service.currentUser.routine.length, 1);
    });

    test('multiple adds accumulate', () {
      service.addActivity(makeActivity('a1'));
      service.addActivity(makeActivity('a2'));
      expect(service.currentUser.routine.length, 2);
    });
  });

  group('removeActivity', () {
    test('removes activity by id', () {
      service.addActivity(makeActivity('a1'));
      service.removeActivity('a1');
      expect(service.currentUser.routine, isEmpty);
    });

    test('removing non-existent id does not crash', () {
      expect(() => service.removeActivity('ghost'), returnsNormally);
    });

    test('only removes the target activity', () {
      service.addActivity(makeActivity('a1'));
      service.addActivity(makeActivity('a2'));
      service.removeActivity('a1');
      expect(service.currentUser.routine.length, 1);
      expect(service.currentUser.routine.first.id, 'a2');
    });
  });

  group('updateActivity', () {
    test('replaces activity with same id', () {
      service.addActivity(makeActivity('a1'));
      final updated = Activity(
        id: 'a1',
        title: 'Updated',
        emoji: '✅',
        color: Colors.green,
        date: DateTime.now(),
      );
      service.updateActivity('a1', updated);
      expect(service.currentUser.routine.first.title, 'Updated');
    });

    test('unknown id is a no-op', () {
      service.addActivity(makeActivity('a1'));
      final updated = makeActivity('ghost');
      service.updateActivity('ghost', updated);
      expect(service.currentUser.routine.length, 1);
      expect(service.currentUser.routine.first.id, 'a1');
    });
  });

  group('emoji management', () {
    test('addEmoji adds new emoji', () {
      final initialLen = service.emojis.length;
      service.addEmoji('🦄');
      expect(service.emojis.length, initialLen + 1);
      expect(service.emojis, contains('🦄'));
    });

    test('addEmoji ignores duplicates', () {
      final firstEmoji = service.emojis.first;
      final initialLen = service.emojis.length;
      service.addEmoji(firstEmoji);
      expect(service.emojis.length, initialLen);
    });

    test('removeEmoji removes it', () {
      service.addEmoji('🦄');
      service.removeEmoji('🦄');
      expect(service.emojis, isNot(contains('🦄')));
    });
  });

  group('quickSuggestions management', () {
    test('addQuickSuggestion appends entry', () {
      final initial = service.quickSuggestions.length;
      service.addQuickSuggestion(const QuickSuggestion(title: 'Dormir', emoji: '😴'));
      expect(service.quickSuggestions.length, initial + 1);
      expect(service.quickSuggestions.last.title, 'Dormir');
    });

    test('removeQuickSuggestion removes by index', () {
      final initial = service.quickSuggestions.length;
      service.removeQuickSuggestion(0);
      expect(service.quickSuggestions.length, initial - 1);
    });

    test('updateQuickSuggestion replaces at index', () {
      service.updateQuickSuggestion(
          0, const QuickSuggestion(title: 'Novo', emoji: '🆕'));
      expect(service.quickSuggestions.first.title, 'Novo');
    });

    test('updateQuickSuggestion out of bounds is a no-op', () {
      final initial = service.quickSuggestions.length;
      expect(
        () => service.updateQuickSuggestion(9999, const QuickSuggestion(title: 'X', emoji: '❓')),
        returnsNormally,
      );
      expect(service.quickSuggestions.length, initial);
    });

    test('swapQuickSuggestions exchanges two items', () {
      final first = service.quickSuggestions[0].title;
      final second = service.quickSuggestions[1].title;
      service.swapQuickSuggestions(0, 1);
      expect(service.quickSuggestions[0].title, second);
      expect(service.quickSuggestions[1].title, first);
    });

    test('setQuickSuggestions replaces all', () {
      service.setQuickSuggestions([
        const QuickSuggestion(title: 'A', emoji: '🅰️'),
        const QuickSuggestion(title: 'B', emoji: '🅱️'),
      ]);
      expect(service.quickSuggestions.length, 2);
      expect(service.quickSuggestions.first.title, 'A');
    });
  });

  group('updateCurrentUser', () {
    test('updates id, name, avatarUrl', () {
      service.updateCurrentUser(id: 'uid', name: 'Daniel', avatarUrl: 'url');
      expect(service.currentUser.id, 'uid');
      expect(service.currentUser.name, 'Daniel');
      expect(service.currentUser.avatarUrl, 'url');
    });

    test('preserves existing routine when updating user info', () {
      service.addActivity(makeActivity('a1'));
      service.updateCurrentUser(id: 'uid', name: 'Daniel', avatarUrl: 'url');
      expect(service.currentUser.routine.length, 1);
    });
  });
}
