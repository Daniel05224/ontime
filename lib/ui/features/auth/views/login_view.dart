import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/widgets/animations.dart';
import 'auth_shared.dart';
import 'forgot_password_view.dart';
import 'signup_view.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _passwordVisible = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) return;

    HapticFeedback.mediumImpact();
    setState(() { _loading = true; _error = null; });

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
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
    String m when m.contains('invalid login credentials') =>
      'E-mail ou senha incorretos.',
    String m when m.contains('email not confirmed') =>
      'Confirme seu e-mail antes de entrar. Verifique sua caixa de entrada.',
    String m when m.contains('too many requests') =>
      'Muitas tentativas. Aguarde alguns minutos.',
    String m when m.contains('user not found') =>
      'Nenhuma conta encontrada com esse e-mail.',
    _ => message,
  };

  void _goToSignup() {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: AppMotion.normal,
        reverseTransitionDuration: AppMotion.exit,
        pageBuilder: (_, __, ___) => const SignupView(),
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: AppMotion.enterCurve,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0.05, 0),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

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
                  const SizedBox(height: 48),

                  // ── Logo ──────────────────────────────────────────────
                  const Center(child: OnTimeHero()),

                  const SizedBox(height: 52),

                  // ── Heading ───────────────────────────────────────────
                  EntranceFade(
                    index: 3,
                    child: const Text(
                      'Entrar',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  EntranceFade(
                    index: 4,
                    child: const Text(
                      'Bem-vindo de volta 👋',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 15,
                      ),
                    ),
                  ),

                  const SizedBox(height: 36),

                  // ── Fields ────────────────────────────────────────────
                  EntranceFade(
                    index: 5,
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
                    index: 6,
                    child: GlassInput(
                      controller: _passwordController,
                      label: 'Senha',
                      hint: '••••••••',
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
                  const SizedBox(height: 14),
                  EntranceFade(
                    index: 7,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          PageRouteBuilder(
                            transitionDuration: AppMotion.normal,
                            reverseTransitionDuration: AppMotion.exit,
                            pageBuilder: (_, __, ___) =>
                                const ForgotPasswordView(),
                            transitionsBuilder: (_, animation, __, child) {
                              final curved = CurvedAnimation(
                                parent: animation,
                                curve: AppMotion.enterCurve,
                              );
                              return FadeTransition(
                                opacity: curved,
                                child: SlideTransition(
                                  position: Tween(
                                    begin: const Offset(0.05, 0),
                                    end: Offset.zero,
                                  ).animate(curved),
                                  child: child,
                                ),
                              );
                            },
                          ),
                        ),
                        child: const Text(
                          'Esqueci minha senha',
                          style: TextStyle(
                            color: AppColors.primaryBright,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── CTA ───────────────────────────────────────────────
                  EntranceFade(
                    index: 8,
                    child: AuthPrimaryButton(
                      label: 'Entrar',
                      loading: _loading,
                      onTap: _submit,
                    ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    AuthErrorMessage(message: _error!),
                  ],

                  const SizedBox(height: 48),

                  // ── Nav link ──────────────────────────────────────────
                  EntranceFade(
                    index: 9,
                    child: Center(
                      child: AuthNavLink(
                        question: 'Não tem conta? ',
                        actionLabel: 'Criar conta',
                        onTap: _goToSignup,
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

