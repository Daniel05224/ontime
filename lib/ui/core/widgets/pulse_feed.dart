import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../domain/models/user_profile.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import '../../features/social/views/social_hub_view.dart';
import 'story_viewer.dart';
import 'user_avatar.dart';

class PulseFeed extends StatefulWidget {
  const PulseFeed({
    super.key,
    required this.friends,
    this.self,
    this.onSelfTap,
  });

  final List<UserProfile> friends;
  final UserProfile? self;
  final VoidCallback? onSelfTap;

  @override
  State<PulseFeed> createState() => _PulseFeedState();
}

class _PulseFeedState extends State<PulseFeed>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;
  double _t = 0;

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
  void didUpdateWidget(PulseFeed old) {
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
    final size = MediaQuery.sizeOf(context);
    final hasOnline = _live.isNotEmpty || _planned.isNotEmpty;
    final hasAnyone = widget.friends.isNotEmpty || widget.self != null;

    // Online cell: ~46% of screen width so ~2 visible at once
    final onlineCellW = size.width * 0.46;
    final onlineCellH = size.height * 0.34;
    final onlineAvatar = onlineCellW * 0.80;

    // Offline cell: smaller
    final offlineCellW = size.width * 0.30;
    final offlineCellH = size.height * 0.20;
    final offlineAvatar = offlineCellW * 0.72;

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: CustomPaint(painter: _AuraPainter(t: _t * 0.05)),
        ),
        if (!hasAnyone)
          const Center(child: _EmptyPulseHint())
        else
          ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              // ── Meu pulso ─────────────────────────────────────────────────
              if (widget.self != null)
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: _SelfBubble(
                    user: widget.self!,
                    t: _t,
                    onTap: widget.onSelfTap,
                  ),
                ),

              // ── Online ────────────────────────────────────────────────────
              if (hasOnline) ...[
                const SizedBox(height: 24),
                _SectionDivider(
                  label: 'Online',
                  count: _allActive.length,
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: onlineCellH,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _allActive.length,
                    itemBuilder: (_, i) => _BubbleCell(
                      friend: _allActive[i],
                      cellWidth: onlineCellW,
                      cellHeight: onlineCellH,
                      avatarSize: onlineAvatar,
                      t: _t,
                      phaseIndex: i,
                      isOffline: false,
                      onTap: () => _openStory(_allActive[i]),
                    ),
                  ),
                ),
              ],

              // ── Offline ───────────────────────────────────────────────────
              if (_offline.isNotEmpty) ...[
                const SizedBox(height: 24),
                _SectionDivider(
                  label: 'Offline',
                  count: _offline.length,
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: offlineCellH,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _offline.length,
                    itemBuilder: (_, i) => _BubbleCell(
                      friend: _offline[i],
                      cellWidth: offlineCellW,
                      cellHeight: offlineCellH,
                      avatarSize: offlineAvatar,
                      t: _t,
                      phaseIndex: i + 50,
                      isOffline: true,
                      onTap: _openSocialHub,
                    ),
                  ),
                ),
              ],
            ],
          ),
      ],
    );
  }
}

// ── Self bubble (top) ────────────────────────────────────────────────────────

class _SelfBubble extends StatelessWidget {
  const _SelfBubble({
    required this.user,
    required this.t,
    this.onTap,
  });

  final UserProfile user;
  final double t;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final act = user.currentActivity;
    final color = act?.color ?? AppColors.primary;
    // subtle float on self bubble
    final dy = math.sin(t * 0.35 + 0.5) * 4.0;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap?.call();
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.translate(
            offset: Offset(0, dy),
            child: _AvatarRing(
              url: user.avatarUrl,
              size: 76,
              color: color,
              isLive: act?.isLive ?? false,
              emoji: act?.emoji,
              ringWidth: 2.5,
              isOffline: false,
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Meu pulso',
                style: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                act != null ? '${act.emoji}  ${act.title}' : 'Toque para atualizar',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Section divider ──────────────────────────────────────────────────────────

class _SectionDivider extends StatelessWidget {
  const _SectionDivider({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 0.5,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              count > 0 ? '$label  $count' : label,
              style: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.8,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 0.5,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Animated bubble cell ──────────────────────────────────────────────────────
// Each cell is a fixed slot; the avatar floats inside with sine drift.

class _BubbleCell extends StatelessWidget {
  const _BubbleCell({
    required this.friend,
    required this.cellWidth,
    required this.cellHeight,
    required this.avatarSize,
    required this.t,
    required this.phaseIndex,
    required this.isOffline,
    required this.onTap,
  });

  final UserProfile friend;
  final double cellWidth;
  final double cellHeight;
  final double avatarSize;
  final double t;
  final int phaseIndex;
  final bool isOffline;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final act = friend.currentActivity;
    final color =
        isOffline ? AppColors.textTertiary : (act?.color ?? AppColors.primary);
    final firstName = friend.name.split(' ').first;

    // Each bubble gets its own phase so they all move differently
    final p1 = phaseIndex * 1.618; // golden ratio phase spread
    final p2 = phaseIndex * 2.414 + 0.9;
    final maxDrift = isOffline ? 6.0 : 10.0;
    final dx = math.sin(t * 0.38 + p1) * maxDrift;
    final dy = math.cos(t * 0.29 + p2) * maxDrift;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: SizedBox(
        width: cellWidth,
        height: cellHeight,
        child: Center(
          child: Transform.translate(
            offset: Offset(dx, dy),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _AvatarRing(
                  url: friend.avatarUrl,
                  size: avatarSize,
                  color: color,
                  isLive: !isOffline && (act?.isLive ?? false),
                  emoji: isOffline ? null : act?.emoji,
                  ringWidth: isOffline ? 2.0 : 3.0,
                  isOffline: isOffline,
                ),
                SizedBox(height: isOffline ? 6 : 10),
                SizedBox(
                  width: cellWidth - 8,
                  child: Text(
                    firstName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isOffline
                          ? AppColors.textTertiary
                          : AppColors.textPrimary,
                      fontSize: isOffline ? 11 : 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (!isOffline && act != null) ...[
                  const SizedBox(height: 2),
                  SizedBox(
                    width: cellWidth - 8,
                    child: Text(
                      act.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 11,
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

// ── Avatar ring ───────────────────────────────────────────────────────────────

class _AvatarRing extends StatelessWidget {
  const _AvatarRing({
    required this.url,
    required this.size,
    required this.color,
    required this.isLive,
    required this.emoji,
    required this.ringWidth,
    this.isOffline = false,
  });

  final String url;
  final double size;
  final Color color;
  final bool isLive;
  final String? emoji;
  final double ringWidth;
  final bool isOffline;

  @override
  Widget build(BuildContext context) {
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
          ),
          child: Padding(
            padding: EdgeInsets.all(ringWidth),
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
        if (isLive)
          Positioned(
            top: size * 0.04,
            right: size * 0.04,
            child: Container(
              width: size * 0.14,
              height: size * 0.14,
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
        if (emoji != null && emoji!.isNotEmpty && !isOffline)
          Positioned(
            bottom: -size * 0.04,
            right: -size * 0.04,
            child: Container(
              width: size * 0.28,
              height: size * 0.28,
              decoration: BoxDecoration(
                color: AppColors.canvas,
                shape: BoxShape.circle,
                border:
                    Border.all(color: color.withValues(alpha: 0.7), width: 1.5),
              ),
              child: Center(
                child: Text(
                  emoji!,
                  style: TextStyle(fontSize: size * 0.14),
                ),
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

class _EmptyPulseHint extends StatelessWidget {
  const _EmptyPulseHint();

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
