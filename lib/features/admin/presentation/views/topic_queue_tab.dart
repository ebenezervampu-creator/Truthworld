import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/features/admin/presentation/views/widgets/admin_decision_dialog.dart';
import 'package:truthworld/features/admin/presentation/views/widgets/admin_queue_helpers.dart';
import 'package:truthworld/theme/app_theme.dart';


/// Topic verification and review queue tab
class TopicQueueTab extends StatelessWidget {
  final AdminController controller;

  const TopicQueueTab({
    required this.controller,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width <= 800;
    return Obx(() {
      final currentFilter = controller.topicFilterTab.value;
      final allTopics = controller.topics;

      final filteredList = allTopics.where((t) {
        if (currentFilter == 'approved') {
          return controller.isTopicApproved(t);
        } else if (currentFilter == 'pending') {
          return controller.isTopicPending(t);
        } else if (currentFilter == 'rejected') {
          return controller.isTopicRejected(t);
        }
        return true; // 'all'
      }).toList();

      final filterBar = Container(
        padding: const EdgeInsets.all(12),
        color: AppColors.bgPage,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(
                controller,
                'pending',
                'Pending (${allTopics.where(controller.isTopicPending).length})',
                controller.topicFilterTab,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                controller,
                'all',
                'All Topics (${allTopics.length})',
                controller.topicFilterTab,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                controller,
                'approved',
                'Approved (${allTopics.where(controller.isTopicApproved).length})',
                controller.topicFilterTab,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                controller,
                'rejected',
                'Rejected (${allTopics.where(controller.isTopicRejected).length})',
                controller.topicFilterTab,
              ),
            ],
          ),
        ),
      );

      Widget listWidget;
      if (filteredList.isEmpty) {
        listWidget = Column(
          children: [
            filterBar,
            const Expanded(
              child: Center(
                child: Text(
                  'No topics found in this view.',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        );
      } else {
        listWidget = Container(
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
          ),
          child: Column(
            children: [
              filterBar,
              Expanded(
                child: ListView.separated(
                  itemCount: filteredList.length,
                  separatorBuilder: (context, index) =>
                      Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
                  itemBuilder: (context, index) {
                    final topic = filteredList[index];
                    final isSelected =
                        controller.selectedTopic.value?['id'] == topic['id'];
                    final name = topic['name'] ?? topic['title'] ?? 'Untitled Topic';
                    final handle = topic['handle'] ?? topic['slug'] ?? 'none';
                    final status = topic['status'] ?? (topic['isApproved'] == true || topic['geminiApproved'] == true ? 'active' : 'underReview');
                    final thumbUrl = topic['thumbnailUrl'] ?? topic['coverImageUrl'] ?? topic['imageUrl'];

                    return Material(
                      color: isSelected ? AppColors.bgSurface : Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          controller.selectedTopic.value = topic;
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: AppColors.bgSurface,
                                  borderRadius: BorderRadius.circular(8),
                                  image: thumbUrl != null && thumbUrl.toString().isNotEmpty
                                      ? DecorationImage(
                                          image: CachedNetworkImageProvider(thumbUrl.toString()),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: thumbUrl == null || thumbUrl.toString().isEmpty
                                    ? const Icon(
                                        Icons.tag_rounded,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '#$name',
                                      style: const TextStyle(
                                        fontFamily: TWTypography.brandFamily,
                                        color: AppColors.textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Handle: @$handle • Category: ${topic['category'] ?? 'General'}',
                                      style: const TextStyle(
                                        fontFamily: TWTypography.uiFamily,
                                        color: AppColors.textTertiary,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    _buildStatusBadge(status.toString()),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      }

      final inspectorWidget = Obx(() {
        final selected = controller.selectedTopic.value;
        if (selected == null) {
          return const Center(
            child: Text(
              'Select a topic to inspect details and verification controls',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.textSecondary,
              ),
            ),
          );
        }

        final name = selected['name'] ?? selected['title'] ?? 'Untitled Topic';
        final handle = selected['handle'] ?? selected['slug'] ?? 'none';
        final status = (selected['status'] ?? (selected['isApproved'] == true || selected['geminiApproved'] == true ? 'active' : 'underReview')).toString();
        final thumbUrl = selected['thumbnailUrl'] ?? selected['coverImageUrl'] ?? selected['imageUrl'];
        final reason = selected['moderationReason'] ?? selected['rejectionReason'] ?? selected['reason'];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isMobile)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextButton.icon(
                    onPressed: () => controller.selectedTopic.value = null,
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 18,
                    ),
                    label: const Text(
                      'Back to Topics',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              Text(
                '#$name',
                style: const TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Gemini Topic Verification Gateway Status Box
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (controller.isTopicApproved(selected)
                          ? AppColors.success
                          : (controller.isTopicRejected(selected)
                                ? AppColors.error
                                : AppColors.warning))
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (controller.isTopicApproved(selected)
                            ? AppColors.success
                            : (controller.isTopicRejected(selected)
                                  ? AppColors.error
                                  : AppColors.warning))
                        .withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          controller.isTopicApproved(selected)
                              ? Icons.verified_user_rounded
                              : (controller.isTopicRejected(selected)
                                    ? Icons.block_flipped
                                    : Icons.gavel_rounded),
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Verification Gateway Decision: ${status.toUpperCase()}',
                                style: TextStyle(
                                  fontFamily: TWTypography.brandFamily,
                                  color: controller.isTopicApproved(selected)
                                      ? AppColors.success
                                      : (controller.isTopicRejected(selected)
                                            ? AppColors.error
                                            : AppColors.warning),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (selected['manuallyVerified'] == true || selected['overriddenByAdmin'] == true) ...[
                                const SizedBox(height: 2),
                                const Text(
                                  '⚡ Manually Verified / Overridden by Admin',
                                  style: TextStyle(
                                    fontFamily: TWTypography.uiFamily,
                                    color: Colors.amber,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (reason != null && reason.toString().trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Reason Log: $reason',
                        style: const TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          color: AppColors.textPrimary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Thumbnail Frame if available
              if (thumbUrl != null && thumbUrl.toString().isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.bgPage,
                      image: DecorationImage(
                        image: CachedNetworkImageProvider(thumbUrl.toString()),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Technical Metadata
              const Text(
                'Topic Verification & Metadata',
                style: TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildMetadataTable([
                MetadataRow('Topic ID', (selected['id'] ?? 'N/A').toString()),
                MetadataRow('Topic Name', name.toString()),
                MetadataRow('Handle / Slug', '@$handle'),
                MetadataRow('Category', (selected['category'] ?? 'General').toString()),
                MetadataRow('Description', (selected['description'] ?? 'None').toString()),
                MetadataRow('Owner / Creator ID', (selected['ownerId'] ?? selected['userId'] ?? selected['creatorId'] ?? 'Unknown').toString()),
                MetadataRow('Status', status),
                MetadataRow(
                  'Created At',
                  _formatTimestamp(selected['createdAt']),
                ),
                if (selected['updatedAt'] != null)
                  MetadataRow(
                    'Updated At',
                    _formatTimestamp(selected['updatedAt']),
                  ),
              ]),
              const SizedBox(height: 32),

              // Action buttons (Approve / Reject)
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ElevatedButton.icon(
                    onPressed: controller.isActionSubmitting.value
                        ? null
                        : () => _showDecisionDialog(
                            context,
                            controller,
                            selected['id'],
                            'approve',
                            false,
                            isTopic: true,
                          ),
                    icon: const Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: Colors.white,
                    ),
                    label: Text(
                      controller.isTopicApproved(selected)
                          ? 'Approved (Re-confirm)'
                          : 'Approve Topic',
                      style: const TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: controller.isActionSubmitting.value
                        ? null
                        : () => _showDecisionDialog(
                            context,
                            controller,
                            selected['id'],
                            'reject',
                            false,
                            isTopic: true,
                          ),
                    icon: const Icon(
                      Icons.block_flipped,
                      size: 18,
                      color: Colors.white,
                    ),
                    label: Text(
                      controller.isTopicApproved(selected)
                          ? 'Override & Reject Topic'
                          : 'Reject Topic & Quarantine',
                      style: const TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.error),
                      foregroundColor: AppColors.error,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      });

      if (isMobile) {
        return controller.selectedTopic.value != null
            ? inspectorWidget
            : listWidget;
      }

      return Row(
        children: [
          Expanded(flex: 2, child: listWidget),
          Expanded(flex: 3, child: inspectorWidget),
        ],
      );
    });
  }

  void _showDecisionDialog(
    BuildContext context,
    AdminController controller,
    String id,
    String action,
    bool isVideo, {
    bool isTopic = false,
    bool isChannel = false,
    bool isReport = false,
  }) {
    showAdminDecisionDialog(
      context,
      controller,
      id,
      action,
      isVideo,
      isTopic: isTopic,
      isChannel: isChannel,
      isReport: isReport,
    );
  }

  Widget _buildStatusBadge(String status) => AdminStatusBadge(status: status);

  Widget _buildMetadataTable(List<MetadataRow> rows) => AdminMetadataTable(rows: rows);

  Widget _buildFilterChip(
    AdminController controller,
    String value,
    String label,
    RxString targetProperty,
  ) => AdminFilterChip(
    controller: controller,
    value: value,
    label: label,
    targetProperty: targetProperty,
  );

  String _formatTimestamp(dynamic val) => formatAdminTimestamp(val);
}
