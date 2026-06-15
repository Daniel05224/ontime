import 'package:flutter/material.dart';

import '../../domain/models/activity.dart';
import '../../domain/models/quick_suggestion.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/models/vibe.dart';

/// In-memory data source for routine, friends, and preferences.
/// Replace with API or local DB services when backend is available.
class RoutineLocalService {
  UserProfile _currentUser = UserProfile(
    id: 'user_1',
    name: 'You',
    avatarUrl: '',
    routine: [],
  );

  final List<UserProfile> _friends = [
    UserProfile(
      id: 'friend_1',
      name: 'Alice ✨',
      avatarUrl: '',
      routine: [
        Activity(
          id: 'a1',
          title: 'Tirando fotos',
          startTime: TimeOfDay(hour: 9, minute: 0),
          endTime: TimeOfDay(hour: 18, minute: 0),
          emoji: '📸',
          color: Colors.pinkAccent,
          date: DateTime.now(),
          photoUrl:
              'https://images.unsplash.com/photo-1542038784456-1ea8e935640e?q=80&w=600&auto=format&fit=crop',
        ),
      ],
    ),
    UserProfile(
      id: 'friend_2',
      name: 'Bob',
      avatarUrl: '',
      routine: [
        Activity(
          id: 'a2',
          title: 'Treino insano',
          startTime: TimeOfDay(hour: 18, minute: 0),
          endTime: TimeOfDay(hour: 20, minute: 0),
          emoji: '🏋️‍♂️',
          color: Colors.orange,
          date: DateTime.now(),
          photoUrl:
              'https://images.unsplash.com/photo-1517838277536-f5f99be501cd?q=80&w=600&auto=format&fit=crop',
        ),
      ],
    ),
    UserProfile(
      id: 'friend_3',
      name: 'Charlie 🎮',
      avatarUrl: '',
      routine: [
        Activity(
          id: 'a3',
          title: 'Gameplay da noite',
          startTime: TimeOfDay(hour: 20, minute: 0),
          endTime: TimeOfDay(hour: 23, minute: 0),
          emoji: '🎮',
          color: Colors.purpleAccent,
          date: DateTime.now(),
          photoUrl:
              'https://images.unsplash.com/photo-1600861195091-690c92f1d2cc?q=80&w=600&auto=format&fit=crop',
        ),
      ],
    ),
    UserProfile(
      id: 'friend_4',
      name: 'Dani ☕',
      avatarUrl: '',
      routine: [
        Activity(
          id: 'a4',
          title: 'Tomando um cafézinho',
          startTime: TimeOfDay(hour: 8, minute: 0),
          endTime: TimeOfDay(hour: 9, minute: 0),
          emoji: '☕',
          color: Colors.brown,
          date: DateTime.now(),
          photoUrl:
              'https://images.unsplash.com/photo-1507133750040-4a8f57021571?q=80&w=600&auto=format&fit=crop',
        ),
      ],
    ),
    UserProfile(
      id: 'friend_5',
      name: 'Clara 🌊',
      avatarUrl: '',
      routine: [
        Activity(
          id: 'a5',
          title: 'Relaxando na praia',
          startTime: TimeOfDay(hour: 16, minute: 0),
          endTime: TimeOfDay(hour: 18, minute: 0),
          emoji: '🌊',
          color: Colors.cyanAccent,
          date: DateTime.now(),
          photoUrl:
              'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?q=80&w=600&auto=format&fit=crop',
        ),
      ],
    ),
  ];

  final List<String> _emojis = ['💻', '🏋️‍♂️', '🎮', '📚', '☕️', '💤'];

  final List<QuickSuggestion> _quickSuggestions = Vibe.catalog
      .where((v) => !v.isFree)
      .map((v) => QuickSuggestion(title: v.label, emoji: v.emoji))
      .toList();

  UserProfile get currentUser => _currentUser;

  void updateCurrentUser({
    required String id,
    required String name,
    required String avatarUrl,
  }) {
    _currentUser = UserProfile(
      id: id,
      name: name,
      avatarUrl: avatarUrl,
      routine: _currentUser.routine,
    );
  }
  List<UserProfile> get friends => List.unmodifiable(_friends);
  List<String> get emojis => List.unmodifiable(_emojis);
  List<QuickSuggestion> get quickSuggestions =>
      List.unmodifiable(_quickSuggestions);

  void addEmoji(String emoji) {
    if (!_emojis.contains(emoji)) {
      _emojis.add(emoji);
    }
  }

  void removeEmoji(String emoji) {
    _emojis.remove(emoji);
  }

  void setQuickSuggestions(List<QuickSuggestion> suggestions) {
    _quickSuggestions
      ..clear()
      ..addAll(suggestions);
  }

  void addQuickSuggestion(QuickSuggestion suggestion) {
    _quickSuggestions.add(suggestion);
  }

  void updateQuickSuggestion(int index, QuickSuggestion suggestion) {
    if (index < 0 || index >= _quickSuggestions.length) return;
    _quickSuggestions[index] = suggestion;
  }

  void removeQuickSuggestion(int index) {
    _quickSuggestions.removeAt(index);
  }

  void swapQuickSuggestions(int index1, int index2) {
    final temp = _quickSuggestions[index1];
    _quickSuggestions[index1] = _quickSuggestions[index2];
    _quickSuggestions[index2] = temp;
  }

  void addActivity(Activity activity) {
    _currentUser = _currentUser.copyWith(
      routine: [..._currentUser.routine, activity],
    );
  }

  void updateActivity(String activityId, Activity newActivity) {
    final routine = _currentUser.routine
        .map((a) => a.id == activityId ? newActivity : a)
        .toList();
    _currentUser = _currentUser.copyWith(routine: routine);
  }

  void removeActivity(String id) {
    _currentUser = _currentUser.copyWith(
      routine: _currentUser.routine.where((a) => a.id != id).toList(),
    );
  }
}
