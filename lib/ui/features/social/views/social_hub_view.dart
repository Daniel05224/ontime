import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../data/services/supabase_chat_service.dart';
import '../../../../data/services/supabase_friend_service.dart';
import '../../friends/views/friend_search_view.dart';
import '../../../../domain/models/chat_message.dart';
import '../../../../domain/models/user_profile.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/inactive_poke_section.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../friends/view_models/feed_view_model.dart';
import '../view_models/social_hub_view_model.dart';
import 'chat_view.dart';

class SocialHubView extends StatefulWidget {
  const SocialHubView({super.key});

  @override
  State<SocialHubView> createState() => _SocialHubViewState();
}

class _SocialHubViewState extends State<SocialHubView>
    with SingleTickerProviderStateMixin {
  // Tab 0 = Amigos, Tab 1 = Solicitações
  late final TabController _tabs = TabController(
    length: 2,
    vsync: this,
    initialIndex: 0,
  );

  // Referência salva em initState para uso seguro no dispose
  late final SocialHubViewModel _hubVm;

  final Map<String, ChatMessage?> _lastMessages = {};
  final Map<String, int> _unreadCounts = {};
  bool _previewsLoaded = false;

  @override
  void initState() {
    super.initState();
    _hubVm = context.read<SocialHubViewModel>();
    _tabs.addListener(_onTabChange);
    // Adiar para depois do primeiro frame: onHubOpened() chama notifyListeners(),
    // o que causaria "setState during build" se chamado sincronamente em initState().
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _hubVm.onHubOpened();
      _loadPreviews();
    });
  }

  void _onTabChange() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChange);
    _tabs.dispose();
    // Adia o notifyListeners para depois do frame de dispose,
    // evitando "deactivated widget" no FriendsView que escuta o ViewModel.
    Future.microtask(_hubVm.onHubClosed);
    super.dispose();
  }

  Future<void> _loadPreviews() async {
    final friends = context.read<FeedViewModel>().friends;
    if (friends.isEmpty) {
      if (mounted) setState(() => _previewsLoaded = true);
      return;
    }
    final futures = friends.map((f) async {
      final results = await Future.wait([
        SupabaseChatService.instance.getLastMessage(f.id),
        SupabaseChatService.instance.getUnreadCount(f.id),
      ]);
      return (f.id, results[0] as ChatMessage?, results[1] as int);
    });
    final all = await Future.wait(futures);
    if (!mounted) return;
    setState(() {
      for (final (id, msg, count) in all) {
        _lastMessages[id] = msg;
        _unreadCounts[id] = count;
      }
      _previewsLoaded = true;
    });
  }

  void _openChat(UserProfile friend) {
    HapticFeedback.selectionClick();
    setState(() => _unreadCounts[friend.id] = 0);
    SupabaseChatService.instance.markAsRead(friend.id);
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: AppMotion.normal,
        reverseTransitionDuration: AppMotion.exit,
        pageBuilder: (_, __, ___) => ChatView(friend: friend),
        transitionsBuilder: (ctx, anim, _, child) {
          if (AppMotion.reduced(ctx)) {
            return FadeTransition(opacity: anim, child: child);
          }
          final c = CurvedAnimation(parent: anim, curve: AppMotion.enterCurve);
          return SlideTransition(
            position: Tween(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(c),
            child: child,
          );
        },
      ),
    );
  }

  int get _totalUnread => _unreadCounts.values.fold(0, (a, b) => a + b);

  @override
  Widget build(BuildContext context) {
    final feedVm = context.watch<FeedViewModel>();
    final activeCount = feedVm.feedFriends
        .where((f) => f.currentActivity != null)
        .length;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HubHeader(
              totalFriends: feedVm.feedFriends.length,
              activeCount: activeCount,
              unreadMessages: _totalUnread,
              onBack: () => Navigator.of(context).pop(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: _SegmentedTabs(
                selectedIndex: _tabs.index,
                pendingCount: feedVm.pendingCount,
                onSelect: (i) {
                  HapticFeedback.selectionClick();
                  _tabs.animateTo(i);
                },
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _FriendsTab(
                    friends: feedVm.friends,
                    lastMessages: _lastMessages,
                    unreadCounts: _unreadCounts,
                    blockedIds: feedVm.blockedIds,
                    blockedByIds: feedVm.blockedByIds,
                    loading: !_previewsLoaded,
                    onTap: _openChat,
                  ),
                  _RequestsTab(
                    requests: feedVm.pendingRequests,
                    onAccept: feedVm.acceptRequest,
                    onReject: feedVm.rejectRequest,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _HubHeader extends StatelessWidget {
  const _HubHeader({
    required this.totalFriends,
    required this.activeCount,
    required this.unreadMessages,
    required this.onBack,
  });

  final int totalFriends;
  final int activeCount;
  final int unreadMessages;
  final VoidCallback onBack;

  String get _subtitle {
    final parts = <String>[];
    if (activeCount > 0) {
      parts.add(
        '$activeCount ${activeCount == 1 ? 'ativo agora' : 'ativos agora'}',
      );
    }
    if (unreadMessages > 0) {
      parts.add(
        '$unreadMessages ${unreadMessages == 1 ? 'nova mensagem' : 'novas mensagens'}',
      );
    }
    if (parts.isEmpty && totalFriends > 0) {
      return '$totalFriends ${totalFriends == 1 ? 'amigo' : 'amigos'}';
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Título centralizado
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShaderMask(
                shaderCallback: (b) => AppColors.brandGradient.createShader(b),
                child: const Text(
                  'Social',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              if (_subtitle.isNotEmpty)
                Text(
                  _subtitle,
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          // Botão voltar à esquerda — 44×44 touch target
          Align(
            alignment: Alignment.centerLeft,
            child: Semantics(
              button: true,
              label: 'Voltar',
              child: InkResponse(
                onTap: onBack,
                radius: 28,
                child: const SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
          // Espaço espelho à direita para manter título centralizado
          const Align(
            alignment: Alignment.centerRight,
            child: SizedBox(width: 48, height: 48),
          ),
        ],
      ),
    );
  }
}

// ── Segmented tab selector (igual ao composer de vibes) ──────────────────────

class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({
    required this.selectedIndex,
    required this.pendingCount,
    required this.onSelect,
  });

  final int selectedIndex;
  final int pendingCount;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Stack(
        children: [
          // Indicador deslizante com gradiente
          AnimatedAlign(
            duration: AppMotion.normal,
            curve: AppMotion.enterCurve,
            alignment: selectedIndex == 0
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
              ),
            ),
          ),
          // Labels
          Row(
            children: [
              _segment('Amigos', 0, 0),
              _segment('Solicitações', 1, pendingCount),
            ],
          ),
        ],
      ),
    );
  }

  Widget _segment(String label, int index, int badge) {
    final selected = selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelect(index),
        child: Center(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedDefaultTextStyle(
                duration: AppMotion.fast,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.textSecondary,
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
                child: Text(label),
              ),
              if (badge > 0)
                Positioned(
                  top: -6,
                  right: -14,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(
                        alpha: selected ? 0.3 : 0.0,
                      ),
                      gradient: selected ? null : AppColors.brandGradient,
                      borderRadius: BorderRadius.circular(Radii.pill),
                      border: Border.all(
                        color: selected
                            ? Colors.white.withValues(alpha: 0.5)
                            : AppColors.canvas,
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        badge > 9 ? '9+' : '$badge',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shimmer skeleton ──────────────────────────────────────────────────────────

class _Shimmer extends StatefulWidget {
  const _Shimmer({required this.child});
  final Widget child;

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) {
        final t = _ctrl.value;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(-2 + t * 4, 0),
            end: Alignment(-1 + t * 4, 0),
            colors: const [
              AppColors.surfaceHigh,
              Color(0xFF3E3E56),
              AppColors.surfaceHigh,
            ],
          ).createShader(bounds),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow({this.wide = false});
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(
                color: AppColors.surfaceHigh,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 13,
                    width: wide ? 110 : 90,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 11,
                    width: wide ? 160 : 130,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Friends tab ───────────────────────────────────────────────────────────────

class _FriendsTab extends StatelessWidget {
  const _FriendsTab({
    required this.friends,
    required this.lastMessages,
    required this.unreadCounts,
    required this.blockedIds,
    required this.blockedByIds,
    required this.loading,
    required this.onTap,
  });

  final List<UserProfile> friends;
  final Map<String, ChatMessage?> lastMessages;
  final Map<String, int> unreadCounts;
  final Set<String> blockedIds;
  final Set<String> blockedByIds;
  final bool loading;
  final ValueChanged<UserProfile> onTap;

  // True for anyone in either block direction — always shown as offline.
  bool _isAnyBlocked(String id) =>
      blockedIds.contains(id) || blockedByIds.contains(id);

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return _Shimmer(
        child: ListView(
          padding: const EdgeInsets.only(top: 16),
          physics: const NeverScrollableScrollPhysics(),
          children: const [
            _SkeletonRow(wide: true),
            _SkeletonRow(),
            _SkeletonRow(wide: true),
            _SkeletonRow(),
            _SkeletonRow(wide: true),
          ],
        ),
      );
    }

    if (friends.isEmpty) return const _EmptyFriends();

    // Blocked or blocking friends always appear as inactive (hide their activity).
    final active = friends
        .where((f) => f.currentActivity != null && !_isAnyBlocked(f.id))
        .toList();
    final inactive = friends
        .where((f) => f.currentActivity == null || _isAnyBlocked(f.id))
        .toList()
      ..sort((a, b) {
        final ua = unreadCounts[a.id] ?? 0;
        final ub = unreadCounts[b.id] ?? 0;
        if (ua != ub) return ub.compareTo(ua);
        return a.name.compareTo(b.name);
      });

    // Ninguém ativo → mostra a seção de cutucar
    if (active.isEmpty) {
      return InactivePokeSection(
        friends: inactive,
        unreadCounts: unreadCounts,
        onChat: onTap,
      );
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── Ativos agora ────────────────────────────────────────────────────
        if (active.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _SectionLabel(
              label: 'ATIVOS AGORA',
              count: active.length,
              accent: AppColors.live,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => EntranceFade(
                  index: i,
                  offsetY: 16,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ActiveFriendCard(
                      friend: active[i],
                      lastMessage: lastMessages[active[i].id],
                      unreadCount: unreadCounts[active[i].id] ?? 0,
                      onTap: () => onTap(active[i]),
                    ),
                  ),
                ),
                childCount: active.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
        ],

        // ── Todos os amigos ──────────────────────────────────────────────────
        if (inactive.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: _SectionLabel(
              label: active.isEmpty ? 'AMIGOS' : 'OFFLINE',
              count: inactive.length,
              accent: AppColors.textTertiary,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => EntranceFade(
                  index: active.length + i,
                  offsetY: 16,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _FriendRow(
                      friend: inactive[i],
                      lastMessage: _isAnyBlocked(inactive[i].id)
                          ? null
                          : lastMessages[inactive[i].id],
                      unreadCount: _isAnyBlocked(inactive[i].id)
                          ? 0
                          : (unreadCounts[inactive[i].id] ?? 0),
                      onTap: () => onTap(inactive[i]),
                    ),
                  ),
                ),
                childCount: inactive.length,
              ),
            ),
          ),
        ] else
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.label,
    required this.count,
    required this.accent,
  });

  final String label;
  final int count;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: accent.withValues(alpha: 0.7), blurRadius: 6),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
              color: accent == AppColors.textTertiary
                  ? AppColors.textTertiary
                  : accent.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: accent.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Active friend card (glassmorphic) ─────────────────────────────────────────

class _ActiveFriendCard extends StatelessWidget {
  const _ActiveFriendCard({
    required this.friend,
    required this.lastMessage,
    required this.unreadCount,
    required this.onTap,
  });

  final UserProfile friend;
  final ChatMessage? lastMessage;
  final int unreadCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activity = friend.currentActivity!;
    final hasUnread = unreadCount > 0;

    return PressableScale(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.lg),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.live.withValues(alpha: 0.08),
                  AppColors.primary.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(Radii.lg),
              border: Border.all(color: AppColors.live.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: AppColors.live.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                _GlowAvatar(
                  url: friend.avatarUrl,
                  glowColor: AppColors.live,
                  size: 52,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        friend.name,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: hasUnread
                              ? FontWeight.w800
                              : FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            activity.emoji,
                            style: const TextStyle(fontSize: 13),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              activity.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.live,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (lastMessage != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          lastMessage!.previewText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: hasUnread
                                ? AppColors.textSecondary
                                : AppColors.textTertiary,
                            fontSize: 12,
                            fontWeight: hasUnread
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (hasUnread)
                      _UnreadBadge(count: unreadCount)
                    else
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textTertiary,
                        size: 20,
                      ),
                    if (lastMessage != null) ...[
                      const SizedBox(height: 4),
                      _TimeLabel(date: lastMessage!.createdAt),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Inactive friend row ───────────────────────────────────────────────────────

class _FriendRow extends StatelessWidget {
  const _FriendRow({
    required this.friend,
    required this.lastMessage,
    required this.unreadCount,
    required this.onTap,
  });

  final UserProfile friend;
  final ChatMessage? lastMessage;
  final int unreadCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasUnread = unreadCount > 0;

    return PressableScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: hasUnread
              ? AppColors.primary.withValues(alpha: 0.06)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(
            color: hasUnread
                ? AppColors.primary.withValues(alpha: 0.25)
                : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            _StaticAvatar(url: friend.avatarUrl, size: 50),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    friend.name,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: hasUnread ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _PreviewText(lastMessage: lastMessage, hasUnread: hasUnread),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (hasUnread)
                  _UnreadBadge(count: unreadCount)
                else
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textTertiary,
                    size: 20,
                  ),
                if (lastMessage != null) ...[
                  const SizedBox(height: 4),
                  _TimeLabel(date: lastMessage!.createdAt),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewText extends StatelessWidget {
  const _PreviewText({required this.lastMessage, required this.hasUnread});
  final ChatMessage? lastMessage;
  final bool hasUnread;

  @override
  Widget build(BuildContext context) {
    if (lastMessage == null) {
      return const Text(
        'Diga oi · iniciar conversa',
        style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
      );
    }
    return Text(
      lastMessage!.previewText,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: hasUnread ? AppColors.textSecondary : AppColors.textTertiary,
        fontSize: 12,
        fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
      ),
    );
  }
}

// ── Requests tab ──────────────────────────────────────────────────────────────

class _RequestsTab extends StatelessWidget {
  const _RequestsTab({
    required this.requests,
    required this.onAccept,
    required this.onReject,
  });

  final List<PendingRequest> requests;
  final ValueChanged<String> onAccept;
  final ValueChanged<String> onReject;

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) return const _EmptyRequests();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      itemCount: requests.length,
      itemBuilder: (_, i) => EntranceFade(
        index: i,
        offsetY: 16,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _RequestCard(
            request: requests[i],
            onAccept: () {
              HapticFeedback.mediumImpact();
              onAccept(requests[i].id);
            },
            onReject: () {
              HapticFeedback.selectionClick();
              onReject(requests[i].id);
            },
          ),
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.onAccept,
    required this.onReject,
  });

  final PendingRequest request;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.lg),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary.withValues(alpha: 0.1),
                AppColors.secondary.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(Radii.lg),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              _StaticAvatar(url: request.avatarUrl, size: 50),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Quer se conectar com você',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                children: [
                  _ActionBtn(
                    label: 'Aceitar',
                    gradient: AppColors.brandGradient,
                    textColor: Colors.white,
                    onTap: onAccept,
                  ),
                  const SizedBox(height: 6),
                  _ActionBtn(
                    label: 'Recusar',
                    color: AppColors.surfaceElevated,
                    textColor: AppColors.textSecondary,
                    onTap: onReject,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Empty states ──────────────────────────────────────────────────────────────

class _EmptyFriends extends StatefulWidget {
  const _EmptyFriends();

  @override
  State<_EmptyFriends> createState() => _EmptyFriendsState();
}

class _EmptyFriendsState extends State<_EmptyFriends>
    with TickerProviderStateMixin {
  late final AnimationController _orbit = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  )..repeat();
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);

  static const _shareText =
      'Ei, baixa o VibeTime! 👋\n\n'
      'É um app onde você compartilha o que está fazendo agora em tempo real com seus amigos usando as VIBES — '
      'tipo um status ao vivo. Dá pra ver o que cada um está aprontando, mandar cutucadas, '
      'reagir e trocar mensagem na hora. Chega de mandar "oi, o que está fazendo?" Me adicione lá 😄\n\n'
      '📲 Baixe grátis: https://apps.apple.com/app/vibetime';

  Future<void> _shareWhatsApp() async {
    HapticFeedback.mediumImpact();
    await Share.share(_shareText);
  }

  @override
  void dispose() {
    _orbit.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 16, 28, 48),
        child: Column(
          children: [
            // ── Ilustração animada ──────────────────────────────────────────
            SizedBox(
              height: 260,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Orbe de fundo pulsante
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, __) => Container(
                      width: 180 + _pulse.value * 20,
                      height: 180 + _pulse.value * 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.primary.withValues(alpha: 0.18),
                            AppColors.secondary.withValues(alpha: 0.08),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Avatares fantasma em órbita
                  AnimatedBuilder(
                    animation: _orbit,
                    builder: (_, __) {
                      final t = _orbit.value * 2 * math.pi;
                      return SizedBox(
                        width: 220,
                        height: 220,
                        child: Stack(
                          alignment: Alignment.center,
                          children: List.generate(3, (i) {
                            final angle = t + (i * 2 * math.pi / 3);
                            final x = math.cos(angle) * 88;
                            final y = math.sin(angle) * 70;
                            final opacity =
                                0.25 + 0.2 * math.sin(angle + math.pi / 2);
                            return Transform.translate(
                              offset: Offset(x, y),
                              child: Opacity(
                                opacity: opacity.clamp(0.1, 0.55),
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: AppColors.brandGradient,
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.2,
                                      ),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.person_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      );
                    },
                  ),
                  // Avatar central com BreathingGlow
                  BreathingGlow(
                    color: AppColors.primary,
                    minBlur: 18,
                    maxBlur: 40,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        gradient: AppColors.brandGradient,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.waving_hand_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Copy ────────────────────────────────────────────────────────
            EntranceFade(
              index: 0,
              child: ShaderMask(
                shaderCallback: (b) => AppColors.brandGradient.createShader(b),
                child: const Text(
                  'Chame seus amigos!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const EntranceFade(
              index: 1,
              child: Text(
                'O VibeTime é muito melhor com amigos.\nVeja o que eles estão fazendo agora, mande cutucadas e converse em tempo real.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  height: 1.55,
                ),
              ),
            ),
            const SizedBox(height: 36),

            // ── Botão WhatsApp ───────────────────────────────────────────────
            EntranceFade(
              index: 2,
              child: PressableScale(
                onTap: _shareWhatsApp,
                child: Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366),
                    borderRadius: BorderRadius.circular(Radii.lg),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF25D366).withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_rounded, color: Colors.white, size: 22),
                      SizedBox(width: 10),
                      Text(
                        'Convidar pelo WhatsApp',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Buscar pelo nome ──────────────────────────────────────────────
            EntranceFade(
              index: 3,
              child: PressableScale(
                onTap: () {
                  HapticFeedback.selectionClick();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const FriendSearchView()),
                  );
                },
                child: Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(Radii.lg),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_rounded,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Buscar pelo nome',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyRequests extends StatelessWidget {
  const _EmptyRequests();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              gradient: AppColors.violetGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 28,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.people_alt_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Sem solicitações',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Quando alguém quiser\nse conectar com você, aparece aqui.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared micro-widgets ──────────────────────────────────────────────────────

/// Avatar with animated breathing glow — for active friends.
class _GlowAvatar extends StatelessWidget {
  const _GlowAvatar({
    required this.url,
    required this.glowColor,
    required this.size,
  });

  final String url;
  final Color glowColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return BreathingGlow(
      color: glowColor,
      minBlur: 8,
      maxBlur: 22,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: glowColor.withValues(alpha: 0.8), width: 2),
          color: AppColors.surfaceElevated,
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.person_rounded, color: AppColors.textTertiary),
        ),
      ),
    );
  }
}

/// Plain avatar — for offline friends.
class _StaticAvatar extends StatelessWidget {
  const _StaticAvatar({required this.url, required this.size});
  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    return UserAvatar(
      url: url,
      size: size,
      borderColor: AppColors.border,
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(Radii.pill),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        count > 9 ? '9+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _TimeLabel extends StatelessWidget {
  const _TimeLabel({required this.date});
  final DateTime date;

  String get _label {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'agora';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _label,
      style: const TextStyle(color: AppColors.textTertiary, fontSize: 10),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.label,
    required this.textColor,
    required this.onTap,
    this.gradient,
    this.color,
  });

  final String label;
  final Color textColor;
  final VoidCallback onTap;
  final Gradient? gradient;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: gradient,
          color: gradient == null ? color : null,
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
