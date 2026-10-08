import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_comments_controller.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/comments/dashboard_comments_widgets.dart';
import 'package:truthworld/theme/app_theme.dart';

export 'package:truthworld/features/dashboard/presentation/views/dashboard/comments/dashboard_comments_widgets.dart';

/// Studio Comment Management Page
/// Aligned with Consumer App's Library screen and Settings page theme, UI, and typography.
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
      backgroundColor: AppColors.bgPage,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 768;

          return Column(
            children: [
              // Header Bar & Navigation Tabs
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
                              color: AppColors.bgDivider,
                            ),
                          ),
                        ),
                        child: Material(
                          color: AppColors.bgPage,
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

    final hasLoadMore = controller.hasMoreComments.value;
    final totalCount = comments.length + (hasLoadMore ? 1 : 0);

    return ListView.separated(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 0 : 16,
        vertical: isMobile ? 0 : 12,
      ),
      itemCount: totalCount,
      separatorBuilder: (context, index) => const Divider(
        height: 1,
        thickness: 1,
        color: AppColors.bgDivider,
      ),
      itemBuilder: (context, index) {
        if (index < comments.length) {
          final comment = comments[index];
          return DashboardCommentCard(
            comment: comment,
            isMobile: isMobile,
            controller: controller,
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: OutlinedButton(
              onPressed: controller.isLoadingMoreComments.value
                  ? null
                  : controller.loadMoreStudioComments,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: BorderSide(
                  color: AppColors.textSecondary.withValues(alpha: 0.3),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: controller.isLoadingMoreComments.value
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Load more comments',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}
