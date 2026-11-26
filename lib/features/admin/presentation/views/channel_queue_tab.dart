import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/widgets/channel_verified_badge.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/features/admin/presentation/views/widgets/admin_channel_discount_dialog.dart';
import 'package:truthworld/features/admin/presentation/views/widgets/admin_channel_quota_dialog.dart';
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
        } else if (currentFilter == 'trusted') {
          return controller.isChannelTrusted(c);
        } else if (currentFilter == 'active') {
          return controller.isChannelActive(c);
        } else if (currentFilter == 'hold') {
          return controller.isChannelOnHold(c);
        } else if (currentFilter == 'rejected') {
          return controller.isChannelRejected(c);
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
                'Pending (${allChannels.where(controller.isChannelPending).length})',
                controller.channelFilterTab,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                controller,
                'trusted',
                'Trusted (No Mod) (${allChannels.where(controller.isChannelTrusted).length})',
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
                'hold',
                'On Hold (${allChannels.where(controller.isChannelOnHold).length})',
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
                      color: isSelected ? AppColors.bgSurface : Colors.transparent,
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
                                  color: AppColors.bgSurface,
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
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
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
                                        ),
                                        if (controller.isChannelTrusted(channel)) ...[
                                          const SizedBox(width: 4),
                                          const ChannelVerifiedBadge(size: 13),
                                        ],
                                      ],
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
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        _buildStatusBadge(status.toString()),
                                        if (controller.isChannelTrusted(channel))
                                          _buildTrustedBadge(),
                                        _buildQuotaBadge(channel),
                                        _buildChannelDubbingDiscountBadge(channel),
                                        _buildChannelCreditsBadge(channel),
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
                    backgroundColor: AppColors.bgSurface,
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
                        Row(
                          children: [
                            Flexible(
                              child: Text(
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
                            ),
                            if (controller.isChannelTrusted(selected)) ...[
                              const SizedBox(width: 6),
                              const ChannelVerifiedBadge(size: 18),
                            ],
                          ],
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
                                    : (status == 'onHold' || status == 'hold'
                                          ? AppColors.warning
                                          : AppColors.info)))
                          .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        (status == 'active'
                                ? AppColors.success
                                : (status == 'verificationRejected'
                                      ? AppColors.error
                                      : (status == 'onHold' || status == 'hold'
                                          ? AppColors.warning
                                          : AppColors.info)))
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
                            'Verification Gateway: ${status == 'active' ? 'APPROVED / ACTIVE' : (status == 'verificationRejected' ? 'REJECTED' : ((status == 'onHold' || status == 'hold') ? 'ON HOLD' : 'UNDER REVIEW'))}',
                            style: TextStyle(
                              fontFamily: TWTypography.brandFamily,
                              color: status == 'active'
                                  ? AppColors.success
                                  : (status == 'verificationRejected'
                                        ? AppColors.error
                                        : ((status == 'onHold' || status == 'hold')
                                              ? AppColors.warning
                                              : AppColors.info)),
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
              if (selected['monetizationApplication'] != null ||
                  selected['monetizationStatus'] == 'underReview') ...[
                _buildMonetizationApplicationReviewCard(selected),
                const SizedBox(height: 20),
              ],
              if (controller.isSuperAdmin) ...[
                _buildChannelAiDiscountsCard(context, controller, selected),
                const SizedBox(height: 20),
                _buildChannelFinancialEconomicsCard(context, controller, selected),
                const SizedBox(height: 20),
              ],
              _buildTrustedModerationCard(context, controller, selected),
              const SizedBox(height: 20),
              _buildQuotaManagementCard(context, controller, selected),
              const SizedBox(height: 20),
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
                            isChannel: true,
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
                            'hold',
                            false,
                            isChannel: true,
                          ),
                    icon: const Icon(
                      Icons.pause_circle_outline_rounded,
                      size: 18,
                      color: AppColors.warning,
                    ),
                    label: const Text(
                      'Hold Verification',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.warning),
                      foregroundColor: AppColors.warning,
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
                            isChannel: true,
                          ),
                    icon: const Icon(
                      Icons.block_flipped,
                      size: 18,
                      color: AppColors.error,
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

  Widget _buildMonetizationApplicationReviewCard(Map<String, dynamic> channel) {
    final app = channel['monetizationApplication'] is Map
        ? channel['monetizationApplication'] as Map<String, dynamic>
        : <String, dynamic>{};

    final videoTitle = app['qualifiedVideoTitle']?.toString() ?? 'N/A';
    final views = app['qualifiedVideoViews']?.toString() ?? '1000+';
    final watchHours = app['qualifiedVideoWatchHours']?.toString() ?? '30.0';
    final applicantName = app['applicantName']?.toString() ??
        app['legalName']?.toString() ??
        channel['name'] ??
        'N/A';
    final idType = app['idType']?.toString() ?? 'Govt ID';
    final bankName = app['bankName']?.toString() ?? 'Direct Bank';
    final maskedAcc = app['accountNumberMasked']?.toString() ??
        app['accountNumber']?.toString() ??
        '••••';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.monetization_on_outlined,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Monetization Application & Payout Details',
                  style: TextStyle(
                    fontFamily: TWTypography.brandFamily,
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.bgSurfaceHover,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: const Text(
                  '1k Views & 30h Met',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildReviewRow('Qualified Video', '$videoTitle ($views views, $watchHours hrs)'),
          const SizedBox(height: 6),
          _buildReviewRow('Applicant (KYC)', '$applicantName • $idType'),
          const SizedBox(height: 6),
          _buildReviewRow('Bank Payout', '$bankName • $maskedAcc'),
        ],
      ),
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 12,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChannelDubbingDiscountBadge(Map<String, dynamic> channel) {
    final dubType = (channel['dubbingDiscountType'] ?? 'none').toString();
    final dubPct = (channel['dubbingDiscountPercent'] as num?)?.toDouble() ?? 0.0;
    final isDubFree = dubType == 'free' || dubPct >= 100.0;

    if (!isDubFree && dubPct <= 0) return const SizedBox.shrink();

    final label = isDubFree ? '100% Free Dubbing' : '${dubPct.round()}% Off Dubbing';
    final color = isDubFree ? AppColors.success : AppColors.warning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_offer_rounded, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelCreditsBadge(Map<String, dynamic> channel) {
    final credits = (channel['freeDubbingCredits'] as num?)?.toInt() ?? 0;
    if (credits <= 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt_rounded, size: 10, color: AppColors.info),
          const SizedBox(width: 3),
          Text(
            '+${credits.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} chars',
            style: const TextStyle(
              color: AppColors.info,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuotaBadge(Map<String, dynamic> channel) {
    final chType = (channel['channelType'] ?? channel['type'] ?? 'standard')
        .toString()
        .toLowerCase();
    if (chType == 'custom') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.info.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: AppColors.info.withValues(alpha: 0.3),
          ),
        ),
        child: const Text(
          'Custom',
          style: TextStyle(
            color: AppColors.info,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    final dailySeconds = (channel['customDailyVideoDurationSeconds'] as num?)?.toInt() ??
        (channel['maxDailyVideoDurationSeconds'] as num?)?.toInt() ??
        600;
    final isCustom = channel['hasCustomQuota'] == true || dailySeconds > 600;
    final minutes = (dailySeconds / 60).round();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: (isCustom ? AppColors.info : AppColors.bgElevated)
            .withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: (isCustom ? AppColors.info : Colors.white)
              .withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isCustom) ...[
            const Icon(Icons.bolt_rounded, size: 11, color: AppColors.textLink),
            const SizedBox(width: 2),
          ],
          Text(
            isCustom ? '$minutes min/day' : '10 min/day',
            style: TextStyle(
              color: isCustom ? AppColors.textLink : AppColors.textSecondary,
              fontSize: 10,
              fontWeight: isCustom ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuotaManagementCard(
    BuildContext context,
    AdminController controller,
    Map<String, dynamic> channel,
  ) {
    final chType = (channel['channelType'] ?? channel['type'] ?? 'standard')
        .toString()
        .toLowerCase();
    final isCustomChannel = chType == 'custom';
    final dailySeconds = (channel['customDailyVideoDurationSeconds'] as num?)?.toInt() ??
        (channel['maxDailyVideoDurationSeconds'] as num?)?.toInt() ??
        (isCustomChannel ? 86400 : 600);
    final maxVideoSeconds = (channel['customMaxVideoDurationSeconds'] as num?)?.toInt() ??
        (channel['maxVideoDurationSeconds'] as num?)?.toInt() ??
        dailySeconds;
    final isIncreased = channel['hasCustomQuota'] == true ||
        (!isCustomChannel && dailySeconds > 600);
    final dailyLabel =
        ContentValidationMixin.formatDurationMinutesSeconds(dailySeconds);
    final maxVideoLabel =
        ContentValidationMixin.formatDurationMinutesSeconds(maxVideoSeconds);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isIncreased
              ? AppColors.info.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.bolt_rounded,
                color: isIncreased ? AppColors.textLink : Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Channel Video Upload Quotas & Limits',
                  style: TextStyle(
                    fontFamily: TWTypography.brandFamily,
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isIncreased
                          ? AppColors.info
                          : AppColors.bgSurfaceHover)
                      .withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (isIncreased
                            ? AppColors.info
                            : Colors.white)
                        .withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  isIncreased
                      ? '⚡ Increased Quota ($dailyLabel/day)'
                      : (isCustomChannel
                          ? 'Pro Channel (Unlimited)'
                          : 'Standard Channel (10m/day)'),
                  style: TextStyle(
                    color: isIncreased ? AppColors.textLink : Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildReviewRow(
            'Daily Limit',
            '$dailyLabel per day ${isIncreased ? "⚡ (Admin Increased)" : (isCustomChannel ? "(Unlimited)" : "(10 min default)")}',
          ),
          const SizedBox(height: 6),
          _buildReviewRow(
            'Max Video Limit',
            '$maxVideoLabel max duration per video',
          ),
          if (isIncreased && channel['quotaIncreasedBy'] != null) ...[
            const SizedBox(height: 6),
            _buildReviewRow(
              'Increased By',
              '${channel['quotaIncreasedBy']}',
            ),
          ],
          if (isIncreased &&
              channel['quotaIncreaseReason'] != null &&
              channel['quotaIncreaseReason'].toString().isNotEmpty) ...[
            const SizedBox(height: 6),
            _buildReviewRow(
              'Reason Note',
              '${channel['quotaIncreaseReason']}',
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => showAdminChannelQuotaDialog(
                context: context,
                controller: controller,
                channel: channel,
              ),
              icon: const Icon(
                Icons.edit_calendar_rounded,
                size: 16,
                color: Colors.white,
              ),
              label: Text(
                isIncreased ? 'Adjust or Reset Quota' : 'Increase Quota Manually',
                style: const TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.3),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrustedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.5),
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_user_rounded, size: 11, color: AppColors.success),
          SizedBox(width: 3),
          Text(
            'TRUSTED (NO MOD)',
            style: TextStyle(
              color: AppColors.success,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelAiDiscountsCard(
    BuildContext context,
    AdminController controller,
    Map<String, dynamic> channel,
  ) {
    final channelId = (channel['id'] ?? channel['channelId'] ?? '').toString();
    final dubType = (channel['dubbingDiscountType'] ?? 'none').toString();
    final dubPercent = (channel['dubbingDiscountPercent'] as num?)?.toDouble() ?? 0.0;
    final subType = (channel['subtitlesDiscountType'] ?? 'none').toString();
    final subPercent = (channel['subtitlesDiscountPercent'] as num?)?.toDouble() ?? 0.0;

    final freeCredits = (channel['freeDubbingCredits'] as num?)?.toInt() ?? 0;
    final dailySeconds = (channel['customDailyVideoDurationSeconds'] as num?)?.toInt() ??
        (channel['maxDailyVideoDurationSeconds'] as num?)?.toInt() ??
        600;
    final dailyMinutes = (dailySeconds / 60).round();

    final isDubFree = dubType == 'free' || dubPercent >= 100.0;
    final isDub50 = dubType == '50%' || dubPercent == 50.0;
    final isDubCustom = dubType == 'custom' || (dubPercent > 0 && !isDubFree && !isDub50);

    final isSubFree = subType == 'free' || subPercent >= 100.0;
    final isSub50 = subType == '50%' || subPercent == 50.0;
    final isSubCustom = subType == 'custom' || (subPercent > 0 && !isSubFree && !isSub50);

    final hasAnyBenefit = isDubFree || dubPercent > 0 || isSubFree || subPercent > 0 || freeCredits > 0 || dailyMinutes > 10;

    var dubLabel = 'Standard Rate (0%)';
    if (isDubFree) {
      dubLabel = '100% Free';
    } else if (isDub50) {
      dubLabel = '50% Discount';
    } else if (isDubCustom) {
      dubLabel = '${dubPercent.round()}% Custom Discount';
    }

    var subLabel = 'Standard Rate (0%)';
    if (isSubFree) {
      subLabel = '100% Free';
    } else if (isSub50) {
      subLabel = '50% Discount';
    } else if (isSubCustom) {
      subLabel = '${subPercent.round()}% Custom Discount';
    }

    final creditsLabel = freeCredits > 0
        ? '+${freeCredits.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} free chars active'
        : 'None granted (Standard)';
    final quotaLabel = dailyMinutes > 10
        ? '$dailyMinutes min/day (Custom High-Volume)'
        : '10 min/day (Standard)';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasAnyBenefit
              ? AppColors.warning.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.admin_panel_settings_rounded,
                color: AppColors.warning,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Super Admin Channel Privileges (Discounts & Credits)',
                  style: TextStyle(
                    fontFamily: TWTypography.brandFamily,
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                ),
                child: const Text(
                  'SUPER ADMIN ONLY',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: AppColors.warning,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Directly give special discounts, free Dubbing Studio credits, and manage upload duration limits for this channel.',
            style: TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),

          // Benefit summary rows
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              children: [
                _buildDiscountDetailRow(
                  label: 'AI Audio Dubbing:',
                  value: dubLabel,
                  isFree: isDubFree,
                  hasDiscount: dubPercent > 0 || isDubFree,
                  icon: Icons.record_voice_over_rounded,
                  iconColor: AppColors.info,
                ),
                const Divider(color: Colors.white10, height: 14),
                _buildDiscountDetailRow(
                  label: 'AI Subtitles & Captions:',
                  value: subLabel,
                  isFree: isSubFree,
                  hasDiscount: subPercent > 0 || isSubFree,
                  icon: Icons.subtitles_rounded,
                  iconColor: AppColors.textLink,
                ),
                const Divider(color: Colors.white10, height: 14),
                _buildDiscountDetailRow(
                  label: 'Free Dubbing Studio Credits:',
                  value: creditsLabel,
                  isFree: freeCredits > 0,
                  hasDiscount: freeCredits > 0,
                  icon: Icons.bolt_rounded,
                  iconColor: AppColors.warning,
                ),
                const Divider(color: Colors.white10, height: 14),
                _buildDiscountDetailRow(
                  label: 'Channel Upload Limit Duration:',
                  value: quotaLabel,
                  isFree: dailyMinutes > 10,
                  hasDiscount: dailyMinutes > 10,
                  icon: Icons.timer_outlined,
                  iconColor: AppColors.success,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Action Buttons Row
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: () => showAdminChannelDiscountDialog(
                  context: context,
                  controller: controller,
                  channel: channel,
                ),
                icon: const Icon(Icons.admin_panel_settings_rounded, size: 16, color: Colors.black),
                label: const Text(
                  'Configure Super Admin Privileges',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: controller.isActionSubmitting.value
                    ? null
                    : () async {
                        await controller.grantChannelDubbingCredits(
                          channelId: channelId,
                          amountCredits: 10000,
                          reason: 'Super Admin Quick Grant (+10,000 Chars)',
                        );
                      },
                icon: const Icon(Icons.bolt_rounded, size: 16, color: AppColors.warning),
                label: const Text(
                  '+10,000 Free Credits',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: BorderSide(color: AppColors.warning.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => showAdminChannelQuotaDialog(
                  context: context,
                  controller: controller,
                  channel: channel,
                ),
                icon: const Icon(Icons.timer_outlined, size: 16, color: AppColors.success),
                label: Text(
                  'Upload Limit (${dailyMinutes}m)',
                  style: const TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: BorderSide(color: AppColors.success.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDiscountDetailRow({
    required String label,
    required String value,
    required bool isFree,
    required bool hasDiscount,
    required IconData icon,
    required Color iconColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isFree
                  ? AppColors.success.withValues(alpha: 0.15)
                  : (hasDiscount
                      ? AppColors.warning.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.05)),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isFree
                    ? AppColors.success.withValues(alpha: 0.3)
                    : (hasDiscount
                        ? AppColors.warning.withValues(alpha: 0.3)
                        : Colors.white.withValues(alpha: 0.08)),
              ),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: isFree
                    ? AppColors.success
                    : (hasDiscount ? AppColors.warning : AppColors.textPrimary),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTrustedModerationCard(
    BuildContext context,
    AdminController controller,
    Map<String, dynamic> channel,
  ) {
    final isTrusted = controller.isChannelTrusted(channel);
    final setBy = channel['trustedModerationBypassSetBy']?.toString();
    final reason = channel['trustedModerationBypassReason']?.toString();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isTrusted
              ? AppColors.success.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.verified_user_rounded,
                color: isTrusted ? AppColors.success : Colors.white70,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Trusted Channel Exemption (Zero Moderation)',
                  style: TextStyle(
                    fontFamily: TWTypography.brandFamily,
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isTrusted
                          ? AppColors.success
                          : AppColors.bgSurfaceHover)
                      .withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (isTrusted
                            ? AppColors.success
                            : Colors.white)
                        .withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  isTrusted ? '🟢 Zero Moderation Active' : '⚪ Standard Moderation',
                  style: TextStyle(
                    color: isTrusted ? AppColors.success : Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isTrusted
                ? 'Content moderation and image verification are turned OFF for this channel. All videos, community posts, topics, and images (thumbnails, banners, avatars) published by this channel permanently bypass automated moderation.'
                : 'When enabled, this trusted channel completely bypasses automated AI content moderation and image verification across all videos, community posts, topics, and thumbnails.',
            style: const TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          if (isTrusted) ...[
            const SizedBox(height: 10),
            _buildReviewRow('Exemption Status', 'Active (All Moderation Off)'),
            if (setBy != null && setBy.isNotEmpty) ...[
              const SizedBox(height: 6),
              _buildReviewRow('Exemption Granted By', setBy),
            ],
            if (reason != null && reason.isNotEmpty) ...[
              const SizedBox(height: 6),
              _buildReviewRow('Audit Reason', reason),
            ],
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: isTrusted
                ? OutlinedButton.icon(
                    onPressed: controller.isActionSubmitting.value
                        ? null
                        : () => _showTrustedModerationConfirmDialog(
                              context,
                              controller,
                              channel,
                              false,
                            ),
                    icon: const Icon(
                      Icons.shield_outlined,
                      size: 16,
                      color: AppColors.warning,
                    ),
                    label: const Text(
                      'Revoke Trusted Exemption (Resume Moderation)',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: AppColors.warning,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.warning),
                      foregroundColor: AppColors.warning,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: controller.isActionSubmitting.value
                        ? null
                        : () => _showTrustedModerationConfirmDialog(
                              context,
                              controller,
                              channel,
                              true,
                            ),
                    icon: const Icon(
                      Icons.verified_user_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Turn OFF Moderation for this Channel (Make Trusted)',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  void _showTrustedModerationConfirmDialog(
    BuildContext context,
    AdminController controller,
    Map<String, dynamic> channel,
    bool enable,
  ) {
    final reasonController = TextEditingController(
      text: enable
          ? 'Verified partner channel with established trust.'
          : 'Periodic review / trusted exemption revoked.',
    );
    final channelName = channel['name'] ?? channel['handle'] ?? 'this channel';

    Get.dialog(
      AlertDialog(
        backgroundColor: AppColors.bgPage,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (enable ? AppColors.success : AppColors.warning)
                    .withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                enable ? Icons.verified_user_rounded : Icons.shield_outlined,
                color: enable ? AppColors.success : AppColors.warning,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                enable ? 'Grant Trusted Exemption' : 'Revoke Trusted Exemption',
                style: const TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              enable
                  ? 'Are you sure you want to turn OFF all content and image moderation for "$channelName"?\n\n'
                      'All future videos, community posts, topics, thumbnails, and images uploaded by this channel will publish immediately without any AI content moderation or image verification.'
                  : 'Are you sure you want to resume standard content and image moderation for "$channelName"?',
              style: const TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Reason / Audit Note',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: reasonController,
              maxLines: 2,
              style: const TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: Colors.white,
                fontSize: 13,
              ),
              decoration: InputDecoration(
                hintText: 'Enter reason for this administrative action...',
                hintStyle: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 13,
                ),
                filled: true,
                fillColor: AppColors.bgSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: enable ? AppColors.success : AppColors.warning,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Get.back();
              await controller.toggleChannelTrustedModeration(
                channelId: (channel['id'] ?? '').toString(),
                enabled: enable,
                reason: reasonController.text.trim(),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  enable ? AppColors.success : AppColors.warning,
              foregroundColor: enable ? Colors.white : Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              enable ? 'Confirm & Turn OFF Moderation' : 'Confirm & Resume Moderation',
              style: const TextStyle(
                fontFamily: TWTypography.uiFamily,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelFinancialEconomicsCard(
    BuildContext context,
    AdminController controller,
    Map<String, dynamic> channel,
  ) {
    return Obx(() {
      final econ = controller.channelEconomics.value;
      final isLoading = controller.isLoadingChannelEconomics.value;

      final revenue = econ?['revenue'] is Map ? (econ!['revenue'] as Map<String, dynamic>) : <String, dynamic>{};
      final spendings = econ?['spendings'] is Map ? (econ!['spendings'] as Map<String, dynamic>) : <String, dynamic>{};
      final economics = econ?['economics'] is Map ? (econ!['economics'] as Map<String, dynamic>) : <String, dynamic>{};
      final breakdownRev = revenue['breakdown'] is Map ? (revenue['breakdown'] as Map<String, dynamic>) : <String, dynamic>{};
      final payouts = revenue['payouts'] is Map ? (revenue['payouts'] as Map<String, dynamic>) : <String, dynamic>{};
      final breakdownSpend = spendings['breakdown'] is Map ? (spendings['breakdown'] as Map<String, dynamic>) : <String, dynamic>{};
      final txList = (econ?['transactions'] as List?)?.whereType<Map>().map(Map<String, dynamic>.from).toList() ?? <Map<String, dynamic>>[];

      final grossINR = (revenue['grossINR'] as num?)?.toDouble() ?? 0.0;
      final grossUSD = (revenue['grossUSD'] as num?)?.toDouble() ?? (grossINR / 84.0);
      final platformShareINR = (revenue['platformShareINR'] as num?)?.toDouble() ?? (grossINR * 0.30);
      final platformShareUSD = (revenue['platformShareUSD'] as num?)?.toDouble() ?? (grossUSD * 0.30);
      final totalInfraINR = (spendings['totalInfraINR'] as num?)?.toDouble() ?? 0.0;
      final totalInfraUSD = (spendings['totalInfraUSD'] as num?)?.toDouble() ?? (totalInfraINR / 84.0);
      final netMarginINR = (economics['netPlatformContributionINR'] as num?)?.toDouble() ?? (platformShareINR - totalInfraINR);
      final marginPercent = (economics['marginPercent'] as num?)?.toDouble() ?? 0.0;
      final isProfitable = (economics['isProfitable'] as bool?) ?? (netMarginINR >= 0);

      final isCustom = (channel['channelType'] ?? '').toString().toLowerCase() == 'custom' ||
          (channel['channelType'] ?? '').toString().toLowerCase() == 'pro';

      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.bgPage,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.warning.withValues(alpha: 0.35),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: AppColors.warning,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Channel Financial Economics & Spendings',
                        style: TextStyle(
                          fontFamily: TWTypography.brandFamily,
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Real-time monetization ledger, cloud infrastructure costs & net margin',
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          color: AppColors.textTertiary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.warning),
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.5),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_rounded, size: 10, color: AppColors.warning),
                      SizedBox(width: 4),
                      Text(
                        'SUPER ADMIN ONLY',
                        style: TextStyle(
                          color: AppColors.warning,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 4 Top KPI Cards
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 600;
                final kpiGross = _buildEconomicsKpiCard(
                  title: 'Gross Revenue',
                  primaryValue: '₹${NumberFormat('#,##,###').format(grossINR.round())}',
                  secondaryValue: '≈ \$${grossUSD.toStringAsFixed(2)} USD',
                  accentColor: AppColors.success,
                );
                final kpiPlatformCut = _buildEconomicsKpiCard(
                  title: 'Platform Share Cut',
                  primaryValue: '₹${NumberFormat('#,##,###').format(platformShareINR.round())}',
                  secondaryValue: isCustom
                      ? 'Pro SaaS: \$${platformShareUSD.toStringAsFixed(2)}/mo'
                      : '30% Split: \$${platformShareUSD.toStringAsFixed(2)}',
                  accentColor: AppColors.textLink,
                );
                final kpiInfra = _buildEconomicsKpiCard(
                  title: 'Our Spendings (Infra)',
                  primaryValue: '₹${NumberFormat('#,##,###').format(totalInfraINR.round())}',
                  secondaryValue: '\$${totalInfraUSD.toStringAsFixed(2)} USD (Cloud/AI)',
                  accentColor: AppColors.error,
                );
                final kpiMargin = _buildEconomicsKpiCard(
                  title: 'Net Platform Margin',
                  primaryValue:
                      '${netMarginINR >= 0 ? "+" : "-"}₹${NumberFormat('#,##,###').format(netMarginINR.abs().round())}',
                  secondaryValue:
                      '${isProfitable ? "🟢 Profitable" : "🔴 Deficit"} (${marginPercent >= 0 ? "+" : ""}${marginPercent.toStringAsFixed(1)}%)',
                  accentColor: isProfitable ? AppColors.success : AppColors.error,
                  isHighlighted: true,
                );

                if (isNarrow) {
                  return Column(
                    children: [
                      Row(children: [Expanded(child: kpiGross), const SizedBox(width: 8), Expanded(child: kpiPlatformCut)]),
                      const SizedBox(height: 8),
                      Row(children: [Expanded(child: kpiInfra), const SizedBox(width: 8), Expanded(child: kpiMargin)]),
                    ],
                  );
                } else {
                  return Row(
                    children: [
                      Expanded(child: kpiGross),
                      const SizedBox(width: 8),
                      Expanded(child: kpiPlatformCut),
                      const SizedBox(width: 8),
                      Expanded(child: kpiInfra),
                      const SizedBox(width: 8),
                      Expanded(child: kpiMargin),
                    ],
                  );
                }
              },
            ),
            const SizedBox(height: 16),

            // Two Breakdown Cards: Revenue Streams vs. Platform Spendings
            LayoutBuilder(
              builder: (context, breakdownConstraints) {
                final isStacked = breakdownConstraints.maxWidth < 650;
                final colRevenue = Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.bgPage,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Text('📊', style: TextStyle(fontSize: 12)),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Revenue Streams Breakdown',
                              style: TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _buildEconRow('📺 Video Ads', '₹${((breakdownRev['adsINR'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(0)}'),
                      _buildEconRow('⭐ Premium Pool Share', '₹${((breakdownRev['premiumINR'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(0)}'),
                      _buildEconRow('👥 Memberships', '₹${((breakdownRev['membershipsINR'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(0)}'),
                      _buildEconRow('💬 Superchats & Tips', '₹${((breakdownRev['superchatsINR'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(0)}'),
                      const Divider(color: Colors.white12, height: 16),
                      _buildEconRow('Creator Share (${isCustom ? "100%" : "70%"})', '₹${((revenue['creatorShareINR'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(0)}', color: AppColors.success),
                      _buildEconRow('Paid Out / Cashed', '₹${((payouts['withdrawnINR'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(0)}', color: AppColors.textSecondary),
                      _buildEconRow('Pending In-Flight (T+7)', '₹${((payouts['pendingINR'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(0)}', color: AppColors.warning),
                    ],
                  ),
                );

                final colSpendings = Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.bgPage,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Text('⚡', style: TextStyle(fontSize: 12)),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Platform Spendings & Cloud Infra',
                              style: TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _buildEconRow('🤖 Gemini AI Fact-Checking', '\$${((breakdownSpend['geminiAI'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}'),
                      _buildEconRow('🌐 Cloud CDN Egress', '\$${((breakdownSpend['cdnEgress'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}'),
                      _buildEconRow('🎙️ AI Dubbing & TTS', '\$${((breakdownSpend['translationDubbing'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}'),
                      _buildEconRow('📝 Speech Transcription', '\$${((breakdownSpend['transcription'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}'),
                      _buildEconRow('⚙️ Transcoding & Compute', '\$${(((breakdownSpend['mediaTranscoding'] as num?)?.toDouble() ?? 0.0) + ((breakdownSpend['compute'] as num?)?.toDouble() ?? 0.0) + ((breakdownSpend['firestoreOps'] as num?)?.toDouble() ?? 0.0)).toStringAsFixed(2)}'),
                      const Divider(color: Colors.white12, height: 16),
                      _buildEconRow('Creator AI Wallet Spend', '\$${((spendings['creatorWalletSpendUSD'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}', color: AppColors.textLink),
                      _buildEconRow('Current Month Accrued', '\$${((spendings['currentMonthInfraCostUSD'] as num?)?.toDouble() ?? 0.0).toStringAsFixed(2)}', color: AppColors.error),
                    ],
                  ),
                );

                if (isStacked) {
                  return Column(
                    children: [
                      colRevenue,
                      const SizedBox(height: 12),
                      colSpendings,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: colRevenue),
                    const SizedBox(width: 12),
                    Expanded(child: colSpendings),
                  ],
                );
              },
            ),

            // Recent Transactions List
            if (txList.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.bgPage,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📜 Recent Channel Wallet Transactions (${txList.length})',
                      style: const TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...txList.take(5).map((tx) {
                      final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
                      final desc = (tx['description'] ?? 'Transaction').toString();
                      final cat = (tx['category'] ?? 'spend').toString().toUpperCase();
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.bgSurface,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                cat,
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                desc,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '-\$${amount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.error,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    });
  }

  Widget _buildEconomicsKpiCard({
    required String title,
    required String primaryValue,
    required String secondaryValue,
    required Color accentColor,
    bool isHighlighted = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgPage,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isHighlighted ? accentColor.withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            primaryValue,
            style: TextStyle(
              fontFamily: TWTypography.brandFamily,
              color: accentColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            secondaryValue,
            style: const TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEconRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: TWTypography.uiFamily,
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontFamily: TWTypography.brandFamily,
              color: color ?? Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
