import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/chat_message.dart';

/// Direct-message service backed by the `direct_messages` Supabase table.
///
/// Required SQL migration:
/// ```sql
/// create table direct_messages (
///   id          uuid primary key default gen_random_uuid(),
///   sender_id   uuid references auth.users(id) on delete cascade,
///   receiver_id uuid references auth.users(id) on delete cascade,
///   content     text not null,
///   type        text not null default 'text',
///   metadata    jsonb,
///   read_at     timestamptz,
///   created_at  timestamptz not null default now()
/// );
/// alter table direct_messages enable row level security;
/// create policy "read own messages"  on direct_messages for select
///   using (auth.uid() = sender_id or auth.uid() = receiver_id);
/// create policy "insert own messages" on direct_messages for insert
///   with check (auth.uid() = sender_id);
/// create policy "mark as read" on direct_messages for update
///   using (auth.uid() = receiver_id);
/// ```
class SupabaseChatService {
  SupabaseChatService._();
  static final instance = SupabaseChatService._();

  SupabaseClient get _db => Supabase.instance.client;
  String? get _uid => _db.auth.currentUser?.id;

  // ── Read ──────────────────────────────────────────────────────────────────

  Future<List<ChatMessage>> getMessages(String friendId,
      {int limit = 60}) async {
    final uid = _uid;
    if (uid == null) return [];
    try {
      final rows = await _db
          .from('direct_messages')
          .select()
          .or('and(sender_id.eq.$uid,receiver_id.eq.$friendId),'
              'and(sender_id.eq.$friendId,receiver_id.eq.$uid)')
          .order('created_at', ascending: false)
          .limit(limit);
      return rows
          .map<ChatMessage>((r) => ChatMessage.fromMap(r))
          .toList()
          .reversed
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<ChatMessage?> getLastMessage(String friendId) async {
    final uid = _uid;
    if (uid == null) return null;
    try {
      final rows = await _db
          .from('direct_messages')
          .select()
          .or('and(sender_id.eq.$uid,receiver_id.eq.$friendId),'
              'and(sender_id.eq.$friendId,receiver_id.eq.$uid)')
          .order('created_at', ascending: false)
          .limit(1);
      if (rows.isEmpty) return null;
      return ChatMessage.fromMap(rows.first);
    } catch (_) {
      return null;
    }
  }

  Future<int> getUnreadCount(String friendId) async {
    final uid = _uid;
    if (uid == null) return 0;
    try {
      final rows = await _db
          .from('direct_messages')
          .select('id')
          .eq('sender_id', friendId)
          .eq('receiver_id', uid)
          .isFilter('read_at', null);
      return rows.length;
    } catch (_) {
      return 0;
    }
  }

  Future<int> getTotalUnread() async {
    final uid = _uid;
    if (uid == null) return 0;
    try {
      final rows = await _db
          .from('direct_messages')
          .select('id')
          .eq('receiver_id', uid)
          .isFilter('read_at', null);
      return rows.length;
    } catch (_) {
      return 0;
    }
  }

  // ── Write ─────────────────────────────────────────────────────────────────

  Future<void> sendMessage(
    String receiverId,
    String content, {
    ChatMessageType type = ChatMessageType.text,
    Map<String, dynamic>? metadata,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _db.from('direct_messages').insert({
        'sender_id': uid,
        'receiver_id': receiverId,
        'content': content,
        'type': type.name,
        if (metadata != null) 'metadata': metadata,
      });
    } catch (_) {}
  }

  Future<void> sendPoke(String receiverId) =>
      sendMessage(receiverId, 'perguntou o que você está fazendo? 🤔',
          type: ChatMessageType.poke);

  Future<void> sendReaction(String receiverId, String emoji) =>
      sendMessage(receiverId, emoji,
          type: ChatMessageType.reaction, metadata: {'emoji': emoji});

  /// Remove mensagens antigas para não consumir cota do Supabase.
  /// Pokes: expiram em 24 h.  Reações: 15 dias.  Textos: 30 dias.
  Future<void> cleanupOldMessages() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final cutoff24h = DateTime.now().toUtc().subtract(const Duration(hours: 24));
      final cutoff15d = DateTime.now().toUtc().subtract(const Duration(days: 15));
      final cutoff30d = DateTime.now().toUtc().subtract(const Duration(days: 30));

      await _db
          .from('direct_messages')
          .delete()
          .or('sender_id.eq.$uid,receiver_id.eq.$uid')
          .eq('type', 'poke')
          .lt('created_at', cutoff24h.toIso8601String());

      await _db
          .from('direct_messages')
          .delete()
          .or('sender_id.eq.$uid,receiver_id.eq.$uid')
          .eq('type', 'reaction')
          .lt('created_at', cutoff15d.toIso8601String());

      await _db
          .from('direct_messages')
          .delete()
          .or('sender_id.eq.$uid,receiver_id.eq.$uid')
          .eq('type', 'text')
          .lt('created_at', cutoff30d.toIso8601String());
    } catch (_) {}
  }

  Future<void> markAsRead(String friendId) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _db
          .from('direct_messages')
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('sender_id', friendId)
          .eq('receiver_id', uid)
          .isFilter('read_at', null);
    } catch (_) {}
  }

  // ── Realtime ──────────────────────────────────────────────────────────────

  RealtimeChannel subscribeToChat(
      String friendId, void Function() onUpdate) {
    final uid = _uid ?? 'anon';
    final sortedIds = [uid, friendId]..sort();
    return _db
        .channel('dm_${sortedIds[0]}_${sortedIds[1]}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'direct_messages',
          callback: (_) => onUpdate(),
        )
        .subscribe();
  }

  RealtimeChannel subscribeToInbox(void Function() onUpdate) {
    final uid = _uid ?? 'anon';
    return _db
        .channel('inbox_$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'direct_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: uid,
          ),
          callback: (_) => onUpdate(),
        )
        .subscribe();
  }

  void unsubscribe(RealtimeChannel channel) => _db.removeChannel(channel);
}
