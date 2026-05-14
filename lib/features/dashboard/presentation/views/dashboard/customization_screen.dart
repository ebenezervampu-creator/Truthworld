import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:typed_data';
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
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBrandingTab(),
                _buildBasicInfoTab(),
                _buildAdvancedTab(),
                _buildSettingsTab(),
              ],
            ),
          );
        }
      }),
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
          const SizedBox(height: 32),
          _buildSectionTitle('Channel Avatar'),
          const SizedBox(height: 8),
          const Text(
            'Recommended size: 800 x 800 pixels',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Center(
            child: Obx(() => _buildImagePicker(
                  currentUrl: controller.avatarUrl.value,
                  newBytes: controller.newAvatarBytes.value,
                  onTap: () => controller.pickImage(true),
                  height: 150,
                  isCircular: true,
                )),
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
      imageWidget = Image.network(currentUrl, fit: BoxFit.cover);
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







