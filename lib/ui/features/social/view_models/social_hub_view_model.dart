import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../data/services/supabase_chat_service.dart';

/// Tracks total unread DM count for the header badge.
/// Subscribes to incoming messages via Supabase Realtime.
class SocialHubViewModel extends ChangeNotifier {
  SocialHubViewModel() {
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
    }
  }

  late final StreamSubscription<AuthState> _authSub;
  RealtimeChannel? _inboxChannel;

  int _unreadMessages = 0;
  bool _hubOpen = false;

  int get unreadMessages => _hubOpen ? 0 : _unreadMessages;

  Future<void> _setup() async {
    _unreadMessages = await SupabaseChatService.instance.getTotalUnread();
    notifyListeners();

    _inboxChannel ??=
        SupabaseChatService.instance.subscribeToInbox(_onNewMessage);
  }

  void _clear() {
    _unreadMessages = 0;
    if (_inboxChannel != null) {
      SupabaseChatService.instance.unsubscribe(_inboxChannel!);
      _inboxChannel = null;
    }
    notifyListeners();
  }

  void _onNewMessage() {
    if (_hubOpen) return;
    _unreadMessages++;
    notifyListeners();
  }

  void onHubOpened() {
    _hubOpen = true;
    _unreadMessages = 0;
    notifyListeners();
  }

  void onHubClosed() {
    _hubOpen = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub.cancel();
    if (_inboxChannel != null) {
      SupabaseChatService.instance.unsubscribe(_inboxChannel!);
    }
    super.dispose();
  }
}
