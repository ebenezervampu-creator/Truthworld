import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/features/admin/presentation/views/dashboard_components/admin_dashboard_barrel.dart';
import 'package:truthworld/theme/app_theme.dart';

export 'package:truthworld/features/admin/presentation/views/audit_logs_tab.dart';
export 'package:truthworld/features/admin/presentation/views/channel_queue_tab.dart';
export 'package:truthworld/features/admin/presentation/views/dashboard_components/admin_dashboard_barrel.dart';
export 'package:truthworld/features/admin/presentation/views/image_queue_tab.dart';
export 'package:truthworld/features/admin/presentation/views/overview_tab.dart';
export 'package:truthworld/features/admin/presentation/views/reports_queue_tab.dart';
export 'package:truthworld/features/admin/presentation/views/topic_queue_tab.dart';
export 'package:truthworld/features/admin/presentation/views/video_queue_tab.dart';
export 'package:truthworld/features/admin/presentation/views/widgets/admin_decision_dialog.dart';
export 'package:truthworld/features/admin/presentation/views/widgets/admin_queue_helpers.dart';

class AdminDashboardScreen extends StatelessWidget {
  AdminDashboardScreen({super.key}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AdminController.to.ensureSubscriptionsStarted();
    });
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final controller = AdminController.to;
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.bgPage,
      appBar: AdminHeader(
        controller: controller,
        isDesktop: isDesktop,
        onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      drawer: isDesktop
          ? null
          : Drawer(
              backgroundColor: AppColors.bgSurface,
              child: SafeArea(
                child: AdminSidebar(
                  controller: controller,
                  onCloseDrawer: () {
                    if (_scaffoldKey.currentState?.isDrawerOpen == true) {
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ),
            ),
      body: SafeArea(
        child: Row(
          children: [
            // Sidebar (desktop only)
            if (isDesktop) AdminSidebar(controller: controller),

            // Main Workspace
            Expanded(
              child: Obx(() {
                final currentTab = controller.currentTab.value;
                if (!controller.isTabAllowed(currentTab)) {
                  final allowed = controller.getAllowedTabs();
                  final target = allowed.isNotEmpty ? allowed.first : 'help';
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (controller.currentTab.value != target) {
                      controller.currentTab.value = target;
                    }
                  });
                  return AdminTabRouter.buildTabForId(
                    target,
                    context,
                    controller,
                  );
                }
                return AdminTabRouter.buildTabForId(
                  currentTab,
                  context,
                  controller,
                );
              }),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Obx(() {
        if (controller.selectedItemIds.isNotEmpty) {
          return AdminBulkActionBar(controller: controller);
        }
        return isDesktop
            ? const SizedBox.shrink()
            : AdminMobileBottomNavBar(
                controller: controller,
                onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
              );
      }),
    );
  }
}
