import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Top-level handler required by firebase_messaging for background/terminated messages.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // FCM already shows the system notification automatically in background/terminated.
  // Nothing to do here — tap handling happens in onMessageOpenedApp / getInitialMessage.
}

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _local = FlutterLocalNotificationsPlugin();

  /// Set by ChatView when opened — suppresses notifications for that sender.
  String? activeChatWithId;

  /// Called when user taps a message notification.
  void Function(String senderId, String senderName)? onMessageTap;

  /// Called when user taps the "o que está fazendo?" expiry notification.
  VoidCallback? onExpiryTap;

  static const _msgChannelId = 'vibetime_messages';
  static const _msgChannelName = 'Mensagens';
  static const _expiryChannelId = 'vibetime_expiry';
  static const _expiryChannelName = 'Atividade';
  static const _expiryNotifId = 42;

  Future<void> init() async {
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@drawable/ic_notification');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      defaultPresentAlert: true,
      defaultPresentBadge: false, // never let local notifications touch the badge
      defaultPresentSound: true,
    );
    await _local.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: _onLocalTap,
      onDidReceiveBackgroundNotificationResponse: _onLocalTapBackground,
    );

    if (Platform.isAndroid) {
      final androidPlugin = _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _msgChannelId,
          _msgChannelName,
          importance: Importance.high,
          playSound: true,
        ),
      );
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          _expiryChannelId,
          _expiryChannelName,
          importance: Importance.defaultImportance,
        ),
      );
    }

    await _setupFcm();
  }

  // ── FCM setup ─────────────────────────────────────────────────────────────

  Future<void> _setupFcm() async {
    final messaging = FirebaseMessaging.instance;

    // Request permission (iOS shows the system dialog)
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // On iOS the APNs token must be available before FCM token can be fetched.
    // We wait up to ~3s for it; if still missing, onTokenRefresh will save it later.
    if (Platform.isIOS) {
      String? apns;
      for (int i = 0; i < 3 && apns == null; i++) {
        apns = await messaging.getAPNSToken();
        if (apns == null) await Future.delayed(const Duration(seconds: 1));
      }
    }

    // Save token — if auth session isn't restored yet, store for later flush.
    try {
      final token = await messaging.getToken();
      if (token != null) {
        await saveFcmToken(token);
      }
    } catch (_) {
      // APNs not ready yet — onTokenRefresh below will save it when available
    }

    // Refresh token whenever iOS rotates it
    messaging.onTokenRefresh.listen((token) {
      saveFcmToken(token);
    });

    // Foreground: FCM does NOT auto-show a banner — we show a local notification
    FirebaseMessaging.onMessage.listen(_handleFcmForeground);

    // Background tap: app was in background, user tapped notification
    FirebaseMessaging.onMessageOpenedApp.listen(_handleFcmTap);

    // Terminated tap: app was closed, user tapped notification
    final initial = await messaging.getInitialMessage();
    if (initial != null) _handleFcmTap(initial);

    // Clear any badge that FCM may have set during registration/delivery
    if (Platform.isIOS) {
      Future.delayed(const Duration(milliseconds: 800), clearBadge);
    }
  }

  /// Saves the FCM token to the user's profile in Supabase.
  /// Called at init and whenever the token refreshes.
  Future<void> saveFcmToken(String token) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'fcm_token': token}).eq('id', uid);
    } catch (_) {}
  }

  /// Clears all pending/delivered local notifications and resets the iOS badge.
  Future<void> clearBadge() async {
    try {
      await _local.cancelAll();
    } catch (_) {}
    if (Platform.isIOS) {
      try {
        await _local.show(
          id: 0,
          title: null,
          body: null,
          notificationDetails: const NotificationDetails(
            iOS: DarwinNotificationDetails(
              presentAlert: false,
              presentBadge: true,
              presentSound: false,
              badgeNumber: 0,
            ),
          ),
        );
        await _local.cancel(id: 0);
      } catch (_) {}
    }
  }

  Future<void> clearFcmToken() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'fcm_token': null}).eq('id', uid);
    } catch (_) {}
  }

  /// Call this when the user signs in. Waits for APNs (iOS) then saves the
  /// FCM token. Reliable even when called before _setupFcm completes.
  Future<void> ensureFcmToken() async {
    final messaging = FirebaseMessaging.instance;

    // requestPermission triggers APNs registration on iOS — must happen first.
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    if (Platform.isIOS) {
      String? apns;
      for (int i = 0; i < 10 && apns == null; i++) {
        apns = await messaging.getAPNSToken();
        if (apns == null) await Future.delayed(const Duration(seconds: 1));
      }
      if (apns == null) return;
    }
    try {
      final token = await messaging.getToken();
      if (token != null) await saveFcmToken(token);
    } catch (_) {}
  }

  void _handleFcmForeground(RemoteMessage message) {
    final data = message.data;
    final senderId = data['sender_id'] as String? ?? '';
    final senderName = data['sender_name'] as String? ?? '';
    final body = data['body'] as String? ?? message.notification?.body ?? '';
    showMessage(senderId: senderId, senderName: senderName, body: body);
  }

  void _handleFcmTap(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] as String?;
    if (type == 'message') {
      final senderId = data['sender_id'] as String? ?? '';
      final senderName = data['sender_name'] as String? ?? '';
      onMessageTap?.call(senderId, senderName);
    }
  }

  // ── Message notification ──────────────────────────────────────────────────

  /// Shows a local notification for an incoming chat message (foreground only).
  /// Suppressed if the user already has that chat open.
  Future<void> showMessage({
    required String senderId,
    required String senderName,
    required String body,
  }) async {
    if (activeChatWithId == senderId) return;

    final id = senderId.hashCode.abs() % 100000;
    await _local.show(
      id: id,
      title: senderName,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _msgChannelId,
          _msgChannelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: false,
          presentSound: true,
        ),
      ),
      payload: jsonEncode({
        'type': 'message',
        'sender_id': senderId,
        'sender_name': senderName,
      }),
    );
  }

  // ── Expiry notification ───────────────────────────────────────────────────

  Future<void> scheduleExpiry(DateTime expiresAt) async {
    await cancelExpiry();

    final scheduledAt = tz.TZDateTime.from(expiresAt, tz.local);
    if (!scheduledAt.isAfter(tz.TZDateTime.now(tz.local))) return;

    await _local.zonedSchedule(
      id: _expiryNotifId,
      title: 'O que você está fazendo? ⚡',
      body: 'Sua atividade acabou. Conta pra galera o que vem por aí!',
      scheduledDate: scheduledAt,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _expiryChannelId,
          _expiryChannelName,
          importance: Importance.defaultImportance,
        ),
        iOS: DarwinNotificationDetails(presentBadge: false),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: jsonEncode({'type': 'expiry'}),
    );
  }

  Future<void> cancelExpiry() async {
    await _local.cancel(id: _expiryNotifId);
  }

  // ── Inbox subscription (Realtime — foreground only) ───────────────────────

  RealtimeChannel subscribeToInbox() {
    final uid = Supabase.instance.client.auth.currentUser?.id ?? 'anon';
    return Supabase.instance.client
        .channel('notif_inbox_$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'direct_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: uid,
          ),
          callback: (payload) => _handleIncomingMessage(payload.newRecord),
        )
        .subscribe();
  }

  Future<void> _handleIncomingMessage(Map<String, dynamic> record) async {
    final senderId = record['sender_id'] as String? ?? '';
    final type = record['type'] as String? ?? 'text';
    final content = record['content'] as String? ?? '';

    String senderName = 'Alguém';
    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('name')
          .eq('id', senderId)
          .maybeSingle();
      if (profile != null) {
        final fullName = profile['name'] as String? ?? '';
        senderName = fullName.split(' ').first;
      }
    } catch (_) {}

    final body = switch (type) {
      'poke' => 'cutucou você 👋',
      'reaction' => 'reagiu: $content',
      _ => content,
    };

    await showMessage(
      senderId: senderId,
      senderName: senderName,
      body: body,
    );
  }

  // ── Local notification tap handling ──────────────────────────────────────

  void _onLocalTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final type = data['type'] as String?;
      if (type == 'message') {
        final senderId = data['sender_id'] as String? ?? '';
        final senderName = data['sender_name'] as String? ?? '';
        onMessageTap?.call(senderId, senderName);
      } else if (type == 'expiry') {
        onExpiryTap?.call();
      }
    } catch (_) {}
  }
}

@pragma('vm:entry-point')
void _onLocalTapBackground(NotificationResponse response) {
  // Handled on next foreground resume.
}
