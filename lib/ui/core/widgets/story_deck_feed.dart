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
    this.onReport,
    this.onBlock,
    this.topPadding = 0,
  });

  final List<UserProfile> friends;
  final UserProfile? self;
  final VoidCallback? onSelfTap;
  final void Function(String userId)? onReport;
  final void Function(String userId)? onBlock;
  final double topPadding;

  @override
  State<StoryDeckFeed> createState() => _StoryDeckFeedState();
}

class _StoryDeckFeedState extends State<StoryDeckFeed>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;
  double _t = 0;
  int _currentIndex = 0;

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
      onReport: widget.onReport,
      onBlock: widget.onBlock,
    );
  }

  void _openCurrentStory({int offset = 0, bool instant = false}) {
    final all = _allActive;
    if (all.isEmpty) return;
    final idx = (_currentIndex + offset).clamp(0, all.length - 1);
    HapticFeedback.selectionClick();
    if (instant) {
      Navigator.of(context).push(PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: AppMotion.exit,
        pageBuilder: (_, __, ___) => StoryViewer(
          stories: all,
          initialIndex: idx,
          onReport: widget.onReport,
          onBlock: widget.onBlock,
        ),
        transitionsBuilder: (_, __, ___, child) => child,
      ));
    } else {
      StoryViewer.open(
        context,
        stories: all,
        initialIndex: idx,
        onReport: widget.onReport,
        onBlock: widget.onBlock,
      );
    }
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
              SizedBox(height: widget.topPadding > 0 ? widget.topPadding : 12),
              _StoriesRow(
                self: widget.self,
                active: active,
                offline: _offline,
                t: _t,
                onSelfTap: widget.onSelfTap,
                onStory: _openStory,
                onOffline: _openSocialHub,
              ),
              const SizedBox(height: 0),

              // ── Card deck ─────────────────────────────────────────────────
              Expanded(
                child: active.isEmpty
                    ? const Center(child: _EmptyDeckHint())
                    : _CardStack(
                        active: active,
                        currentIndex: _currentIndex,
                        onTap: () => _openCurrentStory(),
                        onSwipeLeft: () => _openCurrentStory(
                            offset: active.length > 1 ? 1 : 0,
                            instant: true),
                        onSwipeRight: () => _openCurrentStory(
                            offset: _currentIndex > 0 ? -1 : 0,
                            instant: true),
                        onReport: widget.onReport,
                        onBlock: widget.onBlock,
                      ),
              ),
            ],
          ),
      ],
    );
  }
}

// ── Card stack ────────────────────────────────────────────────────────────────

class _CardStack extends StatefulWidget {
  const _CardStack({
    required this.active,
    required this.currentIndex,
    required this.onTap,
    required this.onSwipeLeft,
    required this.onSwipeRight,
    this.onReport,
    this.onBlock,
  });

  final List<UserProfile> active;
  final int currentIndex;
  final VoidCallback onTap;
  final VoidCallback onSwipeLeft;
  final VoidCallback onSwipeRight;
  final void Function(String userId)? onReport;
  final void Function(String userId)? onBlock;

  @override
  State<_CardStack> createState() => _CardStackState();
}

class _CardStackState extends State<_CardStack>
    with SingleTickerProviderStateMixin {
  double _dragX = 0;
  double _springFrom = 0;
  double _springTo = 0;

  late final AnimationController _spring = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  )..addListener(() => setState(() {}));

  @override
  void dispose() {
    _spring.dispose();
    super.dispose();
  }

  double get _offset {
    if (_spring.isAnimating) {
      final t = Curves.easeOutCubic.transform(_spring.value);
      return _springFrom + (_springTo - _springFrom) * t;
    }
    return _dragX;
  }

  void _animateTo(double target, {VoidCallback? onDone}) {
    _springFrom = _offset;
    _springTo = target;
    _spring.reset();
    _spring.forward().whenCompleteOrCancel(() {
      if (!mounted) return;
      setState(() => _dragX = 0);
      onDone?.call();
    });
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_spring.isAnimating) return;
    setState(() => _dragX += d.primaryDelta ?? 0);
  }

  void _onPanEnd(DragEndDetails d) {
    if (_spring.isAnimating) return;
    final v = d.primaryVelocity ?? 0;
    final w = MediaQuery.sizeOf(context).width;

    if (v < -400 || _dragX < -w * 0.28) {
      _animateTo(-w * 1.4, onDone: widget.onSwipeLeft);
    } else if (v > 400 || _dragX > w * 0.28) {
      _animateTo(w * 1.4, onDone: widget.onSwipeRight);
    } else {
      _animateTo(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stackCount = math.min(3, widget.active.length - widget.currentIndex);
    final screenW = MediaQuery.sizeOf(context).width;
    final offset = _offset;

    // 0..1 progress toward next card (swiping left)
    final progress = (-offset / screenW).clamp(0.0, 1.0);

    // px that each behind card peeks on the right side
    const peekRight = 24.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: offset.abs() < 5 ? widget.onTap : null,
      onHorizontalDragUpdate: _onPanUpdate,
      onHorizontalDragEnd: _onPanEnd,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 4),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Cards atrás — peek pela direita, avançam enquanto o card da frente sai
            for (var o = stackCount - 1; o >= 1; o--)
              Positioned(
                top: 0,
                bottom: 0,
                // At rest: shifted right by peekRight*o (peek visible on right side)
                // As front card slides out: moves toward center (left=0, right=0)
                left: o * peekRight * (1 - progress),
                right: -o * peekRight * (1 - progress),
                child: IgnorePointer(
                  child: Opacity(
                    opacity: (1.0 - o * 0.25) + o * 0.25 * progress,
                    child: Transform.scale(
                      scale: (1.0 - o * 0.04) + o * 0.04 * progress,
                      child: LivePhotoCard(
                          user: widget.active[widget.currentIndex + o]),
                    ),
                  ),
                ),
              ),
            // Card atual — move com o drag e rota levemente
            Positioned.fill(
              child: Transform.translate(
                offset: Offset(offset, 0),
                child: Transform.rotate(
                  angle: offset / screenW * 0.06,
                  child: LivePhotoCard(
                    user: widget.active[widget.currentIndex],
                    onReport: widget.onReport != null
                        ? () => widget.onReport!(
                            widget.active[widget.currentIndex].id)
                        : null,
                    onBlock: widget.onBlock != null
                        ? () => widget.onBlock!(
                            widget.active[widget.currentIndex].id)
                        : null,
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
