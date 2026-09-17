import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/features/admin/presentation/views/widgets/admin_decision_dialog.dart';
import 'package:truthworld/features/admin/presentation/views/widgets/admin_queue_helpers.dart';
import 'package:truthworld/theme/app_theme.dart';


/// Channel creation and profile verification queue tab
class ChannelQueueTab extends StatelessWidget {
  final AdminController controller;

  const ChannelQueueTab({
    required this.controller,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width <= 800;
    return Obx(() {
      final currentFilter = controller.channelFilterTab.value;
      final allChannels = controller.channels;

      final filteredList = allChannels.where((c) {
        if (currentFilter == 'pending') {
          return controller.isChannelPending(c);
        } else if (currentFilter == 'active') {
          return controller.isChannelActive(c);
        } else if (currentFilter == 'rejected') {
          return controller.isChannelRejected(c);
        }
        return true; // 'all'
      }).toList();

      final filterBar = Container(
        padding: const EdgeInsets.all(12),
        color: const Color(0xFF181818),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(
                controller,
                'pending',
                'Pending (${allChannels.where(controller.isChannelPending).length})',
                controller.channelFilterTab,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                controller,
                'all',
                'All Channels (${allChannels.length})',
                controller.channelFilterTab,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                controller,
                'active',
                'Active (${allChannels.where(controller.isChannelActive).length})',
                controller.channelFilterTab,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                controller,
                'rejected',
                'Rejected (${allChannels.where(controller.isChannelRejected).length})',
                controller.channelFilterTab,
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
                  'No channels found in this view.',
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
                    final channel = filteredList[index];
                    final isSelected =
                        controller.selectedChannel.value?['id'] == channel['id'];
                    final title =
                        channel['channelName'] ?? channel['name'] ?? 'Unnamed Channel';
                    final status = channel['status'] ?? 'underReview';

                    return Material(
                      color: isSelected ? const Color(0xFF212121) : Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          controller.selectedChannel.value = channel;
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
                                  color: const Color(0xFF212121),
                                  shape: BoxShape.circle,
                                  image:
                                      channel['avatarUrl'] != null &&
                                          channel['avatarUrl'].toString().isNotEmpty
                                      ? DecorationImage(
                                          image: CachedNetworkImageProvider(channel['avatarUrl']),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child:
                                    channel['avatarUrl'] == null ||
                                        channel['avatarUrl'].toString().isEmpty
                                    ? const Icon(
                                        Icons.face_rounded,
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
                                      'Handle: @${channel['handle'] ?? channel['customUrl'] ?? 'none'}',
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
        final selected = controller.selectedChannel.value;
        if (selected == null) {
          return const Center(
            child: Text(
              'Select a channel to inspect avatars, banners, and verification results',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.textSecondary,
              ),
            ),
          );
        }

        final avatarUrl = selected['avatarUrl'];
        final bannerUrl = selected['bannerImageUrl'] ?? selected['bannerUrl'];
        final status = selected['status'] ?? 'underReview';
        final verificationResponse =
            selected['moderationReason'] ?? 'Channel Verification Gateway verified.';

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isMobile)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextButton.icon(
                    onPressed: () => controller.selectedChannel.value = null,
                    icon: const Icon(
                      Icons.arrow_back,
                      color: Colors.white,
                      size: 18,
                    ),
                    label: const Text(
                      'Back to Channels',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              // Channel Banner Image
              if (bannerUrl != null && bannerUrl.toString().isNotEmpty) ...[
                const Text(
                  'Channel Banner Preview',
                  style: TextStyle(
                    fontFamily: TWTypography.brandFamily,
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: CachedNetworkImageProvider(bannerUrl),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundImage:
                        avatarUrl != null && avatarUrl.toString().isNotEmpty
                        ? CachedNetworkImageProvider(avatarUrl)
                        : null,
                    backgroundColor: const Color(0xFF212121),
                    child: avatarUrl == null || avatarUrl.toString().isEmpty
                        ? const Icon(
                            Icons.face_rounded,
                            size: 30,
                            color: Colors.white,
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selected['channelName'] ??
                              selected['name'] ??
                              'Unnamed Channel',
                          style: const TextStyle(
                            fontFamily: TWTypography.brandFamily,
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '@${selected['handle'] ?? selected['customUrl'] ?? 'none'} • Owner: ${selected['ownerId'] ?? selected['userId'] ?? 'Unknown'}',
                          style: const TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            color: AppColors.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Gemini Channel Verification Gateway Status Box
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:
                      (status == 'active'
                              ? AppColors.success
                              : (status == 'verificationRejected'
                                    ? AppColors.error
                                    : AppColors.warning))
                          .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        (status == 'active'
                                ? AppColors.success
                                : (status == 'verificationRejected'
                                      ? AppColors.error
                                      : AppColors.warning))
                            .withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_user_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Verification Gateway: ${status == 'active' ? 'APPROVED / ACTIVE' : (status == 'verificationRejected' ? 'REJECTED' : 'UNDER REVIEW')}',
                            style: TextStyle(
                              fontFamily: TWTypography.brandFamily,
                              color: status == 'active'
                                  ? AppColors.success
                                  : (status == 'verificationRejected'
                                        ? AppColors.error
                                        : AppColors.warning),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Verification Log: $verificationResponse',
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              color: AppColors.textPrimary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Action buttons
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
                      'Approve Channel Verification',
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
                      'Reject Verification',
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
              ),
            ],
          ),
        );
      });

      if (isMobile) {
        return controller.selectedChannel.value != null
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
}
