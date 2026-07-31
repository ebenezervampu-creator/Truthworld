import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

class StandardHeader extends StatelessWidget implements PreferredSizeWidget {
  const StandardHeader({
    required this.title,
    super.key,
    this.actions,
    this.leading,
    this.showDivider = true,
  });
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showDivider;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (showDivider ? 1.0 : 0.0));

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppBar(
          backgroundColor: AppTheme.colors.surface,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: leading,
          centerTitle: false,
          title: Text(
            title,
            style: AppTheme.typography.h2.copyWith(
              color: AppTheme.colors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            ...?actions,
            SizedBox(width: AppTheme.spacing.sm),
          ],
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            color: AppTheme.colors.border.withValues(alpha: 0.5),
          ),
      ],
    );
  }
}
