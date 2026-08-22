import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/core/widgets/app_logo.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/presentation/controllers/create_topic_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Topic Creation Component matching Create Playlist Screen Design System 1:1
class CreateTopicDialog extends StatelessWidget {
  const CreateTopicDialog({
    required this.isDarkMode,
    required this.channelVideosFuture,
    required this.onCreateTopicSubmitted,
    super.key,
  });

  final bool isDarkMode;
  final Future<List<Map<String, dynamic>>> channelVideosFuture;
  final Future<void> Function(CreateTopicController controller) onCreateTopicSubmitted;

  /// Helper launcher method for opening Topic Creation as a full-screen page route.
  static Future<void> show({
    required BuildContext context,
    required bool isDarkMode,
    required Future<List<Map<String, dynamic>>> channelVideosFuture,
    required Future<void> Function(CreateTopicController controller) onCreateTopicSubmitted,
  }) async {
    final controller = Get.isRegistered<CreateTopicController>()
        ? Get.find<CreateTopicController>()
        : Get.put(CreateTopicController());
    controller.resetForm();

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          backgroundColor: context.colors.background,
          body: SafeArea(
            child: CreateTopicDialog(
              isDarkMode: isDarkMode,
              channelVideosFuture: channelVideosFuture,
              onCreateTopicSubmitted: onCreateTopicSubmitted,
            ),
          ),
        ),
      ),
    );
  }

  static const List<String> availableCategories = [
    'Science & Technology',
    'Technology',
    'Education',
    'Entertainment',
    'Music',
    'News',
    'Sports',
    'Science',
    'Travel',
    'Lifestyle',
    'Comedy',
    'Documentary',
    'Movies',
    'TV Shows',
    'Vlogs',
    'DIY & How-to',
    'Health & Fitness',
    'Fashion',
  ];

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<CreateTopicController>()
        ? Get.find<CreateTopicController>()
        : Get.put(CreateTopicController());

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900;

    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Column(
          children: [
            if (isDesktop) _buildDesktopTopHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 48.0 : 16.0,
                  vertical: 24.0,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Form(
                      key: controller.formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildPageHeader(context, isDesktop),
                          const SizedBox(height: 24),
                          _buildProfanityErrorAlert(controller),
                          if (isDesktop)
                            _buildDesktopTwoColumnLayout(context, controller)
                          else
                            _buildMobileSingleColumnLayout(context, controller),
                          const SizedBox(height: 24),
                          _buildSection9TopicImage(context, controller),
                          const SizedBox(height: 32),
                          if (isDesktop) _buildDesktopFooterActions(context, controller),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (!isDesktop) _buildMobileStickyFooter(context, controller),
          ],
        ),
      ),
    );
  }

  // ================= Top Desktop Bar (Playlist Theme Matching) =================
  Widget _buildDesktopTopHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.background,
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: Row(
        children: [
          // Logo
          Row(
            children: [
              const AppLogo(
                size: 26,
                borderRadius: 6,
              ),
              const SizedBox(width: 8),
              Text(
                'TRUTHWORLD',
                style: context.themeTypography.logo.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(width: 48),

          // Search Bar
          Expanded(
            child: Container(
              height: 40,
              constraints: const BoxConstraints(maxWidth: 540),
              decoration: BoxDecoration(
                color: const Color(0xFF161618),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: TextField(
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search videos, channels, topics...',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 13,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Colors.white,
                    size: 18,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),

          // Right Icons
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
            onPressed: () {},
          ),
          const SizedBox(width: 12),
          Row(
            children: [
              const CircleAvatar(
                radius: 16,
                backgroundColor: Color(0xFF333333),
                child: Icon(Icons.person, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.keyboard_arrow_down,
                color: Colors.white.withValues(alpha: 0.7),
                size: 18,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================= Page Header (Playlist Theme Matching) =================
  Widget _buildPageHeader(BuildContext context, bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: Get.back,
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 12),
            Text(
              'Create Topic',
              style: context.themeTypography.display.copyWith(
                fontSize: isDesktop ? 26 : 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 36),
          child: Text(
            'Build a topic to organize and curate videos around a theme.',
            style: context.themeTypography.body.copyWith(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: isDesktop ? 14 : 12,
            ),
          ),
        ),
      ],
    );
  }

  // ================= Desktop 2-Column Layout =================
  Widget _buildDesktopTwoColumnLayout(BuildContext context, CreateTopicController controller) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column (Sections 1 to 5)
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSection1TopicName(context, controller),
              const SizedBox(height: 24),
              _buildSection2Handle(context, controller),
              const SizedBox(height: 24),
              _buildSection3Title(context, controller),
              const SizedBox(height: 24),
              _buildSection4Description(context, controller),
              const SizedBox(height: 24),
              _buildSection5Tags(context, controller),
            ],
          ),
        ),
        const SizedBox(width: 32),

        // Right Column (Sections 6 to 8)
        Expanded(
          flex: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSection6Category(context, controller),
              const SizedBox(height: 24),
              _buildSection7TopicType(context, controller),
              const SizedBox(height: 24),
              _buildSection8AddVideos(context, controller),
            ],
          ),
        ),
      ],
    );
  }

  // ================= Mobile Single Column Layout =================
  Widget _buildMobileSingleColumnLayout(BuildContext context, CreateTopicController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSection1TopicName(context, controller),
        const SizedBox(height: 20),
        _buildSection2Handle(context, controller),
        const SizedBox(height: 20),
        _buildSection3Title(context, controller),
        const SizedBox(height: 20),
        _buildSection4Description(context, controller),
        const SizedBox(height: 20),
        _buildSection5Tags(context, controller),
        const SizedBox(height: 20),
        _buildSection6Category(context, controller),
        const SizedBox(height: 20),
        _buildSection7TopicType(context, controller),
        const SizedBox(height: 20),
        _buildSection8AddVideos(context, controller),
      ],
    );
  }

  /// Error Banner Alert
  Widget _buildProfanityErrorAlert(CreateTopicController controller) {
    return Obx(() {
      if (controller.profanityError.value.isEmpty) {
        return const SizedBox.shrink();
      }
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.gavel_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                controller.profanityError.value,
                style: const TextStyle(
                  color: AppColors.error,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  // ================= Section 1: Topic Name =================
  Widget _buildSection1TopicName(BuildContext context, CreateTopicController controller) {
    return _buildCardContainer(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(context, '1. Topic Name'),
          const SizedBox(height: 12),
          Stack(
            alignment: Alignment.centerRight,
            children: [
              TextFormField(
                controller: controller.nameController,
                maxLength: 60,
                onChanged: (_) => controller.formKey.currentState?.validate(),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: _buildInputDecoration(hintText: 'Enter topic name'),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Topic Name is required';
                  if (val.trim().length < 3) return 'Name must be at least 3 characters';
                  return null;
                },
              ),
              Positioned(
                right: 14,
                child: Text(
                  '${controller.nameController.text.length}/60',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a clear and simple name.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ================= Section 2: Handle =================
  Widget _buildSection2Handle(BuildContext context, CreateTopicController controller) {
    return _buildCardContainer(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(context, '2. Handle'),
          const SizedBox(height: 12),
          Stack(
            alignment: Alignment.centerRight,
            children: [
              TextFormField(
                controller: controller.handleController,
                maxLength: 30,
                onChanged: (_) => controller.onHandleManualEdit(),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: _buildInputDecoration(
                  hintText: 'topic-handle',
                  prefixIcon: const Icon(Icons.alternate_email_rounded, color: Colors.white, size: 18),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Handle is required';
                  if (val.contains(' ')) return 'Handle cannot contain spaces';
                  return null;
                },
              ),
              Positioned(
                right: 14,
                child: Text(
                  '${controller.handleController.text.length}/30',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Your unique topic handle. Example: @spaceexploration',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ================= Section 3: Title =================
  Widget _buildSection3Title(BuildContext context, CreateTopicController controller) {
    return _buildCardContainer(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(context, '3. Title'),
          const SizedBox(height: 12),
          Stack(
            alignment: Alignment.centerRight,
            children: [
              TextFormField(
                controller: controller.titleController,
                maxLength: 100,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: _buildInputDecoration(hintText: 'Enter a catchy title for your topic'),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Title is required';
                  return null;
                },
              ),
              Positioned(
                right: 14,
                child: Text(
                  '${controller.titleController.text.length}/100',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'This title will be shown on your topic page.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ================= Section 4: Description =================
  Widget _buildSection4Description(BuildContext context, CreateTopicController controller) {
    return _buildCardContainer(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(context, '4. Description'),
          const SizedBox(height: 12),
          Stack(
            children: [
              TextFormField(
                controller: controller.descriptionController,
                maxLines: 4,
                maxLength: 500,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: _buildInputDecoration(
                  hintText: 'Describe your topic. What is it about?',
                  contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                ),
              ),
              Positioned(
                right: 14,
                bottom: 10,
                child: Text(
                  '${controller.descriptionController.text.length}/500',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Share more details about this topic.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ================= Section 5: Tags =================
  Widget _buildSection5Tags(BuildContext context, CreateTopicController controller) {
    return _buildCardContainer(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(context, '5. Tags'),
          const SizedBox(height: 12),
          TextFormField(
            controller: controller.tagInputController,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: _buildInputDecoration(hintText: 'Add tags and press Enter'),
            onFieldSubmitted: (val) {
              if (val.trim().isNotEmpty) {
                controller.addTag(val);
              }
            },
          ),
          const SizedBox(height: 12),
          // Interactive Tag Chips
          Obx(() {
            final tags = controller.tagsList.toList();
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E24),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$tag ',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      InkWell(
                        onTap: () => controller.removeTag(tag),
                        child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          }),
          const SizedBox(height: 8),
          Text(
            'Add relevant tags to help others find your topic.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ================= Section 6: Topic Category =================
  Widget _buildSection6Category(BuildContext context, CreateTopicController controller) {
    return _buildCardContainer(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(context, '6. Topic Category'),
          const SizedBox(height: 4),
          Text(
            'Choose the category that best fits your topic.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: controller.categoryController.text.isNotEmpty
                ? controller.categoryController.text
                : 'Science & Technology',
            dropdownColor: const Color(0xFF161618),
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: _buildInputDecoration(
              hintText: 'Select category',
              prefixIcon: const Icon(Icons.science_outlined, color: Colors.white, size: 20),
            ),
            items: availableCategories
                .map((cat) => DropdownMenuItem<String>(value: cat, child: Text(cat)))
                .toList(),
            onChanged: (val) {
              if (val != null) {
                controller.categoryController.text = val;
              }
            },
          ),
        ],
      ),
    );
  }

  // ================= Section 7: Topic Type (Visibility) =================
  Widget _buildSection7TopicType(BuildContext context, CreateTopicController controller) {
    return _buildCardContainer(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(context, '7. Topic Type'),
          const SizedBox(height: 4),
          Text(
            'Choose who can view this topic',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          Obx(() {
            final isPublic = controller.selectedVisibility.value == TopicVisibilityType.public;
            return InkWell(
              onTap: () => controller.selectedVisibility.value = TopicVisibilityType.public,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isPublic ? const Color(0xFF1F1F24) : const Color(0xFF0F0F11),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isPublic ? Colors.white : Colors.white.withValues(alpha: 0.12),
                    width: isPublic ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.public_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Public', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                          Text(
                            'Anyone can view this topic',
                            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5)),
                          ),
                        ],
                      ),
                    ),
                    Radio<TopicVisibilityType>(
                      value: TopicVisibilityType.public,
                      groupValue: controller.selectedVisibility.value,
                      onChanged: (val) => controller.selectedVisibility.value = val!,
                      activeColor: Colors.white,
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 10),
          Obx(() {
            final isPrivate = controller.selectedVisibility.value == TopicVisibilityType.private;
            return Column(
              children: [
                InkWell(
                  onTap: () => controller.selectedVisibility.value = TopicVisibilityType.private,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isPrivate ? const Color(0xFF1F1F24) : const Color(0xFF0F0F11),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isPrivate ? Colors.white : Colors.white.withValues(alpha: 0.12),
                        width: isPrivate ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Private', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                              Text(
                                'Only you can view this topic',
                                style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5)),
                              ),
                            ],
                          ),
                        ),
                        Radio<TopicVisibilityType>(
                          value: TopicVisibilityType.private,
                          groupValue: controller.selectedVisibility.value,
                          onChanged: (val) => controller.selectedVisibility.value = val!,
                          activeColor: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
                if (isPrivate) ...[
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: controller.accessCodeController,
                    obscureText: controller.obscureAccessCode.value,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: _buildInputDecoration(
                      hintText: 'Enter Private Passcode',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.visibility_off_rounded, color: Colors.white, size: 18),
                        onPressed: controller.togglePasscodeVisibility,
                      ),
                    ),
                  ),
                ],
              ],
            );
          }),
        ],
      ),
    );
  }

  // ================= Section 8: Add Videos =================
  Widget _buildSection8AddVideos(BuildContext context, CreateTopicController controller) {
    return _buildCardContainer(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildSectionTitle(context, '8. Add Videos'),
              const SizedBox(width: 6),
              const Text(
                '* (Required)',
                style: TextStyle(
                  color: Color(0xFFF59E0B),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'At least 1 video is required to create a topic.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),

          // Select Videos Button
          OutlinedButton.icon(
            onPressed: () => _openVideoSelectorModal(context, controller),
            icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
            label: Obx(() {
              final count = controller.selectedVideoIds.length;
              return Text(
                count > 0 ? '+ Select videos ($count)' : '+ Select videos',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              );
            }),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
            ),
          ),

          const SizedBox(height: 12),

          // Selected Video Cards List
          FutureBuilder<List<Map<String, dynamic>>>(
            future: channelVideosFuture,
            builder: (context, snapshot) {
              final videos = snapshot.data ?? [];
              return Obx(() {
                final selectedIds = controller.selectedVideoIds.toList();
                final selectedVideos = videos.where((v) => selectedIds.contains(v['id'])).toList();

                if (selectedVideos.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F0F11),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        'No videos selected yet. (At least 1 video required)',
                        style: TextStyle(color: const Color(0xFFF59E0B).withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: selectedVideos.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final v = selectedVideos[index];
                        final thumb = v['thumbnailUrl'] ?? '';
                        final title = v['title'] ?? 'Untitled Video';

                        return Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F0F11),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.drag_indicator_rounded, color: Colors.white, size: 18),
                              const SizedBox(width: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: 56,
                                  height: 38,
                                  color: const Color(0xFF1E1E24),
                                  child: thumb.isNotEmpty
                                      ? Image.network(thumb, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.movie, size: 16, color: Colors.white))
                                      : const Icon(Icons.movie, size: 16, color: Colors.white),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                                onPressed: () {
                                  controller.selectedVideoIds.remove(v['id']);
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${selectedVideos.length} videos selected',
                        style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.45)),
                      ),
                    ),
                  ],
                );
              });
            },
          ),
        ],
      ),
    );
  }

  // ================= Section 9: Topic Image =================
  Widget _buildSection9TopicImage(BuildContext context, CreateTopicController controller) {
    return _buildCardContainer(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(context, '9. Topic Image'),
          const SizedBox(height: 4),
          Text(
            'Choose a thumbnail for your topic',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),

          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 600;

              final optionA = Obx(() {
                final isVideoThumb = controller.thumbnailSource.value == 'video';
                return InkWell(
                  onTap: () => controller.thumbnailSource.value = 'video',
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isVideoThumb ? const Color(0xFF1F1F24) : const Color(0xFF0F0F11),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isVideoThumb ? Colors.white : Colors.white.withValues(alpha: 0.12),
                        width: isVideoThumb ? 1.5 : 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Radio<String>(
                              value: 'video',
                              groupValue: controller.thumbnailSource.value,
                              onChanged: (val) => controller.thumbnailSource.value = val!,
                              activeColor: Colors.white,
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Use thumbnail from selected video', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                                  Text(
                                    'Choose from your selected videos',
                                    style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Video Thumbnail Row Picker
                        FutureBuilder<List<Map<String, dynamic>>>(
                          future: channelVideosFuture,
                          builder: (context, snapshot) {
                            final videos = snapshot.data ?? [];
                            return Obx(() {
                              final selectedIds = controller.selectedVideoIds.toList();
                              final selectedVideos = videos.where((v) => selectedIds.contains(v['id'])).toList();

                              if (selectedVideos.isEmpty) {
                                return Text(
                                  'Select videos in section 8 first.',
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                                );
                              }

                              return SizedBox(
                                height: 60,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: selectedVideos.length,
                                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                                  itemBuilder: (context, index) {
                                    final v = selectedVideos[index];
                                    final thumb = v['thumbnailUrl'] ?? '';
                                    final isChosen = controller.chosenVideoThumbnailUrl.value == thumb;

                                    return InkWell(
                                      onTap: () => controller.chosenVideoThumbnailUrl.value = thumb,
                                      child: Container(
                                        width: 90,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: isChosen ? Colors.white : Colors.white.withValues(alpha: 0.12),
                                            width: isChosen ? 2.0 : 1.0,
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: thumb.isNotEmpty
                                              ? Image.network(thumb, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.movie, size: 20, color: Colors.white))
                                              : const Icon(Icons.movie, size: 20, color: Colors.white),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                );
              });

              final optionB = Obx(() {
                final isCustom = controller.thumbnailSource.value == 'custom';
                return InkWell(
                  onTap: () => controller.thumbnailSource.value = 'custom',
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isCustom ? const Color(0xFF1F1F24) : const Color(0xFF0F0F11),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCustom ? Colors.white : Colors.white.withValues(alpha: 0.12),
                        width: isCustom ? 1.5 : 1.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Radio<String>(
                              value: 'custom',
                              groupValue: controller.thumbnailSource.value,
                              onChanged: (val) => controller.thumbnailSource.value = val!,
                              activeColor: Colors.white,
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Upload custom image', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                                  Text(
                                    'Pick an image from your device',
                                    style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Upload Box
                        InkWell(
                          onTap: controller.pickCustomThumbnail,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF161618),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                            ),
                            child: Column(
                              children: [
                                if (controller.pickedCustomImageBytes.value != null) ...[
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.memory(controller.pickedCustomImageBytes.value!, height: 80, fit: BoxFit.cover),
                                  ),
                                  const SizedBox(height: 8),
                                ] else ...[
                                  const Icon(Icons.upload_rounded, color: Colors.white, size: 24),
                                  const SizedBox(height: 6),
                                ],
                                const Text('Upload image', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                                Text(
                                  'PNG, JPG or WEBP. Max 5MB.',
                                  style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.4)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              });

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: optionA),
                    const SizedBox(width: 16),
                    Expanded(child: optionB),
                  ],
                );
              }

              return Column(
                children: [
                  optionA,
                  const SizedBox(height: 14),
                  optionB,
                ],
              );
            },
          ),

          const SizedBox(height: 10),
          Text(
            'Recommended size: 1280x720 (16:9). Max size: 5MB.',
            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.45)),
          ),
        ],
      ),
    );
  }

  // ================= Card Container (Playlist Theme Matching) =================
  Widget _buildCardContainer({required BuildContext context, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: child,
    );
  }

  // ================= Section Title (Playlist Theme Matching) =================
  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: context.themeTypography.title.copyWith(
        fontWeight: FontWeight.bold,
        fontSize: 15,
      ),
    );
  }

  // ================= Input Decoration (Playlist Theme Matching) =================
  InputDecoration _buildInputDecoration({
    required String hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    EdgeInsetsGeometry? contentPadding,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        color: Colors.white.withValues(alpha: 0.35),
        fontSize: 14,
      ),
      counterText: '',
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      fillColor: const Color(0xFF0F0F11),
      filled: true,
      contentPadding: contentPadding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.white),
      ),
    );
  }

  // ================= Desktop Footer Actions (Playlist Theme Matching) =================
  Widget _buildDesktopFooterActions(BuildContext context, CreateTopicController controller) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton(
          onPressed: Get.back,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.2),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 16),
        Obx(() {
          return ElevatedButton(
            onPressed: controller.isSubmitting.value
                ? null
                : () async {
                    final isValid = await controller.validateFormBeforeSubmit();
                    if (!isValid) return;
                    controller.isSubmitting.value = true;
                    try {
                      await onCreateTopicSubmitted(controller);
                      if (context.mounted) {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        } else {
                          Get.back();
                        }
                      }
                    } catch (e) {
                      AppSnackbar.show('Error', e.toString());
                    } finally {
                      controller.isSubmitting.value = false;
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: controller.isSubmitting.value
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.black,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Create Topic',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
          );
        }),
      ],
    );
  }

  // ================= Mobile Sticky Footer (Playlist Theme Matching) =================
  Widget _buildMobileStickyFooter(BuildContext context, CreateTopicController controller) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: Obx(() {
          return ElevatedButton(
            onPressed: controller.isSubmitting.value
                ? null
                : () async {
                    final isValid = await controller.validateFormBeforeSubmit();
                    if (!isValid) return;
                    controller.isSubmitting.value = true;
                    try {
                      await onCreateTopicSubmitted(controller);
                      if (context.mounted) {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        } else {
                          Get.back();
                        }
                      }
                    } catch (e) {
                      AppSnackbar.show('Error', e.toString());
                    } finally {
                      controller.isSubmitting.value = false;
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: controller.isSubmitting.value
                ? const CircularProgressIndicator(color: Colors.black)
                : const Text(
                    'Create Topic',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
          );
        }),
      ),
    );
  }

  // ================= Video Selector Modal =================
  void _openVideoSelectorModal(BuildContext context, CreateTopicController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Color(0xFF161618),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Videos for Topic',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 16),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: channelVideosFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Colors.white));
                  }
                  final videos = snapshot.data ?? [];
                  if (videos.isEmpty) {
                    return const Text('No channel videos available.', style: TextStyle(color: Colors.white54));
                  }
                  return Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: videos.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final v = videos[index];
                        final id = v['id'] as String;
                        final thumb = v['thumbnailUrl'] as String? ?? '';
                        final title = v['title'] as String? ?? 'Untitled Video';

                        return Obx(() {
                          final isSelected = controller.selectedVideoIds.contains(id);
                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (_) {
                              controller.toggleVideoSelection(id, thumb);
                            },
                            title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
                            secondary: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: thumb.isNotEmpty
                                  ? Image.network(thumb, width: 48, height: 32, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.movie, color: Colors.white))
                                  : const Icon(Icons.movie, color: Colors.white),
                            ),
                            activeColor: Colors.white,
                            checkColor: Colors.black,
                          );
                        });
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }
}
