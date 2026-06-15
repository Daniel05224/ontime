import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../domain/models/activity.dart';
import '../../../../domain/models/vibe.dart';
import '../../../core/responsive/responsive_breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/widgets/animations.dart';
import '../../activity/views/status_composer_view.dart';
import '../../routine/view_models/routine_view_model.dart';

class MyDayView extends StatelessWidget {
  const MyDayView({super.key});

  static const _periods = [
    (RoutinePeriod.morning, 'Manhã', '06:00 – 12:00', '☀️', AppColors.morning),
    (RoutinePeriod.afternoon, 'Tarde', '12:00 – 18:00', '🌤️', AppColors.afternoon),
    (RoutinePeriod.evening, 'Noite', '18:00 – 22:00', '🌙', AppColors.evening),
    (RoutinePeriod.night, 'Madrugada', '22:00 – 06:00', '✨', AppColors.night),
  ];

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<RoutineViewModel>();
    final current = viewModel.currentUser.currentActivity;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final windowHeight = MediaQuery.sizeOf(context).height;
          final large = isLargeScreen(constraints.maxWidth);
          final heroHeight = large
              ? (windowHeight * 0.55).clamp(340.0, 520.0)
              : windowHeight * 0.72;
          final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
          final bottomSpacer = large ? 40.0 : (bottomInset + 88.0).clamp(100.0, 220.0);

          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: _Hero(
                  height: heroHeight,
                  activity: current,
                ),
              ),
              SliverToBoxAdapter(
                child: _StreakBanner(streak: viewModel.ownStreak),
              ),
              SliverToBoxAdapter(
                child: _DayProgress(viewModel: viewModel),
              ),
              _PeriodsSliver(
                viewModel: viewModel,
                constraints: constraints,
                bottomSpacer: bottomSpacer,
                currentPeriod: currentPeriod(),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Hero with an animated duotone gradient backdrop.
class _Hero extends StatefulWidget {
  const _Hero({required this.height, required this.activity});
  final double height;
  final Activity? activity;

  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(seconds: 8));

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
    final activity = widget.activity;
    final accent = activity?.color ?? AppColors.primary;

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Stack(
        children: [
          // Animated gradient backdrop.
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = Curves.easeInOut.transform(_controller.value);
              return SizedBox.expand(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0, -0.6 + 0.2 * t),
                      radius: 1.1 + 0.15 * t,
                      colors: [
                        Color.lerp(accent, AppColors.secondary, 0.2 * t)!
                            .withValues(alpha: 0.30),
                        AppColors.canvas,
                      ],
                      stops: const [0, 0.85],
                    ),
                  ),
                ),
              );
            },
          ),
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 2),
                    if (activity != null)
                      _ActiveState(activity: activity, accent: accent)
                    else
                      const _EmptyState(),
                    const Spacer(flex: 3),
                    const EntranceFade(
                      index: 5,
                      child: _ScrollHint(),
                    ),
                    const SizedBox(height: 20),
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

class _ActiveState extends StatelessWidget {
  const _ActiveState({required this.activity, required this.accent});
  final Activity activity;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        EntranceFade(
          index: 0,
          child: BreathingGlow(
            color: accent,
            child: Container(
              width: 116,
              height: 116,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface,
                border: Border.all(color: accent.withValues(alpha: 0.5), width: 2),
              ),
              child: Text(activity.emoji, style: const TextStyle(fontSize: 60)),
            ),
          ),
        ),
        const SizedBox(height: 24),
        EntranceFade(
          index: 1,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                    color: AppColors.live, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                'AGORA',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                  color: accent,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        EntranceFade(
          index: 2,
          child: Text(
            activity.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
              height: 1.1,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 28),
        EntranceFade(
          index: 3,
          child: PressableScale(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const StatusComposerView(),
              ),
            ),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(Radii.pill),
                border: Border.all(color: accent.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_rounded, color: accent, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    'Editar status',
                    style: TextStyle(
                      color: accent,
                      fontSize: 15,
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const EntranceFade(
          index: 0,
          child: Text(
            'O que você\nestá fazendo?',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.5,
              height: 1.05,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 14),
        const EntranceFade(
          index: 1,
          child: Text(
            'Poste agora para desbloquear o feed dos amigos.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(height: 36),
        EntranceFade(
          index: 2,
          child: PressableScale(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const StatusComposerView()),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(Radii.lg),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.18),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: const BoxDecoration(
                      gradient: AppColors.brandGradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.bolt_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 14),
                  const Text(
                    'Responder agora',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 17,
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

class _ScrollHint extends StatelessWidget {
  const _ScrollHint();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Text(
          'MEU DIA',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 6,
            color: AppColors.textTertiary,
          ),
        ),
        SizedBox(height: 10),
        Icon(Icons.keyboard_arrow_down_rounded,
            color: AppColors.textTertiary, size: 30),
      ],
    );
  }
}

/// Header for the planning section: label + a gamified day-progress bar
/// where each segment lights up with its period color once planned.
class _DayProgress extends StatelessWidget {
  const _DayProgress({required this.viewModel});
  final RoutineViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final periods = MyDayView._periods;
    final filledFlags = [
      for (final p in periods) viewModel.getActivitiesByPeriod(p.$1).isNotEmpty,
    ];
    final filled = filledFlags.where((f) => f).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 18),
      child: EntranceFade(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'PLANEJAMENTO',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.5,
                    color: AppColors.textTertiary,
                  ),
                ),
                const Spacer(),
                _CountPill(filled: filled, total: periods.length),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                for (var i = 0; i < periods.length; i++) ...[
                  Expanded(
                    child: AnimatedContainer(
                      duration: AppMotion.normal,
                      curve: AppMotion.enterCurve,
                      height: 8,
                      decoration: BoxDecoration(
                        gradient: filledFlags[i]
                            ? AppColors.periodGradient(periods[i].$5)
                            : null,
                        color:
                            filledFlags[i] ? null : AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(Radii.pill),
                        boxShadow: filledFlags[i]
                            ? [
                                BoxShadow(
                                  color: periods[i]
                                      .$5
                                      .withValues(alpha: 0.45),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                  if (i < periods.length - 1) const SizedBox(width: 6),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Pill showing how much of the day is planned — turns into a celebratory
/// gradient badge once all four periods are set.
class _CountPill extends StatelessWidget {
  const _CountPill({required this.filled, required this.total});
  final int filled;
  final int total;

  @override
  Widget build(BuildContext context) {
    final complete = filled == total;
    return AnimatedContainer(
      duration: AppMotion.normal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: complete ? AppColors.brandGradient : null,
        color: complete ? null : AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(
          color: complete ? Colors.transparent : AppColors.border,
        ),
      ),
      child: Text(
        complete ? 'Dia completo 🎉' : '$filled de $total',
        style: TextStyle(
          color: complete ? Colors.white : AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _PeriodsSliver extends StatelessWidget {
  const _PeriodsSliver({
    required this.viewModel,
    required this.constraints,
    required this.bottomSpacer,
    required this.currentPeriod,
  });

  final RoutineViewModel viewModel;
  final BoxConstraints constraints;
  final double bottomSpacer;
  final RoutinePeriod currentPeriod;

  @override
  Widget build(BuildContext context) {
    final periods = MyDayView._periods;

    if (isExpandedContent(constraints.maxWidth)) {
      return SliverMainAxisGroup(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverGrid(
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 20,
                crossAxisSpacing: 20,
                childAspectRatio: 1.0,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final p = periods[index];
                  return EntranceFade(
                    index: index,
                    child: _PeriodCard(
                      viewModel: viewModel,
                      period: p.$1,
                      title: p.$2,
                      subtitle: p.$3,
                      emoji: p.$4,
                      accent: p.$5,
                      isCurrent: p.$1 == currentPeriod,
                    ),
                  );
                },
                childCount: periods.length,
              ),
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: bottomSpacer)),
        ],
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          for (var i = 0; i < periods.length; i++)
            EntranceFade(
              index: i,
              child: _PeriodCard(
                viewModel: viewModel,
                period: periods[i].$1,
                title: periods[i].$2,
                subtitle: periods[i].$3,
                emoji: periods[i].$4,
                accent: periods[i].$5,
                isCurrent: periods[i].$1 == currentPeriod,
              ),
            ),
          SizedBox(height: bottomSpacer),
        ]),
      ),
    );
  }
}

class _PeriodCard extends StatefulWidget {
  const _PeriodCard({
    required this.viewModel,
    required this.period,
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.accent,
    required this.isCurrent,
  });

  final RoutineViewModel viewModel;
  final RoutinePeriod period;
  final String title;
  final String subtitle;
  final String emoji;
  final Color accent;
  final bool isCurrent;

  @override
  State<_PeriodCard> createState() => _PeriodCardState();
}

class _PeriodCardState extends State<_PeriodCard>
    with SingleTickerProviderStateMixin {
  /// Drives the breathing ring/glow on the current period card only.
  AnimationController? _pulse;
  bool _pressed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.isCurrent && !AppMotion.reduced(context)) {
      _pulse ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2600),
      )..repeat(reverse: true);
    } else {
      _pulse?.dispose();
      _pulse = null;
    }
  }

  @override
  void dispose() {
    _pulse?.dispose();
    super.dispose();
  }

  void _add() {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StatusComposerView(
          initialTab: ComposerTab.day,
          focusPeriod: widget.period,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    final isCurrent = widget.isCurrent;
    final activities = widget.viewModel.getActivitiesByPeriod(widget.period);
    final hasActivities = activities.isNotEmpty;
    final reduced = AppMotion.reduced(context);

    final emojiTile = Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: AppColors.periodGradient(accent),
        borderRadius: BorderRadius.circular(Radii.md),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(widget.emoji, style: const TextStyle(fontSize: 22)),
    );

    final content = Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              isCurrent ? BreathingGlow(color: accent, child: emojiTile) : emojiTile,
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.title,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (isCurrent) ...[
                          const SizedBox(width: 8),
                          _NowChip(accent: accent),
                        ],
                      ],
                    ),
                    Text(
                      widget.subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Trailing action icon flips between add/edit with a fade.
              AnimatedSwitcher(
                duration: AppMotion.fast,
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: Icon(
                  hasActivities
                      ? Icons.edit_rounded
                      : Icons.add_circle_outline_rounded,
                  key: ValueKey(hasActivities),
                  color: accent,
                  size: 24,
                ),
              ),
            ],
          ),
          // Smoothly grows/shrinks as activities are added or cleared.
          AnimatedSize(
            duration: AppMotion.normal,
            curve: AppMotion.enterCurve,
            alignment: Alignment.topCenter,
            child: hasActivities
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      for (final a in activities)
                        _ActivityRow(
                            activity: a, accent: accent, period: widget.period),
                    ],
                  )
                : Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(Radii.md),
                        border:
                            Border.all(color: accent.withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_rounded, color: accent, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'Toque para planejar',
                            style: TextStyle(
                              color: accent,
                              fontSize: 14,
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

    // Builds the (optionally pulsing) outer shell for the current period.
    // [child] stays stable across frames so only the glow rebuilds.
    Widget currentShell(double t, Widget child) => Container(
          margin: const EdgeInsets.only(bottom: 18),
          decoration: BoxDecoration(
            gradient: AppColors.duotone(accent),
            borderRadius: BorderRadius.circular(Radii.lg + 1.5),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.18 + 0.22 * t),
                blurRadius: 18 + 18 * t,
                spreadRadius: 1 + t,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(1.5),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.lg),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(AppColors.surface, accent, 0.14)!,
                  AppColors.surface,
                ],
              ),
            ),
            child: child,
          ),
        );

    Widget card;
    if (isCurrent) {
      card = _pulse == null
          ? currentShell(0.5, content)
          : AnimatedBuilder(
              animation: _pulse!,
              builder: (_, child) =>
                  currentShell(Curves.easeInOut.transform(_pulse!.value), child!),
              child: content,
            );
    } else {
      card = Container(
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: content,
      );
    }

    // Whole card is pressable, with a subtle scale-in on touch.
    return GestureDetector(
      onTap: _add,
      onTapDown: (_) {
        if (!reduced) setState(() => _pressed = true);
      },
      onTapUp: (_) {
        if (_pressed) setState(() => _pressed = false);
      },
      onTapCancel: () {
        if (_pressed) setState(() => _pressed = false);
      },
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: AppMotion.fast,
        curve: Curves.easeOut,
        child: card,
      ),
    );
  }
}

/// Small "AGORA" badge with a live dot, shown on the current period card.
class _NowChip extends StatelessWidget {
  const _NowChip({required this.accent});
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: accent.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.live,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            'AGORA',
            style: TextStyle(
              color: accent,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({
    required this.activity,
    required this.accent,
    required this.period,
  });
  final Activity activity;
  final Color accent;
  final RoutinePeriod period;

  @override
  Widget build(BuildContext context) {
    final isLive = activity.isActiveNow;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PressableScale(
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => StatusComposerView(
                initialTab: ComposerTab.day,
                focusPeriod: period,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withValues(alpha: 0.22),
                accent.withValues(alpha: 0.07),
              ],
            ),
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(
              color: accent.withValues(alpha: isLive ? 0.60 : 0.40),
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: isLive ? 0.22 : 0.10),
                blurRadius: isLive ? 18 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Prominent emoji tile — same visual language as the period tile.
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: AppColors.periodGradient(accent),
                  borderRadius: BorderRadius.circular(Radii.md),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.45),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  activity.emoji,
                  style: const TextStyle(fontSize: 28),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        height: 1.1,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (activity.startTime != null && activity.endTime != null)
                      Text(
                        '${activity.startTime!.format(context)} – ${activity.endTime!.format(context)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: accent,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      )
                    else
                      Text(
                        period.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: accent.withValues(alpha: 0.75),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isLive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.live.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(Radii.pill),
                    border: Border.all(
                      color: AppColors.live.withValues(alpha: 0.40),
                    ),
                  ),
                  child: const Text(
                    'AO VIVO',
                    style: TextStyle(
                      color: AppColors.live,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.edit_rounded, color: accent, size: 16),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StreakBanner extends StatelessWidget {
  const _StreakBanner({required this.streak});
  final int streak;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: streak == 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(Radii.lg),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: const [
                  Text('🔥', style: TextStyle(fontSize: 20)),
                  SizedBox(width: 10),
                  Text(
                    'Poste algo hoje para começar seu streak!',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFF6500).withValues(alpha: 0.16),
                    const Color(0xFFFF9500).withValues(alpha: 0.05),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(Radii.lg),
                border: Border.all(
                  color: const Color(0xFFFF6500).withValues(alpha: 0.45),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6500).withValues(alpha: 0.10),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 26)),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$streak ${streak == 1 ? "dia seguido" : "dias seguidos"}',
                        style: const TextStyle(
                          color: Colors.orange,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        streak >= 7
                            ? 'Incrível! Continua assim 🌟'
                            : 'Continue postando todo dia!',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6500).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(Radii.pill),
                      border: Border.all(
                        color: const Color(0xFFFF6500).withValues(alpha: 0.40),
                      ),
                    ),
                    child: Text(
                      '🔥 $streak',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
