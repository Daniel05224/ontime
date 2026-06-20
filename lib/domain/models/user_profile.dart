import 'activity.dart';

class UserProfile {
  final String id;
  final String name;
  final String avatarUrl;
  final List<Activity> routine;
  final int streak;

  const UserProfile({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.routine,
    this.streak = 0,
  });

  UserProfile copyWith({
    String? id,
    String? name,
    String? avatarUrl,
    List<Activity>? routine,
    int? streak,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      routine: routine ?? this.routine,
      streak: streak ?? this.streak,
    );
  }

  Activity? get currentActivity {
    // Status ao vivo tem prioridade: ativo enquanto não expirou
    for (final activity in routine) {
      if (activity.isLive && !activity.isExpired) return activity;
    }
    // Sem status ao vivo: usa day_plan do período atual
    for (final activity in routine) {
      if (!activity.isLive && activity.isActiveNow) return activity;
    }
    return null;
  }
}
