import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/services/supabase_chat_service.dart';
import '../../../domain/models/user_profile.dart';
import '../theme/app_colors.dart';
import '../theme/app_motion.dart';
import 'animations.dart';
import 'user_avatar.dart';

/// "All friends offline" poke section.
/// Bubble tap → sends poke question.
/// Avatar tap or chat button → opens chat.
class InactivePokeSection extends StatelessWidget {
  const InactivePokeSection({
    super.key,
    required this.friends,
    this.unreadCounts = const {},
    required this.onChat,
  });

  final List<UserProfile> friends;
  final Map<String, int> unreadCounts;
  final ValueChanged<UserProfile> onChat;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Heading ────────────────────────────────────────────────────────
          const EntranceFade(
            index: 0,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  Text(
                    'Ninguém ativo no momento',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.4,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Toque no balão pra perguntar\no que o amigo está fazendo 👇',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 0),

          // ── Cards ───────────────────────────────────────────────────────────
          SizedBox(
            height: 340,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: friends.length,
              itemBuilder: (context, i) => EntranceFade(
                index: i + 1,
                delay: const Duration(milliseconds: 80),
                child: _PokeCard(
                  friend: friends[i],
                  index: i,
                  unreadCount: unreadCounts[friends[i].id] ?? 0,
                  onPoke: () {},
                  onChat: () => onChat(friends[i]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Continuous float animation ────────────────────────────────────────────────

class _FloatingBob extends StatefulWidget {
  const _FloatingBob({
    required this.child,
    this.period = const Duration(milliseconds: 2700),
    this.amplitude = 8.0,
    this.phaseMs = 0,
  });

  final Widget child;
  final Duration period;
  final double amplitude;
  final int phaseMs;

  @override
  State<_FloatingBob> createState() => _FloatingBobState();
}

class _FloatingBobState extends State<_FloatingBob>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.period,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!AppMotion.reduced(context) && !_controller.isAnimating) {
      _controller.forward(
        from: (widget.phaseMs % widget.period.inMilliseconds) /
            widget.period.inMilliseconds,
      );
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
    if (AppMotion.reduced(context)) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Transform.translate(
          offset: Offset(0, -widget.amplitude * t),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

// ── Poke card ─────────────────────────────────────────────────────────────────

class _PokeCard extends StatefulWidget {
  const _PokeCard({
    required this.friend,
    required this.index,
    required this.unreadCount,
    required this.onPoke,
    required this.onChat,
  });

  final UserProfile friend;
  final int index;
  final int unreadCount;
  final VoidCallback onPoke;
  final VoidCallback onChat;

  @override
  State<_PokeCard> createState() => _PokeCardState();
}

class _PokeCardState extends State<_PokeCard> {
  static const _accents = [
    AppColors.primary,
    AppColors.secondary,
    AppColors.accent,
    AppColors.live,
  ];

  bool _poked = false;

  Color get _accent => _accents[widget.index % _accents.length];

  Future<void> _poke() async {
    if (_poked) return;
    HapticFeedback.mediumImpact();
    setState(() => _poked = true);
    SupabaseChatService.instance.sendPoke(widget.friend.id);
    Future.delayed(const Duration(milliseconds: 2600), () {
      if (mounted) setState(() => _poked = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.friend.name.replaceAll(' ✨', '').split(' ').first;
    final bobPeriod = Duration(milliseconds: 2500 + (widget.index % 4) * 220);
    final avatarBobPeriod =
        Duration(milliseconds: 2900 + (widget.index % 3) * 180);

    return Padding(
      padding: const EdgeInsets.only(right: 20),
      child: SizedBox(
        width: 156,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // ── Speech bubble (tap = poke) ──────────────────────────────────
            Semantics(
              button: true,
              label: 'Perguntar o que $name está fazendo',
              child: GestureDetector(
                onTap: _poke,
                behavior: HitTestBehavior.opaque,
                child: _FloatingBob(
                  period: bobPeriod,
                  amplitude: 7,
                  phaseMs: widget.index * 600,
                  child: _PokeBubble(accent: _accent, poked: _poked),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ── Bubble tail dots ────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _PokeDot(size: 8, accent: _accent, active: _poked),
                const SizedBox(width: 5),
                _PokeDot(size: 5, accent: _accent, active: _poked),
              ],
            ),

            const SizedBox(height: 8),

            // ── Avatar (tap = chat) ─────────────────────────────────────────
            Semantics(
              button: true,
              label: 'Conversar com $name',
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  widget.onChat();
                },
                child: _FloatingBob(
                  period: avatarBobPeriod,
                  amplitude: 5,
                  phaseMs: widget.index * 400 + 300,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      AnimatedContainer(
                        duration: AppMotion.normal,
                        curve: AppMotion.enterCurve,
                        width: 108,
                        height: 108,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _accent.withValues(alpha: _poked ? 0.9 : 0.4),
                            width: _poked ? 3 : 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _accent.withValues(
                                  alpha: _poked ? 0.5 : 0.22),
                              blurRadius: _poked ? 28 : 18,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: ColorFiltered(
                            colorFilter: const ColorFilter.matrix(<double>[
                              0.33, 0.33, 0.33, 0, 0,
                              0.33, 0.33, 0.33, 0, 0,
                              0.33, 0.33, 0.33, 0, 0,
                              0, 0, 0, 1, 0,
                            ]),
                            child: UserAvatar(
                                url: widget.friend.avatarUrl, size: 108),
                          ),
                        ),
                      ),
                      if (widget.unreadCount > 0)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: AppColors.brandGradient,
                              borderRadius: BorderRadius.circular(Radii.pill),
                              border:
                                  Border.all(color: AppColors.canvas, width: 1.5),
                            ),
                            child: Text(
                              widget.unreadCount > 9
                                  ? '9+'
                                  : '${widget.unreadCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Name ─────────────────────────────────────────────────────────
            Text(
              name,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 10),

            // ── Big chat button ───────────────────────────────────────────────
            Semantics(
              button: true,
              label: 'Conversar com $name',
              child: PressableScale(
                onTap: () {
                  HapticFeedback.selectionClick();
                  widget.onChat();
                },
                child: Container(
                  width: double.infinity,
                  height: 46,
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _accent.withValues(alpha: 0.45),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _accent.withValues(alpha: 0.18),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_rounded,
                          size: 17, color: _accent),
                      const SizedBox(width: 7),
                      Text(
                        'Conversar',
                        style: TextStyle(
                          color: _accent,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
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

// ── Speech bubble ─────────────────────────────────────────────────────────────

class _PokeBubble extends StatelessWidget {
  const _PokeBubble({required this.accent, required this.poked});
  final Color accent;
  final bool poked;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.normal,
      curve: AppMotion.enterCurve,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: poked ? AppColors.duotone(accent) : null,
        color: poked ? null : AppColors.surfaceHigh,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
          bottomLeft: Radius.circular(6),
          bottomRight: Radius.circular(20),
        ),
        border: Border.all(
          color: poked ? Colors.transparent : accent.withValues(alpha: 0.45),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: poked ? 0.5 : 0.18),
            blurRadius: poked ? 22 : 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: AnimatedSwitcher(
        duration: AppMotion.fast,
        child: Text(
          poked ? 'Perguntado! 🤔' : 'O que você\nestá fazendo? 👀',
          key: ValueKey(poked),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: poked ? Colors.white : AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
        ),
      ),
    );
  }
}

// ── Bubble tail dot ───────────────────────────────────────────────────────────

class _PokeDot extends StatelessWidget {
  const _PokeDot({
    required this.size,
    required this.accent,
    required this.active,
  });

  final double size;
  final Color accent;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.fast,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: active ? accent : AppColors.surfaceHigh,
        shape: BoxShape.circle,
        border: Border.all(
          color: active ? accent : AppColors.border,
          width: 1.2,
        ),
      ),
    );
  }
}
