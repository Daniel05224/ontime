import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/services/supabase_chat_service.dart';
import '../../../data/services/supabase_reaction_service.dart';
import '../../../domain/models/user_profile.dart';
import '../../../domain/models/vibe.dart';
import '../../features/social/views/chat_view.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import 'user_avatar.dart';

/// Quick emoji palette shown in the reaction picker.
const _kQuickReactions = ['🔥', '❤️', '😂', '😮', '😍', '💀'];

/// Full-bleed "live" photo card — the centerpiece of the feed deck.
/// The Vibe (emoji + label + color) is the visual hero of every card.
class LivePhotoCard extends StatefulWidget {
  const LivePhotoCard({
    super.key,
    required this.user,
    this.isOwn = false,
    this.hideActions = false,
    this.onReport,
    this.onBlock,
  });
  final UserProfile user;
  final bool isOwn;
  final bool hideActions;
  final VoidCallback? onReport;
  final VoidCallback? onBlock;

  @override
  State<LivePhotoCard> createState() => _LivePhotoCardState();
}

class _LivePhotoCardState extends State<LivePhotoCard>
    with SingleTickerProviderStateMixin {

  Map<String, int> _counts = {};
  String? _myEmoji;
  bool _busy = false;
  bool _showPicker = false;
  bool _poked = false;

  // Reaction button animation
  String? _animEmoji;
  late final AnimationController _reactCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  late final Animation<double> _reactScale = CurvedAnimation(
    parent: _reactCtrl,
    curve: Curves.elasticOut,
  );

  // Reaction key: period + date.
  String? get _period => widget.user.currentActivity?.period?.name;
  String get _planDate {
    final d = widget.user.currentActivity?.date ?? DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _loadReactions();
  }

  @override
  void didUpdateWidget(LivePhotoCard old) {
    super.didUpdateWidget(old);
    if (old.user.id != widget.user.id) _loadReactions();
  }

  @override
  void dispose() {
    _reactCtrl.dispose();
    super.dispose();
  }

  void _showModerationSheet(BuildContext context) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ModerationSheet(
        userName: widget.user.name.split(' ').first,
        onReport: widget.onReport,
        onBlock: widget.onBlock,
      ),
    );
  }

  Future<void> _poke() async {
    if (_poked) return;
    HapticFeedback.mediumImpact();
    setState(() => _poked = true);
    SupabaseChatService.instance.sendPoke(widget.user.id);
    await Future.delayed(const Duration(milliseconds: 2600));
    if (mounted) setState(() => _poked = false);
  }

  void _openChat(BuildContext context) {
    HapticFeedback.selectionClick();
    SupabaseChatService.instance.markAsRead(widget.user.id);
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: AppMotion.normal,
        reverseTransitionDuration: AppMotion.exit,
        pageBuilder: (_, __, ___) => ChatView(friend: widget.user),
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
      ),
    );
  }

  Future<void> _loadReactions() async {
    final period = _period;
    if (period == null) return;
    final summary = await SupabaseReactionService.instance
        .getReactions(widget.user.id, period, _planDate);
    if (!mounted) return;
    setState(() {
      _counts = Map.from(summary.counts);
      _myEmoji = summary.myEmoji;
    });
  }

  Future<void> _react(String emoji) async {
    final period = _period;
    if (period == null || _busy) return;
    HapticFeedback.selectionClick();

    final isRemoving = _myEmoji == emoji;

    setState(() {
      _busy = true;
      _showPicker = false;
      if (isRemoving) {
        _counts[emoji] = (_counts[emoji] ?? 1) - 1;
        if ((_counts[emoji] ?? 0) <= 0) _counts.remove(emoji);
        _myEmoji = null;
      } else {
        if (_myEmoji != null) {
          _counts[_myEmoji!] = (_counts[_myEmoji!] ?? 1) - 1;
          if ((_counts[_myEmoji!] ?? 0) <= 0) _counts.remove(_myEmoji!);
        }
        _counts[emoji] = (_counts[emoji] ?? 0) + 1;
        _myEmoji = emoji;
      }
    });

    // Animate the Reagir button only when adding a reaction.
    if (!isRemoving) {
      setState(() => _animEmoji = emoji);
      _reactCtrl.forward(from: 0);
      Future.delayed(const Duration(milliseconds: 1600), () {
        if (mounted) setState(() => _animEmoji = null);
      });
    }

    try {
      if (isRemoving) {
        await SupabaseReactionService.instance
            .removeReaction(widget.user.id, period, _planDate);
      } else {
        await Future.wait([
          SupabaseReactionService.instance
              .react(widget.user.id, period, _planDate, emoji),
          SupabaseChatService.instance.sendReaction(widget.user.id, emoji),
        ]);
      }
    } catch (_) {
      await _loadReactions();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activity = widget.user.currentActivity;
    final isActive = activity != null;
    final hasPhoto = isActive && activity.photoUrl != null;
    final accent = isActive ? activity.color : AppColors.primary;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.xl),
        border: Border.all(color: accent.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.25),
            blurRadius: 36,
            spreadRadius: 2,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.xl - 2),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background: foto real ou vibe animada
            if (hasPhoto)
              _Photo(url: activity.photoUrl!, accent: accent)
            else
              _VibeBg(
                emoji: isActive ? activity.emoji : '😴',
                accent: accent,
              ),

            // Scrim escuro apenas com foto
            if (hasPhoto) const _Scrim(),

            // Gradiente inferior para legibilidade do footer (sem foto)
            if (!hasPhoto)
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 280,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xD4000000)],
                    ),
                  ),
                ),
              ),

            // Lavagem de cor da vibe (apenas com foto)
            if (hasPhoto)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 300,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        accent.withValues(alpha: 0.10),
                        accent.withValues(alpha: 0.22),
                      ],
                    ),
                  ),
                ),
              ),

            if (!widget.isOwn && (widget.onReport != null || widget.onBlock != null))
              Positioned(
                top: 14,
                right: 14,
                child: GestureDetector(
                  onTap: () => _showModerationSheet(context),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.more_horiz_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),

            if (isActive && activity.isLive && !widget.isOwn)
              Positioned(
                  top: 18,
                  right: (widget.onReport != null || widget.onBlock != null) ? 56 : 18,
                  child: _LiveBadge(accent: accent)),

            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: _CardFooter(
                  user: widget.user,
                  accent: accent,
                  counts: _counts,
                  myEmoji: _myEmoji,
                  showPicker: _showPicker,
                  animEmoji: _animEmoji,
                  reactScale: _reactScale,
                  onTogglePicker: isActive
                      ? () => setState(() => _showPicker = !_showPicker)
                      : null,
                  onReact: isActive && !widget.isOwn ? _react : null,
                  poked: _poked,
                  onPoke: isActive && !widget.isOwn && !widget.hideActions ? _poke : null,
                  onChat: isActive && !widget.isOwn && !widget.hideActions ? () => _openChat(context) : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Photo + overlays
// ─────────────────────────────────────────────────────────────────────────────

class _Photo extends StatelessWidget {
  const _Photo({required this.url, required this.accent});
  final String url;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: AppColors.surfaceElevated,
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: accent.withValues(alpha: 0.6),
              value: progress.expectedTotalBytes != null
                  ? progress.cumulativeBytesLoaded /
                      progress.expectedTotalBytes!
                  : null,
            ),
          ),
        );
      },
      errorBuilder: (_, __, ___) => Container(
        color: AppColors.surfaceElevated,
        child: const Icon(Icons.image_not_supported_outlined,
            color: AppColors.textTertiary, size: 40),
      ),
    );
  }
}

class _VibeBg extends StatefulWidget {
  const _VibeBg({required this.emoji, required this.accent});
  final String emoji;
  final Color accent;

  @override
  State<_VibeBg> createState() => _VibeBgState();
}

class _VibeBgState extends State<_VibeBg> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!AppMotion.reduced(context) && !_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(AppColors.canvas, widget.accent, 0.50)!,
            Color.lerp(AppColors.canvas, widget.accent, 0.22)!,
            AppColors.canvas,
          ],
        ),
      ),
      child: Center(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) => Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 180 + _ctrl.value * 40,
                height: 180 + _ctrl.value * 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      widget.accent.withValues(alpha: _ctrl.value * 0.35),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              Transform.scale(
                scale: 1.0 + _ctrl.value * 0.13,
                child: child,
              ),
            ],
          ),
          child: Text(widget.emoji, style: const TextStyle(fontSize: 100)),
        ),
      ),
    );
  }
}

class _Scrim extends StatelessWidget {
  const _Scrim();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0, 0.30, 0.60, 1],
          colors: [
            Colors.black.withValues(alpha: 0.40),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.50),
            Colors.black.withValues(alpha: 0.92),
          ],
        ),
      ),
    );
  }
}

class _LiveBadge extends StatefulWidget {
  const _LiveBadge({required this.accent});
  final Color accent;

  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!AppMotion.reduced(context) && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(Radii.pill),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(Radii.pill),
            border: Border.all(color: AppColors.live.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FadeTransition(
                opacity:
                    Tween<double>(begin: 0.4, end: 1).animate(_controller),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.live,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 7),
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

// ─────────────────────────────────────────────────────────────────────────────
// Footer: vibe hero + reactions + name
// ─────────────────────────────────────────────────────────────────────────────

String _elapsed(DateTime since) {
  final diff = DateTime.now().difference(since);
  if (diff.inMinutes < 1) return 'agora';
  if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
  return 'há ${diff.inHours}h';
}

class _CardFooter extends StatelessWidget {
  const _CardFooter({
    required this.user,
    required this.accent,
    required this.counts,
    required this.myEmoji,
    required this.showPicker,
    required this.animEmoji,
    required this.reactScale,
    required this.onTogglePicker,
    required this.onReact,
    required this.poked,
    required this.onPoke,
    required this.onChat,
  });

  final UserProfile user;
  final Color accent;
  final Map<String, int> counts;
  final String? myEmoji;
  final bool showPicker;
  final String? animEmoji;
  final Animation<double> reactScale;
  final VoidCallback? onTogglePicker;
  final void Function(String emoji)? onReact;
  final bool poked;
  final VoidCallback? onPoke;
  final VoidCallback? onChat;

  @override
  Widget build(BuildContext context) {
    final activity = user.currentActivity;
    final isActive = activity != null;
    final firstName = user.name.replaceAll(' ✨', '').split(' ').first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Vibe hero ───────────────────────────────────────────────────────
        if (isActive) ...[
          Text(activity.emoji, style: const TextStyle(fontSize: 64)),
          const SizedBox(height: 6),
          Text(
            activity.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 10),

          // ── Reactions ────────────────────────────────────────────────────
          _ReactionRow(
            accent: accent,
            counts: counts,
            myEmoji: myEmoji,
            animEmoji: animEmoji,
            reactScale: reactScale,
            onReact: onReact,
            onTogglePicker: onTogglePicker,
          ),

          // ── Emoji picker (slides in/out) ─────────────────────────────────
          AnimatedSize(
            duration: AppMotion.normal,
            curve: AppMotion.enterCurve,
            child: showPicker
                ? _EmojiPicker(
                    accent: accent,
                    myEmoji: myEmoji,
                    onReact: onReact,
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 14),
        ],

        // ── Name row (secondary) ─────────────────────────────────────────
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.duotone(accent),
              ),
              child: UserAvatar(
                url: user.avatarUrl,
                size: isActive ? 30 : 40,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                firstName,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isActive ? 15 : 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            if (isActive) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(Radii.pill),
                  border: Border.all(color: accent.withValues(alpha: 0.45)),
                ),
                child: Text(
                  activity.isLive
                      ? _elapsed(activity.date)
                      : activity.period?.label ?? '',
                  style: TextStyle(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (activity.isLive && activity.endsAt != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(Radii.pill),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer_outlined,
                          color: Colors.white70, size: 11),
                      const SizedBox(width: 4),
                      Text(
                        activity.endsAtLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),

        if (isActive && (onPoke != null || onChat != null)) ...[
          const SizedBox(height: 10),
          _CardActionRow(
            accent: accent,
            poked: poked,
            onPoke: onPoke,
            onChat: onChat,
            streak: user.streak,
          ),
        ],

        if (!isActive) ...[
          const SizedBox(height: 8),
          const Text(
            'Offline agora',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Action row: chat + poke
// ─────────────────────────────────────────────────────────────────────────────

class _CardActionRow extends StatelessWidget {
  const _CardActionRow({
    required this.accent,
    required this.poked,
    required this.onPoke,
    required this.onChat,
    required this.streak,
  });

  final Color accent;
  final bool poked;
  final VoidCallback? onPoke;
  final VoidCallback? onChat;
  final int streak;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: GestureDetector(
            onTap: onChat,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(Radii.lg),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.45),
                    blurRadius: 18,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Mensagem',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (streak > 0) ...[
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: _StreakFireCard(streak: streak),
          ),
        ],
      ],
    );
  }
}

class _StreakFireCard extends StatelessWidget {
  const _StreakFireCard({required this.streak});
  final int streak;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF2A1000), Color(0xFF1A0800)],
        ),
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(
          color: const Color(0xFFFF6500).withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 5),
          Text(
            '$streak',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reaction row: pills with counts + "Reagir" button
// ─────────────────────────────────────────────────────────────────────────────

class _ReactionRow extends StatelessWidget {
  const _ReactionRow({
    required this.accent,
    required this.counts,
    required this.myEmoji,
    required this.animEmoji,
    required this.reactScale,
    required this.onReact,
    required this.onTogglePicker,
  });

  final Color accent;
  final Map<String, int> counts;
  final String? myEmoji;
  final String? animEmoji;
  final Animation<double> reactScale;
  final void Function(String)? onReact;
  final VoidCallback? onTogglePicker;

  @override
  Widget build(BuildContext context) {
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final visible = sorted.take(4).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          for (final entry in visible) ...[
            _ReactionPill(
              emoji: entry.key,
              count: entry.value,
              isMine: myEmoji == entry.key,
              accent: accent,
              onTap: onReact != null ? () => onReact!(entry.key) : null,
            ),
            const SizedBox(width: 6),
          ],

          // "Reagir" button with emoji burst animation.
          GestureDetector(
            onTap: onTogglePicker,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: animEmoji != null
                    ? Colors.white.withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(Radii.pill),
                border: Border.all(
                  color: animEmoji != null
                      ? Colors.white.withValues(alpha: 0.45)
                      : Colors.white.withValues(alpha: 0.22),
                ),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: anim,
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: animEmoji != null
                    ? ScaleTransition(
                        key: ValueKey(animEmoji),
                        scale: reactScale,
                        child: Text(
                          animEmoji!,
                          style: const TextStyle(fontSize: 18),
                        ),
                      )
                    : Row(
                        key: const ValueKey('reagir'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            counts.isEmpty ? '😊' : '+',
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'Reagir',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReactionPill extends StatelessWidget {
  const _ReactionPill({
    required this.emoji,
    required this.count,
    required this.isMine,
    required this.accent,
    required this.onTap,
  });

  final String emoji;
  final int count;
  final bool isMine;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isMine
              ? accent.withValues(alpha: 0.28)
              : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(
            color: isMine
                ? accent.withValues(alpha: 0.70)
                : Colors.white.withValues(alpha: 0.20),
            width: isMine ? 1.5 : 1,
          ),
          boxShadow: isMine
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.35),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 5),
            Text(
              '$count',
              style: TextStyle(
                color: isMine ? accent : Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick emoji picker
// ─────────────────────────────────────────────────────────────────────────────

class _EmojiPicker extends StatelessWidget {
  const _EmojiPicker({
    required this.accent,
    required this.myEmoji,
    required this.onReact,
  });

  final Color accent;
  final String? myEmoji;
  final void Function(String)? onReact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(Radii.lg),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(Radii.lg),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (final emoji in _kQuickReactions)
                  _EmojiButton(
                    emoji: emoji,
                    isMine: myEmoji == emoji,
                    accent: accent,
                    onTap: onReact != null ? () => onReact!(emoji) : null,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmojiButton extends StatelessWidget {
  const _EmojiButton({
    required this.emoji,
    required this.isMine,
    required this.accent,
    required this.onTap,
  });

  final String emoji;
  final bool isMine;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isMine
              ? accent.withValues(alpha: 0.30)
              : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: isMine
                ? accent.withValues(alpha: 0.70)
                : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: isMine
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.40),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: Center(
          child: AnimatedScale(
            scale: isMine ? 1.25 : 1.0,
            duration: AppMotion.fast,
            child: Text(emoji, style: const TextStyle(fontSize: 22)),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Moderation sheet: report + block
// ─────────────────────────────────────────────────────────────────────────────

class _ModerationSheet extends StatelessWidget {
  const _ModerationSheet({
    required this.userName,
    this.onReport,
    this.onBlock,
  });

  final String userName;
  final VoidCallback? onReport;
  final VoidCallback? onBlock;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          if (onReport != null)
            _ModerationOption(
              icon: Icons.flag_outlined,
              label: 'Denunciar conteúdo',
              sublabel: 'Reportar como inapropriado',
              color: const Color(0xFFFF9500),
              onTap: () {
                Navigator.pop(context);
                onReport!();
                _showConfirmation(context, 'Conteúdo denunciado',
                    'Obrigado! Nossa equipe vai analisar em até 24h.');
              },
            ),
          if (onReport != null && onBlock != null) const SizedBox(height: 10),
          if (onBlock != null)
            _ModerationOption(
              icon: Icons.block_rounded,
              label: 'Bloquear $userName',
              sublabel: 'Remove do seu feed imediatamente',
              color: const Color(0xFFFF3B30),
              onTap: () {
                Navigator.pop(context);
                onBlock!();
                _showConfirmation(context, '$userName bloqueado',
                    'Você não verá mais o conteúdo desta pessoa.');
              },
            ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: double.infinity,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Cancelar',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showConfirmation(BuildContext context, String title, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title — $msg'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

class _ModerationOption extends StatelessWidget {
  const _ModerationOption({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    sublabel,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
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
