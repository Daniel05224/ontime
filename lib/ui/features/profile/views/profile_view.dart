import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../data/services/supabase_friend_service.dart';
import '../../../../data/services/supabase_profile_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/avatar_crop_view.dart';
import '../../friends/view_models/feed_view_model.dart';

class ProfileView extends StatefulWidget {
  const ProfileView({super.key});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  User? get _user => Supabase.instance.client.auth.currentUser;

  String get _name => (_user?.userMetadata?['name'] as String? ?? '').trim();

  String get _email => _user?.email ?? '';

  String get _initial => _name.isNotEmpty
      ? _name[0].toUpperCase()
      : (_email.isNotEmpty ? _email[0].toUpperCase() : '?');

  String? _avatarUrl;
  bool _avatarUploading = false;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    final url = await SupabaseProfileService.instance.loadAvatarUrl();
    if (mounted && url != null) setState(() => _avatarUrl = url);
  }

  // ── Alterar foto ──────────────────────────────────────────────────────────

  void _editAvatar() {
    _showSheet(
      title: 'Foto de perfil',
      child: Column(
        children: [
          _SheetButton(
            label: 'Câmera',
            loading: false,
            onTap: () {
              Navigator.pop(context);
              _pickAvatar(ImageSource.camera);
            },
          ),
          const SizedBox(height: 12),
          PressableScale(
            onTap: () {
              Navigator.pop(context);
              _pickAvatar(ImageSource.gallery);
            },
            child: Container(
              width: double.infinity,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(Radii.md),
                border: Border.all(color: AppColors.border),
              ),
              child: const Text(
                'Galeria',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAvatar(ImageSource source) async {
    final xFile = await ImagePicker().pickImage(
      source: source,
      imageQuality: 92,
    );
    if (xFile == null || !mounted) return;

    final rawBytes = await xFile.readAsBytes();
    if (!mounted) return;

    // Abre o editor de crop antes de fazer upload
    final croppedBytes = await Navigator.of(context).push<Uint8List>(
      PageRouteBuilder(
        opaque: true,
        barrierColor: Colors.black,
        transitionDuration: AppMotion.normal,
        reverseTransitionDuration: AppMotion.exit,
        pageBuilder: (_, __, ___) => AvatarCropView(
          imageBytes: rawBytes,
          onConfirm: (bytes) => Navigator.of(context).pop(bytes),
          onCancel: () => Navigator.of(context).pop(),
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
    if (croppedBytes == null || !mounted) return;

    setState(() => _avatarUploading = true);
    try {
      final url = await SupabaseProfileService.instance.uploadAvatar(
        croppedBytes,
        'png',
      );
      if (mounted && url != null) setState(() => _avatarUrl = url);
    } catch (_) {
      // mantém avatar anterior em caso de erro
    } finally {
      if (mounted) setState(() => _avatarUploading = false);
    }
  }

  // ── Alterar nome ──────────────────────────────────────────────────────────

  void _editName() {
    final controller = TextEditingController(text: _name);
    _showSheet(
      title: 'Alterar nome',
      child: _NameForm(
        controller: controller,
        onSave: (name) async {
          await SupabaseProfileService.instance.updateName(name);
          if (mounted) setState(() {});
        },
      ),
    );
  }

  // ── Alterar senha ─────────────────────────────────────────────────────────

  void _editPassword() {
    _showSheet(
      title: 'Alterar senha',
      child: _PasswordForm(
        onSave: (newPassword) async {
          await Supabase.instance.client.auth.updateUser(
            UserAttributes(password: newPassword),
          );
        },
      ),
    );
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  Future<void> _logout() async {
    final confirmed = await _confirm(
      icon: Icons.logout_rounded,
      iconColor: AppColors.textSecondary,
      title: 'Sair da conta?',
      message: 'Você precisará fazer login novamente para acessar o VibeTime.',
      confirmLabel: 'Sair',
      confirmColor: AppColors.textSecondary,
    );
    if (!confirmed) return;

    HapticFeedback.mediumImpact();
    await Supabase.instance.client.auth.signOut();
  }

  // ── Excluir conta ─────────────────────────────────────────────────────────

  Future<void> _deleteAccount() async {
    final confirmed = await _confirm(
      icon: Icons.delete_forever_rounded,
      iconColor: AppColors.danger,
      title: 'Excluir conta?',
      message:
          'Todos os seus dados serão apagados permanentemente. Essa ação não pode ser desfeita.',
      confirmLabel: 'Excluir conta',
      confirmColor: AppColors.danger,
    );
    if (!confirmed || !mounted) return;

    HapticFeedback.heavyImpact();
    try {
      await Supabase.instance.client.rpc('delete_own_account');
      await Supabase.instance.client.auth.signOut();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Não foi possível excluir a conta. Tente novamente.',
          ),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.md),
          ),
        ),
      );
    }
  }

  // ── Helpers de UI ─────────────────────────────────────────────────────────

  void _showSheet({required String title, required Widget child}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _Sheet(title: title, child: child),
    );
  }

  Future<bool> _confirm({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => _ConfirmDialog(
            icon: icon,
            iconColor: iconColor,
            title: title,
            message: message,
            confirmLabel: confirmLabel,
            confirmColor: confirmColor,
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
              child: Row(
                children: [
                  PressableScale(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        color: AppColors.textPrimary,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Perfil',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                children: [
                  // ── Avatar ──────────────────────────────────────────────
                  EntranceFade(
                    index: 0,
                    child: Center(
                      child: GestureDetector(
                        onTap: _editAvatar,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            BreathingGlow(
                              color: AppColors.primary,
                              minBlur: 16,
                              maxBlur: 36,
                              child: Container(
                                width: 88,
                                height: 88,
                                decoration: BoxDecoration(
                                  gradient: _avatarUrl == null
                                      ? AppColors.brandGradient
                                      : null,
                                  color: _avatarUrl != null
                                      ? AppColors.surfaceElevated
                                      : null,
                                  shape: BoxShape.circle,
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: _avatarUploading
                                    ? const Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : _avatarUrl != null
                                    ? Image.network(
                                        _avatarUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Center(
                                          child: Text(
                                            _initial,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 38,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                      )
                                    : Center(
                                        child: Text(
                                          _initial,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 38,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  gradient: AppColors.brandGradient,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.canvas,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  EntranceFade(
                    index: 1,
                    child: Center(
                      child: Text(
                        _name.isNotEmpty ? _name : 'Sem nome',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  EntranceFade(
                    index: 2,
                    child: Center(
                      child: Text(
                        _email,
                        style: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 36),

                  // ── Amizades ─────────────────────────────────────────────
                  EntranceFade(
                    index: 3,
                    child: _SectionLabel(label: 'Amizades'),
                  ),
                  const SizedBox(height: 10),
                  EntranceFade(index: 4, child: _FriendRequestsTile()),

                  const SizedBox(height: 28),

                  // ── Conta ────────────────────────────────────────────────
                  EntranceFade(index: 5, child: _SectionLabel(label: 'Conta')),
                  const SizedBox(height: 10),
                  EntranceFade(
                    index: 6,
                    child: _ProfileCard(
                      children: [
                        _ProfileTile(
                          icon: Icons.person_rounded,
                          label: 'Alterar nome',
                          value: _name.isNotEmpty ? _name : null,
                          onTap: _editName,
                        ),
                        _Divider(),
                        _ProfileTile(
                          icon: Icons.lock_rounded,
                          label: 'Alterar senha',
                          onTap: _editPassword,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Sessão ───────────────────────────────────────────────
                  EntranceFade(index: 7, child: _SectionLabel(label: 'Sessão')),
                  const SizedBox(height: 10),
                  EntranceFade(
                    index: 8,
                    child: _ProfileCard(
                      children: [
                        _ProfileTile(
                          icon: Icons.logout_rounded,
                          label: 'Sair da conta',
                          onTap: _logout,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Zona de perigo ────────────────────────────────────────
                  EntranceFade(
                    index: 9,
                    child: _SectionLabel(
                      label: 'Atenção',
                      color: AppColors.danger,
                    ),
                  ),
                  const SizedBox(height: 10),
                  EntranceFade(
                    index: 10,
                    child: _ProfileCard(
                      borderColor: AppColors.danger.withValues(alpha: 0.25),
                      children: [
                        _ProfileTile(
                          icon: Icons.delete_forever_rounded,
                          label: 'Excluir conta',
                          color: AppColors.danger,
                          onTap: _deleteAccount,
                        ),
                      ],
                    ),
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

// ════════════════════════════════════════════════════════════════════════
// Componentes internos
// ════════════════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.label,
    this.color = AppColors.textTertiary,
  });
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.children, this.borderColor});
  final List<Widget> children;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: borderColor ?? AppColors.border),
      ),
      child: Column(children: children),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.value,
    this.color = AppColors.textPrimary,
  });

  final IconData icon;
  final String label;
  final String? value;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (value != null) ...[
              Text(
                value!,
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Icon(
              Icons.chevron_right_rounded,
              color: color.withValues(alpha: 0.4),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, indent: 52, color: AppColors.border);
  }
}

// ── Bottom sheets de edição ───────────────────────────────────────────────────

class _Sheet extends StatelessWidget {
  const _Sheet({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
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
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class _NameForm extends StatefulWidget {
  const _NameForm({required this.controller, required this.onSave});
  final TextEditingController controller;
  final Future<void> Function(String) onSave;

  @override
  State<_NameForm> createState() => _NameFormState();
}

class _NameFormState extends State<_NameForm> {
  bool _loading = false;
  String? _error;

  Future<void> _save() async {
    final name = widget.controller.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.onSave(name);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Não foi possível salvar. Tente novamente.');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SheetInput(
          controller: widget.controller,
          hint: 'Seu nome',
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _save(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            style: const TextStyle(color: AppColors.danger, fontSize: 13),
          ),
        ],
        const SizedBox(height: 16),
        _SheetButton(label: 'Salvar', loading: _loading, onTap: _save),
      ],
    );
  }
}

class _PasswordForm extends StatefulWidget {
  const _PasswordForm({required this.onSave});
  final Future<void> Function(String) onSave;

  @override
  State<_PasswordForm> createState() => _PasswordFormState();
}

class _PasswordFormState extends State<_PasswordForm> {
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _newVisible = false;
  bool _confirmVisible = false;

  @override
  void dispose() {
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final newPass = _newCtrl.text;
    final confirm = _confirmCtrl.text;
    if (newPass.isEmpty || confirm.isEmpty) return;
    if (newPass != confirm) {
      setState(() => _error = 'As senhas não coincidem.');
      return;
    }
    if (newPass.length < 6) {
      setState(() => _error = 'A senha deve ter pelo menos 6 caracteres.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.onSave(newPass);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Não foi possível alterar. Tente novamente.');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SheetInput(
          controller: _newCtrl,
          hint: 'Nova senha',
          autofocus: true,
          obscure: !_newVisible,
          textInputAction: TextInputAction.next,
          suffix: _EyeToggle(
            visible: _newVisible,
            onTap: () => setState(() => _newVisible = !_newVisible),
          ),
        ),
        const SizedBox(height: 12),
        _SheetInput(
          controller: _confirmCtrl,
          hint: 'Confirmar nova senha',
          obscure: !_confirmVisible,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _save(),
          suffix: _EyeToggle(
            visible: _confirmVisible,
            onTap: () => setState(() => _confirmVisible = !_confirmVisible),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            style: const TextStyle(color: AppColors.danger, fontSize: 13),
          ),
        ],
        const SizedBox(height: 16),
        _SheetButton(label: 'Alterar senha', loading: _loading, onTap: _save),
      ],
    );
  }
}

class _SheetInput extends StatelessWidget {
  const _SheetInput({
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.autofocus = false,
    this.textInputAction,
    this.onSubmitted,
    this.suffix,
  });

  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        obscureText: obscure,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
        cursorColor: AppColors.primaryBright,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textTertiary),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
          ),
          border: InputBorder.none,
          suffixIcon: suffix != null
              ? Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: suffix,
                )
              : null,
          suffixIconConstraints: const BoxConstraints(
            minWidth: 0,
            minHeight: 0,
          ),
        ),
      ),
    );
  }
}

class _EyeToggle extends StatelessWidget {
  const _EyeToggle({required this.visible, required this.onTap});
  final bool visible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Icon(
        visible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
        color: AppColors.textTertiary,
        size: 20,
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.label,
    required this.onTap,
    this.loading = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: loading ? null : onTap,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: BorderRadius.circular(Radii.md),
          boxShadow: [
            BoxShadow(
              color: AppColors.secondary.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
    );
  }
}

// ── Pedidos de amizade ────────────────────────────────────────────────────────

class _FriendRequestsTile extends StatefulWidget {
  @override
  State<_FriendRequestsTile> createState() => _FriendRequestsTileState();
}

class _FriendRequestsTileState extends State<_FriendRequestsTile> {
  List<PendingRequest> _requests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final requests = await SupabaseFriendService.instance
          .getPendingRequests();
      if (mounted) {
        setState(() {
          _requests = requests;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _accept(String id) async {
    await SupabaseFriendService.instance.acceptRequest(id);
    setState(() => _requests = _requests.where((r) => r.id != id).toList());
    if (mounted) {
      try {
        context.read<FeedViewModel>().refresh();
      } catch (_) {}
    }
  }

  Future<void> _reject(String id) async {
    await SupabaseFriendService.instance.rejectRequest(id);
    setState(() => _requests = _requests.where((r) => r.id != id).toList());
  }

  void _showSheet() {
    try {
      context.read<FeedViewModel>().clearPendingBadge();
    } catch (_) {}
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
            left: 20,
            right: 20,
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
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Pedidos de amizade',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              if (_requests.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'Nenhum pedido pendente 👍',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 15,
                      ),
                    ),
                  ),
                )
              else
                ...List.generate(_requests.length, (i) {
                  final req = _requests[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(Radii.lg),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.surface,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.network(
                              req.avatarUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.person_rounded,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              req.name,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () async {
                              await _accept(req.id);
                              setModal(() {});
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                gradient: AppColors.brandGradient,
                                borderRadius: BorderRadius.circular(Radii.pill),
                              ),
                              child: const Text(
                                'Aceitar',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () async {
                              await _reject(req.id);
                              setModal(() {});
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceHigh,
                                borderRadius: BorderRadius.circular(Radii.pill),
                              ),
                              child: const Text(
                                'Recusar',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = _requests.length;
    return _ProfileCard(
      borderColor: count > 0 ? AppColors.primary.withValues(alpha: 0.35) : null,
      children: [
        PressableScale(
          onTap: _showSheet,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Icon(
                  Icons.people_rounded,
                  color: count > 0 ? AppColors.primary : AppColors.textPrimary,
                  size: 20,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Pedidos de amizade',
                    style: TextStyle(
                      color: count > 0
                          ? AppColors.primary
                          : AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (_loading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                else if (count > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: BorderRadius.circular(Radii.pill),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: (count > 0 ? AppColors.primary : AppColors.textPrimary)
                      .withValues(alpha: 0.4),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Dialog de confirmação ─────────────────────────────────────────────────────

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.confirmColor,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String confirmLabel;
  final Color confirmColor;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: PressableScale(
                    onTap: () => Navigator.of(context).pop(false),
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(Radii.md),
                        border: Border.all(color: AppColors.border),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PressableScale(
                    onTap: () => Navigator.of(context).pop(true),
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: confirmColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(Radii.md),
                        border: Border.all(
                          color: confirmColor.withValues(alpha: 0.4),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        confirmLabel,
                        style: TextStyle(
                          color: confirmColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
