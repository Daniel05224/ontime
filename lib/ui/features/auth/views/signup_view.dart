import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/widgets/animations.dart';
import 'auth_shared.dart';

class SignupView extends StatefulWidget {
  const SignupView({super.key});

  @override
  State<SignupView> createState() => _SignupViewState();
}

class _SignupViewState extends State<SignupView> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _passwordVisible = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (name.isEmpty || email.isEmpty || password.isEmpty) return;

    HapticFeedback.mediumImpact();
    setState(() { _loading = true; _error = null; });

    try {
      await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {'name': name},
      );
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = _translateError(e.message));
    } catch (_) {
      if (mounted) setState(() => _error = 'Erro inesperado. Tente novamente.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _translateError(String message) => switch (message.toLowerCase()) {
    String m when m.contains('user already registered') =>
      'Já existe uma conta com esse e-mail.',
    String m when m.contains('password should be at least') =>
      'A senha deve ter pelo menos 6 caracteres.',
    String m when m.contains('unable to validate email') =>
      'E-mail inválido.',
    String m when m.contains('too many requests') =>
      'Muitas tentativas. Aguarde alguns minutos.',
    _ => message,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          const AuthBackground(),
          SafeArea(
            child: SingleChildScrollView(
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  // ── Top bar ───────────────────────────────────────────
                  EntranceFade(
                    index: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        AuthBackButton(
                            onTap: () => Navigator.of(context).pop()),
                        ShaderMask(
                          shaderCallback: (b) =>
                              AppColors.brandGradient.createShader(b),
                          child: const Text(
                            'VibeTime',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 44),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // ── Heading ───────────────────────────────────────────
                  EntranceFade(
                    index: 1,
                    child: const Text(
                      'Criar conta',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  EntranceFade(
                    index: 2,
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 15,
                          height: 1.4,
                        ),
                        children: [
                          TextSpan(text: 'Junte-se ao '),
                          TextSpan(
                            text: 'VibeTime',
                            style: TextStyle(
                              color: AppColors.primaryBright,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextSpan(text: ' e compartilhe seu agora ✨'),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // ── Fields ────────────────────────────────────────────
                  EntranceFade(
                    index: 3,
                    child: GlassInput(
                      controller: _nameController,
                      label: 'Seu nome',
                      hint: 'Como quer ser chamado?',
                      keyboardType: TextInputType.name,
                      textInputAction: TextInputAction.next,
                      autofocus: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  EntranceFade(
                    index: 4,
                    child: GlassInput(
                      controller: _emailController,
                      label: 'E-mail',
                      hint: 'seu@email.com',
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                    ),
                  ),
                  const SizedBox(height: 16),
                  EntranceFade(
                    index: 5,
                    child: GlassInput(
                      controller: _passwordController,
                      label: 'Senha',
                      hint: 'Mínimo 8 caracteres',
                      obscureText: !_passwordVisible,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      suffix: GestureDetector(
                        onTap: () => setState(
                            () => _passwordVisible = !_passwordVisible),
                        child: Icon(
                          _passwordVisible
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: AppColors.textTertiary,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  EntranceFade(
                    index: 6,
                    child: _PasswordHint(controller: _passwordController),
                  ),

                  const SizedBox(height: 36),

                  // ── CTA ───────────────────────────────────────────────
                  EntranceFade(
                    index: 7,
                    child: AuthPrimaryButton(
                      label: 'Criar conta',
                      loading: _loading,
                      onTap: _submit,
                    ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    AuthErrorMessage(message: _error!),
                  ],

                  const SizedBox(height: 20),

                  // ── Terms ─────────────────────────────────────────────
                  EntranceFade(
                    index: 8,
                    child: Center(
                      child: Text.rich(
                        const TextSpan(
                          style: TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 12,
                            height: 1.6,
                          ),
                          children: [
                            TextSpan(
                                text:
                                    'Ao criar uma conta você concorda com os '),
                            TextSpan(
                              text: 'Termos de Uso',
                              style: TextStyle(color: AppColors.primaryBright),
                            ),
                            TextSpan(text: ' e a '),
                            TextSpan(
                              text: 'Política de Privacidade',
                              style: TextStyle(color: AppColors.primaryBright),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),

                  const SizedBox(height: 36),

                  // ── Nav link ──────────────────────────────────────────
                  EntranceFade(
                    index: 9,
                    child: Center(
                      child: AuthNavLink(
                        question: 'Já tem conta? ',
                        actionLabel: 'Entrar',
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Password strength indicator ───────────────────────────────────────────────

class _PasswordHint extends StatefulWidget {
  const _PasswordHint({required this.controller});
  final TextEditingController controller;

  @override
  State<_PasswordHint> createState() => _PasswordHintState();
}

class _PasswordHintState extends State<_PasswordHint> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() => setState(() {}));
  }

  int get _strength {
    final p = widget.controller.text;
    if (p.isEmpty) return 0;
    int s = 0;
    if (p.length >= 8) s++;
    if (p.contains(RegExp(r'[A-Z]'))) s++;
    if (p.contains(RegExp(r'[0-9]'))) s++;
    if (p.contains(RegExp(r'[!@#\$%^&*]'))) s++;
    return s;
  }

  Color get _color => switch (_strength) {
        0 => AppColors.textTertiary,
        1 => AppColors.danger,
        2 => AppColors.secondary,
        3 => AppColors.morning,
        _ => AppColors.live,
      };

  String get _label => switch (_strength) {
        0 => '',
        1 => 'Fraca',
        2 => 'Regular',
        3 => 'Boa',
        _ => 'Forte',
      };

  @override
  Widget build(BuildContext context) {
    if (widget.controller.text.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        for (int i = 0; i < 4; i++) ...[
          Expanded(
            child: AnimatedContainer(
              duration: AppMotion.fast,
              height: 3,
              decoration: BoxDecoration(
                color: i < _strength
                    ? _color
                    : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          if (i < 3) const SizedBox(width: 4),
        ],
        const SizedBox(width: 10),
        AnimatedDefaultTextStyle(
          duration: AppMotion.fast,
          style: TextStyle(
            color: _color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
          child: Text(_label),
        ),
      ],
    );
  }
}
