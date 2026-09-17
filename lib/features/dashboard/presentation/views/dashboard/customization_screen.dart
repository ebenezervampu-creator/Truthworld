import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/customization_controller.dart';
import 'package:truthworld/theme/app_colors.dart';

class ChannelCustomizationPage extends StatefulWidget {
  const ChannelCustomizationPage({
    required this.channelId,
    required this.ownerId,
    super.key,
  });
  final String channelId;
  final String ownerId;

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
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.brand,
          indicatorWeight: 3,
          labelColor: AppColors.brand,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: const TextStyle(
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
                    if (_formKey.currentState!.validate()) {
                      controller.saveChanges();
                    }
                  },
                  icon: const Icon(Icons.save_rounded, size: 16),
                  label: const Text('Save'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
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
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.brand),
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
                    color: bannerColor,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Channel Banner'),
          const SizedBox(height: 6),
          const Text(
            'Recommended size: 2560 x 1440 pixels (Displays across mobile, desktop & TV feeds)',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Obx(
            () => _buildImagePicker(
              currentUrl: controller.bannerUrl.value,
              newBytes: controller.newBannerBytes.value,
              onTap: () => controller.pickImage(false),
              height: 200,
              label: 'Channel Banner',
            ),
          ),
          Obx(
            () => _buildImageStatusNotice(
              status: controller.bannerStatus.value,
              reason: controller.bannerStatusReason.value,
              isBanner: true,
            ),
          ),
          const SizedBox(height: 32),
          _buildSectionTitle('Channel Avatar'),
          const SizedBox(height: 6),
          const Text(
            'Recommended size: 800 x 800 pixels',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Obx(
                  () => _buildImagePicker(
                    currentUrl: controller.avatarUrl.value,
                    newBytes: controller.newAvatarBytes.value,
                    onTap: () => controller.pickImage(true),
                    height: 150,
                    isCircular: true,
                    label: 'Channel Avatar',
                  ),
                ),
                Obx(
                  () => _buildImageStatusNotice(
                    status: controller.avatarStatus.value,
                    reason: controller.avatarStatusReason.value,
                    isBanner: false,
                  ),
                ),
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
      color = const Color(0xFF8B5CF6);
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
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
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
                      style: TextStyle(fontSize: 12),
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
            prefix: const Text(
              '@',
              style: TextStyle(
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
            hint: 'e.g., Gaming, Education, Entertainment',
          ),
          const SizedBox(height: 32),
          _buildSectionTitle('Social Links'),
          const SizedBox(height: 16),
          _buildTextField(
            controller: controller.twitterController,
            label: 'Twitter / X',
            hint: 'https://twitter.com/username',
            prefixIcon: Icons.link_rounded,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: controller.instagramController,
            label: 'Instagram',
            hint: 'https://instagram.com/username',
            prefixIcon: Icons.link_rounded,
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: controller.facebookController,
            label: 'Facebook',
            hint: 'https://facebook.com/username',
            prefixIcon: Icons.link_rounded,
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
          Obx(
            () => _buildSwitchTile(
              title: 'Public Channel',
              subtitle: 'Allow anyone to view your channel and videos',
              value: controller.isPublic.value,
              onChanged: (val) => controller.isPublic.value = val,
            ),
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
        ],
      ),
    );
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
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters ?? TruthworldTextInputFormatters.standard,
      validator: validator,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helperText,
        prefix: prefix,
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: Colors.white, size: 20)
            : null,
        labelStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
        ),
        hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
        helperStyle: const TextStyle(
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

  Widget _buildImagePicker({
    required String currentUrl,
    required Uint8List? newBytes,
    required VoidCallback onTap,
    required double height,
    required String label,
    bool isCircular = false,
  }) {
    Widget imageWidget;

    if (newBytes != null) {
      imageWidget = Image.memory(newBytes, fit: BoxFit.cover);
    } else if (currentUrl.isNotEmpty) {
      imageWidget = CachedNetworkImage(
        imageUrl: currentUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        ),
        errorWidget: (context, url, error) => const ColoredBox(
          color: AppColors.bgSurface,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.broken_image_rounded,
                size: 40,
                color: Colors.white,
              ),
              SizedBox(height: 6),
              Text(
                'Failed to load image',
                style: TextStyle(color: AppColors.textTertiary, fontSize: 11),
              ),
            ],
          ),
        ),
      );
    } else {
      imageWidget = ColoredBox(
        color: AppColors.bgSurface,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isCircular
                  ? Icons.account_circle_rounded
                  : Icons.add_photo_alternate_rounded,
              size: 48,
              color: Colors.white,
            ),
            const SizedBox(height: 8),
            Text(
              'Upload $label',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tap to select image',
              style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }

    final pickerCard = Container(
      height: isCircular ? height : null,
      width: isCircular ? height : double.infinity,
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: isCircular
            ? BorderRadius.circular(height / 2)
            : BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.bgDivider,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(child: imageWidget),
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
            bottom: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF27272A),
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
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: onTap,
        borderRadius: isCircular
            ? BorderRadius.circular(height / 2)
            : BorderRadius.circular(12),
        child: isCircular
            ? SizedBox(
                width: height,
                height: height,
                child: pickerCard,
              )
            : AspectRatio(
                aspectRatio: 16 / 9,
                child: pickerCard,
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
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: SwitchListTile(
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppColors.brand,
        activeTrackColor: AppColors.brand.withValues(alpha: 0.4),
      ),
    );
  }
}
