import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../data/repositories/routine_repository.dart';
import '../../../../data/services/demo_mode.dart';
import '../../../../data/services/supabase_profile_service.dart';
import '../../../../data/services/supabase_status_service.dart';
import '../../../../data/services/supabase_streak_service.dart';
import '../../../../domain/models/activity.dart';
import '../../../../domain/models/quick_suggestion.dart';
import '../../../../domain/models/user_profile.dart';
import '../../../../domain/models/vibe.dart';

class RoutineViewModel extends ChangeNotifier {
  RoutineViewModel({required RoutineRepository repository})
      : _repository = repository {
    _scheduleNextReset();
  }

  final RoutineRepository _repository;
  static const _uuid = Uuid();
  Timer? _resetTimer;
  Timer? _statusExpiryTimer;
  int _ownStreak = 0;

  UserProfile get currentUser => DemoMode.instance.isActive
      ? DemoMode.self
      : _repository.currentUser;
  List<UserProfile> get friends => _repository.friends;
  List<String> get emojis => _repository.emojis;
  List<QuickSuggestion> get quickSuggestions => _repository.quickSuggestions;
  bool get canSeeFriends => _repository.canSeeFriends;
  int get ownStreak =>
      DemoMode.instance.isActive ? DemoMode.self.streak : _ownStreak;

  List<Activity> getActivitiesByPeriod(RoutinePeriod period) =>
      _repository.getActivitiesByPeriod(period);

  void addEmoji(String emoji) {
    _repository.addEmoji(emoji);
    notifyListeners();
  }

  void removeEmoji(String emoji) {
    _repository.removeEmoji(emoji);
    notifyListeners();
  }

  Future<void> _syncCustomVibes() async {
    try {
      await SupabaseProfileService.instance
          .saveCustomVibes(_repository.quickSuggestions.toList());
    } catch (_) {}
  }

  Future<void> loadCustomVibes() async {
    try {
      final saved = await SupabaseProfileService.instance.loadCustomVibes();
      final catalogDefaults = Vibe.catalog
          .where((v) => !v.isFree)
          .map((v) => QuickSuggestion(title: v.label, emoji: v.emoji))
          .toList();
      // Preserve custom vibes the user added that aren't in the catalog
      final catalogTitles =
          catalogDefaults.map((v) => v.title.toLowerCase()).toSet();
      final extras = saved
          .where((v) => !catalogTitles.contains(v.title.toLowerCase()))
          .toList();
      _repository.setQuickSuggestions([...catalogDefaults, ...extras]);
      _syncCustomVibes();
      notifyListeners();
    } catch (_) {}
  }

  void addQuickSuggestion(String title, String emoji) {
    _repository.addQuickSuggestion(title, emoji);
    _syncCustomVibes();
    notifyListeners();
  }

  void updateQuickSuggestion(int index, String title, String emoji) {
    _repository.updateQuickSuggestion(
        index, QuickSuggestion(title: title, emoji: emoji));
    _syncCustomVibes();
    notifyListeners();
  }

  void removeQuickSuggestion(int index) {
    _repository.removeQuickSuggestion(index);
    _syncCustomVibes();
    notifyListeners();
  }

  void swapQuickSuggestions(int index1, int index2) {
    _repository.swapQuickSuggestions(index1, index2);
    notifyListeners();
  }

  void addActivity(Activity activity) {
    _repository.addActivity(activity);
    notifyListeners();
  }

  void updateActivity(String activityId, Activity newActivity) {
    _repository.updateActivity(activityId, newActivity);
    notifyListeners();
  }

  void removeActivity(String id) {
    _repository.removeActivity(id);
    notifyListeners();
  }

  /// Agenda o próximo reset às 6h do dia seguinte.
  void _scheduleNextReset() {
    _resetTimer?.cancel();
    final now = DateTime.now();
    var next6am = DateTime(now.year, now.month, now.day, 6);
    if (!now.isBefore(next6am)) {
      next6am = next6am.add(const Duration(days: 1));
    }
    _resetTimer = Timer(next6am.difference(now), () {
      _clearForNewDay();
      _scheduleNextReset();
    });
  }

  /// Zera o estado local ao virar o dia (6h) e limpa planos antigos no Supabase.
  void _clearForNewDay() {
    for (final a in List.of(_repository.currentUser.routine)) {
      _repository.removeActivity(a.id);
    }
    notifyListeners();
    SupabaseStatusService.instance.cleanupOldPlans();
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    _statusExpiryTimer?.cancel();
    super.dispose();
  }

  /// Atualiza o perfil do usuário logado a partir do Supabase.
  Future<void> loadUserProfile() async {
    final authUser = Supabase.instance.client.auth.currentUser;
    if (authUser == null) return;
    try {
      final profile = await SupabaseProfileService.instance.getMyProfile();
      final name = ((profile?['name'] as String?) ?? '').trim().isNotEmpty
          ? (profile!['name'] as String).trim()
          : ((authUser.userMetadata?['name'] as String?) ?? '').trim().isNotEmpty
              ? (authUser.userMetadata!['name'] as String).trim()
              : authUser.email?.split('@').first ?? 'Você';
      final avatarUrl = (profile?['avatar_url'] as String?)?.isNotEmpty == true
          ? profile!['avatar_url'] as String
          : '';
      _repository.updateCurrentUser(
        id: authUser.id,
        name: name,
        avatarUrl: avatarUrl,
      );
      notifyListeners();
    } catch (_) {}
  }

  /// Carrega o plano do dia de hoje do Supabase e popula o estado local.
  /// Carrega day_plan E status ao vivo em paralelo — ambos ficam no routine.
  Future<void> loadTodayData() async {
    try {
      final results = await Future.wait([
        SupabaseStatusService.instance.loadTodayData(),
        SupabaseStatusService.instance.loadLiveStatus(),
        SupabaseStreakService.instance.getOwnStreak(),
      ]);
      final plan = results[0] as Map<RoutinePeriod, Vibe?>;
      final liveStatus = results[1] as Activity?;
      _ownStreak = results[2] as int;

      // Limpa atividades existentes
      for (final a in List.of(_repository.currentUser.routine)) {
        _repository.removeActivity(a.id);
      }
      // Popula day_plan
      for (final entry in plan.entries) {
        if (entry.value != null) {
          _repository.addActivity(
            entry.value!.toActivity(id: _uuid.v4(), period: entry.key),
          );
        }
      }
      // Popula status ao vivo (tem prioridade via currentActivity getter)
      if (liveStatus != null) {
        _repository.addActivity(liveStatus);
        if (liveStatus.endsAt != null) {
          scheduleStatusExpiry(liveStatus.endsAt!);
        }
      }
      notifyListeners();
    } catch (_) {
      // Falha silenciosa — app funciona com estado vazio
    }
  }

  /// Recarrega o streak do próprio usuário do Supabase.
  Future<void> refreshStreak() async {
    _ownStreak = await SupabaseStreakService.instance.getOwnStreak();
    notifyListeners();
  }

  /// Atualiza imediatamente o status ao vivo no estado local.
  void setLiveStatus(Vibe vibe, RoutinePeriod period, {DateTime? endsAt, String? photoUrl}) {
    for (final a in List.of(_repository.currentUser.routine)) {
      if (a.isLive) _repository.removeActivity(a.id);
    }
    final uid = Supabase.instance.client.auth.currentUser?.id ?? 'me';
    _repository.addActivity(Activity(
      id: '${uid}_live',
      title: vibe.label,
      emoji: vibe.emoji,
      color: vibe.color,
      date: DateTime.now(),
      period: period,
      isLive: true,
      endsAt: endsAt,
      photoUrl: photoUrl,
    ));
    notifyListeners();
  }

  /// Remove o status ao vivo do estado local.
  void clearLiveStatus() {
    _statusExpiryTimer?.cancel();
    for (final a in List.of(_repository.currentUser.routine)) {
      if (a.isLive) _repository.removeActivity(a.id);
    }
    notifyListeners();
  }

  /// Agenda limpeza automática do status ao vivo quando expira.
  void scheduleStatusExpiry(DateTime endsAt) {
    _statusExpiryTimer?.cancel();
    final delay = endsAt.difference(DateTime.now());
    if (delay.isNegative || delay.inSeconds < 1) {
      clearLiveStatus();
      return;
    }
    _statusExpiryTimer = Timer(delay, () async {
      await SupabaseStatusService.instance.cleanupExpiredStatuses();
      clearLiveStatus();
    });
  }

  /// Replaces whatever is planned for [period] with [activity] (or clears it
  /// when null). Batches into a single notification.
  void setPeriodActivity(RoutinePeriod period, Activity? activity) {
    for (final a in _repository.getActivitiesByPeriod(period)) {
      _repository.removeActivity(a.id);
    }
    if (activity != null) _repository.addActivity(activity);
    notifyListeners();
  }
}
