import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/config/app_flavor.dart';
import 'package:truthworld/core/widgets/app_logo.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_view_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/sections/dashboard_app_bar_actions.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Top application bar for Creator Studio featuring home navigation, search bar,
/// notifications shortcut, video upload trigger, and Google account selector.
class DashboardCreatorAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const DashboardCreatorAppBar({
    required this.viewController,
    required this.dashboardController,
    required this.isDarkMode,
    required this.isDesktop,
    required this.isMobile,
    super.key,
  });

  final DashboardViewController viewController;
  final DashboardController dashboardController;
  final bool isDarkMode;
  final bool isDesktop;
  final bool isMobile;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgPage,
        border: Border(
          bottom: BorderSide(
            color: AppColors.bgDivider,
            width: 0.5,
          ),
        ),
      ),
      child: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 64,
        centerTitle: false,
        titleSpacing: isMobile ? 4 : null,
        leading: isDesktop
            ? null
            : Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(
                    Icons.menu_rounded,
                    color: Colors.white,
                  ),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                  tooltip: 'Menu',
                ),
              ),
        title: Row(
          children: [
            if (!AppFlavor.isStudio)
              IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  size: 20,
                  color: Colors.white,
                ),
                onPressed: () => Get.offAllNamed('/home'),
                tooltip: 'Back to Home',
              ),
            if (!isMobile) ...[
              const AppLogo(
                size: 34,
                borderRadius: 8,
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                isMobile ? 'Studio' : 'Creator Studio',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  fontSize: isMobile ? 18 : 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (isDesktop) ...[
            DashboardSearchField(
              searchController: viewController.searchController,
              focusNode: viewController.searchFocusNode,
              isDarkMode: isDarkMode,
              onChanged: dashboardController.setSearchQuery,
              onClear: () => dashboardController.setSearchQuery(''),
            ),
            const SizedBox(width: 16),
          ],
          DashboardActionButton(
            icon: Icons.notifications_none_rounded,
            onPressed: () => dashboardController.setSelectedIndex(16),
            isDarkMode: isDarkMode,
            tooltip: 'Notifications',
          ),
          SizedBox(width: isMobile ? 4 : 8),
          DashboardActionButton(
            icon: Icons.video_call_rounded,
            label: isDesktop ? 'Upload' : '',
            onPressed: () => Get.toNamed('/upload'),
            isDarkMode: isDarkMode,
            isPrimary: true,
            tooltip: 'Upload Video',
          ),
          SizedBox(width: isMobile ? 4 : 8),
          DashboardGoogleAccountSelector(
            isDarkMode: isDarkMode,
            onSignIn: () {
              HapticFeedback.lightImpact();
              viewController.handleGoogleSignIn();
            },
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}
