import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_view_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/sections/sections.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/widgets/dashboard_screen_barrel.dart';
import 'package:truthworld/theme/app_theme.dart';

export 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';
export 'package:truthworld/features/dashboard/presentation/controllers/dashboard_view_controller.dart';
export 'package:truthworld/features/dashboard/presentation/views/dashboard/widgets/dashboard_screen_barrel.dart';

/// Creator Studio Dashboard coordinating studio tabs, responsive drawer, live analytics,
/// and channel management with 100% Zero-setState declarative reactivity.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<DashboardViewController>(
      init: Get.isRegistered<DashboardViewController>()
          ? Get.find<DashboardViewController>()
          : DashboardViewController(),
      dispose: (_) {
        if (Get.isRegistered<DashboardViewController>()) {
          Get.delete<DashboardViewController>();
        }
      },
      builder: (viewController) {
        final dashboardController = viewController.dashboardController;

        return Obx(() {
      if (!AuthService.to.isAuthenticated.value) {
        return DashboardFallbackLogin(
          onSignIn: () {
            viewController.isSelectingDefault.value = true;
            viewController.handleGoogleSignIn();
          },
        );
      }

      if (viewController.isSelectingDefault.value) {
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                Color(0xFF6366F1),
              ),
            ),
          ),
        );
      }

      final mediaQuery = MediaQuery.of(context);
      final isMobile = mediaQuery.size.width < 600;
      final isTablet =
          mediaQuery.size.width >= 600 && mediaQuery.size.width < 1024;
      final isDesktop = mediaQuery.size.width >= 1024;

      final horizontalPadding = isDesktop
          ? 32.0
          : (isTablet ? 24.0 : 16.0);

      final isDarkMode = Theme.of(context).brightness == Brightness.dark;

      return Scaffold(
        key: viewController.scaffoldKey,
        backgroundColor: AppColors.bgPage,
        appBar: DashboardCreatorAppBar(
          viewController: viewController,
          dashboardController: dashboardController,
          isDarkMode: isDarkMode,
          isDesktop: isDesktop,
          isMobile: isMobile,
        ),
        drawer: isDesktop
            ? null
            : DashboardMobileDrawer(
                controller: dashboardController,
                isDarkMode: isDarkMode,
                onSignOut: viewController.handleSignOut,
              ),
        body: Row(
          children: [
            if (isDesktop)
              DashboardDesktopSidebar(
                controller: dashboardController,
                isDarkMode: isDarkMode,
                drawerAnimation: viewController.drawerAnimation,
                onSignOut: viewController.handleSignOut,
              ),
            Expanded(
              child: DashboardViewRouter(
                viewController: viewController,
                dashboardController: dashboardController,
                isDarkMode: isDarkMode,
                isMobile: isMobile,
                isDesktop: isDesktop,
                isTablet: isTablet,
                horizontalPadding: horizontalPadding,
              ),
            ),
          ],
        ),
      );
    });
      },
    );
  }
}
