import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/widgets/studio_loading_indicator.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/customization_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

class ChannelCustomizationPage extends StatelessWidget {
  const ChannelCustomizationPage({
    required this.channelId,
    required this.ownerId,
    this.initialTabIndex = 0,
    super.key,
  });
  final String channelId;
  final String ownerId;
  /// Which tab to open initially: 0=Branding, 1=Basic Info, 2=Advanced, 3=Settings
  final int initialTabIndex;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<CustomizationController>(
      init: CustomizationController(
        channelId: channelId,
        ownerId: ownerId,
        initialTabIndex: initialTabIndex,
      ),
      tag: channelId,
      builder: (controller) => _CustomizationView(controller: controller),
    );
  }
}

class _CustomizationView extends StatelessWidget {
  const _CustomizationView({required this.controller});
  final CustomizationController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        backgroundColor: AppColors.bgSurface,
        elevation: 0,
        title: const Text(
          'Channel Customization',
          style: TextStyle(
            fontFamily: TWTypography.brandFamily,
            fontFamilyFallback: TWTypography.fallbackFamilies,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        bottom: TabBar(
          controller: controller.tabController,
          indicatorColor: AppColors.brand,
          indicatorWeight: 3,
          labelColor: AppColors.brand,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: const TextStyle(
            fontFamily: TWTypography.uiFamily,
            fontFamilyFallback: TWTypography.fallbackFamilies,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
          tabs: const [
            Tab(text: 'Branding'),
            Tab(text: 'Basic Info'),
            Tab(text: 'Advanced'),
            Tab(text: 'Settings'),
          ],
        ),
        actions: [
          Obx(() {
            if (controller.isSaving.value) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.brand),
                  ),
                ),
              );
            } else {
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (controller.formKey.currentState!.validate()) {
                      controller.saveChanges();
                    }
                  },
                  icon: const Icon(Icons.save_rounded, size: 16, color: Colors.black),
                  label: const Text(
                    'Save',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontFamilyFallback: TWTypography.fallbackFamilies,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              );
            }
          }),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading) {
          return const StudioLoadingIndicator(
            message: 'Loading channel customization...',
          );
        } else {
          return Form(
            key: controller.formKey,
            child: Column(
              children: [
                _buildModerationBanner(),
                Expanded(
                  child: TabBarView(
                    controller: controller.tabController,
                    children: [
                      _buildBrandingTab(),
                      _buildBasicInfoTab(),
                      _buildAdvancedTab(),
                      _buildSettingsTab(),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
      }),
    );
  }

  Widget _buildModerationBanner() {
    final channelStatus = controller.status.value;
    final isGeminiApproved = controller.geminiApproved.value;
    final reason = controller.moderationReason.value;

    if (channelStatus == 'active' || isGeminiApproved) {
      return const SizedBox.shrink();
    }

    Color bannerColor;
    IconData icon;
    String title;
    String subtitle;

    if (channelStatus == 'underReview') {
      bannerColor = AppColors.info;
      icon = Icons.sync_rounded;
      title = 'Branding Under Verification System Review';
      subtitle =
          'Our Verification System is checking your channel details (name, description, tags) against our community guidelines. This usually takes just a few seconds.';
    } else if (channelStatus == 'verificationRejected') {
      bannerColor = AppColors.error;
      icon = Icons.error_outline_rounded;
      title = 'Branding Verification Rejected';
      subtitle =
          'We created channel according to community guidelines, then channel selected for manual verification. ${reason.isNotEmpty ? '\n\nVerification System Response: $reason' : ''}';
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: bannerColor.withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(color: bannerColor.withValues(alpha: 0.3)),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (channelStatus == 'underReview')
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.info),
              ),
            )
          else
            Icon(icon, color: bannerColor, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: TWTypography.brandFamily,
                    fontFamilyFallback: TWTypography.fallbackFamilies,
                    color: bannerColor,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontFamilyFallback: TWTypography.fallbackFamilies,
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
    );
  }

  Widget _buildBrandingTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 720;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Channel Avatar Section (Picture) - Displayed before banner
              _buildSectionTitle('Channel Avatar'),
              const SizedBox(height: 6),
              const Text(
                'Your profile picture will appear where your channel is presented on TruthWorld, like next to your videos and comments.',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontFamilyFallback: TWTypography.fallbackFamilies,
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAvatarCard(),
                    const SizedBox(width: 24),
                    Expanded(
                      child: _buildAvatarControls(),
                    ),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: _buildAvatarCard()),
                    const SizedBox(height: 16),
                    _buildAvatarControls(),
                  ],
                ),

              const SizedBox(height: 36),
              const Divider(color: AppColors.bgDivider, height: 1),
              const SizedBox(height: 36),

              // 2. Channel Banner Section - Industry Standard Size on Desktop
              _buildSectionTitle('Channel Banner'),
              const SizedBox(height: 6),
              const Text(
                'This image will appear across the top of your channel on desktop, mobile, and TV feeds.',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontFamilyFallback: TWTypography.fallbackFamilies,
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 400,
                        minWidth: 300,
                      ),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: _buildBannerCard(),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: _buildBannerControls(),
                    ),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: _buildBannerCard(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildBannerControls(),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImageStatusNotice({
    required String status,
    required String reason,
    required bool isBanner,
  }) {
    if (status == 'APPROVED' || status.isEmpty) {
      return const SizedBox.shrink();
    }

    Color color;
    IconData icon;
    String title;
    String subtitle;
    var isPending = false;

    if (status == 'PENDING') {
      color = AppColors.info;
      icon = Icons.sync_rounded;
      title = '${isBanner ? "Banner" : "Avatar"} Verification Pending';
      subtitle =
          'Google Vision AI is validating this image. Feel free to save changes; verification will complete in the background.';
      isPending = true;
    } else if (status == 'REJECTED') {
      color = AppColors.error;
      icon = Icons.error_outline_rounded;
      title = '${isBanner ? "Banner" : "Avatar"} Rejected';
      subtitle = reason.isNotEmpty
          ? reason
          : 'This image does not comply with safety guidelines. Please upload a new image or request manual review if you believe it complies.';
    } else if (status == 'FLAGGED') {
      color = AppColors.warning;
      icon = Icons.warning_amber_rounded;
      title = '${isBanner ? "Banner" : "Avatar"} Review Needed';
      subtitle = reason.isNotEmpty
          ? reason
          : 'This image has been flagged for potential review. You can upload a new image or request manual admin review.';
    } else if (status == 'MANUAL_REVIEW') {
      color = AppColors.info;
      icon = Icons.rate_review_rounded;
      title = '${isBanner ? "Banner" : "Avatar"} Under Manual Review';
      subtitle =
          'Your appeal has been submitted. Our moderation team is reviewing your image.';
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isPending)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.info),
              ),
            )
          else
            Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontFamilyFallback: TWTypography.fallbackFamilies,
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontFamilyFallback: TWTypography.fallbackFamilies,
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
                if (status == 'REJECTED' || status == 'FLAGGED') ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () =>
                        controller.requestManualReview(isBanner: isBanner),
                    icon: const Icon(
                      Icons.rate_review_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Request Manual Review',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontFamilyFallback: TWTypography.fallbackFamilies,
                        fontSize: 12,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: BorderSide(color: color),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
                if (isPending) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => controller.bypassVerification(isBanner),
                    icon: const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Bypass Verification (Local Dev/Test)',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontFamilyFallback: TWTypography.fallbackFamilies,
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextField(
            controller: controller.channelNameController,
            label: 'Channel Name',
            hint: 'Enter your channel name',
            validator: (val) =>
                val?.isEmpty ?? true ? 'Channel name is required' : null,
          ),
          const SizedBox(height: 24),
          _buildTextField(
            controller: controller.descriptionController,
            label: 'Description',
            hint: 'Tell viewers about your channel',
            maxLines: 5,
          ),
          const SizedBox(height: 24),
          _buildTextField(
            controller: controller.customUrlController,
            label: 'Custom URL / Handle',
            hint: 'yourchannel',
            maxLength: 30,
            inputFormatters: [
              LengthLimitingTextInputFormatter(30),
              FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9._-]')),
            ],
            prefix: const Text(
              '@',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                fontFamilyFallback: TWTypography.fallbackFamilies,
                color: AppColors.brand,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildTextField(
            controller: controller.languageController,
            label: 'Language',
            hint: 'en',
          ),
          const SizedBox(height: 24),
          _buildTextField(
            controller: controller.tagsController,
            label: 'Tags',
            hint: 'tag1, tag2, tag3',
            helperText:
                'Separate tags with commas to boost search discoverability',
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Contact Information'),
          const SizedBox(height: 16),
          _buildTextField(
            controller: controller.contactEmailController,
            label: 'Contact Email',
            hint: 'contact@example.com',
            keyboardType: TextInputType.emailAddress,
            inputFormatters: const [],
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: controller.websiteUrlController,
            label: 'Website URL',
            hint: 'https://example.com',
          ),
          const SizedBox(height: 32),
          _buildSectionTitle('Category'),
          const SizedBox(height: 16),
          _buildTextField(
            controller: controller.categoryController,
            label: 'Channel Category',
            hint: 'e.g., Short Films, Education, Entertainment',
          ),
          const SizedBox(height: 32),
          _buildSectionTitle('Social Links'),
          const SizedBox(height: 8),
          const Text(
            'Link your official profiles across social media to help viewers connect with your presence.',
            style: TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: controller.youtubeController,
            label: 'YouTube',
            hint: 'https://youtube.com/@channel',
            prefixIcon: Icons.smart_display_outlined,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: controller.twitterController,
            label: 'Twitter / X',
            hint: 'https://x.com/username',
            prefixIcon: Icons.alternate_email,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: controller.instagramController,
            label: 'Instagram',
            hint: 'https://instagram.com/username',
            prefixIcon: Icons.camera_alt_outlined,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: controller.facebookController,
            label: 'Facebook',
            hint: 'https://facebook.com/username',
            prefixIcon: Icons.facebook,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: controller.linkedinController,
            label: 'LinkedIn',
            hint: 'https://linkedin.com/in/username',
            prefixIcon: Icons.work_outline,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: controller.tiktokController,
            label: 'TikTok',
            hint: 'https://tiktok.com/@username',
            prefixIcon: Icons.music_note_outlined,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: controller.whatsappController,
            label: 'WhatsApp Channel',
            hint: 'https://whatsapp.com/channel/...',
            prefixIcon: Icons.chat_outlined,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: controller.telegramController,
            label: 'Telegram',
            hint: 'https://t.me/username',
            prefixIcon: Icons.send_outlined,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: controller.discordController,
            label: 'Discord',
            hint: 'https://discord.gg/server',
            prefixIcon: Icons.forum_outlined,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: controller.githubController,
            label: 'GitHub',
            hint: 'https://github.com/username',
            prefixIcon: Icons.code,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: controller.twitchController,
            label: 'Twitch',
            hint: 'https://twitch.tv/username',
            prefixIcon: Icons.live_tv_outlined,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: controller.redditController,
            label: 'Reddit',
            hint: 'https://reddit.com/r/...',
            prefixIcon: Icons.chat_bubble_outline,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: controller.patreonController,
            label: 'Patreon',
            hint: 'https://patreon.com/username',
            prefixIcon: Icons.monetization_on_outlined,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: controller.threadsController,
            label: 'Threads',
            hint: 'https://threads.net/@username',
            prefixIcon: Icons.alternate_email_outlined,
          ),
          if (controller.extraSocialControllers.isNotEmpty) ...[
            for (final entry in controller.extraSocialControllers.entries) ...[
              const SizedBox(height: 16),
              _buildTextField(
                controller: entry.value,
                label: entry.key[0].toUpperCase() + entry.key.substring(1),
                hint: 'https://${entry.key}.com/...',
                prefixIcon: Icons.link_rounded,
              ),
            ],
          ],
          const SizedBox(height: 32),
          _buildSectionTitle('Custom Links'),
          const SizedBox(height: 8),
          const Text(
            'Add custom links to websites, your merchandise store, portfolio, or other external resources for your audience.',
            style: TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          Obx(() {
            if (controller.customLinks.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.bgDivider),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.add_link_rounded,
                      size: 32,
                      color: AppColors.textTertiary,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'No custom links added yet.',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Click "Add Custom Link" below to publish custom links for your channel.',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: AppColors.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: List.generate(controller.customLinks.length, (index) {
                final item = controller.customLinks[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.bgDivider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Custom Link #${index + 1}',
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            onPressed: () =>
                                controller.removeCustomLink(index),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: AppColors.error,
                              size: 20,
                            ),
                            tooltip: 'Remove link',
                            splashRadius: 20,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: item.titleController,
                        label: 'Link Title',
                        hint: 'e.g., My Store, Portfolio, Discord',
                        maxLength: 50,
                        prefixIcon: Icons.title_rounded,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: item.urlController,
                        label: 'Link URL',
                        hint: 'https://example.com',
                        maxLength: 500,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(500),
                          FilteringTextInputFormatter.deny(RegExp(r'\s')),
                        ],
                        prefixIcon: Icons.link_rounded,
                      ),
                    ],
                  ),
                );
              }),
            );
          }),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: controller.addCustomLink,
            icon: const Icon(Icons.add, size: 18, color: Colors.white),
            label: const Text(
              'Add Custom Link',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: AppColors.bgDivider),
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Visibility'),
          const SizedBox(height: 12),
          _buildVisibilityOptionCard(
            value: 'Public',
            title: 'Public',
            subtitle: 'Anyone can search for and view your channel and its videos',
            icon: Icons.public_rounded,
          ),
          _buildVisibilityOptionCard(
            value: 'Unlisted',
            title: 'Unlisted',
            subtitle: "Anyone with the link can view your channel and its videos, but it won't appear in search results",
            icon: Icons.link_rounded,
          ),
          _buildVisibilityOptionCard(
            value: 'Private',
            title: 'Private',
            subtitle: 'Only you and approved viewers can view your channel and its videos',
            icon: Icons.lock_outline_rounded,
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('Interaction Settings'),
          const SizedBox(height: 12),
          Obx(
            () => _buildSwitchTile(
              title: 'Allow Comments',
              subtitle: 'Let viewers comment on your videos',
              value: controller.allowComments.value,
              onChanged: (val) => controller.allowComments.value = val,
            ),
          ),
          Obx(
            () => _buildSwitchTile(
              title: 'Allow Subscriptions',
              subtitle: 'Allow users to subscribe to your channel',
              value: controller.allowSubscriptions.value,
              onChanged: (val) => controller.allowSubscriptions.value = val,
            ),
          ),
          Obx(
            () => _buildSwitchTile(
              title: 'Show Subscriber Count',
              subtitle: 'Display your subscriber count publicly',
              value: controller.showSubscriberCount.value,
              onChanged: (val) => controller.showSubscriberCount.value = val,
            ),
          ),
          Obx(
            () => _buildSwitchTile(
              title: 'Show Like Count',
              subtitle: 'Display like count on your videos publicly',
              value: controller.showLikeCount.value,
              onChanged: (val) => controller.showLikeCount.value = val,
            ),
          ),
          Obx(
            () => _buildSwitchTile(
              title: 'Show Dislike Count',
              subtitle: 'Display dislike count on your videos publicly',
              value: controller.showDislikeCount.value,
              onChanged: (val) => controller.showDislikeCount.value = val,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisibilityOptionCard({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Obx(() {
      final isSelected = controller.visibility.value.toLowerCase() == value.toLowerCase();
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withValues(alpha: 0.06)
              : AppColors.bgSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.brand : AppColors.bgDivider,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => controller.setVisibility(value),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          fontFamilyFallback: TWTypography.fallbackFamilies,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          fontFamilyFallback: TWTypography.fallbackFamilies,
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  isSelected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: isSelected ? AppColors.brand : AppColors.textSecondary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.brand,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontFamily: TWTypography.brandFamily,
            fontFamilyFallback: TWTypography.fallbackFamilies,
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? helperText,
    int maxLines = 1,
    Widget? prefix,
    IconData? prefixIcon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    int? maxLength,
  }) {
    final effectiveLimit = maxLength ?? (maxLines > 1 ? 5000 : 100);
    final effectiveFormatters = inputFormatters ??
        TruthworldTextInputFormatters.internationalWithLimit(effectiveLimit);

    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: effectiveLimit,
      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
      keyboardType: keyboardType,
      inputFormatters: effectiveFormatters,
      validator: validator,
      style: const TextStyle(
        fontFamily: TWTypography.uiFamily,
        fontFamilyFallback: TWTypography.fallbackFamilies,
        color: AppColors.textPrimary,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helperText,
        prefix: prefix,
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: Colors.white, size: 20)
            : null,
        labelStyle: const TextStyle(
          fontFamily: TWTypography.uiFamily,
          fontFamilyFallback: TWTypography.fallbackFamilies,
          color: AppColors.textSecondary,
          fontSize: 13,
        ),
        hintStyle: const TextStyle(
          fontFamily: TWTypography.uiFamily,
          fontFamilyFallback: TWTypography.fallbackFamilies,
          color: AppColors.textTertiary,
          fontSize: 13,
        ),
        helperStyle: const TextStyle(
          fontFamily: TWTypography.uiFamily,
          fontFamilyFallback: TWTypography.fallbackFamilies,
          color: AppColors.textSecondary,
          fontSize: 11,
        ),
        filled: true,
        fillColor: AppColors.bgSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.bgDivider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.bgDivider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.brand, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
    );
  }

  Widget _buildAvatarCard() {
    return Obx(() {
      final currentUrl = controller.avatarUrl.value;
      final newBytes = controller.newAvatarBytes.value;

      Widget contentWidget;
      if (newBytes != null) {
        contentWidget = Image.memory(newBytes, fit: BoxFit.cover);
      } else if (currentUrl.isNotEmpty) {
        final cleanUrl = currentUrl.trim().replaceAll(' ', '%20');
        contentWidget = CachedNetworkImage(
          imageUrl: cleanUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => const ColoredBox(
            color: AppColors.bgSurface,
          ),
          errorWidget: (context, url, error) {
            if (kIsWeb) {
              return Image.network(
                cleanUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, err, stack) =>
                    _buildAvatarPlaceholder(),
              );
            }
            return _buildAvatarPlaceholder();
          },
        );
      } else {
        contentWidget = _buildAvatarPlaceholder();
      }

      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: InkWell(
          onTap: () => controller.pickImage(true),
          borderRadius: BorderRadius.circular(65),
          child: SizedBox(
            width: 130,
            height: 130,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.bgDivider,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  contentWidget,
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.bgSurface,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.bgDivider,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.white,
                        size: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildAvatarPlaceholder() {
    return const ColoredBox(
      color: AppColors.bgSurface,
      child: Center(
        child: Icon(
          Icons.account_circle_rounded,
          size: 64,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildAvatarControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'It’s recommended to use a picture that’s at least 98 x 98 pixels (800 x 800 recommended) and 4MB or less. Use a PNG or JPG file. Make sure your picture follows the TruthWorld Community Guidelines.',
          style: TextStyle(
            fontFamily: TWTypography.uiFamily,
            fontFamilyFallback: TWTypography.fallbackFamilies,
            color: AppColors.textSecondary,
            fontSize: 12,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 16),
        Obx(() {
          final hasAvatar = controller.newAvatarBytes.value != null ||
              controller.avatarUrl.value.isNotEmpty;

          return Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => controller.pickImage(true),
                icon: const Icon(
                  Icons.file_upload_outlined,
                  size: 16,
                  color: Colors.white,
                ),
                label: Text(
                  hasAvatar ? 'Change' : 'Upload',
                  style: const TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontFamilyFallback: TWTypography.fallbackFamilies,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: AppColors.bgElevated),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              if (hasAvatar)
                TextButton.icon(
                  onPressed: controller.removeAvatar,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  label: const Text(
                    'Remove',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontFamilyFallback: TWTypography.fallbackFamilies,
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
            ],
          );
        }),
        Obx(
          () => _buildImageStatusNotice(
            status: controller.avatarStatus.value,
            reason: controller.avatarStatusReason.value,
            isBanner: false,
          ),
        ),
      ],
    );
  }

  Widget _buildBannerCard() {
    return Obx(() {
      final currentUrl = controller.bannerUrl.value;
      final newBytes = controller.newBannerBytes.value;
      final hasBanner = newBytes != null || currentUrl.isNotEmpty;

      Widget contentWidget;
      if (newBytes != null) {
        contentWidget = Image.memory(newBytes, fit: BoxFit.cover);
      } else if (currentUrl.isNotEmpty) {
        final cleanUrl = currentUrl.trim().replaceAll(' ', '%20');
        contentWidget = CachedNetworkImage(
          imageUrl: cleanUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => const ColoredBox(
            color: AppColors.bgSurface,
          ),
          errorWidget: (context, url, error) {
            if (kIsWeb) {
              return Image.network(
                cleanUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, err, stack) =>
                    _buildBannerPlaceholder(hasError: true),
              );
            }
            return _buildBannerPlaceholder(hasError: true);
          },
        );
      } else {
        contentWidget = _buildBannerPlaceholder(hasError: false);
      }

      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: InkWell(
          onTap: () => controller.pickImage(false),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.bgDivider,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                contentWidget,
                if (hasBanner) ...[
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            AppColors.bgPage.withValues(alpha: 0.35),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.bgSurfaceHover,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _buildBannerPlaceholder({required bool hasError}) {
    return ColoredBox(
      color: AppColors.bgSurface,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasError
                  ? Icons.broken_image_rounded
                  : Icons.add_photo_alternate_rounded,
              size: 38,
              color: Colors.white,
            ),
            const SizedBox(height: 8),
            Text(
              hasError ? 'Failed to load banner' : 'Upload Channel Banner',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                fontFamilyFallback: TWTypography.fallbackFamilies,
                color: hasError
                    ? AppColors.textTertiary
                    : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              hasError ? 'Click to re-select' : 'Recommended 2560 x 1440 px',
              style: const TextStyle(
                fontFamily: TWTypography.uiFamily,
                fontFamilyFallback: TWTypography.fallbackFamilies,
                color: AppColors.textTertiary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'For the best results on all devices, use an image that’s at least 2048 x 1152 pixels (2560 x 1440 recommended) and 6MB or less.',
          style: TextStyle(
            fontFamily: TWTypography.uiFamily,
            fontFamilyFallback: TWTypography.fallbackFamilies,
            color: AppColors.textSecondary,
            fontSize: 12,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Safe Area: Logos and text should remain centered within the 1546 x 423 px safe zone so they display consistently across TV, desktop, and mobile screens.',
          style: TextStyle(
            fontFamily: TWTypography.uiFamily,
            fontFamilyFallback: TWTypography.fallbackFamilies,
            color: AppColors.textTertiary,
            fontSize: 11,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        Obx(() {
          final hasBanner = controller.newBannerBytes.value != null ||
              controller.bannerUrl.value.isNotEmpty;

          return Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => controller.pickImage(false),
                icon: const Icon(
                  Icons.file_upload_outlined,
                  size: 16,
                  color: Colors.white,
                ),
                label: Text(
                  hasBanner ? 'Change' : 'Upload',
                  style: const TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontFamilyFallback: TWTypography.fallbackFamilies,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: AppColors.bgElevated),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              if (hasBanner)
                TextButton.icon(
                  onPressed: controller.removeBanner,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  label: const Text(
                    'Remove',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontFamilyFallback: TWTypography.fallbackFamilies,
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
            ],
          );
        }),
        Obx(
          () => _buildImageStatusNotice(
            status: controller.bannerStatus.value,
            reason: controller.bannerStatusReason.value,
            isBanner: true,
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: const TextStyle(
            fontFamily: TWTypography.uiFamily,
            fontFamilyFallback: TWTypography.fallbackFamilies,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontFamily: TWTypography.uiFamily,
            fontFamilyFallback: TWTypography.fallbackFamilies,
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.brand,
        activeTrackColor: AppColors.brand.withValues(alpha: 0.4),
      ),
    );
  }

}
