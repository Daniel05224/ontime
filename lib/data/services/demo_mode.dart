import 'package:flutter/material.dart';

import '../../domain/models/activity.dart';
import '../../domain/models/user_profile.dart';

class DemoMode {
  DemoMode._();
  static final instance = DemoMode._();

  bool isActive = false;

  static final UserProfile self = UserProfile(
    id: 'demo-self',
    name: 'Você',
    avatarUrl: '',
    streak: 7,
    routine: [
      Activity(
        id: 'demo-s1',
        title: 'Testando o app',
        emoji: '📱',
        color: Color(0xFF7C5CFC),
        date: DateTime.now().subtract(const Duration(minutes: 5)),
        isLive: true,
        endsAt: DateTime(2099),
      ),
    ],
  );

  static final List<UserProfile> friends = [
    UserProfile(
      id: 'demo-1',
      name: 'Ana Silva',
      avatarUrl: 'https://i.pravatar.cc/150?img=47',
      streak: 12,
      routine: [
        Activity(
          id: 'demo-a1',
          title: 'Na academia',
          emoji: '🏋️',
          color: Color(0xFFFF6500),
          date: DateTime.now().subtract(const Duration(minutes: 20)),
          isLive: true,
          endsAt: DateTime(2099),
          photoUrl: 'https://images.unsplash.com/photo-1534438327276-14e5300c3a48?w=600&q=80',
        ),
      ],
    ),
    UserProfile(
      id: 'demo-2',
      name: 'Carlos Mendes',
      avatarUrl: 'https://i.pravatar.cc/150?img=12',
      streak: 5,
      routine: [
        Activity(
          id: 'demo-a2',
          title: 'Jantando',
          emoji: '🍽️',
          color: Color(0xFFE040FB),
          date: DateTime.now().subtract(const Duration(minutes: 10)),
          isLive: true,
          endsAt: DateTime(2099),
          photoUrl: 'https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=600&q=80',
        ),
      ],
    ),
    UserProfile(
      id: 'demo-3',
      name: 'Julia Costa',
      avatarUrl: 'https://i.pravatar.cc/150?img=32',
      streak: 21,
      routine: [
        Activity(
          id: 'demo-a3',
          title: 'Assistindo série',
          emoji: '📺',
          color: Color(0xFF00BCD4),
          date: DateTime.now().subtract(const Duration(minutes: 45)),
          isLive: true,
          endsAt: DateTime(2099),
          photoUrl: 'https://images.unsplash.com/photo-1522869635100-9f4c5e86aa37?w=600&q=80',
        ),
      ],
    ),
    UserProfile(
      id: 'demo-4',
      name: 'Pedro Lima',
      avatarUrl: 'https://i.pravatar.cc/150?img=8',
      streak: 3,
      routine: [
        Activity(
          id: 'demo-a4',
          title: 'Jogando',
          emoji: '🎮',
          color: Color(0xFF4CAF50),
          date: DateTime.now().subtract(const Duration(minutes: 2)),
          isLive: true,
          endsAt: DateTime(2099),
          photoUrl: 'https://images.unsplash.com/photo-1593305841991-05c297ba4575?w=600&q=80',
        ),
      ],
    ),
    UserProfile(
      id: 'demo-5',
      name: 'Beatriz Santos',
      avatarUrl: 'https://i.pravatar.cc/150?img=25',
      streak: 0,
      routine: [],
    ),
  ];
}
