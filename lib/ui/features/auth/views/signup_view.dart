import 'package:flutter/gestures.dart';
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
  bool _acceptedTerms = false;
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
    if (!_acceptedTerms) {
      setState(() => _error = 'Você precisa aceitar os Termos de Uso para continuar.');
      return;
    }

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

  void _showTerms(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _TermsSheet(),
    );
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

                  // ── Terms checkbox ────────────────────────────────────
                  EntranceFade(
                    index: 8,
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _acceptedTerms = !_acceptedTerms),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AnimatedContainer(
                            duration: AppMotion.fast,
                            width: 22,
                            height: 22,
                            margin: const EdgeInsets.only(top: 1),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              gradient: _acceptedTerms
                                  ? AppColors.brandGradient
                                  : null,
                              color: _acceptedTerms
                                  ? null
                                  : Colors.white.withValues(alpha: 0.08),
                              border: Border.all(
                                color: _acceptedTerms
                                    ? AppColors.primaryBright
                                    : Colors.white.withValues(alpha: 0.25),
                              ),
                            ),
                            child: _acceptedTerms
                                ? const Icon(Icons.check_rounded,
                                    color: Colors.white, size: 14)
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                                children: [
                                  const TextSpan(text: 'Li e aceito os '),
                                  TextSpan(
                                    text: 'Termos de Uso',
                                    style: const TextStyle(
                                      color: AppColors.primaryBright,
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.underline,
                                      decorationColor: AppColors.primaryBright,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () => _showTerms(context),
                                  ),
                                  const TextSpan(text: ' e a '),
                                  TextSpan(
                                    text: 'Política de Privacidade',
                                    style: const TextStyle(
                                      color: AppColors.primaryBright,
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.underline,
                                      decorationColor: AppColors.primaryBright,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () => _showTerms(context),
                                  ),
                                  const TextSpan(
                                    text: '. Não toleramos conteúdo ofensivo ou comportamento abusivo.',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
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

// ── Terms of Use sheet ────────────────────────────────────────────────────────

class _TermsSheet extends StatelessWidget {
  const _TermsSheet();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF12121F),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Termos de Uso & Privacidade',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Divider(color: Colors.white12, height: 24),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                children: const [
                  _TermsSection(
                    title: '1. Aceitação dos Termos',
                    body:
                        'Ao criar uma conta no VibeTime, você concorda com estes Termos de Uso e com nossa Política de Privacidade. Se não concordar, não utilize o aplicativo.',
                  ),
                  _TermsSection(
                    title: '2. Conteúdo do Usuário',
                    body:
                        'Você é responsável por todo conteúdo que publicar. É estritamente proibido compartilhar conteúdo ofensivo, sexual explícito, que incite violência, discriminação ou que viole leis aplicáveis.',
                  ),
                  _TermsSection(
                    title: '3. Tolerância Zero',
                    body:
                        'Não toleramos conteúdo inapropriado ou comportamento abusivo. Usuários que violarem estas regras terão sua conta suspensa ou permanentemente banida.',
                  ),
                  _TermsSection(
                    title: '4. Denúncias e Moderação',
                    body:
                        'Qualquer usuário pode denunciar conteúdo inapropriado. Nossa equipe analisa todas as denúncias em até 24 horas e remove conteúdo e usuários que violem nossas regras.',
                  ),
                  _TermsSection(
                    title: '5. Bloqueio de Usuários',
                    body:
                        'Você pode bloquear outros usuários a qualquer momento. Usuários bloqueados são removidos instantaneamente do seu feed e não podem interagir com você.',
                  ),
                  _TermsSection(
                    title: '6. Privacidade de Dados',
                    body:
                        'Coletamos apenas os dados necessários para o funcionamento do app (nome, e-mail, fotos publicadas). Não vendemos seus dados a terceiros. Você pode solicitar a exclusão da sua conta e dados a qualquer momento.',
                  ),
                  _TermsSection(
                    title: '7. Contato',
                    body:
                        'Para dúvidas, denúncias ou solicitações relacionadas à privacidade, entre em contato: suporte@vibetime.app',
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                  24, 0, 24, MediaQuery.of(context).padding.bottom + 16),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: double.infinity,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: AppColors.brandGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Entendido',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
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

class _TermsSection extends StatelessWidget {
  const _TermsSection({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 13,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
