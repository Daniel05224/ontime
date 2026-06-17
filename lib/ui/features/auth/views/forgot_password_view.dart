import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/animations.dart';
import 'auth_shared.dart';

const _redirectUrl = 'com.tenco.ontime://login-callback';

class ForgotPasswordView extends StatefulWidget {
  const ForgotPasswordView({super.key});

  @override
  State<ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<ForgotPasswordView> {
  final _emailController = TextEditingController();
  bool _loading = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    HapticFeedback.mediumImpact();
    setState(() { _loading = true; _error = null; });

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: _redirectUrl,
      );
      if (mounted) setState(() => _sent = true);
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = _translateError(e.message));
    } catch (_) {
      if (mounted) setState(() => _error = 'Erro inesperado. Tente novamente.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _translateError(String message) => switch (message.toLowerCase()) {
    String m when m.contains('rate limit') =>
      'Muitas tentativas. Aguarde alguns minutos.',
    String m when m.contains('invalid email') =>
      'E-mail inválido.',
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
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  EntranceFade(
                    index: 0,
                    child: AuthBackButton(
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(height: 32),

                  const Center(child: VibeTimeHero()),
                  const SizedBox(height: 52),

                  EntranceFade(
                    index: 3,
                    child: const Text(
                      'Esqueci minha senha',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  EntranceFade(
                    index: 4,
                    child: Text(
                      _sent
                          ? 'Link enviado! Verifique seu e-mail e clique no link para redefinir sua senha.'
                          : 'Digite seu e-mail e enviaremos um link para você criar uma nova senha.',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                  ),

                  if (!_sent) ...[
                    const SizedBox(height: 36),
                    EntranceFade(
                      index: 5,
                      child: GlassInput(
                        controller: _emailController,
                        label: 'E-mail',
                        hint: 'seu@email.com',
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                      ),
                    ),
                    const SizedBox(height: 28),
                    EntranceFade(
                      index: 6,
                      child: AuthPrimaryButton(
                        label: 'Enviar link',
                        loading: _loading,
                        onTap: _submit,
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      AuthErrorMessage(message: _error!),
                    ],
                  ] else ...[
                    const SizedBox(height: 40),
                    EntranceFade(
                      index: 5,
                      child: Center(
                        child: _SuccessIcon(),
                      ),
                    ),
                    const SizedBox(height: 32),
                    EntranceFade(
                      index: 6,
                      child: AuthPrimaryButton(
                        label: 'Voltar ao login',
                        loading: false,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.4),
            blurRadius: 24,
            spreadRadius: 4,
          ),
        ],
      ),
      child: const Icon(
        Icons.mark_email_read_rounded,
        color: Colors.white,
        size: 38,
      ),
    );
  }
}
