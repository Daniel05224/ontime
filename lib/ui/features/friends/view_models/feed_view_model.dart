import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../data/services/demo_mode.dart';
import '../../../../data/services/notification_service.dart';
import '../../../../data/services/supabase_chat_service.dart';
import '../../../../data/services/supabase_friend_service.dart';
import '../../../../data/services/supabase_moderation_service.dart';
import '../../../../data/services/supabase_status_service.dart';
import '../../../../domain/models/user_profile.dart';

class FeedViewModel extends ChangeNotifier {
  FeedViewModel() {
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      switch (data.event) {
        case AuthChangeEvent.signedIn:
          _setup();
        case AuthChangeEvent.signedOut:
          _clear();
        default:
          break;
      }
    });

    if (Supabase.instance.client.auth.currentUser != null) {
      _setup();
    } else {
      _loading = false;
    }
  }

  List<UserProfile> _friends = [];
  List<PendingRequest> _pendingRequests = [];
  final Set<String> _blockedIds = {};
  bool _loading = true;
  bool _initialized = false;
  bool _canSeeFriends = false;
  bool _loadError = false;
  RealtimeChannel? _feedChannel;
  RealtimeChannel? _friendsChannel;
  RealtimeChannel? _inboxChannel;
  late final StreamSubscription<AuthState> _authSub;
  Timer? _expiryTimer;

  List<UserProfile> get friends => DemoMode.instance.isActive
      ? DemoMode.friends
      : _friends.where((f) => !_blockedIds.contains(f.id)).toList();
  List<PendingRequest> get pendingRequests => _pendingRequests;
  int get pendingCount => _pendingRequests.length;
  bool get loading => _loading;
  bool get canSeeFriends => DemoMode.instance.isActive ? true : _canSeeFriends;
  bool get loadError => _loadError;

  Future<void> _setup() async {
    if (DemoMode.instance.isActive) {
      _loading = false;
      _initialized = true;
      notifyListeners();
      return;
    }

    SupabaseChatService.instance.cleanupOldMessages();

    final blocked = await SupabaseModerationService.instance.getBlockedIds();
    _blockedIds.addAll(blocked);

    await Future.wait([_refresh(), _loadPendingRequests()]);

    _feedChannel ??= SupabaseStatusService.instance.subscribeFeed(_refresh);
    _friendsChannel ??= SupabaseFriendService.instance.subscribeFriendships(() {
      _refresh();
      _loadPendingRequests();
    });
    _inboxChannel ??= NotificationService.instance.subscribeToInbox();
  }

  void _clear() {
    _friends = [];
    _pendingRequests = [];
    _blockedIds.clear();
    _canSeeFriends = false;
    _loading = false;
    _initialized = false;
    _loadError = false;
    if (_feedChannel != null) {
      SupabaseStatusService.instance.unsubscribe(_feedChannel!);
      _feedChannel = null;
    }
    if (_friendsChannel != null) {
      SupabaseFriendService.instance.unsubscribe(_friendsChannel!);
      _friendsChannel = null;
    }
    if (_inboxChannel != null) {
      Supabase.instance.client.removeChannel(_inboxChannel!);
      _inboxChannel = null;
    }
    notifyListeners();
  }

  Future<void> _refresh() async {
    // Only show the loading spinner on the very first fetch.
    // Subsequent Realtime-triggered refreshes update silently so the
    // existing list stays visible and new stories appear without any flash.
    if (!_initialized) {
      _loading = true;
      _loadError = false;
      notifyListeners();
    }

    try {
      final results = await Future.wait([
        SupabaseStatusService.instance.getFeed(),
        SupabaseStatusService.instance.hasPostedToday(),
      ]).timeout(const Duration(seconds: 10));

      _friends = results[0] as List<UserProfile>;
      _canSeeFriends = results[1] as bool;
      _initialized = true;
      _scheduleExpiryRefresh();
    } catch (_) {
      if (!_initialized) _loadError = true;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void _scheduleExpiryRefresh() {
    _expiryTimer?.cancel();
    DateTime? soonest;
    for (final friend in _friends) {
      final endsAt = friend.currentActivity?.endsAt;
      if (endsAt != null && (soonest == null || endsAt.isBefore(soonest))) {
        soonest = endsAt;
      }
    }
    if (soonest != null) {
      final delay = soonest.difference(DateTime.now());
      if (delay.isNegative || delay.inSeconds < 1) {
        _refresh();
        return;
      }
      _expiryTimer = Timer(delay, () {
        SupabaseStatusService.instance.cleanupExpiredStatuses();
        _refresh();
      });
    }
  }

  /// Schedule a feed refresh when the user's own status expires.
  void scheduleRefreshAt(DateTime at) {
    final delay = at.difference(DateTime.now());
    if (delay.isNegative || delay.inSeconds < 1) return;
    Timer(delay, () {
      SupabaseStatusService.instance.cleanupExpiredStatuses();
      _refresh();
    });
  }

  Future<void> _loadPendingRequests() async {
    try {
      _pendingRequests = await SupabaseFriendService.instance.getPendingRequests();
      notifyListeners();
    } catch (_) {}
  }

  /// Zera o badge imediatamente quando o usuário abre a lista de pedidos.
  /// Os pedidos continuam no Supabase — só o indicador visual some.
  void clearPendingBadge() {
    _pendingRequests = [];
    notifyListeners();
  }

  // ── Friend request actions ─────────────────────────────────────────────────

  Future<void> acceptRequest(String requesterId) async {
    await SupabaseFriendService.instance.acceptRequest(requesterId);
    // Realtime will trigger _refresh + _loadPendingRequests automatically,
    // but remove optimistically for instant feedback.
    _pendingRequests = _pendingRequests.where((r) => r.id != requesterId).toList();
    notifyListeners();
  }

  Future<void> rejectRequest(String requesterId) async {
    await SupabaseFriendService.instance.rejectRequest(requesterId);
    _pendingRequests = _pendingRequests.where((r) => r.id != requesterId).toList();
    notifyListeners();
  }

  Future<void> removeFriend(String userId) async {
    _friends = _friends.where((f) => f.id != userId).toList();
    notifyListeners();
    await SupabaseFriendService.instance.removeFriend(userId);
  }

  Future<void> reportUser(String userId) async {
    await SupabaseModerationService.instance.reportUser(userId);
  }

  Future<void> blockUser(String userId) async {
    _blockedIds.add(userId);
    notifyListeners();
    await SupabaseModerationService.instance.blockUser(userId);
    await SupabaseFriendService.instance.removeFriend(userId);
  }

  // ── Called after the user posts ───────────────────────────────────────────

  Future<void> onPosted() async {
    _canSeeFriends = true;
    notifyListeners();
    await _refresh();
  }

  Future<void> refresh() => _refresh();

  @override
  void dispose() {
    _expiryTimer?.cancel();
    _authSub.cancel();
    if (_feedChannel != null) {
      SupabaseStatusService.instance.unsubscribe(_feedChannel!);
    }
    if (_friendsChannel != null) {
      SupabaseFriendService.instance.unsubscribe(_friendsChannel!);
    }
    if (_inboxChannel != null) {
      Supabase.instance.client.removeChannel(_inboxChannel!);
    }
    super.dispose();
  }
}
