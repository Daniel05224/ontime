import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/animations.dart';
import 'auth_shared.dart';

class UpdatePasswordView extends StatefulWidget {
  const UpdatePasswordView({super.key});

  @override
  State<UpdatePasswordView> createState() => _UpdatePasswordViewState();
}

class _UpdatePasswordViewState extends State<UpdatePasswordView> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _passwordVisible = false;
  bool _confirmVisible = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (password.isEmpty || confirm.isEmpty) return;

    if (password != confirm) {
      setState(() => _error = 'As senhas não coincidem.');
      return;
    }

    if (password.length < 6) {
      setState(() => _error = 'A senha deve ter pelo menos 6 caracteres.');
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() { _loading = true; _error = null; });

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: password),
      );
      // onAuthStateChange (signedIn) no main.dart vai navegar para HomeView
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = _translateError(e.message));
    } catch (_) {
      if (mounted) setState(() => _error = 'Erro inesperado. Tente novamente.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _translateError(String message) => switch (message.toLowerCase()) {
    String m when m.contains('weak') || m.contains('short') =>
      'A senha é muito fraca. Use pelo menos 6 caracteres.',
    String m when m.contains('same') =>
      'A nova senha deve ser diferente da anterior.',
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
                  const SizedBox(height: 72),

                  const Center(child: VibeTimeHero()),
                  const SizedBox(height: 52),

                  EntranceFade(
                    index: 3,
                    child: const Text(
                      'Nova senha',
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
                      'Escolha uma senha forte para proteger sua conta.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                  ),

                  const SizedBox(height: 36),

                  EntranceFade(
                    index: 5,
                    child: GlassInput(
                      controller: _passwordController,
                      label: 'Nova senha',
                      hint: '••••••••',
                      obscureText: !_passwordVisible,
                      textInputAction: TextInputAction.next,
                      suffix: GestureDetector(
                        onTap: () =>
                            setState(() => _passwordVisible = !_passwordVisible),
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
                  const SizedBox(height: 16),
                  EntranceFade(
                    index: 6,
                    child: GlassInput(
                      controller: _confirmController,
                      label: 'Confirmar senha',
                      hint: '••••••••',
                      obscureText: !_confirmVisible,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      suffix: GestureDetector(
                        onTap: () =>
                            setState(() => _confirmVisible = !_confirmVisible),
                        child: Icon(
                          _confirmVisible
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: AppColors.textTertiary,
                          size: 20,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  EntranceFade(
                    index: 7,
                    child: AuthPrimaryButton(
                      label: 'Salvar nova senha',
                      loading: _loading,
                      onTap: _submit,
                    ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    AuthErrorMessage(message: _error!),
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
