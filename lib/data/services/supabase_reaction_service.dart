import 'package:supabase_flutter/supabase_flutter.dart';

typedef ReactionSummary = ({Map<String, int> counts, String? myEmoji});

class SupabaseReactionService {
  SupabaseReactionService._();
  static final instance = SupabaseReactionService._();

  SupabaseClient get _db => Supabase.instance.client;
  String? get _uid => _db.auth.currentUser?.id;

  // ── Leitura ───────────────────────────────────────────────────────────────

  Future<ReactionSummary> getReactions(
    String targetUserId,
    String period,
    String planDate,
  ) async {
    final uid = _uid;
    if (uid == null) return (counts: <String, int>{}, myEmoji: null);

    final rows = await _db
        .from('reactions')
        .select('reactor_id, emoji')
        .eq('target_user_id', targetUserId)
        .eq('period', period)
        .eq('plan_date', planDate);

    final counts = <String, int>{};
    String? myEmoji;
    for (final row in rows) {
      final emoji = row['emoji'] as String;
      counts[emoji] = (counts[emoji] ?? 0) + 1;
      if (row['reactor_id'] == uid) myEmoji = emoji;
    }

    return (counts: counts, myEmoji: myEmoji);
  }

  // ── Escrita ───────────────────────────────────────────────────────────────

  Future<void> react(
    String targetUserId,
    String period,
    String planDate,
    String emoji,
  ) async {
    final uid = _uid;
    if (uid == null) return;

    await _db.from('reactions').upsert({
      'reactor_id': uid,
      'target_user_id': targetUserId,
      'period': period,
      'plan_date': planDate,
      'emoji': emoji,
      'reacted_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'reactor_id,target_user_id,period,plan_date');
  }

  Future<void> removeReaction(
    String targetUserId,
    String period,
    String planDate,
  ) async {
    final uid = _uid;
    if (uid == null) return;

    await _db
        .from('reactions')
        .delete()
        .eq('reactor_id', uid)
        .eq('target_user_id', targetUserId)
        .eq('period', period)
        .eq('plan_date', planDate);
  }

  void unsubscribe(RealtimeChannel channel) {
    _db.removeChannel(channel);
  }
}
