import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/library/presentation/controllers/library_controller.dart';
import 'package:truthworld/features/library/presentation/views/library/widgets/library_barrel.dart';

export 'package:truthworld/features/library/presentation/views/library/widgets/library_barrel.dart';

// ==========================================================================
// MODERNIZED LIBRARY SCREEN
// ==========================================================================

/// Modernized responsive Library Screen with Desktop, Tablet, and Mobile support.
class LibraryScreen extends GetView<LibraryController> {
  const LibraryScreen({super.key, this.isDashboard = false});
  final bool isDashboard;

  @override
  LibraryController get controller =>
      Get.isRegistered<LibraryController>()
          ? Get.find<LibraryController>()
          : Get.put(LibraryController());

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: controller.fadeAnimation,
      child: SlideTransition(
        position: controller.slideAnimation,
        child: ScaleTransition(
          scale: controller.scaleAnimation,
          child: _buildResponsiveLayout(context),
        ),
      ),
    );
  }

  Widget _buildResponsiveLayout(BuildContext context) {
    return Obx(() {
      final user = AuthService.to.currentUser.value;
      final userId = user?.uid;

      return LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= kDesktopBreakpoint;
          final isTablet =
              constraints.maxWidth >= kMobileBreakpoint &&
              constraints.maxWidth < kDesktopBreakpoint;

          if (isDesktop) {
            return _buildDesktopLayout(context, userId: userId);
          } else if (isTablet) {
            return _buildTabletLayout(context, userId: userId);
          } else {
            return _buildMobileLayout(context, userId: userId);
          }
        },
      );
    });
  }

  Widget _buildDesktopLayout(BuildContext context, {String? userId}) {
    if (userId == null || userId.isEmpty) {
      return const LibraryUnauthenticatedView(isDesktop: true);
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Row(
          children: [
            // Main Content
            Expanded(
              flex: 7,
              child: LibraryNavList(
                userId: userId,
                isDesktop: true,
              ),
            ),
            // Sidebar with Quick Actions
            if (!isDashboard)
              Expanded(
                flex: 3,
                child: LibrarySidebar(userId: userId),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabletLayout(BuildContext context, {String? userId}) {
    if (userId == null || userId.isEmpty) {
      return const LibraryUnauthenticatedView(isTablet: true);
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: !isDashboard
          ? const LibraryModernAppBar(isTablet: true)
          : null,
      body: SafeArea(
        child: LibraryNavList(
          userId: userId,
          isTablet: true,
        ),
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context, {String? userId}) {
    if (userId == null || userId.isEmpty) {
      return const LibraryUnauthenticatedView();
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: LibraryNavList(userId: userId),
      ),
    );
  }
}
