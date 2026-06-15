import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../data/services/supabase_friend_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/widgets/animations.dart';
import '../view_models/feed_view_model.dart';

/// Full-page friend search and request management.
class FriendSearchView extends StatefulWidget {
  const FriendSearchView({super.key});

  @override
  State<FriendSearchView> createState() => _FriendSearchViewState();
}

class _FriendSearchViewState extends State<FriendSearchView> {
  final _controller = TextEditingController();
  Timer? _debounce;

  List<SearchedUser> _results = [];
  bool _searching = false;
  bool _hasQueried = false;

  List<SearchedUser> _allUsers = [];
  bool _loadingAll = true;

  // Track in-progress button actions per userId.
  final Set<String> _busy = {};
  // Optimistic status overrides (updated immediately on tap).
  final Map<String, String> _statusOverride = {};

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    try {
      final all = await SupabaseFriendService.instance.loadAllUsers();
      if (!mounted) return;
      setState(() {
        _allUsers = all.where((u) => u.friendStatus != 'accepted').toList();
        _loadingAll = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingAll = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() {
        _results = [];
        _hasQueried = false;
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 420), () => _search(q));
  }

  Future<void> _search(String query) async {
    if (!mounted) return;
    if (_controller.text.trim().isEmpty) return;
    try {
      final results = await SupabaseFriendService.instance.searchUsers(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _searching = false;
        _hasQueried = true;
      });
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  String _effectiveStatus(SearchedUser user) =>
      _statusOverride[user.id] ?? user.friendStatus;

  Future<void> _onAction(SearchedUser user) async {
    if (_busy.contains(user.id)) return;
    final status = _effectiveStatus(user);
    HapticFeedback.selectionClick();

    setState(() => _busy.add(user.id));
    try {
      switch (status) {
        case 'none':
          await SupabaseFriendService.instance.sendRequest(user.id);
          if (mounted) setState(() => _statusOverride[user.id] = 'pending_sent');
        case 'pending_sent':
          await SupabaseFriendService.instance.cancelRequest(user.id);
          if (mounted) setState(() => _statusOverride[user.id] = 'none');
        case 'pending_received':
          await SupabaseFriendService.instance.acceptRequest(user.id);
          if (mounted) {
            setState(() => _statusOverride[user.id] = 'accepted');
            context.read<FeedViewModel>().refresh();
          }
        case 'accepted':
          break; // no-op on tap — long press to remove
      }
    } finally {
      if (mounted) setState(() => _busy.remove(user.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingRequests = context.watch<FeedViewModel>().pendingRequests;
    final isSearching = _controller.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textSecondary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Encontrar amigos',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(68),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: _SearchBar(
              controller: _controller,
              onChanged: _onQueryChanged,
            ),
          ),
        ),
      ),
      body: AnimatedSwitcher(
        duration: AppMotion.normal,
        child: _searching
            ? const Center(
                key: ValueKey('loading'),
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primary),
              )
            : CustomScrollView(
                key: const ValueKey('content'),
                slivers: [
                  // Pending requests — shown when not actively searching
                  if (!isSearching && pendingRequests.isNotEmpty)
                    _PendingSection(
                      requests: pendingRequests,
                      onAccept: (id) =>
                          context.read<FeedViewModel>().acceptRequest(id),
                      onReject: (id) =>
                          context.read<FeedViewModel>().rejectRequest(id),
                    ),

                  // Search results
                  if (isSearching && _hasQueried && _results.isEmpty)
                    const SliverFillRemaining(
                      key: ValueKey('empty'),
                      child: _EmptyResults(),
                    )
                  else if (isSearching && _results.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => EntranceFade(
                            index: i,
                            child: _UserTile(
                              user: _results[i],
                              status: _effectiveStatus(_results[i]),
                              busy: _busy.contains(_results[i].id),
                              onAction: () => _onAction(_results[i]),
                            ),
                          ),
                          childCount: _results.length,
                        ),
                      ),
                    ),

                  // Idle: show all users (or loading skeleton)
                  if (!isSearching)
                    _loadingAll
                        ? const SliverFillRemaining(
                            key: ValueKey('all-loading'),
                            child: Center(
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.primary),
                            ),
                          )
                        : _allUsers.isEmpty
                            ? const SliverFillRemaining(
                                key: ValueKey('all-empty'),
                                child: _SearchHint(),
                              )
                            : SliverPadding(
                                key: const ValueKey('all-list'),
                                padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, i) => EntranceFade(
                                      index: i,
                                      child: _UserTile(
                                        user: _allUsers[i],
                                        status: _effectiveStatus(_allUsers[i]),
                                        busy: _busy.contains(_allUsers[i].id),
                                        onAction: () => _onAction(_allUsers[i]),
                                      ),
                                    ),
                                    childCount: _allUsers.length,
                                  ),
                                ),
                              ),
                ],
              ),
      ),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        autofocus: true,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
        cursorColor: AppColors.primary,
        decoration: InputDecoration(
          hintText: 'Buscar por nome...',
          hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 15),
          prefixIcon: const Icon(Icons.search_rounded,
              color: AppColors.textTertiary, size: 20),
          suffixIcon: ValueListenableBuilder(
            valueListenable: controller,
            builder: (_, v, __) => v.text.isEmpty
                ? const SizedBox.shrink()
                : GestureDetector(
                    onTap: () {
                      controller.clear();
                      onChanged('');
                    },
                    child: const Icon(Icons.close_rounded,
                        color: AppColors.textTertiary, size: 18),
                  ),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

class _PendingSection extends StatelessWidget {
  const _PendingSection({
    required this.requests,
    required this.onAccept,
    required this.onReject,
  });
  final List<PendingRequest> requests;
  final ValueChanged<String> onAccept;
  final ValueChanged<String> onReject;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      sliver: SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Text(
                    'SOLICITAÇÕES',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      borderRadius: BorderRadius.circular(Radii.pill),
                    ),
                    child: Text(
                      '${requests.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final req = requests[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _RequestTile(
                    name: req.name,
                    avatarUrl: req.avatarUrl,
                    onAccept: () => onAccept(req.id),
                    onReject: () => onReject(req.id),
                  ),
                );
              },
              childCount: requests.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({
    required this.name,
    required this.avatarUrl,
    required this.onAccept,
    required this.onReject,
  });
  final String name;
  final String avatarUrl;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          _Avatar(url: avatarUrl, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Quer se conectar com você',
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Row(
            children: [
              _SmallButton(
                label: 'Aceitar',
                gradient: AppColors.brandGradient,
                textColor: Colors.white,
                onTap: onAccept,
              ),
              const SizedBox(width: 8),
              _SmallButton(
                label: 'Recusar',
                color: AppColors.surfaceElevated,
                textColor: AppColors.textSecondary,
                onTap: onReject,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.user,
    required this.status,
    required this.busy,
    required this.onAction,
  });
  final SearchedUser user;
  final String status;
  final bool busy;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            _Avatar(url: user.avatarUrl, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                user.name,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 10),
            _ActionButton(status: status, busy: busy, onTap: onAction),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.status,
    required this.busy,
    required this.onTap,
  });
  final String status;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (status == 'accepted') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.live.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(color: AppColors.live.withValues(alpha: 0.35)),
        ),
        child: const Text(
          'Amigos ✓',
          style: TextStyle(
            color: AppColors.live,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    final (label, color, gradient) = switch (status) {
      'pending_sent' => ('Enviado', AppColors.textTertiary, null as Gradient?),
      'pending_received' => ('Aceitar', AppColors.primary, null),
      _ => ('Adicionar', Colors.white, AppColors.brandGradient as Gradient?),
    };

    return GestureDetector(
      onTap: busy ? null : onTap,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: gradient,
          color: gradient == null
              ? (status == 'pending_received'
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : AppColors.surfaceElevated)
              : null,
          borderRadius: BorderRadius.circular(Radii.pill),
          border: status == 'pending_received'
              ? Border.all(color: AppColors.primary.withValues(alpha: 0.5))
              : null,
        ),
        child: busy
            ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: gradient != null ? Colors.white : AppColors.primary,
                ),
              )
            : Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.size});
  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceElevated,
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(
          Icons.person_rounded,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({
    required this.label,
    required this.textColor,
    required this.onTap,
    this.gradient,
    this.color,
  });
  final String label;
  final Color textColor;
  final VoidCallback onTap;
  final Gradient? gradient;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          gradient: gradient,
          color: gradient == null ? color : null,
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded,
              color: AppColors.textTertiary, size: 52),
          SizedBox(height: 16),
          Text(
            'Nada encontrado',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Nenhum usuário com esse nome.',
            style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _SearchHint extends StatelessWidget {
  const _SearchHint();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🔍', style: TextStyle(fontSize: 48)),
          SizedBox(height: 16),
          Text(
            'Busque pelo nome',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Digite acima para encontrar pessoas.',
            style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
