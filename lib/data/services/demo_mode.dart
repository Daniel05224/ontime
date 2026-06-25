import 'package:flutter/material.dart';

import '../../domain/models/activity.dart';
import '../../domain/models/chat_message.dart';
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

  // ── Demo chat messages ────────────────────────────────────────────────────

  static final Map<String, List<ChatMessage>> chats = {
    'demo-1': [
      ChatMessage(
        id: 'dm-1-1',
        senderId: 'demo-1',
        receiverId: 'demo-self',
        content: 'Oi! Tô na academia agora 💪',
        createdAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 10)),
      ),
      ChatMessage(
        id: 'dm-1-2',
        senderId: 'demo-self',
        receiverId: 'demo-1',
        content: 'Arrasando! Qual treino?',
        createdAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 5)),
      ),
      ChatMessage(
        id: 'dm-1-3',
        senderId: 'demo-1',
        receiverId: 'demo-self',
        content: 'Perna hoje 😅 tô morta',
        createdAt: DateTime.now().subtract(const Duration(minutes: 20)),
      ),
    ],
    'demo-2': [
      ChatMessage(
        id: 'dm-2-1',
        senderId: 'demo-self',
        receiverId: 'demo-2',
        content: 'Esse lugar parece ótimo!',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      ChatMessage(
        id: 'dm-2-2',
        senderId: 'demo-2',
        receiverId: 'demo-self',
        content: 'É demais! Você tinha que vir',
        createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
      ),
    ],
    'demo-3': [
      ChatMessage(
        id: 'dm-3-1',
        senderId: 'demo-3',
        receiverId: 'demo-self',
        content: 'Que série você tá assistindo?',
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
      ChatMessage(
        id: 'dm-3-2',
        senderId: 'demo-self',
        receiverId: 'demo-3',
        content: 'Stranger Things! Tá ótima',
        createdAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 50)),
      ),
      ChatMessage(
        id: 'dm-3-3',
        senderId: 'demo-3',
        receiverId: 'demo-self',
        content: 'Assisti tudo 😍 incrível',
        createdAt: DateTime.now().subtract(const Duration(minutes: 45)),
      ),
    ],
    'demo-4': [
      ChatMessage(
        id: 'dm-4-1',
        senderId: 'demo-4',
        receiverId: 'demo-self',
        content: 'Bora jogar mais tarde?',
        createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
      ),
      ChatMessage(
        id: 'dm-4-2',
        senderId: 'demo-self',
        receiverId: 'demo-4',
        content: 'Bora! Que horas?',
        createdAt: DateTime.now().subtract(const Duration(minutes: 25)),
      ),
      ChatMessage(
        id: 'dm-4-3',
        senderId: 'demo-4',
        receiverId: 'demo-self',
        content: 'Tipo umas 21h, blz?',
        createdAt: DateTime.now().subtract(const Duration(minutes: 2)),
      ),
    ],
    'demo-5': [
      ChatMessage(
        id: 'dm-5-1',
        senderId: 'demo-self',
        receiverId: 'demo-5',
        content: 'Oi Bea, sumida!',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ],
  };

  static Map<String, ChatMessage?> get lastMessages => {
        for (final entry in chats.entries)
          entry.key: entry.value.isNotEmpty ? entry.value.last : null,
      };

  static Map<String, int> get unreadCounts => {
        'demo-1': 1,
        'demo-2': 1,
        'demo-3': 1,
        'demo-4': 1,
        'demo-5': 0,
      };
}
