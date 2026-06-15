import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/responsive/responsive_breakpoints.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../../data/services/supabase_status_service.dart';
import '../../activity/views/status_composer_view.dart';
import '../../friends/views/friends_view.dart';
import '../../my_day/views/my_day_view.dart';
import '../../routine/view_models/routine_view_model.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final vm = context.read<RoutineViewModel>();
      vm.loadUserProfile();
      vm.loadCustomVibes();
      vm.loadTodayData();
      SupabaseStatusService.instance.cleanupOldPlans();
    });
  }

  static const _screens = [FriendsView(), MyDayView()];

  static const _items = [
    (Icons.bolt_rounded, Icons.bolt_outlined, 'Agora'),
    (Icons.view_day_rounded, Icons.view_day_outlined, 'Meu dia'),
  ];

  void _select(int index) {
    if (index == _selectedIndex) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedIndex = index);
  }

  void _openComposer() {
    HapticFeedback.lightImpact();
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const StatusComposerView()));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (isLargeScreen(constraints.maxWidth)) {
          return _buildLargeScreenLayout();
        }
        return _buildCompactLayout();
      },
    );
  }

  Widget _buildLargeScreenLayout() {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: Row(
        children: [
          _buildNavigationRail(),
          const VerticalDivider(width: 1, color: AppColors.border),
          Expanded(
            child: IndexedStack(index: _selectedIndex, children: _screens),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactLayout() {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      extendBody: true,
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: _FloatingNavBar(
        selectedIndex: _selectedIndex,
        items: _items,
        onSelect: _select,
        onCompose: _openComposer,
      ),
    );
  }

  Widget _buildNavigationRail() {
    return NavigationRail(
      selectedIndex: _selectedIndex,
      onDestinationSelected: _select,
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.primary.withValues(alpha: 0.22),
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: Insets.lg),
        child: _RailComposeButton(onTap: _openComposer),
      ),
      selectedIconTheme: const IconThemeData(
        color: AppColors.primary,
        size: 28,
      ),
      unselectedIconTheme: const IconThemeData(
        color: AppColors.textTertiary,
        size: 26,
      ),
      selectedLabelTextStyle: const TextStyle(
        color: AppColors.primary,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
      unselectedLabelTextStyle: const TextStyle(
        color: AppColors.textTertiary,
        fontSize: 12,
      ),
      labelType: NavigationRailLabelType.all,
      minWidth: navigationRailWidth,
      destinations: [
        for (final item in _items)
          NavigationRailDestination(
            icon: Icon(item.$2),
            selectedIcon: Icon(item.$1),
            label: Text(item.$3),
          ),
      ],
    );
  }
}

class _RailComposeButton extends StatelessWidget {
  const _RailComposeButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 32,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.5),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}

class _FloatingNavBar extends StatelessWidget {
  const _FloatingNavBar({
    required this.selectedIndex,
    required this.items,
    required this.onSelect,
    required this.onCompose,
  });

  final int selectedIndex;
  final List<(IconData, IconData, String)> items;
  final ValueChanged<int> onSelect;
  final VoidCallback onCompose;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 2),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Radii.xl),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(Radii.xl),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _NavItem(
                      icon: items[0].$1,
                      inactiveIcon: items[0].$2,
                      label: items[0].$3,
                      selected: selectedIndex == 0,
                      onTap: () => onSelect(0),
                    ),
                  ),
                  _ComposeButton(onTap: onCompose),
                  Expanded(
                    child: _NavItem(
                      icon: items[1].$1,
                      inactiveIcon: items[1].$2,
                      label: items[1].$3,
                      selected: selectedIndex == 1,
                      onTap: () => onSelect(1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.inactiveIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData inactiveIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primaryBright : AppColors.textTertiary;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: AppMotion.fast,
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Icon(
                selected ? icon : inactiveIcon,
                key: ValueKey(selected),
                color: color,
                size: 26,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: AppMotion.fast,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0.2,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposeButton extends StatelessWidget {
  const _ComposeButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Semantics(
        button: true,
        label: 'Postar o que você está fazendo',
        child: InkResponse(
          onTap: onTap,
          radius: 36,
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.secondary.withValues(alpha: 0.45),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
          ),
        ),
      ),
    );
  }
}
