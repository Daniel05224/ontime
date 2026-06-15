import 'package:flutter/material.dart';

import '../../ui/core/theme/app_colors.dart';
import 'activity.dart';

/// A "vibe" is a one-tap status: an emoji + a short word + a color.
///
/// The whole point of the composer is to avoid typing and exact times —
/// you pick a vibe and you're done. [Activity] is still the persisted model;
/// a vibe just builds one quickly.
@immutable
class Vibe {
  const Vibe({required this.emoji, required this.label, required this.color});

  final String emoji;
  final String label;
  final Color color;

  /// The signature status — the simplest and most important one.
  static const free = Vibe(
    emoji: '🙌',
    label: 'Livre agora',
    color: AppColors.live,
  );

  /// Curated, no-typing-required catalog — focused on teen daily life.
  static const catalog = <Vibe>[
    free,
    Vibe(emoji: '📚', label: 'Estudando', color: Color(0xFF6AA4FF)),   // soft neon blue
    Vibe(emoji: '🎮', label: 'Jogando', color: Color(0xFFBB7AFF)),     // soft neon purple
    Vibe(emoji: '📺', label: 'Em casa', color: Color(0xFF9D6EF0)),     // soft neon deep violet
    Vibe(emoji: '🍕', label: 'Comendo', color: AppColors.secondary),
    Vibe(emoji: '🏃', label: 'Treinando', color: Color(0xFFFF9D6A)),   // soft neon orange
    Vibe(emoji: '🤝', label: 'Com amigos', color: Color(0xFF34C99A)),  // soft neon emerald
    Vibe(emoji: '🎉', label: 'No rolê', color: Color(0xFFFF7BBF)),     // soft neon rose
    Vibe(emoji: '🚗', label: 'Na rua', color: Color(0xFF4DDFCE)),      // soft neon teal
    sleeping,
  ];

  /// Palette used to color user-created custom vibes.
  static const _customPalette = <Color>[
    AppColors.primary,
    AppColors.secondary,
    AppColors.accent,
    AppColors.morning,
    Color(0xFFA855F7),
    Color(0xFF2DD4BF),
  ];

  static Color customColor(int index) =>
      _customPalette[index % _customPalette.length];

  static const sleeping = Vibe(
    emoji: '😴',
    label: 'Dormindo',
    color: AppColors.night,
  );

  bool get isFree => emoji == free.emoji && label == free.label;

  Activity toActivity({required String id, RoutinePeriod? period}) => Activity(
    id: id,
    title: label,
    period: period,
    emoji: emoji,
    color: color,
    date: DateTime.now(),
  );

  static Vibe fromActivity(Activity a) =>
      Vibe(emoji: a.emoji, label: a.title, color: a.color);

  @override
  bool operator ==(Object other) =>
      other is Vibe && other.emoji == emoji && other.label == label;

  @override
  int get hashCode => Object.hash(emoji, label);
}

/// The current period of day, used so a posted vibe is "live now".
RoutinePeriod currentPeriod() {
  final hour = DateTime.now().hour;
  if (hour >= 6 && hour < 12) return RoutinePeriod.morning;
  if (hour >= 12 && hour < 18) return RoutinePeriod.afternoon;
  if (hour >= 18 && hour < 22) return RoutinePeriod.evening;
  return RoutinePeriod.night;
}

extension RoutinePeriodLabel on RoutinePeriod {
  String get label => switch (this) {
    RoutinePeriod.morning => 'Manhã',
    RoutinePeriod.afternoon => 'Tarde',
    RoutinePeriod.evening => 'Noite',
    RoutinePeriod.night => 'Madrugada',
  };

  String get clock => switch (this) {
    RoutinePeriod.morning => '06–12h',
    RoutinePeriod.afternoon => '12–18h',
    RoutinePeriod.evening => '18–23h',
    RoutinePeriod.night => '23–06h',
  };

  String get glyph => switch (this) {
    RoutinePeriod.morning => '☀️',
    RoutinePeriod.afternoon => '🌤️',
    RoutinePeriod.evening => '🌙',
    RoutinePeriod.night => '✨',
  };
}
