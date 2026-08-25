import 'package:flutter/material.dart';
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
        color: const Color(0xFF181818),
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
                  color: const Color(0xFF212121),
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
                      'Direct Approval & AI Bypass Toggles (Google Cloud Vision & Gemini AI)',
                      style: TextStyle(
                        fontFamily: TWTypography.brandFamily,
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'When a toggle is ON, submissions for that category bypass AI auto-moderation (Gemini AI / Google Cloud Vision) and appear directly in the Admin Portal for manual approval. When OFF, items are automatically filtered and approved/rejected by AI.',
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
              const SizedBox(width: 16),
              Obx(() {
                final allOn = controller.rxBypassChannelBanners.value &&
                    controller.rxBypassChannelAvatars.value &&
                    controller.rxBypassVideoThumbnails.value &&
                    controller.rxBypassCommunityPosts.value &&
                    controller.rxBypassTopicThumbnails.value &&
                    controller.rxBypassPlaylistThumbnails.value &&
                    controller.rxBypassAds.value;
                return OutlinedButton.icon(
                  onPressed: () => controller.toggleAllMediaModes(!allOn),
                  icon: Icon(
                    allOn ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  label: Text(
                    allOn ? 'Turn All Auto AI' : 'Direct Approve All',
                    style: const TextStyle(
                      fontFamily: TWTypography.brandFamily,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFF212121),
                    side: BorderSide(
                      color: allOn
                          ? const Color(0xFF2BA640).withValues(alpha: 0.6)
                          : Colors.white.withValues(alpha: 0.12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              }),
            ],
          ),
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
                    title: 'Advertiser Campaigns',
                    description: 'Advertiser campaign submissions (Feed, Video, Banner & Sponsor ads). When ON, campaigns bypass Gemini AI auto approve/reject and route to Admin for manual review.',
                    icon: Icons.campaign_outlined,
                    modeKey: 'ads',
                    rxValue: controller.rxBypassAds,
                    isGemini: true,
                  ),
                  _buildToggleCard(
                    width: isWide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth,
                    title: 'Channel Banners',
                    description: 'Channel header artwork and banners uploaded by creators.',
                    icon: Icons.panorama_outlined,
                    modeKey: 'banner',
                    rxValue: controller.rxBypassChannelBanners,
                  ),
                  _buildToggleCard(
                    width: isWide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth,
                    title: 'Channel Avatars',
                    description: 'Profile pictures and avatar images uploaded for channels.',
                    icon: Icons.account_circle_outlined,
                    modeKey: 'avatar',
                    rxValue: controller.rxBypassChannelAvatars,
                  ),
                  _buildToggleCard(
                    width: isWide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth,
                    title: 'Video Thumbnails',
                    description: 'Custom preview thumbnails uploaded during video publishing.',
                    icon: Icons.photo_size_select_actual_outlined,
                    modeKey: 'thumbnails',
                    rxValue: controller.rxBypassVideoThumbnails,
                  ),
                  _buildToggleCard(
                    width: isWide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth,
                    title: 'Community Posts',
                    description: 'Image attachments and artwork uploaded in community feed posts.',
                    icon: Icons.dynamic_feed_outlined,
                    modeKey: 'community',
                    rxValue: controller.rxBypassCommunityPosts,
                  ),
                  _buildToggleCard(
                    width: isWide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth,
                    title: 'Topics Custom Thumbnails',
                    description: 'Custom cover thumbnails uploaded for discussion topics.',
                    icon: Icons.tag_rounded,
                    modeKey: 'topics',
                    rxValue: controller.rxBypassTopicThumbnails,
                  ),
                  _buildToggleCard(
                    width: isWide ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth,
                    title: 'Playlists Custom Thumbnails',
                    description: 'Custom cover artwork and thumbnails uploaded for playlists.',
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
        color: const Color(0xFF212121),
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
                  color: const Color(0xFF181818),
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
                  activeTrackColor: const Color(0xFF2BA640),
                  activeColor: Colors.white,
                  inactiveTrackColor: const Color(0xFF333333),
                  inactiveThumbColor: const Color(0xFF888888),
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
                    ? const Color(0xFF2BA640).withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isBypassed
                      ? const Color(0xFF2BA640).withValues(alpha: 0.4)
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
                          ? const Color(0xFF2BA640)
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
                          ? const Color(0xFF2BA640)
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
        color: const Color(0xFF181818),
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
                  color: const Color(0xFF212121),
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
        color: const Color(0xFF181818),
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
                  backgroundColor: const Color(0xFF242424),
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
                    backgroundColor: const Color(0xFF212121),
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
                    backgroundColor: const Color(0xFF212121),
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
                    backgroundColor: const Color(0xFF212121),
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
                activeColor: const Color(0xFF2BA640),
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
        color: const Color(0xFF181818),
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

