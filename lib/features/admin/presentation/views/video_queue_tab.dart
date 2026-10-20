import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/utils/truthworld_text_input_formatters.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/features/admin/presentation/views/widgets/admin_decision_dialog.dart';
import 'package:truthworld/features/admin/presentation/views/widgets/admin_queue_helpers.dart';
import 'package:truthworld/theme/app_theme.dart';


/// Video verification and moderation queue tab
class VideoQueueTab extends StatelessWidget {
  final AdminController controller;

  const VideoQueueTab({
    required this.controller,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width <= 800;
    return Obx(() {
      final currentFilter = controller.videoFilterTab.value;
      final allVideos = controller.videos;
      final filteredList = controller.filteredVideos.where((v) {
        if (currentFilter == 'approved') {
          return controller.isVideoApproved(v);
        } else if (currentFilter == 'pending') {
          return controller.isVideoPending(v);
        } else if (currentFilter == 'rejected') {
          return controller.isVideoRejected(v);
        }
        return true; // 'all'
      }).toList();

      final filterBar = Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: const Color(0xFF181818),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: TextField(
                      maxLength: 100,
                      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                      inputFormatters: TruthworldTextInputFormatters.internationalWithLimit(100),
                      onChanged: (v) => controller.searchQuery.value = v,
                      style: const TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: AppColors.textPrimary,
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search videos by title, ID, or channel...',
                        hintStyle: const TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                        prefixIcon: const Icon(Icons.search, color: Colors.white, size: 16),
                        filled: true,
                        fillColor: AppColors.bgInput,
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.06),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    final allSelected = filteredList.isNotEmpty &&
                        filteredList.every((v) => controller.selectedItemIds.contains(v['id']));
                    if (allSelected) {
                      controller.clearSelection();
                    } else {
                      controller.selectAllItems(filteredList);
                    }
                  },
                  icon: Icon(
                    filteredList.isNotEmpty &&
                            filteredList.every((v) => controller.selectedItemIds.contains(v['id']))
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    color: Colors.white,
                    size: 16,
                  ),
                  label: Text(
                    filteredList.isNotEmpty &&
                            filteredList.every((v) => controller.selectedItemIds.contains(v['id']))
                        ? 'Deselect All'
                        : 'Select All',
                    style: const TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(
                    controller,
                    'pending',
                    'Pending (${allVideos.where(controller.isVideoPending).length})',
                    controller.videoFilterTab,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    controller,
                    'all',
                    'All Videos (${allVideos.length})',
                    controller.videoFilterTab,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    controller,
                    'approved',
                    'Approved (${allVideos.where(controller.isVideoApproved).length})',
                    controller.videoFilterTab,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    controller,
                    'rejected',
                    'Rejected (${allVideos.where(controller.isVideoRejected).length})',
                    controller.videoFilterTab,
                  ),
                ],
              ),
            ),
          ],
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
                  'No videos found in this view.',
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
                    final video = filteredList[index];
                    final isSelected = controller.selectedVideo.value?['id'] == video['id'];
                    final title = video['title'] ?? 'Untitled Video';
                    final mod = video['moderation'] as Map<String, dynamic>?;
                    final status = mod?['status'] ?? video['status'] ?? 'pending';
                    final isTimeout = mod?['violationCategories']?.contains('timeout_passthrough') == true;

                    return Material(
                      color: isSelected ? const Color(0xFF212121) : Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          controller.selectedVideo.value = video;
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0, top: 8.0),
                                child: Checkbox(
                                  value: controller.selectedItemIds.contains(video['id']),
                                  activeColor: const Color(0xFF2BA640),
                                  checkColor: Colors.white,
                                  side: const BorderSide(color: Colors.white54),
                                  onChanged: (_) => controller.toggleItemSelection((video['id'] ?? '').toString()),
                                ),
                              ),
                              Container(
                                width: 80,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF212121),
                                  borderRadius: BorderRadius.circular(6),
                                  image: video['thumbnailUrl'] != null &&
                                          video['thumbnailUrl'].toString().isNotEmpty
                                      ? DecorationImage(
                                          image: CachedNetworkImageProvider(video['thumbnailUrl']),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: video['thumbnailUrl'] == null ||
                                        video['thumbnailUrl'].toString().isEmpty
                                    ? const Icon(
                                        Icons.videocam_rounded,
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
                                      title,
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
                                      'User: ${video['userId'] ?? video['ownerId'] ?? 'Unknown'}',
                                      style: const TextStyle(
                                        fontFamily: TWTypography.uiFamily,
                                        color: AppColors.textTertiary,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        _buildStatusBadge(status.toString()),
                                        if (isTimeout) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.error.withValues(
                                                alpha: 0.15,
                                              ),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'TIMEOUT',
                                              style: TextStyle(
                                                fontFamily: TWTypography.brandFamily,
                                                color: AppColors.error,
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
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
        final selected = controller.selectedVideo.value;
        if (selected == null) {
          return const Center(
            child: Text(
              'Select a video to inspect details and moderation controls',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.textSecondary,
              ),
            ),
          );
        }

        final videoUrl = (selected['originalUrl'] ??
                selected['videoUrl'] ??
                selected['mediaUrl'] ??
                selected['hlsUrl'] ??
                selected['url'])
            ?.toString();
        final mod = selected['moderation'] as Map<String, dynamic>?;
        final status = (mod?['status'] ?? selected['status'] ?? 'pending').toString();
        final gatewayDecision = selected['gatewayDecision'] as Map<String, dynamic>?;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isMobile)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextButton.icon(
                    onPressed: () => controller.selectedVideo.value = null,
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 18,
                    ),
                    label: const Text(
                      'Back to Videos',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              Text(
                selected['title'] ?? 'Untitled Video',
                style: const TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Gemini Verification Gateway Status Box
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (status == 'approved'
                          ? AppColors.success
                          : (status == 'rejected'
                                ? AppColors.error
                                : AppColors.warning))
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (status == 'approved'
                            ? AppColors.success
                            : (status == 'rejected'
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
                          status == 'approved'
                              ? Icons.verified_user_rounded
                              : (status == 'rejected'
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
                                  color: status == 'approved'
                                      ? AppColors.success
                                      : (status == 'rejected'
                                            ? AppColors.error
                                            : AppColors.warning),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (mod?['overriddenByAdmin'] == true) ...[
                                const SizedBox(height: 2),
                                const Text(
                                  '⚡ Overridden by Admin',
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
                    if (mod?['reason'] != null || mod?['moderationReason'] != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Reason: ${mod?['reason'] ?? mod?['moderationReason']}',
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

              // Video Player Frame
              if ((videoUrl != null && videoUrl.isNotEmpty) || selected.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ColoredBox(
                    color: AppColors.bgPage,
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: AdminVideoPlayer(
                        key: ValueKey(selected['id'] ?? videoUrl),
                        url: videoUrl ?? '',
                        videoData: selected,
                      ),
                    ),
                  ),
                )
              else
                Container(
                  height: 200,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF181818),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'No video URL metadata present.',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              const SizedBox(height: 24),

              // Technical Metadata
              const Text(
                'Verification & Technical Metadata',
                style: TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildMetadataTable([
                MetadataRow('Video ID', selected['id']),
                MetadataRow('Description', selected['description'] ?? 'None'),
                MetadataRow('Pipeline Status', status),
                MetadataRow(
                  'Verification Gateway Decision',
                  gatewayDecision?['status'] ?? mod?['status'] ?? 'N/A',
                ),
                MetadataRow(
                  'Confidence Score',
                  (mod?['confidenceScore'] ?? gatewayDecision?['confidence'] ?? 'N/A').toString(),
                ),
                MetadataRow(
                  'Uploaded At',
                  _formatTimestamp(selected['createdAt']),
                ),
              ]),
              const SizedBox(height: 32),

              // Action buttons (Enables rejection of ANY video at any time, including approved videos!)
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
                            true,
                          ),
                    icon: const Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: Colors.white,
                    ),
                    label: Text(
                      status == 'approved' ? 'Approved (Re-confirm)' : 'Approve Video',
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
                            true,
                          ),
                    icon: const Icon(
                      Icons.block_flipped,
                      size: 18,
                      color: Colors.white,
                    ),
                    label: Text(
                      status == 'approved'
                          ? 'Override & Reject Video'
                          : 'Reject Video & Quarantine',
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
        return controller.selectedVideo.value != null
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
