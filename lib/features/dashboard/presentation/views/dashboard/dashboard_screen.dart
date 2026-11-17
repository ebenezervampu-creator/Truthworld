import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/config/app_flavor.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/utils/route_redirect_middleware.dart';
import 'package:truthworld/core/widgets/studio_loading_indicator.dart';
import 'package:truthworld/features/channel/presentation/views/channel/channel_screen_wizard.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_view_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/sections/sections.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/widgets/dashboard_screen_barrel.dart';
import 'package:truthworld/theme/app_theme.dart';

export 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';
export 'package:truthworld/features/dashboard/presentation/controllers/dashboard_view_controller.dart';
export 'package:truthworld/features/dashboard/presentation/views/dashboard/widgets/dashboard_screen_barrel.dart';

/// Creator Studio Dashboard coordinating studio tabs, responsive drawer, live analytics,
/// and channel management with 100% Zero-setState declarative reactivity.
/// Fully themed with TruthWorld consumer app UI, theme tokens, and typography.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  DashboardViewController _resolveLiveViewController([
    DashboardViewController? candidate,
  ]) {
    if (candidate != null && !candidate.isDisposed) {
      return candidate;
    }
    if (Get.isRegistered<DashboardViewController>()) {
      final registered = Get.find<DashboardViewController>();
      if (!registered.isDisposed) {
        return registered;
      }
      Get.delete<DashboardViewController>(force: true);
    }
    return Get.put(DashboardViewController());
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: buildAppTheme(),
      child: Builder(
        builder: (context) {
          return GetBuilder<DashboardViewController>(
            autoRemove: false,
            init: _resolveLiveViewController(),
            builder: (viewController) {
              return Obx(() {
                // Observe disposal so out-of-band GetX route replacement cannot
                // leave the dashboard bound to a dead AnimationController.
                final isCandidateDisposed = viewController.rxIsDisposed.value;
                final effectiveViewController = isCandidateDisposed ||
                        viewController.isDisposed
                    ? _resolveLiveViewController(viewController)
                    : viewController;
                effectiveViewController.rxIsDisposed.value;
                final dashboardController =
                    effectiveViewController.dashboardController;
                // NOTE: Never call applyRouteTargetIfPresent() directly inside
                // an Obx builder — mutating Rx values during a build phase
                // triggers "setState() called during build" Flutter assertions.
                // The controller already calls this in onInit(); for subsequent
                // navigations a post-frame callback is used here instead.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  dashboardController.applyRouteTargetIfPresent();
                });

                final mediaQuery = MediaQuery.of(context);
                final isMobile = mediaQuery.size.width < 600;
                final isTablet =
                    mediaQuery.size.width >= 600 && mediaQuery.size.width < 1024;
                final isDesktop = mediaQuery.size.width >= 1024;

                final horizontalPadding = isDesktop
                    ? 32.0
                    : (isTablet ? 24.0 : 16.0);

                final isDarkMode = Theme.of(context).brightness == Brightness.dark;

                if (!AuthService.to.isAuthenticated.value) {
                  return DashboardFallbackLogin(
                    onSignIn: () {
                      AuthService.to.triggerPlatformSignIn();
                    },
                  );
                }

                if (effectiveViewController.isSelectingDefault.value) {
                  return const StudioLoadingIndicator();
                }

                if (effectiveViewController.isChannelInDeletionGracePeriod.value &&
                    effectiveViewController.channelPendingDeletion.value != null) {
                  return ChannelDeletionGracePeriodPage(
                    channel: effectiveViewController.channelPendingDeletion.value!,
                    isRestoring: effectiveViewController.isRestoringChannel.value,
                    onCancelDeletion: effectiveViewController.cancelChannelDeletion,
                    onSignOut: effectiveViewController.handleSignOut,
                  );
                }

                final currentChannel = effectiveViewController.channel;
                final channelId = effectiveViewController.getChannelId(currentChannel);
                if (channelId.isEmpty &&
                    !AuthService.to.hasChannel.value &&
                    AuthService.to.userChannel == null) {
                  return const ChannelScreen();
                }

                final scaffoldKey = GlobalKey<ScaffoldState>();

                return PopScope(
                  canPop: false,
                  onPopInvokedWithResult: (didPop, _) async {
                    if (didPop) return;

                    if (scaffoldKey.currentState?.isDrawerOpen ?? false) {
                      scaffoldKey.currentState?.closeDrawer();
                      return;
                    }

                    if (dashboardController.selectedIndex.value != 1) {
                      dashboardController.setSelectedIndex(1);
                      return;
                    }

                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                      return;
                    }

                    if (!AppFlavor.isStudio) {
                      RouteStackObserver.navigateToHome();
                      return;
                    }

                    await SystemNavigator.pop();
                  },
                  child: FocusScope(
                    autofocus: true,
                    child: Scaffold(
                      key: scaffoldKey,
                      backgroundColor: AppColors.bgPage,
                      appBar: DashboardCreatorAppBar(
                        viewController: effectiveViewController,
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
                              onSignOut: effectiveViewController.handleSignOut,
                            ),
                      body: Row(
                        children: [
                          if (isDesktop)
                            DashboardDesktopSidebar(
                              controller: dashboardController,
                              isDarkMode: isDarkMode,
                              drawerAnimation: effectiveViewController.drawerAnimation,
                              onSignOut: effectiveViewController.handleSignOut,
                            ),
                          Expanded(
                            child: DashboardViewRouter(
                              viewController: effectiveViewController,
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
                    ),
                  ),
                );
              });
            },
          );
        },
      ),
    );
  }
}
