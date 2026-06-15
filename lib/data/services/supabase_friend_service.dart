import 'package:supabase_flutter/supabase_flutter.dart';

/// Result of a user search.
typedef SearchedUser = ({String id, String name, String avatarUrl, String friendStatus});

/// A pending friend request directed at the current user.
typedef PendingRequest = ({String id, String name, String avatarUrl});

/// Possible friendship states between the current user and a target.
// 'none' | 'pending_sent' | 'pending_received' | 'accepted'

class SupabaseFriendService {
  SupabaseFriendService._();
  static final instance = SupabaseFriendService._();

  SupabaseClient get _db => Supabase.instance.client;
  String? get _uid => _db.auth.currentUser?.id;

  // ── Search ────────────────────────────────────────────────────────────────

  /// Searches users by name. Returns results with pre-fetched friendship status
  /// so the UI can render action buttons without extra round-trips.
  Future<List<SearchedUser>> searchUsers(String query) async {
    final uid = _uid;
    if (uid == null || query.trim().isEmpty) return [];

    final rows = await _db
        .from('profiles')
        .select('id, name, avatar_url')
        .neq('id', uid)
        .ilike('name', '%${query.trim()}%')
        .limit(25);

    if (rows.isEmpty) return [];

    final ids = rows.map((r) => r['id'] as String).toList();

    // Fetch all relevant friendships in two queries (sent / received).
    final [sent, received] = await Future.wait([
      _db
          .from('friendships')
          .select('addressee_id, status')
          .eq('requester_id', uid)
          .inFilter('addressee_id', ids),
      _db
          .from('friendships')
          .select('requester_id, status')
          .eq('addressee_id', uid)
          .inFilter('requester_id', ids),
    ]);

    final statusMap = <String, String>{};
    for (final f in sent) {
      final aid = f['addressee_id'] as String;
      final s = f['status'] as String;
      statusMap[aid] = s == 'accepted' ? 'accepted' : 'pending_sent';
    }
    for (final f in received) {
      final rid = f['requester_id'] as String;
      if (!statusMap.containsKey(rid)) {
        final s = f['status'] as String;
        statusMap[rid] = s == 'accepted' ? 'accepted' : 'pending_received';
      }
    }

    return rows.map<SearchedUser>((r) {
      final id = r['id'] as String;
      return (
        id: id,
        name: r['name'] as String? ?? '',
        avatarUrl: r['avatar_url'] as String? ?? '',
        friendStatus: statusMap[id] ?? 'none',
      );
    }).toList();
  }

  /// Returns all users (except self) ordered by name, with friendship status.
  /// Used to populate the idle state of the search screen.
  Future<List<SearchedUser>> loadAllUsers() async {
    final uid = _uid;
    if (uid == null) return [];

    final rows = await _db
        .from('profiles')
        .select('id, name, avatar_url')
        .neq('id', uid)
        .order('name')
        .limit(60);

    if (rows.isEmpty) return [];

    final ids = rows.map((r) => r['id'] as String).toList();

    final [sent, received] = await Future.wait([
      _db
          .from('friendships')
          .select('addressee_id, status')
          .eq('requester_id', uid)
          .inFilter('addressee_id', ids),
      _db
          .from('friendships')
          .select('requester_id, status')
          .eq('addressee_id', uid)
          .inFilter('requester_id', ids),
    ]);

    final statusMap = <String, String>{};
    for (final f in sent) {
      final aid = f['addressee_id'] as String;
      final s = f['status'] as String;
      statusMap[aid] = s == 'accepted' ? 'accepted' : 'pending_sent';
    }
    for (final f in received) {
      final rid = f['requester_id'] as String;
      if (!statusMap.containsKey(rid)) {
        final s = f['status'] as String;
        statusMap[rid] = s == 'accepted' ? 'accepted' : 'pending_received';
      }
    }

    return rows.map<SearchedUser>((r) {
      final id = r['id'] as String;
      return (
        id: id,
        name: r['name'] as String? ?? '',
        avatarUrl: r['avatar_url'] as String? ?? '',
        friendStatus: statusMap[id] ?? 'none',
      );
    }).toList();
  }

  // ── Requests ──────────────────────────────────────────────────────────────

  Future<List<PendingRequest>> getPendingRequests() async {
    final uid = _uid;
    if (uid == null) return [];

    final friendships = await _db
        .from('friendships')
        .select('requester_id')
        .eq('addressee_id', uid)
        .eq('status', 'pending');

    if (friendships.isEmpty) return [];

    final ids = friendships.map((f) => f['requester_id'] as String).toList();
    final profiles =
        await _db.from('profiles').select('id, name, avatar_url').inFilter('id', ids);

    return profiles.map<PendingRequest>((r) {
      final id = r['id'] as String;
      return (
        id: id,
        name: r['name'] as String? ?? '',
        avatarUrl: r['avatar_url'] as String? ?? '',
      );
    }).toList();
  }

  Future<void> sendRequest(String targetId) async {
    final uid = _uid;
    if (uid == null) return;
    await _db.from('friendships').insert({
      'requester_id': uid,
      'addressee_id': targetId,
      'status': 'pending',
    });
  }

  Future<void> cancelRequest(String targetId) async {
    final uid = _uid;
    if (uid == null) return;
    await _db
        .from('friendships')
        .delete()
        .eq('requester_id', uid)
        .eq('addressee_id', targetId);
  }

  Future<void> acceptRequest(String requesterId) async {
    final uid = _uid;
    if (uid == null) return;
    await _db
        .from('friendships')
        .update({'status': 'accepted'})
        .eq('requester_id', requesterId)
        .eq('addressee_id', uid);
  }

  Future<void> rejectRequest(String requesterId) async {
    final uid = _uid;
    if (uid == null) return;
    await _db
        .from('friendships')
        .delete()
        .eq('requester_id', requesterId)
        .eq('addressee_id', uid);
  }

  Future<void> removeFriend(String userId) async {
    final uid = _uid;
    if (uid == null) return;
    // Friendship can exist in either direction.
    await Future.wait([
      _db
          .from('friendships')
          .delete()
          .eq('requester_id', uid)
          .eq('addressee_id', userId),
      _db
          .from('friendships')
          .delete()
          .eq('requester_id', userId)
          .eq('addressee_id', uid),
    ]);
  }

  // ── Realtime ───────────────────────────────────────────────────────────────

  RealtimeChannel subscribeFriendships(void Function() onUpdate) {
    final uid = _uid;
    return _db
        .channel('friendships_channel_${uid ?? 'anon'}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'friendships',
          callback: (_) => onUpdate(),
        )
        .subscribe();
  }

  void unsubscribe(RealtimeChannel channel) => _db.removeChannel(channel);
}
