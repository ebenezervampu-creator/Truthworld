import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/utils/storage_utils.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/features/admin/presentation/views/widgets/admin_decision_dialog.dart';
import 'package:truthworld/features/admin/presentation/views/widgets/admin_queue_helpers.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Image and post SafeSearch moderation queue tab
class ImageQueueTab extends StatelessWidget {
  final AdminController controller;

  const ImageQueueTab({
    required this.controller,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width <= 800;
    return Obx(() {
      final currentFilter = controller.imageFilterTab.value;
      final allImages = controller.images;
      final filteredList = controller.filteredImages.where((img) {
        if (currentFilter == 'approved') {
          return controller.isImagePostApproved(img);
        } else if (currentFilter == 'pending') {
          return controller.isImagePostPending(img);
        } else if (currentFilter == 'rejected') {
          return controller.isImagePostRejected(img);
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
                      onChanged: (v) => controller.searchQuery.value = v,
                      style: const TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: AppColors.textPrimary,
                        fontSize: 13,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search media by category, ID, author...',
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
                        filteredList.every((img) => controller.selectedItemIds.contains(img['id']));
                    if (allSelected) {
                      controller.clearSelection();
                    } else {
                      controller.selectAllItems(filteredList);
                    }
                  },
                  icon: Icon(
                    filteredList.isNotEmpty &&
                            filteredList.every((img) => controller.selectedItemIds.contains(img['id']))
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    color: Colors.white,
                    size: 16,
                  ),
                  label: Text(
                    filteredList.isNotEmpty &&
                            filteredList.every((img) => controller.selectedItemIds.contains(img['id']))
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
                    'Pending (${allImages.where(controller.isImagePostPending).length})',
                    controller.imageFilterTab,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    controller,
                    'all',
                    'All Posts (${allImages.length})',
                    controller.imageFilterTab,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    controller,
                    'approved',
                    'Approved (${allImages.where(controller.isImagePostApproved).length})',
                    controller.imageFilterTab,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    controller,
                    'rejected',
                    'Rejected (${allImages.where(controller.isImagePostRejected).length})',
                    controller.imageFilterTab,
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
                  'No community posts or media found in this view.',
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
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: filteredList.length,
                  itemBuilder: (context, index) {
                    final img = filteredList[index];
                    final isSelected =
                        controller.selectedImage.value?['id'] == img['id'];
                    final rawUrl = _extractImageUrl(img);
                    final displayUrl = rawUrl.isNotEmpty
                        ? StorageUtils.getFastDownloadUrl(rawUrl)
                        : '';
                    final statusDisplay = _getImagePostStatusDisplay(controller, img);

            return GestureDetector(
              onTap: () {
                controller.selectedImage.value = img;
              },
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF181818),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.08),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: displayUrl.isNotEmpty
                                ? Image.network(
                                    displayUrl,
                                    fit: BoxFit.cover,
                                    cacheWidth: 350,
                                    cacheHeight: 350,
                                    errorBuilder: (context, error, stackTrace) =>
                                        const Center(
                                          child: Icon(
                                            Icons.broken_image,
                                            color: Colors.white,
                                          ),
                                        ),
                                  )
                                : const Center(
                                    child: Icon(
                                      Icons.image,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                          Positioned(
                            top: 4,
                            left: 4,
                            child: Checkbox(
                              value: controller.selectedItemIds.contains(img['id']),
                              activeColor: const Color(0xFF2BA640),
                              checkColor: Colors.white,
                              side: const BorderSide(color: Colors.white70),
                              onChanged: (_) => controller.toggleItemSelection((img['id'] ?? '').toString()),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            img['title'] ?? img['fileName'] ?? 'Image File',
                            style: const TextStyle(
                              fontFamily: TWTypography.brandFamily,
                              color: AppColors.textPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF212121),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  img['category'] ?? 'Post',
                                  style: const TextStyle(
                                    fontFamily: TWTypography.uiFamily,
                                    color: AppColors.textSecondary,
                                    fontSize: 8,
                                  ),
                                ),
                              ),
                              _buildStatusBadge(statusDisplay),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
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
        final selected = controller.selectedImage.value;
        if (selected == null) {
          return const Center(
            child: Text(
              'Select an image to inspect details',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.textSecondary,
              ),
            ),
          );
        }

        final rawUrl = _extractImageUrl(selected);
        final displayUrl = rawUrl.isNotEmpty
            ? StorageUtils.getFastDownloadUrl(rawUrl)
            : '';
        final scores =
            selected['detailedScores'] as Map<String, dynamic>? ?? {};

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isMobile)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextButton.icon(
                    onPressed: () => controller.selectedImage.value = null,
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 18,
                    ),
                    label: const Text(
                      'Back to Images',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              Text(
                selected['title'] ?? selected['fileName'] ?? 'Inspect Image',
                style: const TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Image Frame
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  color: const Color(0xFF181818),
                  constraints: const BoxConstraints(maxHeight: 280),
                  width: double.infinity,
                  child: displayUrl.isNotEmpty
                      ? Image.network(
                          displayUrl,
                          fit: BoxFit.contain,
                          cacheWidth: 600,
                          cacheHeight: 600,
                          errorBuilder: (context, error, stackTrace) =>
                              const Center(
                                child: Icon(
                                  Icons.broken_image,
                                  size: 48,
                                  color: Colors.white,
                                ),
                              ),
                        )
                      : const Center(
                          child: Icon(
                            Icons.image,
                            size: 48,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),

              // Safe Search Scores
              const Text(
                'AI SafeSearch Violations',
                style: TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildSafeSearchChip('Adult', scores['adult']),
                  _buildSafeSearchChip('Racy', scores['racy']),
                  _buildSafeSearchChip('Violence', scores['violence']),
                  _buildSafeSearchChip('Medical', scores['medical']),
                  _buildSafeSearchChip('Spoof', scores['spoof']),
                ],
              ),
              const SizedBox(height: 24),

              // Metadata Details Table
              const Text(
                'Verification Metadata',
                style: TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildMetadataTable([
                MetadataRow('Document ID', (selected['id'] ?? selected['docId'] ?? 'N/A').toString()),
                MetadataRow('Uploader ID', (selected['userId'] ?? selected['ownerId'] ?? selected['uploaderId'] ?? 'Anonymous').toString()),
                MetadataRow(
                  'Trigger Category',
                  (selected['category'] ?? 'Community Post').toString(),
                ),
                MetadataRow(
                  'AI Reason Log',
                  (selected['reason'] ?? selected['moderationReason'] ?? selected['aiReasonLog'] ?? (controller.isImagePostApproved(selected) ? 'Approved by SafeSearch AI filters.' : 'Flagged by SafeSearch filters.')).toString(),
                ),
                MetadataRow('Severity Score', '${selected['score'] ?? selected['severityScore'] ?? 0} / 5'),
                MetadataRow('GCS Path / URL', rawUrl.isNotEmpty ? rawUrl : 'N/A'),
                MetadataRow(
                  'Flagged / Created At',
                  _formatTimestamp(selected['flaggedAt'] ?? selected['createdAt'] ?? selected['timestamp']),
                ),
              ]),
              const SizedBox(height: 32),

              // Action buttons
              if (controller.isImagePostPending(selected))
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
                            ),
                      icon: const Icon(
                        Icons.check_circle_outline,
                        size: 18,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Approve Image',
                        style: TextStyle(
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
                            ),
                      icon: const Icon(
                        Icons.block_flipped,
                        size: 18,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Reject & Quarantine',
                        style: TextStyle(
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
                )
              else if (controller.isImagePostApproved(selected))
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    OutlinedButton.icon(
                      onPressed: controller.isActionSubmitting.value
                          ? null
                          : () => _showDecisionDialog(
                              context,
                              controller,
                              selected['id'],
                              'reject',
                              false,
                            ),
                      icon: const Icon(
                        Icons.block_flipped,
                        size: 18,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Revoke & Reject',
                        style: TextStyle(
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
                )
              else
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
                            ),
                      icon: const Icon(
                        Icons.check_circle_outline,
                        size: 18,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Override & Approve Image',
                        style: TextStyle(
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
                  ],
                ),
            ],
          ),
        );
      });

      if (isMobile) {
        return controller.selectedImage.value != null
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

  Widget _buildSafeSearchChip(String label, dynamic val) => AdminSafeSearchChip(label: label, val: val);

  String _extractImageUrl(Map<String, dynamic> img) => extractAdminImageUrl(img);

  String _getImagePostStatusDisplay(AdminController controller, Map<String, dynamic> img) =>
      getAdminImagePostStatusDisplay(controller, img);

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
