import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:truthworld/features/library/presentation/views/library/widgets/library_constants.dart';
import 'package:truthworld/features/library/presentation/views/library/widgets/library_dialogs.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Modern top AppBar for Library Screen on Tablet and Mobile.
class LibraryModernAppBar extends StatelessWidget implements PreferredSizeWidget {
  const LibraryModernAppBar({
    super.key,
    this.isTablet = false,
  });

  final bool isTablet;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: surfaceColor.withValues(alpha: 0.95),
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.textPrimary,
                  AppColors.textPrimary.withValues(alpha: 0.5),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.video_library_rounded,
              color: AppColors.textPrimary,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Your Library',
            style: TextStyle(
              fontSize: isTablet ? 24 : 22,
              fontWeight: FontWeight.bold,
              color: primaryText,
            ),
          ),
        ],
      ),
      actions: [
        LibraryAppBarAction(
          icon: Icons.search_rounded,
          onPressed: () => LibraryDialogs.showSearchDialog(context),
          tooltip: 'Search Library',
        ),
        LibraryAppBarAction(
          icon: Icons.more_vert_rounded,
          onPressed: () => LibraryDialogs.showMoreOptions(context),
          tooltip: 'More Options',
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}

/// Action button placed in [LibraryModernAppBar].
class LibraryAppBarAction extends StatelessWidget {
  const LibraryAppBarAction({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
    super.key,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: buttonBg.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(10),
              child: Icon(icon, color: AppColors.textPrimary, size: 22),
            ),
          ),
        ),
      ),
    );
  }
}
