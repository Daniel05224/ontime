import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/widgets/animations.dart';
import '../../home/views/home_view.dart';

const _kOnboardingKey = 'onboarding_complete_v1';

Future<bool> hasSeenOnboarding() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kOnboardingKey) ?? false;
}

Future<void> markOnboardingComplete() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kOnboardingKey, true);
}

// ── Modelo dos slides ─────────────────────────────────────────────────────────

class _Slide {
  const _Slide({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.illustrationBuilder,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Widget Function(BuildContext, Animation<double>) illustrationBuilder;
}

// ── View ──────────────────────────────────────────────────────────────────────

class OnboardingView extends StatefulWidget {
  const OnboardingView({super.key});

  @override
  State<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<OnboardingView>
    with TickerProviderStateMixin {
  final _pageCtrl = PageController();
  int _page = 0;

  late final AnimationController _illu = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat(reverse: true);

  late final AnimationController _orbit = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  )..repeat();

  late final List<_Slide> _slides = [
    _Slide(
      icon: Icons.bolt_rounded,
      color: AppColors.primary,
      title: 'Bem-vindo ao VibeTime!',
      subtitle:
          'Saiba o que seus amigos estão fazendo agora, em tempo real. Nada de notícias de ontem.',
      illustrationBuilder: _buildSlide1,
    ),
    _Slide(
      icon: Icons.auto_awesome_rounded,
      color: AppColors.secondary,
      title: 'Compartilhe sua vibe',
      subtitle:
          'Poste o que você está fazendo agora — livre, trabalhando, na academia, na balada. Seus amigos veem na hora.',
      illustrationBuilder: _buildSlide2,
    ),
    _Slide(
      icon: Icons.waving_hand_rounded,
      color: AppColors.accent,
      title: 'Cutucadas & reações',
      subtitle:
          'Manda uma cutucada pra saber o que o amigo tá fazendo. Reaja ao status dele com um emoji.',
      illustrationBuilder: _buildSlide3,
    ),
    _Slide(
      icon: Icons.chat_bubble_rounded,
      color: AppColors.live,
      title: 'Chat em tempo real',
      subtitle:
          'Converse direto com seus amigos dentro do app, sem precisar sair para o WhatsApp.',
      illustrationBuilder: _buildSlide4,
    ),
  ];

  Widget _buildSlide1(BuildContext ctx, Animation<double> anim) {
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) {
        final t = Curves.easeInOut.transform(anim.value);
        return Stack(
          alignment: Alignment.center,
          children: [
            // Orbe pulsante
            Container(
              width: 160 + t * 24,
              height: 160 + t * 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppColors.primary.withValues(alpha: 0.22),
                  Colors.transparent,
                ]),
              ),
            ),
            // Avatares em órbita
            AnimatedBuilder(
              animation: _orbit,
              builder: (_, __) {
                final angle = _orbit.value * 2 * math.pi;
                return SizedBox(
                  width: 200,
                  height: 200,
                  child: Stack(
                    alignment: Alignment.center,
                    children: List.generate(4, (i) {
                      final a = angle + i * math.pi / 2;
                      return Transform.translate(
                        offset: Offset(math.cos(a) * 80, math.sin(a) * 65),
                        child: _AvatarOrb(
                          index: i,
                          size: 46,
                          active: i % 2 == 0,
                        ),
                      );
                    }),
                  ),
                );
              },
            ),
            // Ícone central
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                gradient: AppColors.brandGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.bolt_rounded,
                  color: Colors.white, size: 36),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSlide2(BuildContext ctx, Animation<double> anim) {
    final vibes = ['🏋️ Na academia', '💻 Trabalhando', '🎮 Jogando', '🎵 Ouvindo música'];
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) {
        final t = Curves.easeInOut.transform(anim.value);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(vibes.length, (i) {
            final delay = i * 0.18;
            final localT = ((anim.value - delay) / (1 - delay)).clamp(0.0, 1.0);
            final slideT = Curves.easeOutCubic.transform(localT);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Transform.translate(
                offset: Offset((1 - slideT) * 60, 0),
                child: Opacity(
                  opacity: slideT.clamp(0.0, 1.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.secondary.withValues(alpha: 0.25 + localT * 0.4),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.secondary.withValues(alpha: 0.12 * t),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Text(
                      vibes[i],
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildSlide3(BuildContext ctx, Animation<double> anim) {
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) {
        final t = Curves.easeInOut.transform(anim.value);
        final poked = anim.value > 0.5;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Balão
            AnimatedContainer(
              duration: AppMotion.normal,
              curve: AppMotion.enterCurve,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                gradient: poked ? AppColors.duotone(AppColors.accent) : null,
                color: poked ? null : AppColors.surfaceHigh,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                  bottomLeft: Radius.circular(6),
                ),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: poked ? 0 : 0.4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: poked ? 0.4 : 0.15),
                    blurRadius: poked ? 24 : 10,
                  ),
                ],
              ),
              child: AnimatedSwitcher(
                duration: AppMotion.fast,
                child: Text(
                  poked ? 'Cutucado! 👋' : 'O que você\nestá fazendo? 👀',
                  key: ValueKey(poked),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: poked ? Colors.white : AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            // Bolinhas conectoras
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Dot(size: 9, active: poked, color: AppColors.accent),
                const SizedBox(width: 3),
                _Dot(size: 6, active: poked, color: AppColors.accent),
              ],
            ),
            const SizedBox(height: 4),
            // Avatar
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.brandGradient,
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.4 + t * 0.4),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.2 + t * 0.25),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: const Icon(Icons.person_rounded,
                  color: Colors.white, size: 30),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSlide4(BuildContext ctx, Animation<double> anim) {
    final msgs = [
      (true, 'Eai, o que tá fazendo? 👀'),
      (false, 'Trabalhando aqui 💻'),
      (true, 'Para mais tarde? 🎮'),
      (false, 'Bora! 🔥'),
    ];
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) {
        final visible = (anim.value * msgs.length).ceil().clamp(0, msgs.length);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(msgs.length, (i) {
            final (isMine, text) = msgs[i];
            final show = i < visible;
            return AnimatedOpacity(
              duration: AppMotion.normal,
              opacity: show ? 1 : 0,
              child: AnimatedSlide(
                duration: AppMotion.normal,
                curve: AppMotion.enterCurve,
                offset: show ? Offset.zero : Offset(isMine ? 0.3 : -0.3, 0),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: isMine
                        ? MainAxisAlignment.end
                        : MainAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        constraints: const BoxConstraints(maxWidth: 220),
                        decoration: BoxDecoration(
                          gradient: isMine
                              ? AppColors.brandGradient
                              : null,
                          color: isMine ? null : AppColors.surfaceElevated,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft:
                                Radius.circular(isMine ? 16 : 4),
                            bottomRight:
                                Radius.circular(isMine ? 4 : 16),
                          ),
                        ),
                        child: Text(
                          text,
                          style: TextStyle(
                            color: isMine
                                ? Colors.white
                                : AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  void _next() {
    HapticFeedback.selectionClick();
    if (_page < _slides.length - 1) {
      _pageCtrl.nextPage(
        duration: AppMotion.normal,
        curve: AppMotion.enterCurve,
      );
    } else {
      _finish();
    }
  }

  void _skip() {
    HapticFeedback.selectionClick();
    _finish();
  }

  Future<void> _finish() async {
    await markOnboardingComplete();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, __, ___) => const HomeView(),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
          child: child,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _illu.dispose();
    _orbit.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_page];
    final isLast = _page == _slides.length - 1;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            // ── Skip ──────────────────────────────────────────────────────
            Align(
              alignment: Alignment.centerRight,
              child: AnimatedOpacity(
                duration: AppMotion.fast,
                opacity: isLast ? 0 : 1,
                child: TextButton(
                  onPressed: isLast ? null : _skip,
                  child: const Text(
                    'Pular',
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),

            // ── Slides ────────────────────────────────────────────────────
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                onPageChanged: (i) {
                  HapticFeedback.lightImpact();
                  setState(() => _page = i);
                },
                itemCount: _slides.length,
                itemBuilder: (ctx, i) {
                  final s = _slides[i];
                  return _SlideContent(
                    slide: s,
                    illu: _illu,
                    orbit: _orbit,
                  );
                },
              ),
            ),

            // ── Dots + botão ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
              child: Column(
                children: [
                  // Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_slides.length, (i) {
                      final active = i == _page;
                      return AnimatedContainer(
                        duration: AppMotion.normal,
                        curve: AppMotion.enterCurve,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: active ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          gradient: active ? AppColors.brandGradient : null,
                          color: active
                              ? null
                              : AppColors.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 28),

                  // CTA
                  _CTAButton(
                    isLast: isLast,
                    color: slide.color,
                    onTap: _next,
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

// ── Slide content ─────────────────────────────────────────────────────────────

class _SlideContent extends StatelessWidget {
  const _SlideContent({
    required this.slide,
    required this.illu,
    required this.orbit,
  });

  final _Slide slide;
  final Animation<double> illu;
  final Animation<double> orbit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Ilustração
          SizedBox(
            height: 260,
            child: Center(
              child: slide.illustrationBuilder(context, illu),
            ),
          ),
          const SizedBox(height: 36),

          // Ícone badge
          EntranceFade(
            index: 0,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: slide.color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: slide.color.withValues(alpha: 0.35),
                ),
              ),
              child: Icon(slide.icon, color: slide.color, size: 24),
            ),
          ),
          const SizedBox(height: 16),

          // Título
          EntranceFade(
            index: 1,
            child: ShaderMask(
              shaderCallback: (b) =>
                  AppColors.brandGradient.createShader(b),
              child: Text(
                slide.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.6,
                  height: 1.15,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Subtítulo
          EntranceFade(
            index: 2,
            child: Text(
              slide.subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Botão CTA ─────────────────────────────────────────────────────────────────

class _CTAButton extends StatelessWidget {
  const _CTAButton({
    required this.isLast,
    required this.color,
    required this.onTap,
  });

  final bool isLast;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.normal,
        curve: AppMotion.enterCurve,
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: BorderRadius.circular(Radii.lg),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.45),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: AppMotion.fast,
            child: Text(
              isLast ? 'Começar agora 🚀' : 'Próximo',
              key: ValueKey(isLast),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _AvatarOrb extends StatelessWidget {
  const _AvatarOrb({required this.index, required this.size, required this.active});

  final int index;
  final double size;
  final bool active;

  static const _colors = [
    AppColors.primary,
    AppColors.secondary,
    AppColors.accent,
    AppColors.live,
  ];

  @override
  Widget build(BuildContext context) {
    final color = _colors[index % _colors.length];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceElevated,
        border: Border.all(
          color: color.withValues(alpha: active ? 0.8 : 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: active ? 0.35 : 0.1),
            blurRadius: active ? 14 : 6,
          ),
        ],
      ),
      child: Icon(
        Icons.person_rounded,
        color: active ? color : AppColors.textTertiary,
        size: size * 0.5,
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.size, required this.active, required this.color});
  final double size;
  final bool active;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.fast,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? color : AppColors.surfaceHigh,
        border: Border.all(
          color: active ? color : AppColors.border,
        ),
      ),
    );
  }
}
