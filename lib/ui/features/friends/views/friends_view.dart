import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../data/services/day_history_service.dart';
import '../../../../data/services/supabase_chat_service.dart';
import '../../../../data/services/supabase_status_service.dart';
import '../../../../domain/models/activity.dart';
import '../../../../domain/models/user_profile.dart';
import '../../../../domain/models/vibe.dart';
import '../../../core/responsive/responsive_breakpoints.dart';
import '../../../core/responsive/responsive_content.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/inactive_poke_section.dart';
import '../../../core/widgets/live_photo_card.dart';
import '../../../core/widgets/story_deck_feed.dart';
import '../../../core/widgets/story_viewer.dart';
import '../../activity/views/status_composer_view.dart';
import '../../profile/views/profile_view.dart';
import '../../social/view_models/social_hub_view_model.dart';
import '../../social/views/chat_view.dart';
import '../../social/views/social_hub_view.dart';
import '../../../core/widgets/user_avatar.dart';
import '../view_models/feed_view_model.dart';
import '../../routine/view_models/routine_view_model.dart';
import 'friend_search_view.dart';

class FriendsView extends StatelessWidget {
  const FriendsView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<FeedViewModel>();
    final routineVm = context.watch<RoutineViewModel>();
    final currentUser = routineVm.currentUser.copyWith(streak: routineVm.ownStreak);
    final canSeeFriends = viewModel.canSeeFriends;
    final activeFriends =
        viewModel.friends.where((f) => f.currentActivity != null).toList();
    final allOffline = !viewModel.loading &&
        viewModel.friends.isNotEmpty &&
        activeFriends.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return ResponsiveContent(
              maxWidth: contentMaxWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EntranceFade(
                    index: 0,
                    child: _Header(activeCount: activeFriends.length),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: EntranceFade(
                            index: 1,
                            offsetY: 40,
                            child: !viewModel.loading && viewModel.friends.isEmpty
                                ? const _InviteFriendsEmpty()
                                : allOffline
                                    ? _AllOfflineView(
                                        friends: viewModel.friends,
                                        self: canSeeFriends ? currentUser : null,
                                        onSelfTap: () =>
                                            _openMyStory(context, currentUser),
                                        onChat: (friend) =>
                                            _openChatFromFriends(context, friend),
                                      )
                                    : StoryDeckFeed(
                                        friends: viewModel.loading
                                            ? const []
                                            : viewModel.friends,
                                        self: canSeeFriends ? currentUser : null,
                                        onSelfTap: () =>
                                            _openMyStory(context, currentUser),
                                      ),
                          ),
                        ),
                        if (viewModel.loading)
                          Positioned.fill(
                            child: ColoredBox(
                              color: AppColors.canvas,
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.primary,
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          ),
                        if (!viewModel.loading && viewModel.loadError)
                          Positioned.fill(
                            child: _OfflineOverlay(
                              onRetry: () => viewModel.refresh(),
                            ),
                          ),
                        if (!viewModel.loading && !viewModel.loadError && !canSeeFriends)
                          Positioned.fill(
                            child: _ReciprocityGate(constraints: constraints),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Opens the current user's own story full-screen (same StoryViewer as friends).
void _openMyStory(BuildContext context, UserProfile currentUser) {
  StoryViewer.open(context, stories: [currentUser], initialIndex: 0);
}

/// Opens a chat with [friend] from the friends/stories screen.
void _openChatFromFriends(BuildContext context, UserProfile friend) {
  HapticFeedback.selectionClick();
  SupabaseChatService.instance.markAsRead(friend.id);
  Navigator.of(context).push(PageRouteBuilder(
    transitionDuration: AppMotion.normal,
    reverseTransitionDuration: AppMotion.exit,
    pageBuilder: (_, __, ___) => ChatView(friend: friend),
    transitionsBuilder: (ctx, anim, _, child) {
      if (AppMotion.reduced(ctx)) {
        return FadeTransition(opacity: anim, child: child);
      }
      final c = CurvedAnimation(parent: anim, curve: AppMotion.enterCurve);
      return SlideTransition(
        position:
            Tween(begin: const Offset(1, 0), end: Offset.zero).animate(c),
        child: child,
      );
    },
  ));
}

// ── All-friends-offline layout ────────────────────────────────────────────────

class _AllOfflineView extends StatelessWidget {
  const _AllOfflineView({
    required this.friends,
    required this.self,
    required this.onSelfTap,
    required this.onChat,
  });

  final List<UserProfile> friends;
  final UserProfile? self;
  final VoidCallback onSelfTap;
  final ValueChanged<UserProfile> onChat;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // "Meu story" no topo, separado do conteúdo central
        if (self != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 16),
            child: _SelfBubbleCorner(user: self!, onTap: onSelfTap),
          ),

        // Título + cards centrados no espaço restante
        Expanded(
          child: InactivePokeSection(
            friends: friends,
            onChat: onChat,
          ),
        ),
      ],
    );
  }
}

class _SelfBubbleCorner extends StatelessWidget {
  const _SelfBubbleCorner({required this.user, required this.onTap});
  final UserProfile user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const r = 38.0;
    final hasStory = user.currentActivity != null;
    final emoji = user.currentActivity?.emoji ?? '';

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: r * 2,
                height: r * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.brandGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.5),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: ClipOval(
                    child: UserAvatar(url: user.avatarUrl, size: r * 2 - 6),
                  ),
                ),
              ),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    gradient: AppColors.brandGradient,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.canvas, width: 2),
                  ),
                  child: hasStory
                      ? Text(emoji, style: const TextStyle(fontSize: 11))
                      : const Icon(Icons.add_rounded,
                          size: 13, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          const Text(
            'Meu story',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.activeCount});
  final int activeCount;

  void _openFriendSearch(BuildContext context) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FriendSearchView()),
    );
  }

  void _openSocialHub(BuildContext context) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: AppMotion.normal,
        reverseTransitionDuration: AppMotion.exit,
        pageBuilder: (_, __, ___) => const SocialHubView(),
        transitionsBuilder: (ctx, anim, _, child) {
          if (AppMotion.reduced(ctx)) {
            return FadeTransition(opacity: anim, child: child);
          }
          final curved =
              CurvedAnimation(parent: anim, curve: AppMotion.enterCurve);
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = context.watch<FeedViewModel>().pendingCount;
    final unreadDMs = context.watch<SocialHubViewModel>().unreadMessages;
    final socialBadge = pendingCount + unreadDMs;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (bounds) =>
                    AppColors.brandGradient.createShader(bounds),
                child: const Text(
                  'VibeTime',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -1.2,
                  ),
                ),
              ),
              Text(
                activeCount > 0
                    ? '$activeCount ${activeCount == 1 ? "amigo ativo" : "amigos ativos"} agora'
                    : 'Ninguém ativo no momento',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Row(
            children: [
              _HeaderIcon(
                icon: Icons.search_rounded,
                label: 'Buscar amigos',
                onTap: () => _openFriendSearch(context),
              ),
              const SizedBox(width: 10),
              _SocialHubIcon(
                badge: socialBadge,
                onTap: () => _openSocialHub(context),
              ),
              const SizedBox(width: 10),
              _ProfileIcon(pendingCount: 0),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Tooltip(
        message: label,
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, color: AppColors.textPrimary, size: 20),
        ),
      ),
    );
  }
}

// ── Empty state: nenhum amigo ainda ──────────────────────────────────────────

class _InviteFriendsEmpty extends StatefulWidget {
  const _InviteFriendsEmpty();

  @override
  State<_InviteFriendsEmpty> createState() => _InviteFriendsEmptyState();
}

class _InviteFriendsEmptyState extends State<_InviteFriendsEmpty>
    with TickerProviderStateMixin {
  late final AnimationController _orbit =
      AnimationController(vsync: this, duration: const Duration(seconds: 12))
        ..repeat();
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..repeat(reverse: true);

  static const _shareMessage =
      'Ei, baixa o VibeTime! 👋\n\n'
      'É um app onde você compartilha o que está fazendo agora em tempo real com seus amigos. '
      'Dá pra ver o que cada um está aprontando, mandar cutucadas e conversar na hora. '
      'Me adiciona lá! 😄\n\n'
      '📲 apps.apple.com/app/vibetime';

  Future<void> _shareWhatsApp() async {
    HapticFeedback.mediumImpact();
    final uri = Uri(
      scheme: 'whatsapp',
      host: 'send',
      queryParameters: {'text': _shareMessage},
    );
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('🔴 WhatsApp error: $e');
    }
  }

  void _openSearch() {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FriendSearchView()),
    );
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
        padding: const EdgeInsets.fromLTRB(28, 8, 28, 48),
        child: Column(
          children: [
            // ── Ilustração animada ────────────────────────────────────────
            SizedBox(
              height: 240,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, __) => Container(
                      width: 170 + _pulse.value * 20,
                      height: 170 + _pulse.value * 20,
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
                  AnimatedBuilder(
                    animation: _orbit,
                    builder: (_, __) {
                      final t = _orbit.value * 2 * math.pi;
                      return SizedBox(
                        width: 210,
                        height: 210,
                        child: Stack(
                          alignment: Alignment.center,
                          children: List.generate(3, (i) {
                            final angle = t + (i * 2 * math.pi / 3);
                            final x = math.cos(angle) * 82;
                            final y = math.sin(angle) * 66;
                            final opacity =
                                0.25 + 0.2 * math.sin(angle + math.pi / 2);
                            return Transform.translate(
                              offset: Offset(x, y),
                              child: Opacity(
                                opacity: opacity.clamp(0.1, 0.55),
                                child: Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: AppColors.brandGradient,
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.2),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: const Icon(Icons.person_rounded,
                                      color: Colors.white, size: 20),
                                ),
                              ),
                            );
                          }),
                        ),
                      );
                    },
                  ),
                  BreathingGlow(
                    color: AppColors.primary,
                    minBlur: 18,
                    maxBlur: 40,
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: const BoxDecoration(
                        gradient: AppColors.brandGradient,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.waving_hand_rounded,
                          color: Colors.white, size: 34),
                    ),
                  ),
                ],
              ),
            ),

            // ── Copy ────────────────────────────────────────────────────
            EntranceFade(
              index: 0,
              child: ShaderMask(
                shaderCallback: (b) =>
                    AppColors.brandGradient.createShader(b),
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
            const SizedBox(height: 32),

            // ── Botão WhatsApp / share ───────────────────────────────────
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
                        color:
                            const Color(0xFF25D366).withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_rounded,
                          color: Colors.white, size: 22),
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

            // ── Botão buscar pelo nome ────────────────────────────────────
            EntranceFade(
              index: 3,
              child: PressableScale(
                onTap: _openSearch,
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
                      Icon(Icons.search_rounded,
                          color: AppColors.textSecondary, size: 20),
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

class _OfflineOverlay extends StatelessWidget {
  const _OfflineOverlay({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          color: AppColors.canvas.withValues(alpha: 0.85),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.textTertiary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.wifi_off_rounded,
                        color: AppColors.textTertiary, size: 36),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Sem conexão',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Verifique seu Wi-Fi ou dados móveis\ne tente novamente.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  PressableScale(
                    onTap: onRetry,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: AppColors.brandGradient,
                        borderRadius: BorderRadius.circular(Radii.pill),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.refresh_rounded,
                              color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Tentar novamente',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReciprocityGate extends StatefulWidget {
  const _ReciprocityGate({required this.constraints});
  final BoxConstraints constraints;

  @override
  State<_ReciprocityGate> createState() => _ReciprocityGateState();
}

class _ReciprocityGateState extends State<_ReciprocityGate> {
  Map<RoutinePeriod, Vibe>? _yesterdayPlan;

  @override
  void initState() {
    super.initState();
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    DayHistoryService.instance
        .load(yesterday.weekday)
        .then((plan) {
      if (mounted && plan != null) {
        setState(() => _yesterdayPlan = plan);
      }
    }).catchError((_) {});
  }

  void _openComposer({Map<RoutinePeriod, Vibe>? prefill}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StatusComposerView(prefillDayPlan: prefill),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding =
        isLargeScreen(widget.constraints.maxWidth) ? 48.0 : 32.0;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          color: AppColors.canvas.withValues(alpha: 0.72),
          padding: EdgeInsets.fromLTRB(horizontalPadding, 12, horizontalPadding, 28),
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              EntranceFade(
                index: 0,
                child: BreathingGlow(
                  color: AppColors.primary,
                  minBlur: 24,
                  maxBlur: 48,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_rounded,
                        size: 42, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const EntranceFade(
                index: 1,
                child: Text(
                  'Mostre o seu agora',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.6,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const EntranceFade(
                index: 2,
                child: Text(
                  'O VibeTime é em tempo real. Conte o que você está '
                  'fazendo agora para desbloquear o que seus amigos estão vivendo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              EntranceFade(
                index: 3,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: formMaxWidth),
                  child: _GateButton(onTap: () => _openComposer()),
                ),
              ),
              if (_yesterdayPlan != null) ...[
                const SizedBox(height: 16),
                EntranceFade(
                  index: 4,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: formMaxWidth),
                    child: _RepeatYesterdayCard(
                      plan: _yesterdayPlan!,
                      onTap: () => _openComposer(prefill: _yesterdayPlan),
                    ),
                  ),
                ),
              ],
            ],
          ),
          ),
        ),
      ),
    );
  }
}

class _RepeatYesterdayCard extends StatelessWidget {
  const _RepeatYesterdayCard({required this.plan, required this.onTap});

  final Map<RoutinePeriod, Vibe> plan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final vibes = RoutinePeriod.values
        .where((p) => plan[p] != null)
        .map((p) => plan[p]!)
        .toList();

    return PressableScale(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Repetir o dia de ontem?',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    vibes.map((v) => '${v.emoji} ${v.label}').join('  ·  '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              child: const Text(
                'Usar',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GateButton extends StatelessWidget {
  const _GateButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 19),
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: BorderRadius.circular(Radii.lg),
          boxShadow: [
            BoxShadow(
              color: AppColors.secondary.withValues(alpha: 0.4),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bolt_rounded, color: Colors.white, size: 22),
            SizedBox(width: 8),
            Text(
              'Postar agora',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SocialHubIcon extends StatelessWidget {
  const _SocialHubIcon({required this.badge, required this.onTap});
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              shape: BoxShape.circle,
              border: Border.all(
                color: badge > 0
                    ? AppColors.primary.withValues(alpha: 0.5)
                    : AppColors.border,
              ),
              boxShadow: badge > 0
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              Icons.forum_rounded,
              color: badge > 0 ? AppColors.primaryBright : AppColors.textPrimary,
              size: 20,
            ),
          ),
          if (badge > 0)
            Positioned(
              top: -3,
              right: -3,
              child: Container(
                constraints:
                    const BoxConstraints(minWidth: 18, minHeight: 18),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.canvas, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    badge > 9 ? '9+' : '$badge',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
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

class _ProfileIcon extends StatelessWidget {
  const _ProfileIcon({this.pendingCount = 0});
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    final avatarUrl =
        context.watch<RoutineViewModel>().currentUser.avatarUrl;

    return PressableScale(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ProfileView()),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          UserAvatar(
            url: avatarUrl,
            size: 42,
            borderColor: AppColors.border,
          ),
          if (pendingCount > 0)
            Positioned(
              top: -3,
              right: -3,
              child: Container(
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradient,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.canvas, width: 1.5),
                ),
                child: Center(
                  child: Text(
                    pendingCount > 9 ? '9+' : '$pendingCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
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

// ── My Story detail page ──────────────────────────────────────────────────────

class _MyStoryDetailPage extends StatefulWidget {
  const _MyStoryDetailPage({required this.user});
  final UserProfile user;

  @override
  State<_MyStoryDetailPage> createState() => _MyStoryDetailPageState();
}

class _MyStoryDetailPageState extends State<_MyStoryDetailPage> {
  bool _deleting = false;

  void _editStory(BuildContext context) {
    Navigator.of(context).pop();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const StatusComposerView(initialTab: ComposerTab.now),
      fullscreenDialog: true,
    ));
  }

  Future<void> _deleteStory(BuildContext context) async {
    if (_deleting) return;
    setState(() => _deleting = true);
    HapticFeedback.mediumImpact();

    final activity = widget.user.currentActivity;
    final routineVM = context.read<RoutineViewModel>();
    final nav = Navigator.of(context);

    try {
      if (activity == null) return;
      if (activity.isLive) {
        await SupabaseStatusService.instance.clearStatuses();
        routineVM.clearLiveStatus();
      } else {
        final period = activity.period;
        if (period != null) {
          await SupabaseStatusService.instance.clearPeriod(period);
          routineVM.setPeriodActivity(period, null);
        }
      }
    } finally {
      if (mounted) nav.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final cardWidth = (size.width * 0.9).clamp(300.0, feedCardMaxWidth);
    final cardHeight = (size.height * 0.68).clamp(400.0, 640.0);
    final hasActivity = widget.user.currentActivity != null;
    final isLive = widget.user.currentActivity?.isLive ?? false;
    final accent = widget.user.currentActivity?.color ?? AppColors.primary;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        behavior: HitTestBehavior.opaque,
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: SizedBox(
            height: size.height,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Story card ──────────────────────────────────────────
                  GestureDetector(
                    onTap: () {},
                    child: SizedBox(
                      width: cardWidth,
                      height: cardHeight,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          hasActivity
                              ? LivePhotoCard(user: widget.user, isOwn: true)
                              : _NoStoryCard(
                                  width: cardWidth,
                                  height: cardHeight,
                                  onAdd: () => _editStory(context),
                                ),

                          // Close — top left
                          Positioned(
                            top: 18,
                            left: 18,
                            child: PressableScale(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close_rounded,
                                    color: Colors.white, size: 18),
                              ),
                            ),
                          ),

                          // Top-right: [AO VIVO] [Editar] [Excluir]
                          Positioned(
                            top: 18,
                            right: 18,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isLive) ...[
                                  _OwnLiveBadge(accent: accent),
                                  const SizedBox(width: 6),
                                ],
                                Semantics(
                                  label: 'Editar story',
                                  button: true,
                                  child: PressableScale(
                                    onTap: () => _editStory(context),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(Radii.pill),
                                      child: BackdropFilter(
                                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                        child: Container(
                                          height: 36,
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                          decoration: BoxDecoration(
                                            gradient: AppColors.brandGradient,
                                            borderRadius: BorderRadius.circular(Radii.pill),
                                            boxShadow: [
                                              BoxShadow(
                                                color: AppColors.primary.withValues(alpha: 0.5),
                                                blurRadius: 14,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.edit_rounded,
                                                  color: Colors.white, size: 13),
                                              SizedBox(width: 5),
                                              Text(
                                                'Editar',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (hasActivity) ...[
                                  const SizedBox(width: 6),
                                  Semantics(
                                    label: 'Excluir story',
                                    button: true,
                                    child: PressableScale(
                                      onTap: _deleting ? null : () => _deleteStory(context),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(100),
                                        child: BackdropFilter(
                                          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                          child: Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.45),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: AppColors.danger.withValues(alpha: 0.6),
                                              ),
                                            ),
                                            child: Center(
                                              child: _deleting
                                                  ? SizedBox(
                                                      width: 16,
                                                      height: 16,
                                                      child: CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: AppColors.danger,
                                                      ),
                                                    )
                                                  : Icon(
                                                      Icons.delete_outline_rounded,
                                                      color: AppColors.danger,
                                                      size: 17,
                                                    ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Live badge rendered in _MyStoryDetailPage overlay so edit controls align with it.
class _OwnLiveBadge extends StatelessWidget {
  const _OwnLiveBadge({required this.accent});
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.pill),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(Radii.pill),
            border: Border.all(color: AppColors.live.withValues(alpha: 0.45)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: AppColors.live,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'AO VIVO',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoStoryCard extends StatelessWidget {
  const _NoStoryCard({
    required this.width,
    required this.height,
    required this.onAdd,
  });
  final double width;
  final double height;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.add_rounded,
                color: AppColors.primaryBright, size: 38),
          ),
          const SizedBox(height: 20),
          const Text(
            'Nenhum story ativo',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Compartilhe o que você está\nfazendo agora com seus amigos.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 28),
          PressableScale(
            onTap: onAdd,
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(Radii.pill),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.45),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Postar agora',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
