import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/advertiser/presentation/controllers/advertiser_portal_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Brand Profile & Settings tab for Truthworld Advertiser Studio.
class BrandSettingsTabView extends StatelessWidget {
  const BrandSettingsTabView({required this.controller, super.key});

  final AdvertiserPortalController controller;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildBrandProfileSection(context),
          const SizedBox(height: 24),
          _buildTeamManagementSection(context),
          const SizedBox(height: 24),
          _buildNotificationTogglesSection(),
          const SizedBox(height: 24),
          _buildDeveloperApiSection(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Brand Profile & Studio Settings',
          style: TextStyle(
            fontFamily: TWTypography.brandFamily,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Manage your public advertiser verification, team member seats, notification triggers, and conversion API credentials.',
          style: TextStyle(
            fontFamily: TWTypography.uiFamily,
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildBrandProfileSection(BuildContext context) {
    final nameCtrl = TextEditingController(text: controller.brandName.value);
    final tagCtrl = TextEditingController(text: controller.brandTagline.value);
    final webCtrl = TextEditingController(text: controller.brandWebsite.value);
    final emailCtrl = TextEditingController(text: controller.brandEmail.value);
    final catCtrl = TextEditingController(text: controller.brandCategory.value);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.verified_user_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Brand Identity & Verified Status',
                    style: TextStyle(
                      fontFamily: TWTypography.brandFamily,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: Colors.white, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'Verified Advertiser',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: nameCtrl,
                  inputFormatters: TruthworldTextInputFormatters.standard,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Brand / Organization Name',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: Color(0xFF121214),
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: catCtrl,
                  inputFormatters: TruthworldTextInputFormatters.standard,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Industry Category',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: Color(0xFF121214),
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: tagCtrl,
            inputFormatters: TruthworldTextInputFormatters.standard,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Brand Motto / Tagline',
              labelStyle: TextStyle(color: AppColors.textSecondary),
              filled: true,
              fillColor: Color(0xFF121214),
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: webCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Official Website URL',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: Color(0xFF121214),
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: emailCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Studio Support Contact Email',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: Color(0xFF121214),
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final tag = tagCtrl.text.trim();
                final cat = catCtrl.text.trim();

                final nameVal = ContentValidator.validate(name, fieldName: 'Brand Name', minLength: 2, maxLength: 80);
                if (!nameVal.isValid) {
                  AppSnackbar.warning(nameVal.message);
                  return;
                }

                if (tag.isNotEmpty) {
                  final tagVal = ContentValidator.validate(tag, fieldName: 'Brand Tagline', maxLength: 150);
                  if (!tagVal.isValid) {
                    AppSnackbar.warning(tagVal.message);
                    return;
                  }
                }

                if (cat.isNotEmpty) {
                  final catVal = ContentValidator.validate(cat, fieldName: 'Industry Category', maxLength: 50);
                  if (!catVal.isValid) {
                    AppSnackbar.warning(catVal.message);
                    return;
                  }
                }

                controller.saveBrandSettings(
                  name: name,
                  tagline: tag,
                  website: webCtrl.text.trim(),
                  email: emailCtrl.text.trim(),
                  category: cat,
                );
              },
              icon: const Icon(Icons.save_rounded, color: Colors.black, size: 16),
              label: const Text(
                'Save Profile Changes',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamManagementSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.group_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Studio Team Members & Role Access',
                    style: TextStyle(
                      fontFamily: TWTypography.brandFamily,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: () => _showInviteMemberDialog(context),
                icon: const Icon(Icons.person_add_rounded, color: Colors.white, size: 16),
                label: const Text(
                  'Invite Member',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontSize: 13,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF3F3F46)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Obx(() {
            final members = controller.teamMembers;
            return Column(
              children: members.map((member) {
                final isOwner = (member['role'] as String).contains('Owner');
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121214),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF27272A)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFF27272A),
                        child: Text(
                          (member['name'] as String).substring(0, 1).toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              member['name'] as String,
                              style: const TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              member['email'] as String,
                              style: const TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E22),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF323238)),
                        ),
                        child: Text(
                          member['role'] as String,
                          style: const TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (!isOwner)
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.white, size: 18),
                          tooltip: 'Remove member',
                          onPressed: () {
                            controller.removeTeamMember(member['email'] as String);
                          },
                        )
                      else
                        const SizedBox(width: 48),
                    ],
                  ),
                );
              }).toList(),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildNotificationTogglesSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.notifications_active_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text(
                'Studio Alerts & Notification Triggers',
                style: TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Obx(() => _buildToggleTile(
                title: 'Low Balance Warning',
                subtitle: 'Send SMS & email alert when prepaid wallet drops below 10% daily burn rate.',
                value: controller.lowBudgetAlert.value,
                onChanged: (val) => controller.lowBudgetAlert.value = val,
              )),
          const Divider(color: Color(0xFF27272A), height: 16),
          Obx(() => _buildToggleTile(
                title: 'Daily Performance Digest',
                subtitle: 'Receive aggregated morning summary of impressions, spend, CTR, and conversions.',
                value: controller.dailyPerformanceDigest.value,
                onChanged: (val) => controller.dailyPerformanceDigest.value = val,
              )),
          const Divider(color: Color(0xFF27272A), height: 16),
          Obx(() => _buildToggleTile(
                title: 'Campaign Status Changes',
                subtitle: 'Instant alerts when campaigns are approved by moderation or conclude delivery.',
                value: controller.campaignStatusNotifications.value,
                onChanged: (val) => controller.campaignStatusNotifications.value = val,
              )),
          const Divider(color: Color(0xFF27272A), height: 16),
          Obx(() => _buildToggleTile(
                title: 'Creator Sponsorship Responses',
                subtitle: 'Notify immediately when a creator accepts or delivers on a sponsorship proposal.',
                value: controller.sponsorshipAlerts.value,
                onChanged: (val) => controller.sponsorshipAlerts.value = val,
              )),
        ],
      ),
    );
  }

  Widget _buildToggleTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          activeColor: AppColors.brand,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildDeveloperApiSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.code_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Developer Conversion API & Tracking Key',
                    style: TextStyle(
                      fontFamily: TWTypography.brandFamily,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: controller.regenerateApiKey,
                icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 16),
                label: const Text(
                  'Regenerate Key',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontSize: 12,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF3F3F46)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Use this secret key in your website or server backend to send server-to-server conversion events (purchases, signups, app installs) directly to Truthworld Attribution.',
            style: TextStyle(
              fontFamily: TWTypography.uiFamily,
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Obx(() {
            final key = controller.conversionApiKey.value;
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF121214),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF27272A)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      key,
                      style: const TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.brand,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 18),
                    tooltip: 'Copy API Key',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: key));
                      AppSnackbar.show(
                        'Key Copied',
                        'Conversion tracking API key copied to clipboard.',
                        backgroundColor: AppColors.success,
                        colorText: AppColors.textPrimary,
                      );
                    },
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showInviteMemberDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final roleChoice = 'Campaign Manager'.obs;

    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF161618),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF27272A)),
        ),
        title: const Text(
          'Invite Studio Team Member',
          style: TextStyle(
            fontFamily: TWTypography.brandFamily,
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                inputFormatters: TruthworldTextInputFormatters.standard,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: Color(0xFF121214),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: Color(0xFF121214),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                ),
              ),
              const SizedBox(height: 12),
              Obx(() {
                return DropdownButtonFormField<String>(
                  value: roleChoice.value,
                  dropdownColor: const Color(0xFF1C1C1F),
                  style: const TextStyle(color: Colors.white, fontFamily: TWTypography.uiFamily),
                  decoration: const InputDecoration(
                    labelText: 'Assigned Role',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: Color(0xFF121214),
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
                  ),
                  items: [
                    'Campaign Manager',
                    'Billing Analyst',
                    'Creative Lead',
                    'Viewer',
                  ].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (val) {
                    if (val != null) roleChoice.value = val;
                  },
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final email = emailCtrl.text.trim();
              if (name.isEmpty || email.isEmpty) {
                AppSnackbar.warning('Please enter member name and email.');
                return;
              }
              final nameVal = ContentValidator.validate(name, fieldName: 'Member Name', minLength: 2, maxLength: 80);
              if (!nameVal.isValid) {
                AppSnackbar.warning(nameVal.message);
                return;
              }
              controller.inviteTeamMember(name, email, roleChoice.value);
              Get.back();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.black,
            ),
            child: const Text('Send Invitation', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
