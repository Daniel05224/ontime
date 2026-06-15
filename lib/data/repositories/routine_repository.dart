import '../../domain/models/activity.dart';
import '../../domain/models/quick_suggestion.dart';
import '../../domain/models/user_profile.dart';
import '../services/routine_local_service.dart';

class RoutineRepository {
  RoutineRepository({required RoutineLocalService localService})
      : _localService = localService;

  final RoutineLocalService _localService;

  UserProfile get currentUser => _localService.currentUser;
  List<UserProfile> get friends => _localService.friends;
  List<String> get emojis => _localService.emojis;
  List<QuickSuggestion> get quickSuggestions => _localService.quickSuggestions;

  static bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool get canSeeFriends =>
      currentUser.routine.any((a) => _isToday(a.date));

  // Retorna APENAS atividades do day_plan (nunca statuses ao vivo)
  List<Activity> getActivitiesByPeriod(RoutinePeriod period) {
    return currentUser.routine.where((a) {
      if (a.isLive) return false; // statuses ficam fora do day_plan
      if (!_isToday(a.date)) return false;
      if (a.period == period) return true;
      if (a.startTime != null) {
        final hour = a.startTime!.hour;
        switch (period) {
          case RoutinePeriod.morning:
            return hour >= 6 && hour < 12;
          case RoutinePeriod.afternoon:
            return hour >= 12 && hour < 18;
          case RoutinePeriod.evening:
            return hour >= 18 && hour < 22;
          case RoutinePeriod.night:
            return hour >= 22 || hour < 6;
        }
      }
      return false;
    }).toList();
  }

  void addEmoji(String emoji) => _localService.addEmoji(emoji);

  void removeEmoji(String emoji) => _localService.removeEmoji(emoji);

  void setQuickSuggestions(List<QuickSuggestion> suggestions) =>
      _localService.setQuickSuggestions(suggestions);

  void addQuickSuggestion(String title, String emoji) {
    _localService.addQuickSuggestion(QuickSuggestion(title: title, emoji: emoji));
  }

  void updateQuickSuggestion(int index, QuickSuggestion suggestion) =>
      _localService.updateQuickSuggestion(index, suggestion);

  void removeQuickSuggestion(int index) =>
      _localService.removeQuickSuggestion(index);

  void swapQuickSuggestions(int index1, int index2) =>
      _localService.swapQuickSuggestions(index1, index2);

  void updateCurrentUser({
    required String id,
    required String name,
    required String avatarUrl,
  }) =>
      _localService.updateCurrentUser(
          id: id, name: name, avatarUrl: avatarUrl);

  void addActivity(Activity activity) => _localService.addActivity(activity);

  void updateActivity(String activityId, Activity newActivity) =>
      _localService.updateActivity(activityId, newActivity);

  void removeActivity(String id) => _localService.removeActivity(id);
}
