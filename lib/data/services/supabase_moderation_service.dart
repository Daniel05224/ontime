import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseModerationService {
  SupabaseModerationService._();
  static final instance = SupabaseModerationService._();

  final _db = Supabase.instance.client;

  Future<void> reportUser(String reportedUserId) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) {
      debugPrint('[ModerationService] reportUser: no authenticated user');
      return;
    }
    try {
      await _db.from('reports').insert({
        'reporter_id': uid,
        'reported_id': reportedUserId,
      });
      debugPrint('[ModerationService] report saved for $reportedUserId');
    } catch (e) {
      debugPrint('[ModerationService] reportUser error: $e');
      rethrow;
    }
  }

  Future<void> blockUser(String blockedId) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await _db.from('blocked_users').insert(
        {'blocker_id': uid, 'blocked_id': blockedId},
      );
    } on PostgrestException catch (e) {
      // 23505 = unique_violation — already blocked, that's fine
      if (e.code == '23505') return;
      debugPrint('[ModerationService] blockUser error: $e');
      rethrow;
    }
  }

  Future<void> unblockUser(String blockedId) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await _db
          .from('blocked_users')
          .delete()
          .eq('blocker_id', uid)
          .eq('blocked_id', blockedId);
    } catch (e) {
      debugPrint('[ModerationService] unblockUser error: $e');
      rethrow;
    }
  }

  Future<List<String>> getBlockedIds() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return [];
    try {
      final rows = await _db
          .from('blocked_users')
          .select('blocked_id')
          .eq('blocker_id', uid);
      return (rows as List).map((r) => r['blocked_id'] as String).toList();
    } catch (e) {
      debugPrint('[ModerationService] getBlockedIds error: $e');
      return [];
    }
  }

  Future<List<String>> getBlockedByIds() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return [];
    try {
      final rows = await _db
          .from('blocked_users')
          .select('blocker_id')
          .eq('blocked_id', uid);
      return (rows as List).map((r) => r['blocker_id'] as String).toList();
    } catch (e) {
      debugPrint('[ModerationService] getBlockedByIds error: $e');
      return [];
    }
  }
}
