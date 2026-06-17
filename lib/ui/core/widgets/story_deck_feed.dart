import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/models/user_profile.dart';
import '../../features/social/views/social_hub_view.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import 'live_photo_card.dart';
import 'story_viewer.dart';
import 'user_avatar.dart';

/// "Agora" home layout: a row of animated, floating story circles at the top
/// and a horizontally swipeable deck of [LivePhotoCard]s below. Swiping the
/// deck moves between friends' posts; tapping a card (or a story circle) opens
/// the full-screen [StoryViewer].
class StoryDeckFeed extends StatefulWidget {
  const StoryDeckFeed({
    super.key,
    required this.friends,
    this.self,
    this.onSelfTap,
  });

  final List<UserProfile> friends;
  final UserProfile? self;
  final VoidCallback? onSelfTap;

  @override
  State<StoryDeckFeed> createState() => _StoryDeckFeedState();
}

class _StoryDeckFeedState extends State<StoryDeckFeed>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;
  double _t = 0;

  late final PageController _deck =
      PageController(viewportFraction: 0.96);

  List<UserProfile> _live = const [];
  List<UserProfile> _planned = const [];
  List<UserProfile> _offline = const [];

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )
      ..addListener(() => setState(() => _t = _ticker.value * math.pi * 6))
      ..repeat();
    _partition();
  }

  @override
  void didUpdateWidget(StoryDeckFeed old) {
    super.didUpdateWidget(old);
    if (old.friends != widget.friends) _partition();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _deck.dispose();
    super.dispose();
  }

  void _partition() {
    final live = <UserProfile>[];
    final planned = <UserProfile>[];
    final offline = <UserProfile>[];
    for (final f in widget.friends) {
      final act = f.currentActivity;
      if (act == null) {
        offline.add(f);
      } else if (act.isLive) {
        live.add(f);
      } else {
        planned.add(f);
      }
    }
    live.sort(
        (a, b) => b.currentActivity!.date.compareTo(a.currentActivity!.date));
    planned.sort(
        (a, b) => b.currentActivity!.date.compareTo(a.currentActivity!.date));
    offline.sort((a, b) => a.name.compareTo(b.name));
    _live = live;
    _planned = planned;
    _offline = offline;
  }

  List<UserProfile> get _allActive => [..._live, ..._planned];

  void _openStory(UserProfile friend) {
    HapticFeedback.selectionClick();
    final all = _allActive;
    final idx = all.indexWhere((u) => u.id == friend.id);
    StoryViewer.open(
      context,
      stories: all.isEmpty ? [friend] : all,
      initialIndex: idx < 0 ? 0 : idx,
    );
  }

  void _openSocialHub() {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(PageRouteBuilder(
      transitionDuration: AppMotion.normal,
      reverseTransitionDuration: AppMotion.exit,
      pageBuilder: (_, __, ___) => const SocialHubView(),
      transitionsBuilder: (ctx, anim, _, child) {
        if (AppMotion.reduced(ctx)) {
          return FadeTransition(opacity: anim, child: child);
        }
        final c = CurvedAnimation(parent: anim, curve: AppMotion.enterCurve);
        return SlideTransition(
          position:
              Tween(begin: const Offset(0, 1), end: Offset.zero).animate(c),
          child: child,
        );
      },
    ));
  }

  @override
  Widget build(BuildContext context) {
    final active = _allActive;
    final hasAnyone = widget.friends.isNotEmpty || widget.self != null;

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: CustomPaint(painter: _AuraPainter(t: _t * 0.05)),
        ),
        if (!hasAnyone)
          const Center(child: _EmptyDeckHint())
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Stories row ───────────────────────────────────────────────
              const SizedBox(height: 6),
              _StoriesRow(
                self: widget.self,
                active: active,
                offline: _offline,
                t: _t,
                onSelfTap: widget.onSelfTap,
                onStory: _openStory,
                onOffline: _openSocialHub,
              ),
              const SizedBox(height: 8),

              // ── Card deck ─────────────────────────────────────────────────
              Expanded(
                child: active.isEmpty
                    ? const Center(child: _EmptyDeckHint())
                    : PageView.builder(
                        controller: _deck,
                        itemCount: active.length,
                        padEnds: true,
                        itemBuilder: (context, i) {
                          final friend = active[i];
                          return Padding(
                            padding:
                                const EdgeInsets.fromLTRB(3, 0, 3, 12),
                            child: GestureDetector(
                              onTap: () => _openStory(friend),
                              child: LivePhotoCard(user: friend),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
      ],
    );
  }
}

// ── Stories row ───────────────────────────────────────────────────────────────

class _StoriesRow extends StatelessWidget {
  const _StoriesRow({
    required this.self,
    required this.active,
    required this.offline,
    required this.t,
    required this.onSelfTap,
    required this.onStory,
    required this.onOffline,
  });

  final UserProfile? self;
  final List<UserProfile> active;
  final List<UserProfile> offline;
  final double t;
  final VoidCallback? onSelfTap;
  final void Function(UserProfile) onStory;
  final VoidCallback onOffline;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          if (self != null)
            _StoryCircle(
              user: self!,
              t: t,
              phaseIndex: 0,
              isSelf: true,
              isOffline: false,
              label: 'Meu story',
              onTap: () {
                HapticFeedback.selectionClick();
                onSelfTap?.call();
              },
            ),
          for (var i = 0; i < active.length; i++)
            _StoryCircle(
              user: active[i],
              t: t,
              phaseIndex: i + 1,
              isSelf: false,
              isOffline: false,
              label: active[i].name.split(' ').first,
              onTap: () => onStory(active[i]),
            ),
          for (var i = 0; i < offline.length; i++)
            _StoryCircle(
              user: offline[i],
              t: t,
              phaseIndex: i + 50,
              isSelf: false,
              isOffline: true,
              label: offline[i].name.split(' ').first,
              onTap: onOffline,
            ),
        ],
      ),
    );
  }
}

class _StoryCircle extends StatelessWidget {
  const _StoryCircle({
    required this.user,
    required this.t,
    required this.phaseIndex,
    required this.isSelf,
    required this.isOffline,
    required this.label,
    required this.onTap,
  });

  final UserProfile user;
  final double t;
  final int phaseIndex;
  final bool isSelf;
  final bool isOffline;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final act = user.currentActivity;
    final color =
        isOffline ? AppColors.textTertiary : (act?.color ?? AppColors.primary);

    // Each circle drifts on its own phase so the row feels alive.
    final p1 = phaseIndex * 1.618;
    final p2 = phaseIndex * 2.414 + 0.9;
    final maxDrift = isOffline ? 4.0 : 7.0;
    final dx = math.sin(t * 0.38 + p1) * maxDrift;
    final dy = math.cos(t * 0.29 + p2) * maxDrift;

    const ringSize = 70.0;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 84,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.translate(
              offset: Offset(dx, dy),
              child: _AvatarRing(
                url: user.avatarUrl,
                size: ringSize,
                color: color,
                isLive: !isOffline && (act?.isLive ?? false),
                emoji: isOffline ? null : act?.emoji,
                isSelf: isSelf,
                hasStory: act != null,
                isOffline: isOffline,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isOffline
                    ? AppColors.textTertiary
                    : AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarRing extends StatelessWidget {
  const _AvatarRing({
    required this.url,
    required this.size,
    required this.color,
    required this.isLive,
    required this.emoji,
    required this.isSelf,
    required this.hasStory,
    required this.isOffline,
  });

  final String url;
  final double size;
  final Color color;
  final bool isLive;
  final String? emoji;
  final bool isSelf;
  final bool hasStory;
  final bool isOffline;

  @override
  Widget build(BuildContext context) {
    const ringWidth = 3.0;
    final gradient = isOffline
        ? const LinearGradient(
            colors: [AppColors.borderStrong, AppColors.borderStrong])
        : AppColors.duotone(color);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: gradient,
            boxShadow: isOffline
                ? null
                : [
                    BoxShadow(
                      color: color.withValues(alpha: 0.45),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(ringWidth),
            child: ClipOval(
              child: isOffline
                  ? ColorFiltered(
                      colorFilter: const ColorFilter.matrix(<double>[
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0, 0, 0, 0.50, 0,
                      ]),
                      child: UserAvatar(url: url, size: size - ringWidth * 2),
                    )
                  : UserAvatar(url: url, size: size - ringWidth * 2),
            ),
          ),
        ),

        // Live dot
        if (isLive)
          Positioned(
            top: size * 0.02,
            right: size * 0.02,
            child: Container(
              width: size * 0.18,
              height: size * 0.18,
              decoration: BoxDecoration(
                color: AppColors.live,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.canvas, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.live.withValues(alpha: 0.8),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),

        // Vibe emoji badge (active friends)
        if (emoji != null && emoji!.isNotEmpty && !isOffline)
          Positioned(
            bottom: -size * 0.04,
            right: -size * 0.04,
            child: Container(
              width: size * 0.34,
              height: size * 0.34,
              decoration: BoxDecoration(
                color: AppColors.canvas,
                shape: BoxShape.circle,
                border:
                    Border.all(color: color.withValues(alpha: 0.7), width: 1.5),
              ),
              child: Center(
                child: Text(
                  emoji!,
                  style: TextStyle(fontSize: size * 0.16),
                ),
              ),
            ),
          ),

        // Self "+" / emoji badge
        if (isSelf)
          Positioned(
            right: -size * 0.04,
            bottom: -size * 0.04,
            child: Container(
              width: size * 0.34,
              height: size * 0.34,
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.canvas, width: 2),
              ),
              child: Center(
                child: hasStory
                    ? Text(emoji ?? '', style: TextStyle(fontSize: size * 0.15))
                    : Icon(Icons.add_rounded,
                        size: size * 0.20, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Aurora background ─────────────────────────────────────────────────────────

class _AuraPainter extends CustomPainter {
  const _AuraPainter({required this.t});
  final double t;

  static const _seeds = [
    (AppColors.primary, 0.28, 0.30, 0.40),
    (AppColors.secondary, 0.74, 0.34, 0.34),
    (AppColors.accent, 0.50, 0.74, 0.46),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < _seeds.length; i++) {
      final (color, bx, by, br) = _seeds[i];
      final phase = i * 2.1;
      final dx = math.sin(t * 0.12 + phase) * size.width * 0.06;
      final dy = math.cos(t * 0.10 + phase) * size.height * 0.05;
      final c = Offset(size.width * bx + dx, size.height * by + dy);
      final radius = size.shortestSide * br;
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0.10),
            color.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: radius))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);
      canvas.drawCircle(c, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_AuraPainter old) => old.t != t;
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyDeckHint extends StatelessWidget {
  const _EmptyDeckHint();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('👀', style: TextStyle(fontSize: 40)),
          SizedBox(height: 12),
          Text(
            'Ninguém postou ainda',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Seja o primeiro a dar o pulso de hoje',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
