import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import 'package:truthworld/components/ui/auth/auth_bottom_sheet.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/channel/presentation/views/channel/channel_screen_wizard.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_view_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/sections/sections.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/widgets/dashboard_screen_barrel.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/widgets/studio_shortcuts_modal.dart';
import 'package:truthworld/theme/app_theme.dart';

export 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';
export 'package:truthworld/features/dashboard/presentation/controllers/dashboard_view_controller.dart';
export 'package:truthworld/features/dashboard/presentation/views/dashboard/widgets/dashboard_screen_barrel.dart';

/// Creator Studio Dashboard coordinating studio tabs, responsive drawer, live analytics,
/// and channel management with 100% Zero-setState declarative reactivity.
/// Fully themed with TruthWorld consumer app UI, theme tokens, and typography.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: buildAppTheme(),
      child: Builder(
        builder: (context) {
          return GetBuilder<DashboardViewController>(
            init: Get.isRegistered<DashboardViewController>()
                ? Get.find<DashboardViewController>()
                : DashboardViewController(),
            builder: (viewController) {
              final dashboardController = viewController.dashboardController;

              return Obx(() {
                if (!AuthService.to.isAuthenticated.value) {
                  return DashboardFallbackLogin(
                    onSignIn: () {
                      AuthBottomSheet.show(context);
                    },
                  );
                }

                if (viewController.isSelectingDefault.value) {
                  return Scaffold(
                    backgroundColor: AppColors.bgPage,
                    body: _buildDashboardSkeleton(),
                  );
                }

                if (viewController.isChannelInDeletionGracePeriod.value &&
                    viewController.channelPendingDeletion.value != null) {
                  return ChannelDeletionGracePeriodPage(
                    channel: viewController.channelPendingDeletion.value!,
                    isRestoring: viewController.isRestoringChannel.value,
                    onCancelDeletion: viewController.cancelChannelDeletion,
                    onSignOut: viewController.handleSignOut,
                  );
                }

                final currentChannel = viewController.channel;
                final channelId = viewController.getChannelId(currentChannel);
                if (channelId.isEmpty &&
                    !AuthService.to.hasChannel.value &&
                    AuthService.to.userChannel == null) {
                  return const ChannelScreen();
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

                return FocusScope(
                  autofocus: true,
                  child: CallbackShortcuts(
                    bindings: <ShortcutActivator, VoidCallback>{
                      const SingleActivator(LogicalKeyboardKey.question): () {
                        StudioShortcutsModal.show(context);
                      },
                      const SingleActivator(LogicalKeyboardKey.slash, shift: true): () {
                        StudioShortcutsModal.show(context);
                      },
                      const SingleActivator(LogicalKeyboardKey.slash): () {
                        final primaryFocus = FocusManager.instance.primaryFocus;
                        if (primaryFocus == null ||
                            primaryFocus.context?.widget is! EditableText) {
                          viewController.searchFocusNode.requestFocus();
                        }
                      },
                      const SingleActivator(LogicalKeyboardKey.keyK, control: true): () {
                        viewController.searchFocusNode.requestFocus();
                      },
                      const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () {
                        viewController.searchFocusNode.requestFocus();
                      },
                      const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
                        AppSnackbar.success(
                          'All studio metadata and edits are up to date.',
                          title: 'Studio Saved',
                        );
                      },
                      const SingleActivator(LogicalKeyboardKey.keyS, meta: true): () {
                        AppSnackbar.success(
                          'All studio metadata and edits are up to date.',
                          title: 'Studio Saved',
                        );
                      },
                      const SingleActivator(LogicalKeyboardKey.escape): () {
                        if (viewController.searchFocusNode.hasFocus) {
                          viewController.searchFocusNode.unfocus();
                        }
                      },
                    },
                    child: Focus(
                      autofocus: true,
                      child: Scaffold(
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

  Widget _buildDashboardSkeleton() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF1E1E1E),
      highlightColor: AppColors.bgSurfaceHover,
      child: Column(
        children: [
          // AppBar skeleton
          Container(
            height: 64,
            decoration: const BoxDecoration(
              color: Color(0xFF1E1E1E),
              border: Border(bottom: BorderSide(color: AppColors.bgDivider)),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                // Sidebar skeleton
                Container(
                  width: 240,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E1E1E),
                    border: Border(right: BorderSide(color: AppColors.bgDivider)),
                  ),
                ),
                // Content area skeleton
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Container(
                          height: 120,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.bgDivider),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: List.generate(
                            4,
                            (index) => Expanded(
                              child: Container(
                                height: 100,
                                margin: EdgeInsets.only(right: index < 3 ? 12 : 0),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1E1E),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.bgDivider),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
