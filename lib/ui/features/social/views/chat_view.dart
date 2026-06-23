import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../data/services/notification_service.dart';
import '../../../../data/services/supabase_chat_service.dart';
import '../../../../domain/models/chat_message.dart';
import '../../../../domain/models/user_profile.dart';
import '../../../../domain/models/vibe.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../friends/view_models/feed_view_model.dart';

class ChatView extends StatefulWidget {
  const ChatView({super.key, required this.friend});
  final UserProfile friend;

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  List<ChatMessage> _messages = [];
  bool _loading = true;
  bool _sending = false;
  bool _poking = false;
  RealtimeChannel? _channel;

  String get _myId =>
      Supabase.instance.client.auth.currentUser?.id ?? 'me';

  @override
  void initState() {
    super.initState();
    NotificationService.instance.activeChatWithId = widget.friend.id;
    _load();
    _channel = SupabaseChatService.instance.subscribeToChat(
      widget.friend.id,
      _onNewMessage,
    );
  }

  @override
  void dispose() {
    NotificationService.instance.activeChatWithId = null;
    if (_channel != null) {
      SupabaseChatService.instance.unsubscribe(_channel!);
    }
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final vm = context.read<FeedViewModel>();
    // Blocker sees an empty chat — messages from the blocked person are hidden.
    if (vm.isBlocked(widget.friend.id)) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final msgs =
        await SupabaseChatService.instance.getMessages(widget.friend.id);
    if (!mounted) return;
    setState(() {
      _messages = msgs;
      _loading = false;
    });
    _scrollToBottom(jump: true);
    await SupabaseChatService.instance.markAsRead(widget.friend.id);
  }

  void _onNewMessage() async {
    final vm = context.read<FeedViewModel>();
    // Blocked the friend → don't show their new messages.
    if (vm.isBlocked(widget.friend.id)) return;
    final msgs =
        await SupabaseChatService.instance.getMessages(widget.friend.id);
    if (!mounted) return;
    setState(() => _messages = msgs);
    _scrollToBottom();
  }

  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final pos = _scrollController.position.maxScrollExtent;
      if (jump) {
        _scrollController.jumpTo(pos);
      } else {
        _scrollController.animateTo(
          pos,
          duration: AppMotion.normal,
          curve: AppMotion.enterCurve,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _sending) return;

    HapticFeedback.selectionClick();
    _textController.clear();
    setState(() => _sending = true);

    await SupabaseChatService.instance.sendMessage(widget.friend.id, text);

    if (mounted) setState(() => _sending = false);
  }

  Future<void> _poke() async {
    if (_poking) return;
    HapticFeedback.mediumImpact();
    setState(() => _poking = true);

    await SupabaseChatService.instance.sendPoke(widget.friend.id);

    await Future.delayed(const Duration(milliseconds: 1800));
    if (mounted) setState(() => _poking = false);
  }

  void _showMoreOptions() {
    HapticFeedback.selectionClick();
    final feedVm = context.read<FeedViewModel>();
    showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _RemoveFriendSheet(
        friend: widget.friend,
        isBlocked: feedVm.isBlocked(widget.friend.id),
      ),
    ).then((action) {
      if (action == null || !mounted) return;
      final name = widget.friend.name.split(' ').first;
      switch (action) {
        case 'remove':
          feedVm.removeFriend(widget.friend.id);
          Navigator.of(context).pop();
        case 'block':
          feedVm.blockUser(widget.friend.id);
          _showModerationSnack(
              'Você bloqueou $name. Posts e novas mensagens ficam ocultos.');
        case 'unblock':
          feedVm.unblockUser(widget.friend.id);
          _load(); // reveal messages that arrived during the block
          _showModerationSnack('Você desbloqueou $name.');
      }
    });
  }

  void _showModerationSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.surfaceHigh,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final friend = widget.friend;
    final bottomPadding = MediaQuery.viewInsetsOf(context).bottom;
    final isBlocked = context.watch<FeedViewModel>().isBlocked(friend.id);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textSecondary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            _ChatAvatar(url: friend.avatarUrl, isActive: friend.currentActivity != null),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (isBlocked)
                    const Text(
                      'bloqueado',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 11,
                      ),
                    )
                  else if (friend.currentActivity != null)
                    Text(
                      friend.currentActivity!.isLive
                          ? '${friend.currentActivity!.emoji} ativo agora'
                          : '${friend.currentActivity!.emoji} ${friend.currentActivity!.period?.label ?? ''}',
                      style: TextStyle(
                        color: friend.currentActivity!.isLive
                            ? AppColors.live
                            : AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  else
                    const Text(
                      'offline',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (!isBlocked) _PokeButton(poking: _poking, onTap: _poke),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded,
                color: AppColors.textSecondary, size: 22),
            onPressed: _showMoreOptions,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : _messages.isEmpty
                    ? _EmptyChat(friend: friend)
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        itemCount: _messages.length,
                        itemBuilder: (context, i) {
                          final msg = _messages[i];
                          final isMine = msg.senderId == _myId;
                          final prev = i > 0 ? _messages[i - 1] : null;
                          final showDateSeparator = prev == null ||
                              !_isSameDay(msg.createdAt, prev.createdAt);
                          return Column(
                            children: [
                              if (showDateSeparator)
                                _DateSeparator(date: msg.createdAt),
                              EntranceFade(
                                index: 0,
                                offsetY: 8,
                                duration: AppMotion.fast,
                                child: _buildMessage(msg, isMine),
                              ),
                            ],
                          );
                        },
                      ),
          ),
          if (isBlocked)
            _BlockedBar(
              friendName: friend.name.split(' ').first,
              bottomPadding: bottomPadding,
            )
          else
            _InputBar(
              controller: _textController,
              sending: _sending,
              onSend: _send,
              extraPadding: bottomPadding,
            ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _buildMessage(ChatMessage msg, bool isMine) {
    return switch (msg.type) {
      ChatMessageType.poke => _PokeMessage(
          isMine: isMine,
          friendName: widget.friend.name,
          createdAt: msg.createdAt,
        ),
      ChatMessageType.reaction => _ReactionMessage(
          emoji: msg.metadata?['emoji'] as String? ?? '❤️',
          isMine: isMine,
          createdAt: msg.createdAt,
        ),
      ChatMessageType.text => _TextBubble(message: msg, isMine: isMine),
    };
  }
}

// ── Message widgets ───────────────────────────────────────────────────────────

class _TextBubble extends StatelessWidget {
  const _TextBubble({required this.message, required this.isMine});
  final ChatMessage message;
  final bool isMine;

  String get _time {
    final t = message.createdAt;
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.72,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          decoration: BoxDecoration(
            gradient: isMine ? AppColors.brandGradient : null,
            color: isMine ? null : AppColors.surfaceElevated,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isMine ? 18 : 4),
              bottomRight: Radius.circular(isMine ? 4 : 18),
            ),
            boxShadow: isMine
                ? [
                    BoxShadow(
                      color: AppColors.secondary.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment:
                isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(
                message.content,
                style: TextStyle(
                  color: isMine ? Colors.white : AppColors.textPrimary,
                  fontSize: 15,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _time,
                style: TextStyle(
                  color: isMine
                      ? Colors.white.withValues(alpha: 0.6)
                      : AppColors.textTertiary,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PokeMessage extends StatelessWidget {
  const _PokeMessage({
    required this.isMine,
    required this.friendName,
    required this.createdAt,
  });
  final bool isMine;
  final String friendName;
  final DateTime createdAt;

  String get _time =>
      '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final name = friendName.split(' ').first;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.secondary.withValues(alpha: 0.18),
                  AppColors.primary.withValues(alpha: 0.18),
                ],
              ),
              borderRadius: BorderRadius.circular(Radii.pill),
              border: Border.all(
                color: AppColors.secondary.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🤔', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(
                  isMine
                      ? 'Você perguntou o que $name\nestá fazendo!'
                      : '$name perguntou o que\nvocê está fazendo!',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _time,
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReactionMessage extends StatefulWidget {
  const _ReactionMessage({
    required this.emoji,
    required this.isMine,
    required this.createdAt,
  });
  final String emoji;
  final bool isMine;
  final DateTime createdAt;

  @override
  State<_ReactionMessage> createState() => _ReactionMessageState();
}

class _ReactionMessageState extends State<_ReactionMessage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  )..forward();

  late final Animation<double> _scale = CurvedAnimation(
    parent: _ctrl,
    curve: Curves.elasticOut,
  );

  late final Animation<double> _fade = CurvedAnimation(
    parent: _ctrl,
    curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String get _time =>
      '${widget.createdAt.hour.toString().padLeft(2, '0')}:${widget.createdAt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Align(
        alignment: widget.isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: widget.isMine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(widget.isMine ? 20 : 4),
                      bottomRight: Radius.circular(widget.isMine ? 4 : 20),
                    ),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(widget.emoji, style: const TextStyle(fontSize: 32)),
                      const SizedBox(width: 10),
                      Text(
                        widget.isMine ? 'Você reagiu\nao status' : 'Reagiu ao\nseu status',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _time,
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.date});
  final DateTime date;

  static const _months = [
    'jan', 'fev', 'mar', 'abr', 'mai', 'jun',
    'jul', 'ago', 'set', 'out', 'nov', 'dez',
  ];

  String get _label {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'Hoje';
    if (d == today.subtract(const Duration(days: 1))) return 'Ontem';
    final month = _months[date.month - 1];
    if (date.year == now.year) return '${date.day} de $month';
    return '${date.day} de $month de ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(child: Divider(color: AppColors.border)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              _label,
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const Expanded(child: Divider(color: AppColors.border)),
        ],
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({required this.friend});
  final UserProfile friend;

  @override
  Widget build(BuildContext context) {
    final name = friend.name.split(' ').first;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ChatAvatar(
              url: friend.avatarUrl,
              isActive: friend.currentActivity != null,
              size: 72),
          const SizedBox(height: 16),
          Text(
            name,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Diga oi para $name! 👋',
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Appbar / input widgets ────────────────────────────────────────────────────

class _ChatAvatar extends StatelessWidget {
  const _ChatAvatar({
    required this.url,
    required this.isActive,
    this.size = 36,
  });

  final String url;
  final bool isActive;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surfaceElevated,
            border: Border.all(
              color: isActive
                  ? AppColors.live.withValues(alpha: 0.7)
                  : AppColors.border,
              width: 1.5,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(
                Icons.person_rounded,
                color: AppColors.textTertiary),
          ),
        ),
        if (isActive)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: size * 0.28,
              height: size * 0.28,
              decoration: BoxDecoration(
                color: AppColors.live,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.canvas, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }
}

class _PokeButton extends StatelessWidget {
  const _PokeButton({required this.poking, required this.onTap});
  final bool poking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: poking ? null : onTap,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: poking ? null : AppColors.brandGradient,
          color: poking ? AppColors.surfaceElevated : null,
          borderRadius: BorderRadius.circular(Radii.pill),
          boxShadow: poking
              ? null
              : [
                  BoxShadow(
                    color: AppColors.secondary.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Text(
          poking ? 'Enviado! 🤔' : 'O que faz? 🤔',
          style: TextStyle(
            color: poking ? AppColors.textTertiary : Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.extraPadding,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final double extraPadding;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: EdgeInsets.fromLTRB(
              16, 10, 16, 10 + MediaQuery.paddingOf(context).bottom),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.9),
            border: const Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(Radii.lg),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TextField(
                    controller: controller,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 15),
                    cursorColor: AppColors.primary,
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    decoration: const InputDecoration(
                      hintText: 'Mensagem...',
                      hintStyle: TextStyle(
                          color: AppColors.textTertiary, fontSize: 15),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _SendButton(sending: sending, onTap: onSend),
            ],
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.sending, required this.onTap});
  final bool sending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: sending ? null : onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.secondary.withValues(alpha: 0.4),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: sending
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
      ),
    );
  }
}

// ── Blocked bar ──────────────────────────────────────────────────────────────

class _BlockedBar extends StatelessWidget {
  const _BlockedBar({required this.friendName, required this.bottomPadding});
  final String friendName;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 14, 20, 14 + MediaQuery.paddingOf(context).bottom),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
        color: AppColors.surface,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.block_rounded, size: 15, color: AppColors.textTertiary),
          const SizedBox(width: 8),
          Text(
            'Você bloqueou $friendName · não pode enviar mensagens',
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Remove friend sheet ───────────────────────────────────────────────────────

class _RemoveFriendSheet extends StatefulWidget {
  const _RemoveFriendSheet({required this.friend, this.isBlocked = false});
  final UserProfile friend;
  final bool isBlocked;

  @override
  State<_RemoveFriendSheet> createState() => _RemoveFriendSheetState();
}

class _RemoveFriendSheetState extends State<_RemoveFriendSheet> {
  bool _loading = false;

  Future<void> _confirm() async {
    setState(() => _loading = true);
    HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) Navigator.of(context).pop('remove');
  }

  void _toggleBlock() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(widget.isBlocked ? 'unblock' : 'block');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          UserAvatar(url: widget.friend.avatarUrl, size: 56),
          const SizedBox(height: 10),
          Text(
            widget.friend.name,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (widget.isBlocked) ...[
            const SizedBox(height: 6),
            Text(
              'Bloqueado · você ainda pode conversar',
              style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 20),
          // Bloquear / Desbloquear
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: PressableScale(
              onTap: _toggleBlock,
              child: Container(
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.isBlocked
                          ? Icons.lock_open_rounded
                          : Icons.block_rounded,
                      color: widget.isBlocked
                          ? AppColors.primaryBright
                          : AppColors.textSecondary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.isBlocked ? 'Desbloquear' : 'Bloquear',
                      style: TextStyle(
                        color: widget.isBlocked
                            ? AppColors.primaryBright
                            : AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: PressableScale(
              onTap: _loading ? null : _confirm,
              child: Container(
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF3A1A1A),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: const Color(0xFFFF4444).withValues(alpha: 0.5)),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFFF4444),
                        ),
                      )
                    : const Text(
                        'Remover amigo',
                        style: TextStyle(
                          color: Color(0xFFFF4444),
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: PressableScale(
              onTap: () => Navigator.of(context).pop(false),
              child: Container(
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
