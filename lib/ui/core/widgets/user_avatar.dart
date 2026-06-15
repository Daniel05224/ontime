import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Circular avatar that shows a standard gray person silhouette
/// when [url] is empty or fails to load — never shows random faces.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.url,
    required this.size,
    this.borderColor,
    this.borderWidth = 1.5,
  });

  final String url;
  final double size;
  final Color? borderColor;
  final double borderWidth;

  bool get _hasPhoto => url.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceHigh,
        border: borderColor != null
            ? Border.all(color: borderColor!, width: borderWidth)
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: _hasPhoto
          ? Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _Placeholder(size: size),
            )
          : _Placeholder(size: size),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF2A2A35),
      child: Icon(
        Icons.person_rounded,
        color: const Color(0xFF6B6B7A),
        size: size * 0.55,
      ),
    );
  }
}
