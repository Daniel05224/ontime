import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/quick_suggestion.dart';

class SupabaseProfileService {
  SupabaseProfileService._();
  static final instance = SupabaseProfileService._();

  SupabaseClient get _db => Supabase.instance.client;

  /// Garante que o perfil existe (para usuários criados antes do trigger).
  Future<void> ensureProfile() async {
    final user = _db.auth.currentUser;
    if (user == null) return;

    await _db.from('profiles').upsert({
      'id': user.id,
      'name': user.userMetadata?['name'] ?? '',
    }, onConflict: 'id', ignoreDuplicates: true);
  }

  Future<Map<String, dynamic>?> getMyProfile() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return null;
    return await _db
        .from('profiles')
        .select()
        .eq('id', uid)
        .maybeSingle();
  }

  Future<void> updateName(String name) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return;
    await _db.from('profiles').update({'name': name}).eq('id', uid);
    await _db.auth.updateUser(UserAttributes(data: {'name': name}));
  }

  Future<List<QuickSuggestion>> loadCustomVibes() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return [];
    try {
      final row = await _db
          .from('profiles')
          .select('custom_vibes')
          .eq('id', uid)
          .maybeSingle();
      if (row == null) return [];
      final list = (row['custom_vibes'] as List<dynamic>?) ?? [];
      return list
          .map((e) => QuickSuggestion(
                title: e['label'] as String,
                emoji: e['emoji'] as String,
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveCustomVibes(List<QuickSuggestion> vibes) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return;
    final data = vibes.map((v) => {'emoji': v.emoji, 'label': v.title}).toList();
    await _db.from('profiles').update({'custom_vibes': data}).eq('id', uid);
  }

  Future<String?> loadAvatarUrl() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return null;
    final row = await _db
        .from('profiles')
        .select('avatar_url')
        .eq('id', uid)
        .maybeSingle();
    return row?['avatar_url'] as String?;
  }

  Future<String?> uploadAvatar(Uint8List bytes, String extension) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return null;
    final path = '$uid/avatar.$extension';
    await _db.storage.from('avatars').uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
    );
    final url = _db.storage.from('avatars').getPublicUrl(path);
    await _db.from('profiles').update({'avatar_url': url}).eq('id', uid);
    return url;
  }

  Future<String?> uploadVibePhoto(Uint8List bytes, String extension) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return null;
    final name = '${DateTime.now().millisecondsSinceEpoch}.$extension';
    final path = '$uid/$name';
    await _db.storage.from('vibe-photos').uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(upsert: false, contentType: 'image/jpeg'),
    );
    return _db.storage.from('vibe-photos').getPublicUrl(path);
  }
}
