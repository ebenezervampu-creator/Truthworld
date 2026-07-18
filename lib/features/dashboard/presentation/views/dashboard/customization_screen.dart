import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:typed_data';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/theme/app_theme.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/customization_controller.dart';

class ChannelCustomizationPage extends StatefulWidget {
  final String channelId;
  final String ownerId;

  const ChannelCustomizationPage({
    super.key,
    required this.channelId,
    required this.ownerId,
  });

  @override
  State<ChannelCustomizationPage> createState() =>
      _ChannelCustomizationPageState();
}

class _ChannelCustomizationPageState extends State<ChannelCustomizationPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  late CustomizationController controller;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    controller = Get.put(
      CustomizationController(
        channelId: widget.channelId,
        ownerId: widget.ownerId,
      ),
      tag: widget.channelId,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        backgroundColor: AppColors.bgSurface,
        elevation: 0,
        title: const Text(
          'Channel Customization',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTokens.colors.error,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.grey,
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
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.error),
                  ),
                ),
              );
            } else {
              return TextButton.icon(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    controller.saveChanges();
                  }
                },
                icon: const Icon(Icons.save, color: Colors.white),
                label: const Text('Save', style: TextStyle(color: Colors.white)),
              );
            }
          }),
          const SizedBox(width: 8),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.error),
            ),
          );
        } else {
          return Form(
            key: _formKey,
            child: Column(
              children: [
                _buildModerationBanner(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
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
    final reason = controller.moderationReason.value;

    if (channelStatus == 'active') {
      return const SizedBox.shrink();
    }

    Color bannerColor;
    IconData icon;
    String title;
    String subtitle;

    if (channelStatus == 'underReview') {
      bannerColor = const Color(0xFF3B82F6); // Blue
      icon = Icons.sync_rounded;
      title = 'Branding Under Gemini AI Moderation';
      subtitle = 'Gemini is checking your channel details (name, description, tags) against our community guidelines. This usually takes just a few seconds.';
    } else if (channelStatus == 'verificationRejected') {
      bannerColor = const Color(0xFFEF4444); // Red
      icon = Icons.error_outline_rounded;
      title = 'Branding Verification Rejected by Gemini AI';
      subtitle = 'We created channel according to community guidelines, then channel selected for manual verification. ${reason.isNotEmpty ? '\n\nGemini Response: $reason' : ''}';
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: bannerColor.withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(color: bannerColor.withValues(alpha: 0.3), width: 1),
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
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
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
                  style: GoogleFonts.roboto(
                    color: bannerColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.roboto(
                    color: Colors.white70,
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Channel Banner'),
          const SizedBox(height: 8),
          const Text(
            'Recommended size: 2560 x 1440 pixels',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Obx(() => _buildImagePicker(
                currentUrl: controller.bannerUrl.value,
                newBytes: controller.newBannerBytes.value,
                onTap: () => controller.pickImage(false),
                height: 200,
              )),
          Obx(() => _buildImageStatusNotice(
                status: controller.bannerStatus.value,
                reason: controller.bannerStatusReason.value,
                isBanner: true,
              )),
          const SizedBox(height: 32),
          _buildSectionTitle('Channel Avatar'),
          const SizedBox(height: 8),
          const Text(
            'Recommended size: 800 x 800 pixels',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Obx(() => _buildImagePicker(
                      currentUrl: controller.avatarUrl.value,
                      newBytes: controller.newAvatarBytes.value,
                      onTap: () => controller.pickImage(true),
                      height: 150,
                      isCircular: true,
                    )),
                Obx(() => _buildImageStatusNotice(
                      status: controller.avatarStatus.value,
                      reason: controller.avatarStatusReason.value,
                      isBanner: false,
                    )),
              ],
            ),
          ),
        ],
      ),
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
    bool isPending = false;

    if (status == 'PENDING') {
      color = const Color(0xFF3B82F6); // Blue
      icon = Icons.sync_rounded;
      title = '${isBanner ? "Banner" : "Avatar"} Verification Pending';
      subtitle = 'Google Vision AI is validating this image. Feel free to save changes; verification will complete in the background.';
      isPending = true;
    } else if (status == 'REJECTED') {
      color = const Color(0xFFEF4444); // Red
      icon = Icons.error_outline_rounded;
      title = '${isBanner ? "Banner" : "Avatar"} Rejected';
      subtitle = reason.isNotEmpty ? reason : 'This image does not comply with our safety and community guidelines. Please upload a different image.';
    } else if (status == 'FLAGGED') {
      color = const Color(0xFFF59E0B); // Amber
      icon = Icons.warning_amber_rounded;
      title = '${isBanner ? "Banner" : "Avatar"} Review Needed';
      subtitle = reason.isNotEmpty ? reason : 'This image has been flagged for manual review. You can upload a different image if you wish.';
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
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
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
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
                  style: GoogleFonts.roboto(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: GoogleFonts.roboto(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
                if (isPending) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => controller.bypassVerification(isBanner),
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 14, color: Colors.white70),
                    label: const Text(
                      'Bypass Verification (Local Dev/Test)',
                      style: TextStyle(color: Colors.white70, fontSize: 11, decoration: TextDecoration.underline),
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
            label: 'Custom URL',
            hint: 'yourchannel',
            prefix: const Text(
              '@',
              style: TextStyle(color: Colors.white70, fontSize: 16),
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
            helperText: 'Separate tags with commas',
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
            hint: 'e.g., Gaming, Education, Entertainment',
          ),
          const SizedBox(height: 32),
          _buildSectionTitle('Social Links'),
          const SizedBox(height: 16),
          _buildTextField(
            controller: controller.twitterController,
            label: 'Twitter',
            hint: 'https://twitter.com/username',
            prefixIcon: Icons.link,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: controller.instagramController,
            label: 'Instagram',
            hint: 'https://instagram.com/username',
            prefixIcon: Icons.link,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: controller.facebookController,
            label: 'Facebook',
            hint: 'https://facebook.com/username',
            prefixIcon: Icons.link,
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
          Obx(() => _buildSwitchTile(
                title: 'Public Channel',
                subtitle: 'Allow anyone to view your channel',
                value: controller.isPublic.value,
                onChanged: (val) => controller.isPublic.value = val,
              )),
          const SizedBox(height: 24),
          _buildSectionTitle('Interaction Settings'),
          Obx(() => _buildSwitchTile(
                title: 'Allow Comments',
                subtitle: 'Let viewers comment on your videos',
                value: controller.allowComments.value,
                onChanged: (val) => controller.allowComments.value = val,
              )),
          Obx(() => _buildSwitchTile(
                title: 'Allow Subscriptions',
                subtitle: 'Allow users to subscribe to your channel',
                value: controller.allowSubscriptions.value,
                onChanged: (val) => controller.allowSubscriptions.value = val,
              )),
          Obx(() => _buildSwitchTile(
                title: 'Show Subscriber Count',
                subtitle: 'Display your subscriber count publicly',
                value: controller.showSubscriberCount.value,
                onChanged: (val) => controller.showSubscriberCount.value = val,
              )),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
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
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helperText,
        prefix: prefix,
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: Colors.white70)
            : null,
        labelStyle: const TextStyle(color: Colors.white70),
        hintStyle: const TextStyle(color: Colors.white38),
        helperStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: AppColors.bgSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppTokens.colors.error, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppTokens.colors.error, width: 1),
        ),
      ),
    );
  }

  Widget _buildImagePicker({
    required String currentUrl,
    required Uint8List? newBytes,
    required VoidCallback onTap,
    required double height,
    bool isCircular = false,
  }) {
    Widget imageWidget;

    if (newBytes != null) {
      imageWidget = Image.memory(newBytes, fit: BoxFit.cover);
    } else if (currentUrl.isNotEmpty) {
      imageWidget = Image.network(
        currentUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: AppColors.bgSurface,
          child: const Icon(
            Icons.broken_image,
            size: 48,
            color: Colors.white38,
          ),
        ),
      );
    } else {
      imageWidget = Container(
        color: AppColors.bgSurface,
        child: const Icon(
          Icons.add_photo_alternate,
          size: 48,
          color: Colors.white38,
        ),
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: height,
          width: isCircular ? height : double.infinity,
          decoration: BoxDecoration(
            borderRadius: isCircular
                ? BorderRadius.circular(height / 2)
                : BorderRadius.circular(8),
            border: Border.all(color: Colors.white24, width: 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              SizedBox.expand(child: imageWidget),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.3),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTokens.colors.error,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
        borderRadius: BorderRadius.circular(8),
      ),
      child: SwitchListTile(
        title: Text(title, style: const TextStyle(color: Colors.white)),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppTokens.colors.error,
      ),
    );
  }
}







