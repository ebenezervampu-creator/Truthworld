import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_comments_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/comments/dashboard_comments_widgets.dart';

export 'package:truthworld/features/dashboard/presentation/views/dashboard/comments/dashboard_comments_widgets.dart';

/// Studio Architecture Comment Management Page
/// 100% AppTheme, 100% AppFonts (GoogleFonts.roboto), Icon Guidelines Compliant
/// Declarative StatelessWidget strictly enforcing Zero setState Policy.
/// Optimized for Mobile (Android/iOS) and Responsive Desktop Layouts.
class DashboardCommentsPage extends StatelessWidget {
  const DashboardCommentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<DashboardCommentsController>()
        ? Get.find<DashboardCommentsController>()
        : Get.put(DashboardCommentsController());

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 768;

          return Column(
            children: [
              // Studio Header Bar & Navigation Tabs
              DashboardCommentsHeaderBar(
                controller: controller,
                isMobile: isMobile,
              ),

              // Filter Chips Toolbar
              DashboardCommentsFilterToolbar(
                controller: controller,
                isMobile: isMobile,
              ),

              // Main Comments Stream & Desktop Layout
              Expanded(
                child: Obx(() {
                  if (isMobile) {
                    return _buildCommentsPane(controller, isMobile);
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Pane: Video Selector (Desktop / Tablet)
                      Container(
                        width: 320,
                        decoration: const BoxDecoration(
                          border: Border(
                            right: BorderSide(
                              color: Color(0xFF282828),
                            ),
                          ),
                        ),
                        child: Material(
                          color: const Color(0xFF0F0F0F),
                          child: DashboardCommentsVideoSelectorPane(
                            controller: controller,
                          ),
                        ),
                      ),

                      // Right Pane: Comments Stream
                      Expanded(
                        child: _buildCommentsPane(controller, isMobile),
                      ),
                    ],
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCommentsPane(
    DashboardCommentsController controller,
    bool isMobile,
  ) {
    if (controller.isLoadingComments.value) {
      return const DashboardCommentsLoadingSkeleton();
    }

    final comments = controller.getFilteredComments();

    if (comments.isEmpty) {
      return DashboardCommentsEmptyState(
        isHeldTab: controller.selectedTab.value == 1,
      );
    }

    return ListView.separated(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 0 : 16,
        vertical: isMobile ? 0 : 12,
      ),
      itemCount: comments.length,
      separatorBuilder: (context, index) => const Divider(
        height: 1,
        thickness: 1,
        color: Color(0xFF282828),
      ),
      itemBuilder: (context, index) {
        final comment = comments[index];
        return DashboardCommentCard(
          comment: comment,
          isMobile: isMobile,
          controller: controller,
        );
      },
    );
  }
}
