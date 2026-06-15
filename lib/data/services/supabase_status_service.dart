import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/models/activity.dart';
import '../../domain/models/user_profile.dart';
import '../../domain/models/vibe.dart';
import 'supabase_streak_service.dart';

class SupabaseStatusService {
  SupabaseStatusService._();
  static final instance = SupabaseStatusService._();

  SupabaseClient get _db => Supabase.instance.client;
  String? get _uid => _db.auth.currentUser?.id;

  // ── Postar status agora ────────────────────────────────────────────────────

  Future<void> postNow(
    Vibe vibe,
    RoutinePeriod period, {
    String? photoUrl,
    DateTime? endsAt,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    await _db.from('statuses').upsert({
      'user_id': uid,
      'vibe_emoji': vibe.emoji,
      'vibe_label': vibe.label,
      'vibe_color': vibe.color.toARGB32(),
      'period': period.name,
      'posted_at': DateTime.now().toUtc().toIso8601String(),
      'photo_url': photoUrl,
      if (endsAt != null) 'ends_at': endsAt.toUtc().toIso8601String(),
    }, onConflict: 'user_id');
    SupabaseStreakService.instance.recordActivity(); // fire-and-forget
  }

  // ── Salvar plano do dia ────────────────────────────────────────────────────

  Future<void> saveDayPlan(Map<RoutinePeriod, Vibe?> plan) async {
    final uid = _uid;
    if (uid == null) return;

    final periods = <String, dynamic>{};
    for (final e in plan.entries) {
      if (e.value != null) {
        periods[e.key.name] = {
          'emoji': e.value!.emoji,
          'label': e.value!.label,
          'color': e.value!.color.toARGB32(),
        };
      }
    }

    final today = DateTime.now();
    final dateStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    await _db.from('day_plans').upsert({
      'user_id': uid,
      'plan_date': dateStr,
      'periods': periods,
    }, onConflict: 'user_id,plan_date');
    SupabaseStreakService.instance.recordActivity(); // fire-and-forget
  }

  // ── Carregar plano do dia atual (somente day_plan) ───────────────────────
  // Statuses ao vivo são carregados separadamente via loadLiveStatus().

  Future<Map<RoutinePeriod, Vibe?>> loadTodayData() async {
    final uid = _uid;
    if (uid == null) return {};

    final today = DateTime.now();
    final dateStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final planRow = await _db
        .from('day_plans')
        .select()
        .eq('user_id', uid)
        .eq('plan_date', dateStr)
        .maybeSingle();

    final plan = <RoutinePeriod, Vibe?>{};
    if (planRow == null) return plan;

    final periods = planRow['periods'] as Map<String, dynamic>;
    periods.forEach((key, value) {
      final period = RoutinePeriod.values.firstWhere(
        (p) => p.name == key,
        orElse: () => RoutinePeriod.morning,
      );
      plan[period] = Vibe(
        emoji: value['emoji'] as String,
        label: value['label'] as String,
        color: Color(value['color'] as int),
      );
    });
    return plan;
  }

  // ── Carregar status ao vivo do próprio usuário ───────────────────────────

  Future<Activity?> loadLiveStatus() async {
    final uid = _uid;
    if (uid == null) return null;

    final row = await _db.from('statuses').select().eq('user_id', uid).maybeSingle();
    if (row == null) return null;

    final today = DateTime.now();
    final posted = DateTime.parse(row['posted_at'] as String).toLocal();
    final isToday = posted.year == today.year &&
        posted.month == today.month &&
        posted.day == today.day;
    if (!isToday) return null;

    final endsAt = row['ends_at'] != null
        ? DateTime.parse(row['ends_at'] as String).toLocal()
        : null;
    if (endsAt != null && endsAt.isBefore(today)) return null;

    final period = RoutinePeriod.values.firstWhere(
      (p) => p.name == row['period'],
      orElse: () => currentPeriod(),
    );

    return Activity(
      id: '${uid}_live',
      title: row['vibe_label'] as String,
      emoji: row['vibe_emoji'] as String,
      color: Color(row['vibe_color'] as int),
      period: period,
      date: posted,
      photoUrl: row['photo_url'] as String?,
      isLive: true,
      endsAt: endsAt,
    );
  }

  // ── Limpar dados do dia (plano vazio) ─────────────────────────────────────

  Future<void> clearTodayData() async {
    final uid = _uid;
    if (uid == null) return;
    final today = DateTime.now();
    final dateStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    await Future.wait([
      _db.from('day_plans').delete().eq('user_id', uid).eq('plan_date', dateStr),
      _db.from('statuses').delete().eq('user_id', uid),
    ]);
  }

  // ── Carregar plano de ontem (para sugestão) ──────────────────────────────

  Future<Map<RoutinePeriod, Vibe?>> loadYesterdayPlan() async {
    final uid = _uid;
    if (uid == null) return {};

    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final dateStr =
        '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

    final row = await _db
        .from('day_plans')
        .select()
        .eq('user_id', uid)
        .eq('plan_date', dateStr)
        .maybeSingle();

    if (row == null) return {};
    final plan = <RoutinePeriod, Vibe?>{};
    final periods = row['periods'] as Map<String, dynamic>;
    periods.forEach((key, value) {
      final period = RoutinePeriod.values
          .firstWhere((p) => p.name == key, orElse: () => RoutinePeriod.morning);
      plan[period] = Vibe(
        emoji: value['emoji'] as String,
        label: value['label'] as String,
        color: Color(value['color'] as int),
      );
    });
    return plan;
  }

  // ── Limpar planos antigos (mantém hoje + ontem) ───────────────────────────
  // Roda ao virar o dia: deleta planos de antes de ontem.

  Future<void> cleanupOldPlans() async {
    final uid = _uid;
    if (uid == null) return;
    final cutoff = DateTime.now().subtract(const Duration(days: 1));
    final cutoffStr =
        '${cutoff.year}-${cutoff.month.toString().padLeft(2, '0')}-${cutoff.day.toString().padLeft(2, '0')}';
    await _db
        .from('day_plans')
        .delete()
        .eq('user_id', uid)
        .lt('plan_date', cutoffStr);
  }

  // ── Limpar status ao vivo ─────────────────────────────────────────────────

  Future<void> clearStatuses() async {
    final uid = _uid;
    if (uid == null) return;
    await _db.from('statuses').delete().eq('user_id', uid);
  }

  /// Removes a single period from today's day_plan in Supabase.
  Future<void> clearPeriod(RoutinePeriod period) async {
    final uid = _uid;
    if (uid == null) return;
    final today = DateTime.now();
    final dateStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    try {
      await _db.rpc('remove_day_plan_period', params: {
        'p_user_id': uid,
        'p_plan_date': dateStr,
        'p_period': period.name,
      });
    } catch (_) {
      // Fallback: load → modify → save
      final plan = await loadTodayData();
      plan.remove(period);
      await saveDayPlan(plan);
    }
  }

  // ── Verificar se tem atividade no período atual ───────────────────────────

  Future<bool> hasPostedToday() async {
    final uid = _uid;
    if (uid == null) return false;

    final today = DateTime.now();
    final dateStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final currentPer = currentPeriod().name;

    final results = await Future.wait([
      _db
          .from('day_plans')
          .select('periods')
          .eq('user_id', uid)
          .eq('plan_date', dateStr)
          .maybeSingle(),
      _db
          .from('statuses')
          .select()
          .eq('user_id', uid)
          .maybeSingle(),
    ]);

    // day_plans tem o período atual?
    final planRow = results[0];
    if (planRow != null) {
      final periods = (planRow['periods'] as Map<String, dynamic>?) ?? {};
      if (periods.containsKey(currentPer)) return true;
    }

    // statuses tem uma postagem de hoje para o período atual (e não expirou)?
    final statusRow = results[1];
    if (statusRow != null) {
      final posted = DateTime.parse(statusRow['posted_at'] as String).toLocal();
      final isToday = posted.year == today.year &&
          posted.month == today.month &&
          posted.day == today.day;
      final endsAt = statusRow['ends_at'] != null
          ? DateTime.parse(statusRow['ends_at'] as String).toLocal()
          : null;
      final isActive = endsAt == null || endsAt.isAfter(DateTime.now());
      if (isToday && statusRow['period'] == currentPer && isActive) return true;
    }

    return false;
  }

  // ── Feed de amigos ────────────────────────────────────────────────────────

  Future<List<UserProfile>> getFeed() async {
    final uid = _uid;
    if (uid == null) return [];

    // Busca amizades aceitas
    final friendships = await _db
        .from('friendships')
        .select('requester_id, addressee_id')
        .or('requester_id.eq.$uid,addressee_id.eq.$uid')
        .eq('status', 'accepted');

    final friendIds = <String>{};
    for (final f in friendships) {
      final rid = f['requester_id'] as String;
      final aid = f['addressee_id'] as String;
      if (rid != uid) friendIds.add(rid);
      if (aid != uid) friendIds.add(aid);
    }

    if (friendIds.isEmpty) return [];

    final today = DateTime.now();
    final dateStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    // Busca dados em paralelo
    final ids = friendIds.toList();
    final results = await Future.wait<dynamic>([
      _db.from('profiles').select().inFilter('id', ids),
      _db.from('statuses').select().inFilter('user_id', ids),
      _db.from('day_plans').select().inFilter('user_id', ids).eq('plan_date', dateStr),
      SupabaseStreakService.instance.getStreaks(ids),
    ]);

    final profiles = results[0] as List;
    final statuses = results[1] as List;
    final dayPlans = results[2] as List;
    final streakMap = results[3] as Map<String, int>;

    final statusMap = {for (final s in statuses) s['user_id'] as String: s};
    final planMap = {for (final p in dayPlans) p['user_id'] as String: p};

    return profiles.map<UserProfile>((profile) {
      final id = profile['id'] as String;
      final status = statusMap[id];
      final plan = planMap[id];

      final activities = <Activity>[];

      // Status ao vivo
      if (status != null) {
        final postedAt = DateTime.parse(status['posted_at']).toLocal();
        final isToday = postedAt.year == today.year &&
            postedAt.month == today.month &&
            postedAt.day == today.day;

        if (isToday) {
          final endsAt = status['ends_at'] != null
              ? DateTime.parse(status['ends_at'] as String).toLocal()
              : null;
          // Skip expired statuses — they'll be cleaned up on next cleanup call
          if (endsAt == null || endsAt.isAfter(DateTime.now())) {
            final period = RoutinePeriod.values.firstWhere(
              (p) => p.name == status['period'],
              orElse: () => currentPeriod(),
            );
            activities.add(Activity(
              id: '${id}_now',
              title: status['vibe_label'],
              emoji: status['vibe_emoji'],
              color: Color(status['vibe_color'] as int),
              period: period,
              date: postedAt,
              photoUrl: status['photo_url'] as String?,
              isLive: true,
              endsAt: endsAt,
            ));
          }
        }
      }

      // Plano do dia
      if (plan != null) {
        final periods = plan['periods'] as Map<String, dynamic>;
        periods.forEach((key, value) {
          final period = RoutinePeriod.values
              .firstWhere((p) => p.name == key, orElse: () => RoutinePeriod.morning);
          activities.add(Activity(
            id: '${id}_$key',
            title: value['label'] as String,
            emoji: value['emoji'] as String,
            color: Color(value['color'] as int),
            period: period,
            date: today,
          ));
        });
      }

      return UserProfile(
        id: id,
        name: profile['name'] as String? ?? '',
        avatarUrl: profile['avatar_url'] as String? ?? '',
        routine: activities,
        streak: streakMap[id] ?? 0,
      );
    }).toList();
  }

  // ── Limpar status expirados ───────────────────────────────────────────────

  Future<void> cleanupExpiredStatuses() async {
    final uid = _uid;
    if (uid == null) return;
    final now = DateTime.now().toUtc().toIso8601String();

    // Fetch expired rows first so we can delete their photos from storage.
    final expired = await _db
        .from('statuses')
        .select('id, photo_url')
        .eq('user_id', uid)
        .not('ends_at', 'is', null)
        .lt('ends_at', now);

    // Delete photos from storage bucket.
    final paths = <String>[];
    for (final row in expired as List) {
      final url = row['photo_url'] as String?;
      if (url == null) continue;
      // URL format: .../storage/v1/object/public/vibe-photos/<path>
      const marker = '/vibe-photos/';
      final idx = url.indexOf(marker);
      if (idx != -1) paths.add(url.substring(idx + marker.length));
    }
    if (paths.isNotEmpty) {
      try {
        await _db.storage.from('vibe-photos').remove(paths);
      } catch (_) {}
    }

    // Now delete the database rows.
    await _db
        .from('statuses')
        .delete()
        .eq('user_id', uid)
        .not('ends_at', 'is', null)
        .lt('ends_at', now);
  }

  // ── Realtime ───────────────────────────────────────────────────────────────

  RealtimeChannel subscribeFeed(void Function() onUpdate) {
    return _db
        .channel('feed_channel')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'statuses',
          callback: (_) => onUpdate(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'day_plans',
          callback: (_) => onUpdate(),
        )
        .subscribe();
  }

  void unsubscribe(RealtimeChannel channel) {
    _db.removeChannel(channel);
  }
}
