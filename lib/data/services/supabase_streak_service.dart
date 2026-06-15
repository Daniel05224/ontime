import 'package:supabase_flutter/supabase_flutter.dart';

/// Daily activity streak ("foguinho 🔥") service.
class SupabaseStreakService {
  SupabaseStreakService._();
  static final instance = SupabaseStreakService._();

  SupabaseClient get _db => Supabase.instance.client;
  String? get _uid => _db.auth.currentUser?.id;

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Records today as an active day.
  /// Safe to call multiple times per day — only counts once.
  Future<void> recordActivity() async {
    final uid = _uid;
    if (uid == null) return;
    final today = _fmt(DateTime.now());
    final yesterday = _fmt(DateTime.now().subtract(const Duration(days: 1)));
    try {
      final row = await _db
          .from('streaks')
          .select()
          .eq('user_id', uid)
          .maybeSingle();

      if (row == null) {
        await _db.from('streaks').insert({
          'user_id': uid,
          'current_streak': 1,
          'last_activity_date': today,
        });
      } else {
        final last = row['last_activity_date'] as String;
        if (last == today) return; // already counted today
        final newStreak =
            last == yesterday ? (row['current_streak'] as int) + 1 : 1;
        await _db.from('streaks').update({
          'current_streak': newStreak,
          'last_activity_date': today,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('user_id', uid);
      }
    } catch (_) {}
  }

  /// Returns the current user's effective streak (0 if expired).
  Future<int> getOwnStreak() async {
    final uid = _uid;
    if (uid == null) return 0;
    try {
      final row = await _db
          .from('streaks')
          .select()
          .eq('user_id', uid)
          .maybeSingle();
      if (row == null) return 0;
      return _effective(row);
    } catch (_) {
      return 0;
    }
  }

  /// Batch fetch streaks for a list of user IDs. Returns uid → streak.
  Future<Map<String, int>> getStreaks(List<String> userIds) async {
    if (userIds.isEmpty) return {};
    try {
      final rows = await _db
          .from('streaks')
          .select()
          .inFilter('user_id', userIds);
      return {
        for (final r in rows as List)
          r['user_id'] as String: _effective(r as Map<String, dynamic>),
      };
    } catch (_) {
      return {};
    }
  }

  int _effective(Map<String, dynamic> row) {
    final last = row['last_activity_date'] as String;
    final today = _fmt(DateTime.now());
    final yesterday = _fmt(DateTime.now().subtract(const Duration(days: 1)));
    if (last != today && last != yesterday) return 0; // streak broken
    return row['current_streak'] as int? ?? 0;
  }
}
