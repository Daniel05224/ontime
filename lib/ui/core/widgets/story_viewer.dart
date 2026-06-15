import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/services/supabase_chat_service.dart';
import '../../../data/services/supabase_reaction_service.dart';
import '../../../data/services/supabase_status_service.dart';
import '../../../domain/models/user_profile.dart';
import '../../../domain/models/vibe.dart';
import '../../features/activity/views/status_composer_view.dart';
import '../../features/routine/view_models/routine_view_model.dart';
import '../../features/social/views/chat_view.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import 'user_avatar.dart';

const _kQuickReactions = ['🔥', '❤️', '😂', '😮', '😍', '🎉', '👏', '💀'];

/// Immersive, full-screen story viewer. Swipe horizontally to move between
/// friends (3D depth transition), swipe down to dismiss. Each page is a
/// full-bleed story with reactions, message and poke actions.
class StoryViewer extends StatefulWidget {
  const StoryViewer({
    super.key,
    required this.stories,
    this.initialIndex = 0,
  });

  final List<UserProfile> stories;
  final int initialIndex;

  /// Opens the viewer as a full-screen fade route.
  static Future<void> open(
    BuildContext context, {
    required List<UserProfile> stories,
    int initialIndex = 0,
  }) {
    HapticFeedback.selectionClick();
    return Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.transparent,
      transitionDuration: AppMotion.normal,
      reverseTransitionDuration: AppMotion.exit,
      pageBuilder: (_, __, ___) => StoryViewer(
        stories: stories,
        initialIndex: initialIndex,
      ),
      transitionsBuilder: (ctx, anim, _, child) {
        if (AppMotion.reduced(ctx)) {
          return FadeTransition(opacity: anim, child: child);
        }
        final curved = CurvedAnimation(parent: anim, curve: AppMotion.enterCurve);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    ));
  }

  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer> {
  // Rotate list so the tapped story is always at index 0 (leftmost bar,
  // leftmost page). Drag left = advance to the next friend. Always.
  late final List<UserProfile> _stories = _rotate();
  late final PageController _controller = PageController(initialPage: 0);
  int _index = 0;
  double _dragDy = 0;
  bool _popping = false;

  List<UserProfile> _rotate() {
    final k = widget.initialIndex.clamp(0, widget.stories.length - 1);
    return [
      ...widget.stories.sublist(k),
      ...widget.stories.sublist(0, k),
    ];
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onVerticalDragUpdate(DragUpdateDetails d) {
    if (_popping || d.primaryDelta == null) return;
    setState(() => _dragDy = (_dragDy + d.primaryDelta!).clamp(0.0, 400.0));
  }

  void _onVerticalDragEnd(DragEndDetails d) {
    if (_popping) return;
    if (_dragDy > 110 || (d.primaryVelocity ?? 0) > 700) {
      _popping = true;
      Navigator.of(context).maybePop();
    } else {
      setState(() => _dragDy = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final dismissT = (_dragDy / 400).clamp(0.0, 1.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
      ),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.black.withValues(alpha: 1 - dismissT * 0.5),
        body: GestureDetector(
        onVerticalDragUpdate: _onVerticalDragUpdate,
        onVerticalDragEnd: _onVerticalDragEnd,
        child: Transform.translate(
          offset: Offset(0, _dragDy),
          child: Transform.scale(
            scale: 1 - dismissT * 0.08,
            child: Stack(
              children: [
                // ── Swipeable stories ──────────────────────────────────────
                PageView.builder(
                  controller: _controller,
                  itemCount: _stories.length,
                  onPageChanged: (i) {
                    setState(() => _index = i);
                    HapticFeedback.selectionClick();
                  },
                  itemBuilder: (context, i) {
                    return AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        if (!context.mounted) return child ?? const SizedBox.shrink();
                        double delta = (_index - i).toDouble();
                        if (_controller.hasClients &&
                            _controller.position.haveDimensions) {
                          delta = (_controller.page ?? _index.toDouble()) - i;
                        }
                        final t = delta.clamp(-1.0, 1.0);
                        return Opacity(
                          opacity: (1 - t.abs() * 0.5).clamp(0.0, 1.0),
                          child: Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.0012)
                              ..rotateY(t * -0.55)
                              ..scaleByDouble(1 - t.abs() * 0.10, 1 - t.abs() * 0.10, 1, 1),
                            child: child,
                          ),
                        );
                      },
                      child: _StoryPage(user: _stories[i]),
                    );
                  },
                ),

                // ── Top overlay: progress + close ──────────────────────────
                Positioned(
                  top: MediaQuery.viewPaddingOf(context).top + 8,
                  left: 14,
                  right: 14,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: _stories.length <= 7
                            ? Row(
                                children: [
                                  for (var i = 0; i < _stories.length; i++)
                                    Expanded(
                                      child: Padding(
                                        padding: EdgeInsets.only(
                                            right: i == _stories.length - 1 ? 0 : 4),
                                        child: AnimatedContainer(
                                          duration: AppMotion.fast,
                                          height: 3.5,
                                          decoration: BoxDecoration(
                                            color: i <= _index
                                                ? Colors.white
                                                : Colors.white.withValues(alpha: 0.28),
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              )
                            : _StoryCounter(
                                current: _index + 1,
                                total: _stories.length,
                              ),
                      ),
                      const SizedBox(width: 10),
                      _GlassIconButton(
                        icon: Icons.close_rounded,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                    ],
                  ),
                ),

                // Hint to swipe (only when more than one story).
                if (widget.stories.length > 1 && size.width > 0)
                  Positioned(
                    right: 16,
                    top: size.height * 0.46,
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: 0.5,
                        child: Icon(Icons.chevron_right_rounded,
                            color: Colors.white.withValues(alpha: 0.6),
                            size: 30),
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

// Counter pill shown instead of individual bars when there are many stories.
class _StoryCounter extends StatelessWidget {
  const _StoryCounter({required this.current, required this.total});
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Thin single track
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Stack(
              children: [
                Container(height: 3.5, color: Colors.white.withValues(alpha: 0.28)),
                FractionallySizedBox(
                  widthFactor: current / total,
                  child: Container(height: 3.5, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.38),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            '$current / $total',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }
}

String _elapsed(DateTime since) {
  final diff = DateTime.now().difference(since);
  if (diff.inMinutes < 1) return 'agora';
  if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
  return 'há ${diff.inHours}h';
}

// ─────────────────────────────────────────────────────────────────────────────
// A single full-screen story
// ─────────────────────────────────────────────────────────────────────────────

class _StoryPage extends StatefulWidget {
  const _StoryPage({required this.user});
  final UserProfile user;

  @override
  State<_StoryPage> createState() => _StoryPageState();
}

class _StoryPageState extends State<_StoryPage>
    with SingleTickerProviderStateMixin {
  Map<String, int> _counts = {};
  String? _myEmoji;
  bool _busy = false;
  bool _showPicker = false;
  bool _poked = false;
  bool _deleting = false;

  bool get _isOwn =>
      widget.user.id == Supabase.instance.client.auth.currentUser?.id;

  String? _animEmoji;
  late final AnimationController _reactCtrl;
  late final Animation<double> _reactScale;

  String? get _period => widget.user.currentActivity?.period?.name;
  String get _planDate {
    final d = widget.user.currentActivity?.date ?? DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _reactCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _reactScale = CurvedAnimation(parent: _reactCtrl, curve: Curves.elasticOut);
    _loadReactions();
  }

  @override
  void dispose() {
    _reactCtrl.dispose();
    super.dispose();
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

  Future<void> _poke() async {
    if (_poked) return;
    HapticFeedback.mediumImpact();
    setState(() => _poked = true);
    SupabaseChatService.instance.sendPoke(widget.user.id);
    await Future.delayed(const Duration(milliseconds: 2600));
    if (mounted) setState(() => _poked = false);
  }

  void _editStory() {
    final nav = Navigator.of(context);
    nav.pop();
    nav.push(MaterialPageRoute(
      builder: (_) => const StatusComposerView(initialTab: ComposerTab.now),
      fullscreenDialog: true,
    ));
  }

  Future<void> _deleteStory() async {
    if (_deleting) return;
    setState(() => _deleting = true);
    HapticFeedback.mediumImpact();
    final activity = widget.user.currentActivity;
    final routineVM = context.read<RoutineViewModel>();
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
      if (mounted) Navigator.of(context).maybePop();
    }
  }

  void _openChat() {
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

  @override
  Widget build(BuildContext context) {
    final activity = widget.user.currentActivity;
    final accent = activity?.color ?? AppColors.primary;
    final hasPhoto = activity?.photoUrl != null;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Background ─────────────────────────────────────────────────────
        if (hasPhoto)
          _PhotoBg(url: activity!.photoUrl!, accent: accent)
        else
          _VibeBg(emoji: activity?.emoji ?? '😴', accent: accent),

        // Scrim for legibility (top + bottom).
        const _Scrim(),

        // Color wash from the vibe at the bottom.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 320,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  accent.withValues(alpha: 0.14),
                  accent.withValues(alpha: 0.30),
                ],
              ),
            ),
          ),
        ),

        // ── Header (avatar + name + time + live) ───────────────────────────
        Positioned(
          top: MediaQuery.viewPaddingOf(context).top + 44,
          left: 16,
          right: 16,
          child: _StoryHeader(user: widget.user, accent: accent),
        ),

        // ── Bottom content ─────────────────────────────────────────────────
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, bottomInset + 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (activity != null) ...[
                  Text(activity.emoji, style: const TextStyle(fontSize: 60)),
                  const SizedBox(height: 4),
                  Text(
                    activity.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.0,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_isOwn) ...[
                    _OwnStoryActions(
                      accent: accent,
                      deleting: _deleting,
                      onEdit: _editStory,
                      onDelete: _deleteStory,
                    ),
                  ] else ...[
                    _ReactionBar(
                      accent: accent,
                      counts: _counts,
                      myEmoji: _myEmoji,
                      animEmoji: _animEmoji,
                      reactScale: _reactScale,
                      onReact: _react,
                      onTogglePicker: () =>
                          setState(() => _showPicker = !_showPicker),
                    ),
                    AnimatedSize(
                      duration: AppMotion.normal,
                      curve: AppMotion.enterCurve,
                      child: _showPicker
                          ? _EmojiPicker(accent: accent, myEmoji: _myEmoji, onReact: _react)
                          : const SizedBox(width: double.infinity),
                    ),
                    const SizedBox(height: 16),
                    _ActionRow(accent: accent, poked: _poked, onPoke: _poke, onChat: _openChat),
                  ],
                ] else ...[
                  if (_isOwn)
                    _OwnStoryActions(
                      accent: accent,
                      deleting: false,
                      onEdit: _editStory,
                      onDelete: null,
                    )
                  else ...[
                    const Text(
                      'Offline agora',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ActionRow(accent: accent, poked: _poked, onPoke: _poke, onChat: _openChat),
                  ],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────

class _StoryHeader extends StatelessWidget {
  const _StoryHeader({required this.user, required this.accent});
  final UserProfile user;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final activity = user.currentActivity;
    final name = user.name.replaceAll(' ✨', '');

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.07),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.duotone(accent),
                ),
                child: UserAvatar(url: user.avatarUrl, size: 44),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                              shadows: [
                                Shadow(blurRadius: 8, color: Colors.black54),
                              ],
                            ),
                          ),
                        ),
                        if (user.streak > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color:
                                  const Color(0xFFFF6500).withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                  color: const Color(0xFFFF6500)
                                      .withValues(alpha: 0.6)),
                            ),
                            child: Text(
                              '🔥 ${user.streak}',
                              style: const TextStyle(
                                color: Colors.orange,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      activity == null
                          ? 'sem atividade'
                          : activity.isLive
                              ? _elapsed(activity.date)
                              : (activity.period?.label ?? ''),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (activity?.isLive ?? false) _LiveChip(),
                  if ((activity?.isLive ?? false) && activity?.endsAt != null) ...[
                    const SizedBox(height: 4),
                    _TimerChip(label: activity!.endsAtLabel),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveChip extends StatefulWidget {
  @override
  State<_LiveChip> createState() => _LiveChipState();
}

class _LiveChipState extends State<_LiveChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!AppMotion.reduced(context) && !_c.isAnimating) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _GlassPill(
      borderColor: AppColors.live.withValues(alpha: 0.5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: Tween<double>(begin: 0.35, end: 1).animate(_c),
            child: Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                  color: AppColors.live, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'AO VIVO',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimerChip extends StatelessWidget {
  const _TimerChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return _GlassPill(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, color: Colors.white70, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reaction bar
// ─────────────────────────────────────────────────────────────────────────────

class _ReactionBar extends StatelessWidget {
  const _ReactionBar({
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
  final void Function(String) onReact;
  final VoidCallback onTogglePicker;

  @override
  Widget build(BuildContext context) {
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final visible = sorted.take(4).toList();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final entry in visible)
          _ReactionPill(
            emoji: entry.key,
            count: entry.value,
            isMine: myEmoji == entry.key,
            accent: accent,
            onTap: () => onReact(entry.key),
          ),
        GestureDetector(
          onTap: onTogglePicker,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              switchInCurve: Curves.easeOutBack,
              transitionBuilder: (child, anim) => ScaleTransition(
                scale: anim,
                child: FadeTransition(opacity: anim, child: child),
              ),
              child: animEmoji != null
                  ? ScaleTransition(
                      key: ValueKey(animEmoji),
                      scale: reactScale,
                      child:
                          Text(animEmoji!, style: const TextStyle(fontSize: 18)),
                    )
                  : const Row(
                      key: ValueKey('reagir'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('😊', style: TextStyle(fontSize: 15)),
                        SizedBox(width: 6),
                        Text(
                          'Reagir',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
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
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: isMine
              ? accent.withValues(alpha: 0.30)
              : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isMine
                ? accent.withValues(alpha: 0.8)
                : Colors.white.withValues(alpha: 0.22),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 5),
            Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
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

class _EmojiPicker extends StatelessWidget {
  const _EmojiPicker({
    required this.accent,
    required this.myEmoji,
    required this.onReact,
  });

  final Color accent;
  final String? myEmoji;
  final void Function(String) onReact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final emoji in _kQuickReactions)
                  GestureDetector(
                    onTap: () => onReact(emoji),
                    child: AnimatedContainer(
                      duration: AppMotion.fast,
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: myEmoji == emoji
                            ? accent.withValues(alpha: 0.35)
                            : Colors.transparent,
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 24)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Action row: message + poke
// ─────────────────────────────────────────────────────────────────────────────

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.accent,
    required this.poked,
    required this.onPoke,
    required this.onChat,
  });

  final Color accent;
  final bool poked;
  final VoidCallback onPoke;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: GestureDetector(
            onTap: onChat,
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.45),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 19),
                  SizedBox(width: 8),
                  Text(
                    'Mensagem',
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
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: GestureDetector(
            onTap: onPoke,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: AnimatedContainer(
                  duration: AppMotion.fast,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: poked ? AppColors.duotone(accent) : null,
                    color: poked ? null : Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: poked
                          ? Colors.transparent
                          : Colors.white.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: AppMotion.fast,
                      child: Text(
                        poked ? 'Enviado! 🤔' : 'O que faz? 🤔',
                        key: ValueKey(poked),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Background + chrome bits
// ─────────────────────────────────────────────────────────────────────────────

class _PhotoBg extends StatelessWidget {
  const _PhotoBg({required this.url, required this.accent});
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
          color: AppColors.canvas,
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: accent.withValues(alpha: 0.6),
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
    duration: const Duration(milliseconds: 2600),
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
            Color.lerp(AppColors.canvas, widget.accent, 0.45)!,
            Color.lerp(AppColors.canvas, widget.accent, 0.18)!,
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
                width: 240 + _ctrl.value * 50,
                height: 240 + _ctrl.value * 50,
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
              Transform.scale(scale: 1.0 + _ctrl.value * 0.12, child: child),
            ],
          ),
          child: Text(widget.emoji, style: const TextStyle(fontSize: 120)),
        ),
      ),
    );
  }
}

class _Scrim extends StatelessWidget {
  const _Scrim();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0, 0.22, 0.55, 1],
          colors: [
            Color(0x99000000),
            Color(0x00000000),
            Color(0x55000000),
            Color(0xE6000000),
          ],
        ),
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.child, this.borderColor});
  final Widget child;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
                color: borderColor ?? Colors.white.withValues(alpha: 0.2)),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Own story: edit + delete buttons
// ─────────────────────────────────────────────────────────────────────────────

class _OwnStoryActions extends StatelessWidget {
  const _OwnStoryActions({
    required this.accent,
    required this.deleting,
    required this.onEdit,
    required this.onDelete,
  });

  final Color accent;
  final bool deleting;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: onEdit,
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.45),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.edit_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Editar story',
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
        ),
        if (onDelete != null) ...[
          const SizedBox(width: 10),
          GestureDetector(
            onTap: deleting ? null : onDelete,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.danger.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Center(
                    child: deleting
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.danger,
                            ),
                          )
                        : Icon(Icons.delete_outline_rounded,
                            color: AppColors.danger, size: 20),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  const _GlassIconButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}
