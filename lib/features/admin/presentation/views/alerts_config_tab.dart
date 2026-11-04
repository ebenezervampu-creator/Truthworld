import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

class AlertsConfigTab extends StatelessWidget {
  final AdminController controller;
  const AlertsConfigTab({required this.controller, super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMediaApprovalModePanel(),
              const SizedBox(height: 32),
              _buildActiveAlertsPanel(),
              const SizedBox(height: 32),
              _buildAlertRulesPanel(),
              const SizedBox(height: 32),
              _buildEscalationTiersPanel(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMediaApprovalModePanel() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.bgPage,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Direct Approval & AI Bypass Switchboard (Google Cloud Vision & Gemini AI)',
                      style: TextStyle(
                        fontFamily: TWTypography.brandFamily,
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'When a moderation switch is ON, submissions for that category bypass automated AI (Gemini AI / Google Cloud Vision) and appear directly in the Admin Portal queues for manual human decision. When OFF, submissions follow the standard automated AI flow.',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ─── MASTER TOGGLE CARD (Route ALL requests to Admin) ───────────────
          Obx(() {
            final isMasterBypassed = controller.rxBypassAll.value;
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isMasterBypassed
                    ? AppColors.success.withValues(alpha: 0.08)
                    : AppColors.bgSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isMasterBypassed
                      ? AppColors.success.withValues(alpha: 0.4)
                      : Colors.white.withValues(alpha: 0.12),
                  width: isMasterBypassed ? 1.5 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isMasterBypassed
                              ? AppColors.success.withValues(alpha: 0.2)
                              : AppColors.bgPage,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isMasterBypassed
                                ? AppColors.success.withValues(alpha: 0.4)
                                : Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Icon(
                          Icons.admin_panel_settings_rounded,
                          color: isMasterBypassed
                              ? AppColors.success
                              : Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Master Switch: Route ALL Moderation Requests to Admin',
                              style: TextStyle(
                                fontFamily: TWTypography.brandFamily,
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isMasterBypassed
                                  ? 'ALL content requests (Videos, Thumbnails, Channels, Avatars, Banners, Topics, Playlists, Community, Ads) are currently routed to Admin queues. Automated AI is completely bypassed.'
                                  : 'Standard automated flow active. Submissions are processed automatically by Gemini AI and Google Cloud Vision unless individual category switches below are enabled.',
                              style: const TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Switch(
                        value: isMasterBypassed,
                        onChanged: (val) => controller.toggleModerationMode('all', val),
                        activeTrackColor: AppColors.success,
                        activeColor: Colors.white,
                        inactiveTrackColor: AppColors.bgDivider,
                        inactiveThumbColor: AppColors.textTertiary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isMasterBypassed
                              ? AppColors.success.withValues(alpha: 0.12)
                              : Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isMasterBypassed
                                ? AppColors.success.withValues(alpha: 0.4)
                                : Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isMasterBypassed
                                    ? AppColors.success
                                    : AppColors.textTertiary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isMasterBypassed
                                  ? '🛡️ DIRECT ADMIN APPROVAL ONLY (All AI Bypassed)'
                                  : '🤖 AUTOMATED AI PIPELINE (Present Flow Active)',
                              style: TextStyle(
                                fontFamily: TWTypography.brandFamily,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isMasterBypassed
                                    ? AppColors.success
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => controller.toggleAllMediaModes(!isMasterBypassed),
                        icon: Icon(
                          isMasterBypassed ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        label: Text(
                          isMasterBypassed ? 'Restore Automated AI Flow' : 'Direct Approve All (Route to Admin)',
                          style: const TextStyle(
                            fontFamily: TWTypography.brandFamily,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: AppColors.bgPage,
                          side: BorderSide(
                            color: isMasterBypassed
                                ? AppColors.success.withValues(alpha: 0.6)
                                : Colors.white.withValues(alpha: 0.12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
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
          }),
          const SizedBox(height: 20),
          Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
          const SizedBox(height: 20),

          // Category Toggles Grid
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 700;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildToggleCard(
                    width: isWide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth,
                    title: 'Videos Content',
                    description: 'Uploaded video media files, audio tracks, and dialogue. When ON, videos bypass Gemini AI automated moderation and route directly to Admin review queue.',
                    icon: Icons.video_library_outlined,
                    modeKey: 'videos',
                    rxValue: controller.rxBypassVideos,
                    isGemini: true,
                  ),
                  _buildToggleCard(
                    width: isWide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth,
                    title: 'Channel Details & Registration',
                    description: 'Channel display name, handle, description, and tags. When ON, channel registrations bypass Gemini AI and are held for Admin manual review.',
                    icon: Icons.verified_user_outlined,
                    modeKey: 'channels',
                    rxValue: controller.rxBypassChannels,
                    isGemini: true,
                  ),
                  _buildToggleCard(
                    width: isWide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth,
                    title: 'Advertiser Campaigns',
                    description: 'Advertiser campaign submissions (Feed, Video, Banner & Sponsor ads). When ON, campaigns bypass Gemini AI auto approve/reject and route to Admin for manual review.',
                    icon: Icons.campaign_outlined,
                    modeKey: 'ads',
                    rxValue: controller.rxBypassAds,
                    isGemini: true,
                  ),
                  _buildToggleCard(
                    width: isWide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth,
                    title: 'Video Thumbnails',
                    description: 'Custom preview thumbnails uploaded during video publishing. When ON, thumbnails bypass Google Cloud Vision AI and route to Admin.',
                    icon: Icons.photo_size_select_actual_outlined,
                    modeKey: 'thumbnails',
                    rxValue: controller.rxBypassVideoThumbnails,
                  ),
                  _buildToggleCard(
                    width: isWide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth,
                    title: 'Channel Banners',
                    description: 'Channel header artwork and banners uploaded by creators. When ON, banners bypass Google Cloud Vision AI and route to Admin.',
                    icon: Icons.panorama_outlined,
                    modeKey: 'banner',
                    rxValue: controller.rxBypassChannelBanners,
                  ),
                  _buildToggleCard(
                    width: isWide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth,
                    title: 'Channel Avatars',
                    description: 'Profile pictures and avatar images uploaded for channels. When ON, avatars bypass Google Cloud Vision AI and route to Admin.',
                    icon: Icons.account_circle_outlined,
                    modeKey: 'avatar',
                    rxValue: controller.rxBypassChannelAvatars,
                  ),
                  _buildToggleCard(
                    width: isWide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth,
                    title: 'Community Posts',
                    description: 'Image attachments and artwork uploaded in community feed posts. When ON, post images bypass Google Cloud Vision AI and route to Admin.',
                    icon: Icons.dynamic_feed_outlined,
                    modeKey: 'community',
                    rxValue: controller.rxBypassCommunityPosts,
                  ),
                  _buildToggleCard(
                    width: isWide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth,
                    title: 'Topics Custom Thumbnails & Details',
                    description: 'Custom cover thumbnails and details submitted for discussion topics. When ON, topics bypass automated AI and route to Admin.',
                    icon: Icons.tag_rounded,
                    modeKey: 'topics',
                    rxValue: controller.rxBypassTopicThumbnails,
                  ),
                  _buildToggleCard(
                    width: isWide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth,
                    title: 'Playlists Custom Thumbnails & Details',
                    description: 'Custom cover artwork and metadata submitted for playlists. When ON, playlists bypass automated AI and route to Admin.',
                    icon: Icons.playlist_play_rounded,
                    modeKey: 'playlists',
                    rxValue: controller.rxBypassPlaylistThumbnails,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildToggleCard({
    required double width,
    required String title,
    required String description,
    required IconData icon,
    required String modeKey,
    required RxBool rxValue,
    bool isGemini = false,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.bgPage,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: TWTypography.brandFamily,
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Obx(() {
                return Switch(
                  value: rxValue.value,
                  onChanged: (val) => controller.toggleModerationMode(modeKey, val),
                  activeTrackColor: AppColors.success,
                  activeColor: Colors.white,
                  inactiveTrackColor: AppColors.bgDivider,
                  inactiveThumbColor: AppColors.textTertiary,
                );
              }),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          Obx(() {
            final isBypassed = rxValue.value;
            final bypassedLabel = isGemini
                ? 'DIRECT ADMIN APPROVAL (Gemini AI Bypassed)'
                : 'DIRECT ADMIN APPROVAL (Vision AI Bypassed)';
            final autoLabel = isGemini
                ? 'AUTOMATED AI (Gemini AI Active)'
                : 'AUTOMATED AI (Google Cloud Vision Active)';

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isBypassed
                    ? AppColors.success.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isBypassed
                      ? AppColors.success.withValues(alpha: 0.4)
                      : Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isBypassed
                          ? AppColors.success
                          : AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isBypassed ? bypassedLabel : autoLabel,
                    style: TextStyle(
                      fontFamily: TWTypography.brandFamily,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isBypassed
                          ? AppColors.success
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildActiveAlertsPanel() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.bgPage,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Active Alerts',
            style: TextStyle(
              fontFamily: TWTypography.brandFamily,
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Real-time system health and threshold violation notifications',
            style: TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          Obx(() {
            final alerts = [
              ...controller.activeAlerts,
              ...controller.anomalyAlerts,
            ];

            if (alerts.isEmpty) {
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 28),
                alignment: Alignment.center,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_outline_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Zero Active System Alerts',
                      style: TextStyle(
                        fontFamily: TWTypography.brandFamily,
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'All moderation pipelines, queues, and thresholds are operating normally.',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: alerts.length,
              itemBuilder: (context, index) {
                final alert = alerts[index];
                final title = alert['title'] ?? alert['name'] ?? alert['type'] ?? 'System Alert';
                final desc = alert['description'] ?? alert['details'] ?? alert['message'] ?? 'Alert triggered';
                final severity = (alert['severity'] ?? 'Medium').toString().toUpperCase();

                Color badgeColor;
                if (severity == 'CRITICAL' || severity == 'HIGH') {
                  badgeColor = AppColors.error;
                } else if (severity == 'WARNING') {
                  badgeColor = Colors.orange;
                } else {
                  badgeColor = Colors.amber;
                }

                return Card(
                  color: AppColors.bgSurface,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: ListTile(
                      leading: const Icon(Icons.warning_amber_rounded, color: Colors.white),
                      title: Text(
                        title.toString(),
                        style: const TextStyle(
                          fontFamily: TWTypography.brandFamily,
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        desc.toString(),
                        style: const TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Chip(
                          label: Text(
                            severity,
                            style: TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              color: badgeColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                          backgroundColor: badgeColor.withValues(alpha: 0.1),
                          side: BorderSide(color: badgeColor),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildAlertRulesPanel() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.bgPage,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Alert Rules Configuration',
                    style: TextStyle(
                      fontFamily: TWTypography.brandFamily,
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Set trigger thresholds and notification channels',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.bgSurface,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                ),
                onPressed: controller.saveAlertRules,
                child: const Text(
                  'Save Alert Rules',
                  style: TextStyle(
                    fontFamily: TWTypography.brandFamily,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Obx(() {
            final rules = controller.alertRules;
            if (rules.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'Loading alert rules...',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: rules.length,
              separatorBuilder: (context, index) =>
                  Divider(color: Colors.white.withValues(alpha: 0.08)),
              itemBuilder: (context, index) {
                final rule = rules[index];
                final name = (rule['name'] ?? 'Alert Rule').toString();
                final threshold = (rule['threshold'] ?? 100).toString();
                final enabled = rule['enabled'] == true;
                final channels = (rule['channels'] is List)
                    ? List<String>.from(rule['channels'])
                    : <String>['push'];

                return _buildDynamicAlertRuleItem(
                  index: index,
                  ruleName: name,
                  threshold: threshold,
                  enabled: enabled,
                  channels: channels,
                );
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDynamicAlertRuleItem({
    required int index,
    required String ruleName,
    required String threshold,
    required bool enabled,
    required List<String> channels,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                ruleName,
                style: const TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Threshold: ',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    height: 32,
                    child: TextFormField(
                      initialValue: threshold,
                      maxLength: 8,
                      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(8),
                      ],
                      onChanged: (val) {
                        final numVal = int.tryParse(val) ?? 0;
                        if (index < controller.alertRules.length) {
                          controller.alertRules[index]['threshold'] = numVal;
                        }
                      },
                      style: const TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: AppColors.textPrimary,
                        fontSize: 12,
                      ),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                        ),
                        filled: true,
                        fillColor: AppColors.bgInput,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  FilterChip(
                    label: const Text(
                      'Push',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: AppColors.textPrimary,
                        fontSize: 12,
                      ),
                    ),
                    onSelected: (sel) {
                      if (index < controller.alertRules.length) {
                        final list = List<String>.from(channels);
                        if (sel) {
                          list.add('push');
                        } else {
                          list.remove('push');
                        }
                        controller.alertRules[index]['channels'] = list;
                        controller.alertRules.refresh();
                      }
                    },
                    selected: channels.contains('push'),
                    selectedColor: AppColors.brand.withValues(alpha: 0.3),
                    backgroundColor: AppColors.bgSurface,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  FilterChip(
                    label: const Text(
                      'Email',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: AppColors.textPrimary,
                        fontSize: 12,
                      ),
                    ),
                    onSelected: (sel) {
                      if (index < controller.alertRules.length) {
                        final list = List<String>.from(channels);
                        if (sel) {
                          list.add('email');
                        } else {
                          list.remove('email');
                        }
                        controller.alertRules[index]['channels'] = list;
                        controller.alertRules.refresh();
                      }
                    },
                    selected: channels.contains('email'),
                    selectedColor: AppColors.brand.withValues(alpha: 0.3),
                    backgroundColor: AppColors.bgSurface,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  FilterChip(
                    label: const Text(
                      'SMS',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: AppColors.textPrimary,
                        fontSize: 12,
                      ),
                    ),
                    onSelected: (sel) {
                      if (index < controller.alertRules.length) {
                        final list = List<String>.from(channels);
                        if (sel) {
                          list.add('sms');
                        } else {
                          list.remove('sms');
                        }
                        controller.alertRules[index]['channels'] = list;
                        controller.alertRules.refresh();
                      }
                    },
                    selected: channels.contains('sms'),
                    selectedColor: AppColors.brand.withValues(alpha: 0.3),
                    backgroundColor: AppColors.bgSurface,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                ],
              ),
              Switch(
                value: enabled,
                onChanged: (val) {
                  if (index < controller.alertRules.length) {
                    controller.alertRules[index]['enabled'] = val;
                    controller.alertRules.refresh();
                  }
                },
                activeColor: AppColors.success,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEscalationTiersPanel() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.bgPage,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Escalation Tiers',
            style: TextStyle(
              fontFamily: TWTypography.brandFamily,
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildTierItem(
            'Tier 1: Automated',
            'Handled by AI model, auto-approved/rejected based on clear guidelines.',
          ),
          _buildTierItem(
            'Tier 2: Junior Mod',
            'Appeals and borderline cases requiring human review.',
          ),
          _buildTierItem(
            'Tier 3: Senior Mod',
            'Complex cases, VIP accounts, and high-severity violations.',
          ),
          _buildTierItem(
            'Tier 4: Admin/Legal',
            'Law enforcement requests, severe illegal content, platform-wide threats.',
          ),
        ],
      ),
    );
  }

  Widget _buildTierItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: TWTypography.brandFamily,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

