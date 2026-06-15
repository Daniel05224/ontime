import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../../../data/services/notification_service.dart';
import '../../../../data/services/supabase_profile_service.dart';
import '../../../../data/services/supabase_status_service.dart';
import '../../../../domain/models/activity.dart';
import '../../../../domain/models/quick_suggestion.dart';
import '../../../../domain/models/vibe.dart';
import '../../../core/responsive/responsive_breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/widgets/animations.dart';
import '../../friends/view_models/feed_view_model.dart';
import '../../routine/view_models/routine_view_model.dart';

enum ComposerTab { now, day }

/// Vibe-first status composer.
///
/// "Agora" lets you set your live status in one or two taps — the headline
/// action being the simple **Livre agora 🙌**. "Meu dia" lets you sketch the
/// whole day by tapping a vibe onto each period — no typing, no exact times.
class StatusComposerView extends StatefulWidget {
  const StatusComposerView({
    super.key,
    this.initialTab = ComposerTab.now,
    this.focusPeriod,
    this.prefillDayPlan,
  });

  final ComposerTab initialTab;
  final RoutinePeriod? focusPeriod;
  final Map<RoutinePeriod, Vibe>? prefillDayPlan;

  @override
  State<StatusComposerView> createState() => _StatusComposerViewState();
}

class _StatusComposerViewState extends State<StatusComposerView> {
  static const _uuid = Uuid();

  late ComposerTab _tab = widget.prefillDayPlan != null
      ? ComposerTab.day
      : widget.initialTab;
  Vibe? _selectedNow;
  final Map<RoutinePeriod, Vibe?> _dayPlan = {};
  bool _suggestionDismissed = false;
  bool _initialized = false;
  Map<RoutinePeriod, Vibe>? _yesterdayPlan;

  Uint8List? _photoBytes;
  String _photoExt = 'jpg';
  bool _posting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    // Pré-seleciona a vibe do status ao vivo, se houver
    final vm = context.read<RoutineViewModel>();
    final liveActivity = vm.currentUser.currentActivity;
    if (liveActivity != null && liveActivity.isLive && !liveActivity.isExpired) {
      final suggestions = vm.quickSuggestions;
      for (var i = 0; i < suggestions.length; i++) {
        if (suggestions[i].emoji == liveActivity.emoji &&
            suggestions[i].title.toLowerCase() == liveActivity.title.toLowerCase()) {
          _selectedNow = _toVibe(suggestions[i], i);
          break;
        }
      }
      // Fallback: cria Vibe diretamente da atividade
      _selectedNow ??= Vibe(
        emoji: liveActivity.emoji,
        label: liveActivity.title,
        color: liveActivity.color,
      );
    }

    if (widget.prefillDayPlan != null) {
      for (final p in RoutinePeriod.values) {
        _dayPlan[p] = widget.prefillDayPlan![p] ??
            (p == RoutinePeriod.night ? Vibe.sleeping : null);
      }
    } else {
      for (final p in RoutinePeriod.values) {
        final acts = vm.getActivitiesByPeriod(p);
        if (acts.isNotEmpty) {
          _dayPlan[p] = Vibe.fromActivity(acts.first);
        } else {
          _dayPlan[p] = p == RoutinePeriod.night ? Vibe.sleeping : null;
        }
      }
    }

    // Carrega o plano de ontem do Supabase para sugestão
    SupabaseStatusService.instance.loadYesterdayPlan().then((plan) {
      if (!mounted) return;
      final filled = Map<RoutinePeriod, Vibe>.fromEntries(
        plan.entries.where((e) => e.value != null).map((e) => MapEntry(e.key, e.value!)),
      );
      if (filled.isNotEmpty) setState(() => _yesterdayPlan = filled);
    }).catchError((_) {});

    if (widget.focusPeriod != null) {
      _tab = ComposerTab.day;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _openPicker(widget.focusPeriod!),
      );
    }
  }

  // ── Actions ────────────────────────────────────────────────────────────

  void _showEndTimePicker(Vibe vibe) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EndTimeSheet(
        vibe: vibe,
        onConfirm: (endsAt) => _postNow(vibe, endsAt),
      ),
    );
  }

  Future<void> _showPhotoQuestion(Vibe vibe) async {
    HapticFeedback.mediumImpact();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PhotoQuestionSheet(
        vibe: vibe,
        onCaptured: (bytes, ext) {
          setState(() {
            _photoBytes = bytes;
            _photoExt = ext;
          });
          Navigator.of(context).pop();
          _showEndTimePicker(vibe);
        },
        onSkip: () {
          Navigator.of(context).pop();
          _showEndTimePicker(vibe);
        },
      ),
    );
  }

  Future<void> _postNow(Vibe vibe, DateTime endsAt) async {
    if (_posting) return;
    setState(() => _posting = true);

    String? photoUrl;
    if (_photoBytes != null) {
      try {
        photoUrl = await SupabaseProfileService.instance
            .uploadVibePhoto(_photoBytes!, _photoExt);
      } catch (_) {}
    }

    if (!mounted) return;
    try {
      // Salva APENAS em statuses — não toca no day_plan
      await SupabaseStatusService.instance.postNow(
        vibe,
        currentPeriod(),
        photoUrl: photoUrl,
        endsAt: endsAt,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Sem conexão. Verifique seu Wi-Fi.',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      setState(() => _posting = false);
      return;
    }
    if (!mounted) return;
    // Atualiza imediatamente o estado local → MyDayView reflete na hora
    final routineVm = context.read<RoutineViewModel>();
    routineVm.setLiveStatus(vibe, currentPeriod(), endsAt: endsAt, photoUrl: photoUrl);
    routineVm.scheduleStatusExpiry(endsAt);
    routineVm.refreshStreak(); // fire-and-forget
    final feedVm = context.read<FeedViewModel>();
    feedVm.onPosted();
    feedVm.scheduleRefreshAt(endsAt);
    NotificationService.instance.scheduleExpiry(endsAt); // fire-and-forget
    HapticFeedback.mediumImpact();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _saveDay() async {
    if (_posting) return;
    setState(() => _posting = true);

    final vm = context.read<RoutineViewModel>();
    final now = currentPeriod();
    final currentVibe = _dayPlan[now];
    final hasAny = _dayPlan.values.any((v) => v != null);

    // Atualiza estado local imediatamente
    _dayPlan.forEach((period, vibe) {
      vm.setPeriodActivity(
        period,
        vibe?.toActivity(id: _uuid.v4(), period: period),
      );
    });

    try {
      if (!hasAny) {
        await SupabaseStatusService.instance.clearTodayData();
        if (!mounted) return;
        context.read<FeedViewModel>().refresh();
      } else if (currentVibe == null) {
        await SupabaseStatusService.instance.saveDayPlan(_dayPlan);
        if (!mounted) return;
        context.read<FeedViewModel>().refresh();
        vm.refreshStreak(); // fire-and-forget
      } else {
        await SupabaseStatusService.instance.saveDayPlan(_dayPlan);
        if (!mounted) return;
        context.read<FeedViewModel>().onPosted();
        vm.refreshStreak(); // fire-and-forget
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Sem conexão. Verifique seu Wi-Fi.',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _posting = false);
      }
      return;
    }

    HapticFeedback.mediumImpact();
    if (mounted) Navigator.of(context).pop();
  }

  void _applySuggestion(Map<RoutinePeriod, Vibe> suggestion) {
    setState(() {
      for (final p in RoutinePeriod.values) {
        _dayPlan[p] = suggestion[p];
      }
    });
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: const Text('Dia montado! Ajuste se quiser. ✨'),
          backgroundColor: AppColors.surfaceHigh,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radii.md)),
        ),
      );
  }

  Future<void> _openPicker(RoutinePeriod period) async {
    final vm = context.read<RoutineViewModel>();
    final suggestions = vm.quickSuggestions;
    final allVibes = [
      for (var i = 0; i < suggestions.length; i++)
        (vibe: _toVibe(suggestions[i], i), index: i),
    ];
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VibePickerSheet(
        period: period,
        current: _dayPlan[period],
        vibes: allVibes,
        onSelect: (v) {
          setState(() => _dayPlan[period] = v);
          Navigator.of(context).pop();
        },
        onAddCustom: _showAddVibe,
      ),
    );
  }

  // Converte QuickSuggestion em Vibe, preservando a cor do catálogo se disponível.
  Vibe _toVibe(QuickSuggestion s, int i) {
    final catalogColor = Vibe.catalog
        .where((v) => v.label.toLowerCase() == s.title.toLowerCase())
        .map((v) => v.color)
        .firstOrNull;
    return Vibe(
      emoji: s.emoji,
      label: s.title,
      color: catalogColor ?? Vibe.customColor(i),
    );
  }

  void _showAddVibe([void Function(Vibe)? thenSelect]) {
    String emoji = '';
    String label = '';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
      ),
      builder: (sheetCtx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Nova vibe',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 20),
              Row(
                children: [
                  SizedBox(
                    width: 64,
                    child: TextField(
                      autofocus: true,
                      maxLength: 4,
                      textAlign: TextAlign.center,
                      cursorColor: AppColors.primary,
                      style: const TextStyle(fontSize: 34),
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(
                            RegExp(r'[a-zA-Z0-9\s]')),
                      ],
                      decoration: const InputDecoration(
                        hintText: '😎',
                        counterText: '',
                        border: InputBorder.none,
                      ),
                      onChanged: (v) => emoji = v,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      cursorColor: AppColors.primary,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w600),
                      decoration: const InputDecoration(
                        hintText: 'Uma palavra...',
                        hintStyle: TextStyle(color: AppColors.textTertiary),
                        border: InputBorder.none,
                      ),
                      onChanged: (v) => label = v,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _GradientButton(
                label: 'Criar vibe',
                gradient: AppColors.brandGradient,
                onTap: () {
                  if (emoji.isEmpty || label.trim().isEmpty) return;
                  final vm = context.read<RoutineViewModel>();
                  vm.addQuickSuggestion(label.trim(), emoji);
                  Navigator.of(sheetCtx).pop();
                  if (thenSelect != null) {
                    thenSelect(Vibe(
                        emoji: emoji,
                        label: label.trim(),
                        color: Vibe.customColor(vm.quickSuggestions.length)));
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    context.watch<RoutineViewModel>(); // reconstrói quando vibes mudam
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: formMaxWidth),
                child: Column(
                  children: [
                    _buildHeader(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                      child: _SegmentedTabs(
                        tab: _tab,
                        onChanged: (t) {
                          HapticFeedback.selectionClick();
                          setState(() => _tab = t);
                        },
                      ),
                    ),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: AppMotion.normal,
                        switchInCurve: AppMotion.enterCurve,
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween(
                              begin: const Offset(0, 0.03),
                              end: Offset.zero,
                            ).animate(anim),
                            child: child,
                          ),
                        ),
                        child: _tab == ComposerTab.now
                            ? _buildNowTab(key: const ValueKey('now'))
                            : _buildDayTab(key: const ValueKey('day')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded,
                color: AppColors.textPrimary, size: 28),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Spacer(),
          const Text('Bora?',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
          const Spacer(),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  // ── AGORA TAB ──────────────────────────────────────────────────────────
  Widget _buildNowTab({Key? key}) {
    final suggestions = context.read<RoutineViewModel>().quickSuggestions;
    final bottomPad = MediaQuery.paddingOf(context).bottom + 96;
    return ListView(
      key: key,
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: EdgeInsets.fromLTRB(20, 8, 20, bottomPad),
      children: [
        EntranceFade(
          index: 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'O que está rolando agora?',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Toque numa vibe e conta pra galera ✨',
                style: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        EntranceFade(
          index: 1,
          child: LayoutBuilder(
            builder: (ctx, constraints) {
              const cols = 3;
              const gap = 12.0;
              final cell = (constraints.maxWidth - gap * (cols - 1)) / cols;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (var i = 0; i < suggestions.length; i++)
                    Builder(builder: (context) {
                      final vibe = _toVibe(suggestions[i], i);
                      return SizedBox(
                        width: cell,
                        height: cell,
                        child: _VibeCard(
                          vibe: vibe,
                          selected: _selectedNow == vibe,
                          onTap: () => setState(() =>
                              _selectedNow =
                                  _selectedNow == vibe ? null : vibe),
                          onLongPress: () => _editCustomVibe(i, vibe),
                        ),
                      );
                    }),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        EntranceFade(
          index: 2,
          child: _AddVibeInputBar(onTap: () => _showAddVibe()),
        ),
      ],
    );
  }

  void _editCustomVibe(int index, Vibe vibe) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditVibeSheet(
        initialEmoji: vibe.emoji,
        initialLabel: vibe.label,
        onSave: (emoji, label) {
          context.read<RoutineViewModel>().updateQuickSuggestion(index, label, emoji);
          if (_selectedNow == vibe) setState(() => _selectedNow = null);
        },
        onDelete: () {
          context.read<RoutineViewModel>().removeQuickSuggestion(index);
          if (_selectedNow == vibe) setState(() => _selectedNow = null);
        },
      ),
    );
  }

  // ── MEU DIA TAB ──────────────────────────────────────────────────────────
  Widget _buildDayTab({Key? key}) {
    final assigned = _dayPlan.values.where((v) => v != null).length;
    final bottomPad = MediaQuery.paddingOf(context).bottom + 96;
    return ListView(
      key: key,
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: EdgeInsets.fromLTRB(20, 4, 20, bottomPad),
      children: [
        if (!_suggestionDismissed && _yesterdayPlan != null)
          EntranceFade(
            index: 0,
            child: _SuggestionCard(
              suggestion: _yesterdayPlan!,
              onYes: () => _applySuggestion(_yesterdayPlan!),
              onDismiss: () => setState(() => _suggestionDismissed = true),
            ),
          ),
        const SizedBox(height: 20),
        EntranceFade(
          index: 1,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Seu dia',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              Text('$assigned/4',
                  style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        const EntranceFade(
          index: 2,
          child: Text(
            'Toque num bloco e jogue uma vibe nele. Sem horário, sem stress.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ),
        const SizedBox(height: 20),
        EntranceFade(index: 3, child: _buildDaySequence()),
      ],
    );
  }

  Widget _buildDaySequence() {
    final p = RoutinePeriod.values;
    const gap = 12.0;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _DayBlock(
                period: p[0],
                vibe: _dayPlan[p[0]],
                onTap: () => _openPicker(p[0]),
              ),
            ),
            const SizedBox(width: gap),
            Expanded(
              child: _DayBlock(
                period: p[1],
                vibe: _dayPlan[p[1]],
                onTap: () => _openPicker(p[1]),
              ),
            ),
          ],
        ),
        const SizedBox(height: gap),
        Row(
          children: [
            Expanded(
              child: _DayBlock(
                period: p[2],
                vibe: _dayPlan[p[2]],
                onTap: () => _openPicker(p[2]),
              ),
            ),
            const SizedBox(width: gap),
            Expanded(
              child: _DayBlock(
                period: p[3],
                vibe: _dayPlan[p[3]],
                onTap: () => _openPicker(p[3]),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── BOTTOM BAR ────────────────────────────────────────────────────────────
  Widget _buildBottomBar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.canvas.withValues(alpha: 0),
            AppColors.canvas.withValues(alpha: 0.92),
            AppColors.canvas,
          ],
          stops: const [0.0, 0.35, 1.0],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: formMaxWidth),
              child: _tab == ComposerTab.now ? _nowCta() : _dayCta(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _nowCta() {
    final v = _selectedNow;
    if (v == null) {
      return const SizedBox(
        height: 56,
        child: Center(
          child: Text(
            'Toque numa vibe para começar',
            style: TextStyle(color: AppColors.textTertiary, fontSize: 14),
          ),
        ),
      );
    }
    final hasLive = context.read<RoutineViewModel>().currentUser.currentActivity?.isLive ?? false;
    final label = hasLive
        ? 'Atualizar  ${v.emoji}  ${v.label}'
        : 'Postar  ${v.emoji}  ${v.label}';
    return _GradientButton(
      label: label,
      gradient: AppColors.duotone(v.color),
      glow: v.color,
      loading: _posting,
      onTap: () => _showPhotoQuestion(v),
    );
  }

  Widget _dayCta() {
    final hasAny = _dayPlan.values.any((v) => v != null);
    return _GradientButton(
      label: hasAny ? 'Salvar meu dia' : 'Limpar planejamento',
      gradient: AppColors.brandGradient,
      glow: AppColors.secondary,
      onTap: _saveDay,
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
// Pieces
// ════════════════════════════════════════════════════════════════════════

class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({required this.tab, required this.onChanged});
  final ComposerTab tab;
  final ValueChanged<ComposerTab> onChanged;

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
          AnimatedAlign(
            duration: AppMotion.normal,
            curve: AppMotion.enterCurve,
            alignment: tab == ComposerTab.now
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
          Row(
            children: [
              _segment('Agora', ComposerTab.now),
              _segment('Meu dia', ComposerTab.day),
            ],
          ),
        ],
      ),
    );
  }

  Widget _segment(String label, ComposerTab value) {
    final selected = tab == value;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(value),
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: AppMotion.fast,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontSize: 15,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}


/// Square vibe card — the primary selection unit.
/// Resting state carries the vibe's own color as a tint so the palette
/// reads like a color grid, not a list of identical gray buttons.
class _VibeCard extends StatelessWidget {
  const _VibeCard({
    required this.vibe,
    required this.selected,
    required this.onTap,
    this.onLongPress,
  });

  final Vibe vibe;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    vibe.color,
                    Color.lerp(vibe.color, const Color(0xFF0B0B12), 0.42)!,
                  ],
                )
              : null,
          color: selected ? null : vibe.color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(
            color: selected
                ? vibe.color
                : vibe.color.withValues(alpha: 0.32),
            width: selected ? 1.5 : 1.0,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: vibe.color.withValues(alpha: 0.42),
                    blurRadius: 22,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              duration: AppMotion.fast,
              scale: selected ? 1.18 : 1.0,
              child: Text(vibe.emoji,
                  style: const TextStyle(fontSize: 34)),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: AnimatedDefaultTextStyle(
                duration: AppMotion.fast,
                style: TextStyle(
                  color:
                      selected ? Colors.white : AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight:
                      selected ? FontWeight.w800 : FontWeight.w600,
                ),
                child: Text(
                  vibe.label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddVibeTile extends StatelessWidget {
  const _AddVibeTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.30),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.add_rounded,
                  color: AppColors.primaryBright, size: 22),
            ),
            const SizedBox(height: 6),
            const Text(
              'Criar',
              style: TextStyle(
                color: AppColors.primaryBright,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Full-width tappable input bar — opens the add-vibe modal when tapped.
class _AddVibeInputBar extends StatelessWidget {
  const _AddVibeInputBar({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            const Text('✨', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Nova vibe...',
                style: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_rounded,
                  color: AppColors.primaryBright, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayBlock extends StatelessWidget {
  const _DayBlock({
    required this.period,
    required this.vibe,
    required this.onTap,
  });

  final RoutinePeriod period;
  final Vibe? vibe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final filled = vibe != null;
    final color = vibe?.color ?? AppColors.textTertiary;

    return PressableScale(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${period.glyph} ${period.label}',
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(period.clock,
              style: const TextStyle(
                  color: AppColors.textTertiary, fontSize: 11)),
          const SizedBox(height: 10),
          AnimatedContainer(
            duration: AppMotion.normal,
            curve: Curves.easeInOut,
            height: 152,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: filled ? AppColors.periodGradient(color) : null,
              color: filled ? null : AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(Radii.lg),
              border: Border.all(
                color: filled
                    ? color.withValues(alpha: 0.6)
                    : AppColors.border,
                width: filled ? 1.5 : 1,
              ),
              boxShadow: filled
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      )
                    ]
                  : null,
            ),
            child: filled
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(vibe!.emoji,
                          style: const TextStyle(fontSize: 44)),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          vibe!.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  )
                : const Icon(Icons.add_rounded,
                    color: AppColors.textTertiary, size: 36),
          ),
        ],
      ),
    );
  }
}


// ── Editar vibe customizada ───────────────────────────────────────────────────

class _EditVibeSheet extends StatefulWidget {
  const _EditVibeSheet({
    required this.initialEmoji,
    required this.initialLabel,
    required this.onSave,
    required this.onDelete,
  });

  final String initialEmoji;
  final String initialLabel;
  final void Function(String emoji, String label) onSave;
  final VoidCallback onDelete;

  @override
  State<_EditVibeSheet> createState() => _EditVibeSheetState();
}

class _EditVibeSheetState extends State<_EditVibeSheet> {
  late final TextEditingController _emojiCtrl =
      TextEditingController(text: widget.initialEmoji);
  late final TextEditingController _labelCtrl =
      TextEditingController(text: widget.initialLabel);

  @override
  void dispose() {
    _emojiCtrl.dispose();
    _labelCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final emoji = _emojiCtrl.text.trim();
    final label = _labelCtrl.text.trim();
    if (emoji.isEmpty || label.isEmpty) return;
    widget.onSave(emoji, label);
    Navigator.of(context).pop();
  }

  void _delete() {
    widget.onDelete();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24,
        right: 24,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Editar vibe',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),
          Row(
            children: [
              SizedBox(
                width: 64,
                child: TextField(
                  controller: _emojiCtrl,
                  autofocus: true,
                  maxLength: 4,
                  textAlign: TextAlign.center,
                  cursorColor: AppColors.primary,
                  style: const TextStyle(fontSize: 34),
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(
                        RegExp(r'[a-zA-Z0-9\s]')),
                  ],
                  decoration: const InputDecoration(
                    counterText: '',
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _labelCtrl,
                  cursorColor: AppColors.primary,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(
                    hintText: 'Nome da vibe',
                    hintStyle: TextStyle(color: AppColors.textTertiary),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _save(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _GradientButton(
            label: 'Salvar',
            gradient: AppColors.brandGradient,
            onTap: _save,
          ),
          const SizedBox(height: 12),
          PressableScale(
            onTap: _delete,
            child: Container(
              width: double.infinity,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(Radii.md),
                border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.3)),
              ),
              child: const Text('Excluir vibe',
                  style: TextStyle(
                      color: AppColors.danger,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.suggestion,
    required this.onYes,
    required this.onDismiss,
  });

  final Map<RoutinePeriod, Vibe> suggestion;
  final VoidCallback onYes;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final emojis = [
      for (final p in RoutinePeriod.values)
        if (suggestion[p] != null) suggestion[p]!.emoji,
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.18),
            AppColors.secondary.withValues(alpha: 0.12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🔁', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Repetir o dia de ontem?',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800),
                ),
              ),
              GestureDetector(
                onTap: onDismiss,
                behavior: HitTestBehavior.opaque,
                child: const Icon(Icons.close_rounded,
                    color: AppColors.textTertiary, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (var i = 0; i < emojis.length; i++) ...[
                Text(emojis[i], style: const TextStyle(fontSize: 24)),
                if (i < emojis.length - 1)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.arrow_forward_rounded,
                        color: AppColors.textTertiary, size: 16),
                  ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          _GradientButton(
            label: 'Sim, repetir',
            gradient: AppColors.brandGradient,
            height: 48,
            onTap: onYes,
          ),
        ],
      ),
    );
  }
}

class _VibePickerSheet extends StatelessWidget {
  const _VibePickerSheet({
    required this.period,
    required this.current,
    required this.vibes,
    required this.onSelect,
    required this.onAddCustom,
  });

  final RoutinePeriod period;
  final Vibe? current;
  final List<({Vibe vibe, int index})> vibes;
  final ValueChanged<Vibe?> onSelect;
  final void Function(void Function(Vibe)) onAddCustom;

  @override
  Widget build(BuildContext context) {
    final allVibes = vibes.map((c) => c.vibe).toList();
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.borderStrong,
                      borderRadius: BorderRadius.circular(Radii.pill),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Text('${period.glyph}  ${period.label}',
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800)),
                    const Spacer(),
                    if (current != null || period == RoutinePeriod.night)
                      GestureDetector(
                        onTap: () => onSelect(null),
                        behavior: HitTestBehavior.opaque,
                        child: const Text('Limpar',
                            style: TextStyle(
                                color: AppColors.danger,
                                fontSize: 14,
                                fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 28 + bottomInset),
              child: LayoutBuilder(
                builder: (ctx, constraints) {
                  const cols = 3;
                  const gap = 12.0;
                  final cell =
                      (constraints.maxWidth - gap * (cols - 1)) / cols;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final v in allVibes)
                        SizedBox(
                          width: cell,
                          height: cell,
                          child: _VibeCard(
                            vibe: v,
                            selected: current == v,
                            onTap: () => onSelect(v),
                          ),
                        ),
                      SizedBox(
                        width: cell,
                        height: cell,
                        child: _AddVibeTile(
                            onTap: () => onAddCustom(onSelect)),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label,
    required this.gradient,
    required this.onTap,
    this.glow,
    this.height = 56,
    this.loading = false,
  });

  final String label;
  final Gradient gradient;
  final VoidCallback onTap;
  final Color? glow;
  final double height;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: loading ? null : onTap,
      child: Container(
        width: double.infinity,
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(Radii.md),
          boxShadow: glow != null
              ? [
                  BoxShadow(
                    color: glow!.withValues(alpha: 0.4),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  )
                ]
              : null,
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2),
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Photo question sheet
// ─────────────────────────────────────────────────────────────────────────────

class _PhotoQuestionSheet extends StatefulWidget {
  const _PhotoQuestionSheet({
    required this.vibe,
    required this.onCaptured,
    required this.onSkip,
  });
  final Vibe vibe;
  final void Function(Uint8List bytes, String ext) onCaptured;
  final VoidCallback onSkip;

  @override
  State<_PhotoQuestionSheet> createState() => _PhotoQuestionSheetState();
}

class _PhotoQuestionSheetState extends State<_PhotoQuestionSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  late final Animation<double> _fade = CurvedAnimation(
    parent: _ctrl,
    curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
  );

  late final Animation<Offset> _slide = Tween(
    begin: const Offset(0, 0.08),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic)));

  CameraController? _camera;
  List<CameraDescription> _cameras = const [];
  int _camIndex = 0;
  bool _initializing = true;
  bool _capturing = false;
  bool _flashOn = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _setupCamera();
  }

  Future<void> _setupCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() {
          _initializing = false;
          _error = 'Nenhuma câmera encontrada';
        });
        return;
      }
      // Prefere a câmera frontal para o "registro do momento".
      _camIndex = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      if (_camIndex < 0) _camIndex = 0;
      await _startController(_cameras[_camIndex]);
    } catch (e) {
      if (mounted) {
        setState(() {
          _initializing = false;
          _error = 'Não foi possível abrir a câmera';
        });
      }
    }
  }

  Future<void> _startController(CameraDescription desc) async {
    final controller = CameraController(
      desc,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    await controller.initialize();
    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() {
      _camera = controller;
      _initializing = false;
      _error = null;
    });
  }

  Future<void> _flipCamera() async {
    if (_cameras.length < 2) return;
    HapticFeedback.selectionClick();
    final old = _camera;
    setState(() {
      _camera = null;
      _initializing = true;
    });
    await old?.dispose();
    _camIndex = (_camIndex + 1) % _cameras.length;
    await _startController(_cameras[_camIndex]);
  }

  Future<void> _toggleFlash() async {
    final cam = _camera;
    if (cam == null || !cam.value.isInitialized) return;
    HapticFeedback.selectionClick();
    try {
      final newFlashMode =
          _flashOn ? FlashMode.off : FlashMode.torch;
      await cam.setFlashMode(newFlashMode);
      setState(() => _flashOn = !_flashOn);
    } catch (_) {}
  }

  Future<void> _capture() async {
    final cam = _camera;
    if (cam == null || _capturing || !cam.value.isInitialized) return;
    setState(() => _capturing = true);
    HapticFeedback.mediumImpact();
    try {
      final file = await cam.takePicture();
      final bytes = await file.readAsBytes();
      final ext = file.path.split('.').last.toLowerCase();
      if (!mounted) return;
      widget.onCaptured(bytes, ext.isEmpty ? 'jpg' : ext);
    } catch (_) {
      if (mounted) setState(() => _capturing = false);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _camera?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cam = _camera;
    final ready = cam != null && cam.value.isInitialized;
    final topPad = MediaQuery.paddingOf(context).top;
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Câmera ao vivo em tela cheia ──────────────────────────────
              if (ready)
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: cam.value.previewSize!.height,
                    height: cam.value.previewSize!.width,
                    child: CameraPreview(cam),
                  ),
                )
              else
                Container(
                  color: Colors.black,
                  alignment: Alignment.center,
                  child: _initializing
                      ? const SizedBox(
                          width: 34,
                          height: 34,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white70,
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _error ?? 'Câmera indisponível',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                ),

              // ── Gradiente superior (título) ───────────────────────────────
              Positioned(
                top: 0, left: 0, right: 0, height: topPad + 180,
                child: const IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x99000000), Colors.transparent],
                      ),
                    ),
                  ),
                ),
              ),

              // ── Gradiente inferior (controles) ────────────────────────────
              Positioned(
                bottom: 0, left: 0, right: 0, height: 240,
                child: const IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xCC000000)],
                      ),
                    ),
                  ),
                ),
              ),

              // ── Título ────────────────────────────────────────────────────
              Positioned(
                top: topPad + 60,
                left: 24,
                right: 24,
                child: Column(
                  children: [
                    ShaderMask(
                      shaderCallback: (b) =>
                          AppColors.brandGradient.createShader(b),
                      child: const Text(
                        'Registrar o momento? 📸',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Mostre a vibe "${widget.vibe.label}" pra galera!',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Botão fechar (X) ──────────────────────────────────────────
              Positioned(
                top: topPad + 54,
                left: 12,
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    Navigator.of(context).pop();
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 24),
                  ),
                ),
              ),

              // ── Botão flash (superior direito) ─────────────────────────
              Positioned(
                top: topPad + 54,
                right: 12,
                child: GestureDetector(
                  onTap: _toggleFlash,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _flashOn
                          ? Colors.amber.withValues(alpha: 0.8)
                          : Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _flashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),

              // ── Controles inferiores: flip + shutter + "só postar" ───────────
              Positioned(
                left: 0,
                right: 0,
                bottom: bottomPad + 20,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Shutter + Flip camera
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Botão trocar câmera (esquerda)
                        if (_cameras.length > 1)
                          Padding(
                            padding: const EdgeInsets.only(right: 24),
                            child: GestureDetector(
                              onTap: _flipCamera,
                              child: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.cameraswitch_rounded,
                                    color: Colors.white, size: 22),
                              ),
                            ),
                          )
                        else
                          const SizedBox(width: 62),
                        // Shutter (centro)
                        GestureDetector(
                          onTap: ready ? _capture : null,
                          child: Opacity(
                            opacity: ready ? 1 : 0.4,
                            child: Container(
                              width: 78,
                              height: 78,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.25),
                                border: Border.all(color: Colors.white, width: 3),
                              ),
                              child: Center(
                                child: _capturing
                                    ? const SizedBox(
                                        width: 28,
                                        height: 28,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Container(
                                        width: 60,
                                        height: 60,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 62),
                      ],
                    ),
                    const SizedBox(height: 18),
                    // Só postar
                    GestureDetector(
                      onTap: widget.onSkip,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(Radii.pill),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25)),
                        ),
                        child: const Text(
                          'Só postar mesmo  🚀',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
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
// End time picker sheet
// ─────────────────────────────────────────────────────────────────────────────

class _EndTimeSheet extends StatefulWidget {
  const _EndTimeSheet({required this.vibe, required this.onConfirm});
  final Vibe vibe;
  final void Function(DateTime endsAt) onConfirm;

  @override
  State<_EndTimeSheet> createState() => _EndTimeSheetState();
}

class _EndTimeSheetState extends State<_EndTimeSheet>
    with TickerProviderStateMixin {
  int? _selectedMinutes;
  DateTime? _customEnd;

  late final AnimationController _enterCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  static const _presets = [
    (minutes: 15, label: '15 min', emoji: '⚡'),
    (minutes: 30, label: '30 min', emoji: '🎯'),
    (minutes: 60, label: '1 hora', emoji: '🔥'),
    (minutes: 90, label: '1h 30', emoji: '🚀'),
    (minutes: 120, label: '2 horas', emoji: '💪'),
    (minutes: 180, label: '3 horas', emoji: '🌙'),
  ];

  static const _maxMinutes = 240.0;

  DateTime? get _endsAt {
    if (_customEnd != null) return _customEnd;
    if (_selectedMinutes == null) return null;
    return DateTime.now().add(Duration(minutes: _selectedMinutes!));
  }

  double get _progress {
    if (_customEnd != null) {
      final mins = _customEnd!.difference(DateTime.now()).inMinutes;
      return (mins / _maxMinutes).clamp(0.0, 1.0);
    }
    if (_selectedMinutes == null) return 0.0;
    return (_selectedMinutes! / _maxMinutes).clamp(0.0, 1.0);
  }

  String get _endLabel {
    final end = _endsAt;
    if (end == null) return '--:--';
    return '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    super.dispose();
  }

  void _selectPreset(int minutes) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedMinutes = minutes;
      _customEnd = null;
    });
  }

  Future<void> _pickCustom() async {
    final now = DateTime.now();
    DateTime picked = DateTime(now.year, now.month, now.day, (now.hour + 1) % 24, now.minute);

    final confirmed = await showCupertinoModalPopup<bool>(
      context: context,
      builder: (ctx) => Container(
        height: 300,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
        ),
        child: Column(
          children: [
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancelar',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ),
                  CupertinoButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('OK',
                        style: TextStyle(
                            color: AppColors.primaryBright,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                initialDateTime: picked,
                use24hFormat: true,
                backgroundColor: AppColors.surface,
                onDateTimeChanged: (dt) => picked = dt,
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    var end = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
    if (end.isBefore(now)) end = end.add(const Duration(days: 1));
    HapticFeedback.mediumImpact();
    setState(() {
      _customEnd = end;
      _selectedMinutes = null;
    });
  }

  void _confirm() {
    final end = _endsAt;
    if (end == null) return;
    Navigator.of(context).pop();
    widget.onConfirm(end);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final accent = widget.vibe.color;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.center,
          colors: [
            Color.lerp(AppColors.surface, accent, 0.10)!,
            AppColors.surface,
          ],
        ),
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(Radii.xl)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomPad + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          ShaderMask(
            shaderCallback: (b) => AppColors.brandGradient.createShader(b),
            child: const Text(
              'Até quando? ⏱',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Defina o horário que você termina',
            style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
          ),
          const SizedBox(height: 24),

          // Animated ring + time display
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: _progress),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (_, value, child) => SizedBox(
              width: 170,
              height: 170,
              child: CustomPaint(
                painter: _RingPainter(progress: value, color: accent),
                child: child,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.vibe.emoji,
                      style: const TextStyle(fontSize: 40)),
                  const SizedBox(height: 6),
                  AnimatedSwitcher(
                    duration: AppMotion.fast,
                    child: Text(
                      _endLabel,
                      key: ValueKey(_endLabel),
                      style: TextStyle(
                        color: _endsAt != null
                            ? accent
                            : AppColors.textTertiary,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                    ),
                  ),
                  AnimatedOpacity(
                    duration: AppMotion.fast,
                    opacity: _endsAt != null ? 1 : 0,
                    child: const Text(
                      'até às',
                      style: TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Preset chips — horizontal scroll with staggered entrance
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _presets.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                if (i == _presets.length) {
                  return _CustomChip(
                    selected: _customEnd != null,
                    accent: accent,
                    onTap: _pickCustom,
                  );
                }
                final preset = _presets[i];
                final selected = _selectedMinutes == preset.minutes;
                return AnimatedBuilder(
                  animation: _enterCtrl,
                  builder: (_, child) {
                    final start = i * 0.10;
                    final raw = ((_enterCtrl.value - start) /
                            (1.0 - start))
                        .clamp(0.0, 1.0);
                    final t = Curves.easeOutBack.transform(raw).clamp(0.0, 1.0);
                    return Opacity(
                      opacity: raw.clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, 24 * (1 - t)),
                        child: child,
                      ),
                    );
                  },
                  child: _PresetChip(
                    emoji: preset.emoji,
                    label: preset.label,
                    selected: selected,
                    accent: accent,
                    onTap: () => _selectPreset(preset.minutes),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          // Confirm button
          AnimatedOpacity(
            opacity: _endsAt != null ? 1.0 : 0.45,
            duration: AppMotion.fast,
            child: _GradientButton(
              label: _endsAt != null
                  ? 'Confirmar  ·  até $_endLabel'
                  : 'Escolha uma duração',
              gradient: _endsAt != null
                  ? AppColors.duotone(accent)
                  : LinearGradient(colors: [
                      AppColors.surfaceHigh,
                      AppColors.surfaceHigh
                    ]),
              glow: _endsAt != null ? accent : null,
              onTap: _confirm,
            ),
          ),
        ],
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.duotone(accent) : null,
          color: selected ? null : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(
            color: selected ? accent : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: selected ? 0.40 : 0.0),
              blurRadius: selected ? 16 : 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 15)),
            const SizedBox(width: 6),
            AnimatedDefaultTextStyle(
              duration: AppMotion.fast,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomChip extends StatelessWidget {
  const _CustomChip({
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.18)
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.60)
                : AppColors.primary.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.schedule_rounded,
              color: selected ? accent : AppColors.primaryBright,
              size: 15,
            ),
            const SizedBox(width: 6),
            Text(
              'Personalizar',
              style: TextStyle(
                color: selected ? accent : AppColors.primaryBright,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 12;
    const thickness = 10.0;

    // Background track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withValues(alpha: 0.15)
        ..strokeWidth = thickness
        ..style = PaintingStyle.stroke,
    );

    if (progress <= 0) return;

    // Glow
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      Paint()
        ..color = color.withValues(alpha: 0.22)
        ..strokeWidth = thickness * 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Fill arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      Paint()
        ..color = color
        ..strokeWidth = thickness
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.color != color;
}

