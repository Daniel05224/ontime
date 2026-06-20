import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseModerationService {
  SupabaseModerationService._();
  static final instance = SupabaseModerationService._();

  final _db = Supabase.instance.client;

  Future<void> reportUser(String reportedUserId) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return;
    await _db.from('reports').insert({
      'reporter_id': uid,
      'reported_user_id': reportedUserId,
    });
  }

  Future<void> blockUser(String blockedId) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return;
    await _db.from('blocked_users').upsert(
      {'blocker_id': uid, 'blocked_id': blockedId},
      onConflict: 'blocker_id,blocked_id',
    );
  }

  Future<List<String>> getBlockedIds() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return [];
    try {
      final rows = await _db
          .from('blocked_users')
          .select('blocked_id')
          .eq('blocker_id', uid);
      return (rows as List)
          .map((r) => r['blocked_id'] as String)
          .toList();
    } catch (_) {
      return [];
    }
  }
}
