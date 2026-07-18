import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/features/commnuity/community_post_upload_controller.dart';
import 'package:truthworld/features/commnuity/data/models/community_draft.dart';
import 'package:truthworld/features/commnuity/data/models/poll_model.dart';
import 'package:truthworld/features/presentation/widgets/upload_shared_widgets.dart';
import 'package:truthworld/theme/app_colors.dart';

// =============================================================================
// COMMUNITY POST UPLOAD SCREEN Ã¢â‚¬â€ 100% StatelessWidget + GetX
// =============================================================================

class CommunityPostUploadScreen extends StatelessWidget {
  final CommunityDraft? draftToLoad;

  CommunityPostUploadScreen({super.key, this.draftToLoad}) {
    if (draftToLoad != null) {
      _c.loadDraft(draftToLoad!);
      _titleCtrl.text = draftToLoad!.title;
      _descCtrl.text = draftToLoad!.description;
      _tagsCtrl.text = draftToLoad!.tags.join(', ');
      if (draftToLoad!.poll != null) {
        _pollQuestionCtrl.text = draftToLoad!.poll!.question;
      }
    }
  }

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  final _pollQuestionCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  CommunityPostUploadController get _c =>
      Get.find<CommunityPostUploadController>();

  bool _isMobile(BuildContext ctx) => MediaQuery.of(ctx).size.width < 600;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.bgPage
          : AppColors.textPrimary,
      body: SafeArea(
        child: _isMobile(context)
            ? _buildMobileLayout(context, isDark)
            : _buildDesktopLayout(context, isDark),
      ),
    );
  }

  // Ã¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€Â DESKTOP LAYOUT Ã¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€Â

  Widget _buildDesktopLayout(BuildContext context, bool isDark) {
    return Row(
      children: [
        // Sidebar
        Container(
          width: 280,
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.bgPage
                : AppColors.textPrimary,
            border: Border(
              right: BorderSide(
                color: isDark
                    ? AppColors.bgSurface
                    : AppColors.textSecondary,
              ),
            ),
          ),
          child: Column(
            children: [
              _buildSidebarHeader(isDark),
              const SizedBox(height: 16),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: UploadChannelSelector(
                  channels: _c.channels,
                  selectedChannel: _c.selectedChannel,
                  onChanged: _c.selectChannel,
                ),
              ),
              const Spacer(),
              _buildBackButton(isDark),
            ],
          ),
        ),
        // Main content
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(32),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailsSection(isDark),
                        const SizedBox(height: 24),
                        _buildImageGallerySection(isDark),
                        const SizedBox(height: 24),
                        _buildPollSection(isDark),
                        const SizedBox(height: 24),
                        _buildSettingsSection(isDark),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 32),
                Expanded(child: _buildPreviewPanel(isDark)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Ã¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€Â MOBILE LAYOUT Ã¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€Â

  Widget _buildMobileLayout(BuildContext context, bool isDark) {
    return Column(
      children: [
        _buildMobileAppBar(isDark),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  UploadChannelSelector(
                    channels: _c.channels,
                    selectedChannel: _c.selectedChannel,
                    onChanged: _c.selectChannel,
                  ),
                  const SizedBox(height: 20),
                  _buildDetailsSection(isDark),
                  const SizedBox(height: 20),
                  _buildImageGallerySection(isDark),
                  const SizedBox(height: 20),
                  _buildPollSection(isDark),
                  const SizedBox(height: 20),
                  _buildSettingsSection(isDark),
                  const SizedBox(height: 24),
                  Obx(
                    () => UploadPublishButton(
                      canPublish:
                          _c.canPublish &&
                          _titleCtrl.text.trim().isNotEmpty &&
                          _descCtrl.text.trim().isNotEmpty,
                      isUploading: _c.isUploading.value,
                      uploadProgress: _c.overallProgress.value,
                      onPublish: _handlePublish,
                      accentColor: AppColors.brand,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Ã¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€Â IMAGE GALLERY (1-10, any ratio) Ã¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€Â

  Widget _buildImageGallerySection(bool isDark) {
    return _card(
      isDark,
      icon: Icons.photo_library_rounded,
      title: 'Images',
      accentColor: AppColors.textPrimary,
      children: [
        Text(
          'Add 1Ã¢â‚¬â€œ10 images, any aspect ratio. Max 20 MB each.',
          style: GoogleFonts.roboto(
            fontSize: 12,
            color: isDark
                ? AppColors.textPrimary38
                : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),

        // Image grid
        Obx(() {
          final images = _c.pickedImages;
          return Column(
            children: [
              if (images.isNotEmpty)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: images.length,
                  itemBuilder: (context, index) {
                    final file = images[index];
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: double.infinity,
                            height: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark
                                    ? AppColors.bgPage
                                    : AppColors.textSecondary,
                              ),
                            ),
                            child: file.bytes != null
                                ? Image.memory(file.bytes!, fit: BoxFit.cover)
                                : const Center(
                                    child: Icon(Icons.broken_image_rounded),
                                  ),
                          ),
                        ),
                        // Upload progress overlay
                        Obx(() {
                          final progress = _c.imageUploadProgress[index] ?? 0.0;
                          if (progress >= 1.0 || progress < 0) {
                            return const SizedBox.shrink();
                          }
                          return Container(
                            decoration: BoxDecoration(
                              color: AppColors.bgPage54,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 3,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppColors.textPrimary,
                                ),
                              ),
                            ),
                          );
                        }),
                        // Error indicator
                        Obx(() {
                          final progress = _c.imageUploadProgress[index] ?? 0.0;
                          if (progress != -1.0) {
                            return const SizedBox.shrink();
                          }
                          return Container(
                            decoration: BoxDecoration(
                              color: AppColors.textSecondary.withValues(
                                alpha: 0.7,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.error_outline_rounded,
                                color: AppColors.textPrimary,
                                size: 28,
                              ),
                            ),
                          );
                        }),
                        // Remove button
                        Positioned(
                          top: 6,
                          right: 6,
                          child: InkWell(
                            onTap: () => _c.removeImage(index),
                            child: Container(
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.bgPage.withValues(
                                  alpha: 0.54,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close_rounded,
                                color: AppColors.textPrimary,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                        // Index badge
                        Positioned(
                          bottom: 6,
                          left: 6,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.bgPage54,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${index + 1}',
                              style: GoogleFonts.roboto(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              const SizedBox(height: 12),

              // Add button
              if (images.length < CommunityPostUploadController.maxImages)
                InkWell(
                  onTap: _c.pickImages,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 24),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.bgPage
                          : AppColors.textPrimary,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.textPrimary.withValues(
                          alpha: 0.4,
                        ),
                        width: 2,
                        strokeAlign: BorderSide.strokeAlignInside,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.add_photo_alternate_rounded,
                          size: 36,
                          color: AppColors.textPrimary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          images.isEmpty
                              ? 'Add Images'
                              : 'Add More (${images.length}/${CommunityPostUploadController.maxImages})',
                          style: GoogleFonts.roboto(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'JPEG, PNG, GIF Ã¢â‚¬Â¢ Any aspect ratio',
                          style: GoogleFonts.roboto(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.textPrimary38
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        }),
      ],
    );
  }

  // Ã¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€Â POLL SECTION Ã¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€Â

  Widget _buildPollSection(bool isDark) {
    return Obx(() {
      return _card(
        isDark,
        icon: Icons.poll_rounded,
        title: 'Poll',
        accentColor: AppColors.textSecondary,
        children: [
          // Toggle
          SwitchListTile.adaptive(
            title: Text(
              'Add a poll',
              style: GoogleFonts.roboto(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? AppColors.textPrimary
                    : AppColors.bgPage,
              ),
            ),
            subtitle: Text(
              'Let your community vote',
              style: GoogleFonts.roboto(
                fontSize: 12,
                color: isDark
                    ? AppColors.textPrimary38
                    : AppColors.textSecondary,
              ),
            ),
            value: _c.hasPoll.value,
            onChanged: _c.togglePoll,
            activeTrackColor: AppColors.textSecondary,
            contentPadding: EdgeInsets.zero,
          ),

          if (_c.hasPoll.value) ...[
            const SizedBox(height: 16),

            // Poll type selector
            Row(
              children: [
                _pollTypeChip(
                  isDark,
                  PollType.yesNo,
                  'Yes / No',
                  Icons.thumbs_up_down_rounded,
                ),
                const SizedBox(width: 10),
                _pollTypeChip(
                  isDark,
                  PollType.multiChoice,
                  'Multi-Choice',
                  Icons.list_rounded,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Question field
            UploadInputField(
              controller: _pollQuestionCtrl,
              label: 'Question',
              icon: Icons.help_outline_rounded,
              hint: 'Ask your community something...',
              maxLength: 200,
              validator: (v) {
                if (_c.hasPoll.value && (v == null || v.trim().isEmpty)) {
                  return 'Question is required';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Options (for multi-choice)
            if (_c.pollType.value == PollType.multiChoice) ...[
              Text(
                'Options (3Ã¢â‚¬â€œ5)',
                style: GoogleFonts.roboto(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? AppColors.textPrimary70
                      : AppColors.bgPage,
                ),
              ),
              const SizedBox(height: 10),
              ...List.generate(_c.pollOptions.length, (i) {
                return Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.textSecondary.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '${i + 1}',
                            style: GoogleFonts.roboto(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          initialValue: _c.pollOptions[i],
                          onChanged: (v) => _c.updatePollOption(i, v),
                          style: GoogleFonts.roboto(
                            fontSize: 14,
                            color: isDark
                                ? AppColors.textPrimary
                                : AppColors.bgPage,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Option ${i + 1}',
                            hintStyle: GoogleFonts.roboto(
                              color: isDark
                                  ? AppColors.textPrimary30
                                  : AppColors.textSecondary,
                              fontSize: 14,
                            ),
                            filled: true,
                            fillColor: isDark
                                ? AppColors.bgPage
                                : AppColors.textPrimary,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: isDark
                                    ? AppColors.bgPage
                                    : AppColors.textSecondary,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: isDark
                                    ? AppColors.bgPage
                                    : AppColors.textSecondary,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                color: AppColors.textSecondary,
                                width: 2,
                              ),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            isDense: true,
                          ),
                        ),
                      ),
                      if (_c.pollOptions.length > 3)
                        IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color: AppColors.textSecondary,
                          ),
                          onPressed: () => _c.removePollOption(i),
                        ),
                    ],
                  ),
                );
              }),
              if (_c.pollOptions.length < 5)
                TextButton.icon(
                  onPressed: _c.addPollOption,
                  icon: Icon(
                    Icons.add_rounded,
                    color: AppColors.textSecondary,
                  ),
                  label: Text(
                    'Add Option',
                    style: GoogleFonts.roboto(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
            ],

            // Yes/No preview
            if (_c.pollType.value == PollType.yesNo) const SizedBox(height: 12),
            if (_c.pollType.value == PollType.yesNo)
              Row(
                children: [
                  Expanded(
                    child: _yesNoPill(
                      isDark,
                      'Yes',
                      Icons.check_rounded,
                      AppColors.bgPage,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _yesNoPill(
                      isDark,
                      'No',
                      Icons.close_rounded,
                      AppColors.textSecondary,
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 16),

            // Poll duration
            Row(
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 16,
                  color: isDark
                      ? AppColors.textPrimary38
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Poll Duration',
                  style: GoogleFonts.roboto(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? AppColors.textPrimary70
                        : AppColors.bgPage,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [null, 1, 3, 7].map((days) {
                final isSelected = _c.pollDurationDays.value == days;
                return InkWell(
                  onTap: () => _c.pollDurationDays.value = days,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.textSecondary.withValues(
                              alpha: 0.15,
                            )
                          : isDark
                          ? AppColors.bgPage
                          : AppColors.textPrimary,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.textSecondary
                            : isDark
                            ? AppColors.bgPage
                            : AppColors.textSecondary,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Text(
                      days == null
                          ? 'No limit'
                          : days == 1
                          ? '1 day'
                          : '$days days',
                      style: GoogleFonts.roboto(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w500
                            : FontWeight.w500,
                        color: isSelected
                            ? AppColors.textSecondary
                            : isDark
                            ? AppColors.textPrimary60
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      );
    });
  }

  Widget _pollTypeChip(
    bool isDark,
    PollType type,
    String label,
    IconData icon,
  ) {
    return Obx(() {
      final isSelected = _c.pollType.value == type;
      return Expanded(
        child: InkWell(
          onTap: () => _c.setPollType(type),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.textSecondary.withValues(alpha: 0.12)
                  : isDark
                  ? AppColors.bgPage
                  : AppColors.textPrimary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppColors.textSecondary
                    : isDark
                    ? AppColors.bgPage
                    : AppColors.textSecondary,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected
                      ? AppColors.textSecondary
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.roboto(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w500 : FontWeight.w500,
                    color: isSelected
                        ? AppColors.textSecondary
                        : isDark
                        ? AppColors.textPrimary60
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _yesNoPill(bool isDark, String label, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.roboto(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // Ã¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€Â DETAILS Ã¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€Â

  Widget _buildDetailsSection(bool isDark) {
    return _card(
      isDark,
      icon: Icons.edit_rounded,
      title: 'Post Details',
      accentColor: AppColors.textPrimary,
      children: [
        UploadInputField(
          controller: _titleCtrl,
          label: 'Title',
          icon: Icons.campaign_rounded,
          hint: "What's happening?",
          maxLength: 100,
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Title is required' : null,
        ),
        const SizedBox(height: 16),
        UploadInputField(
          controller: _descCtrl,
          label: 'Description',
          icon: Icons.description_rounded,
          hint: 'Share more details with your community',
          maxLines: 4,
          maxLength: 2000,
          validator: (v) => (v == null || v.trim().isEmpty)
              ? 'Description is required'
              : null,
        ),
        const SizedBox(height: 16),
        UploadInputField(
          controller: _tagsCtrl,
          label: 'Tags',
          icon: Icons.tag_rounded,
          hint: 'Add tags separated by commas',
          maxLength: 200,
        ),
      ],
    );
  }

  // Ã¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€Â SETTINGS Ã¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€Â

  Widget _buildSettingsSection(bool isDark) {
    return _card(
      isDark,
      icon: Icons.tune_rounded,
      title: 'Settings',
      accentColor: AppColors.textPrimary,
      children: [
        Text(
          'Visibility',
          style: GoogleFonts.roboto(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isDark
                ? AppColors.textPrimary70
                : AppColors.bgPage,
          ),
        ),
        const SizedBox(height: 12),
        UploadVisibilitySelector(selectedVisibility: _c.selectedVisibility),
        const SizedBox(height: 16),

        // Category
        Text(
          'Category',
          style: GoogleFonts.roboto(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isDark
                ? AppColors.textPrimary70
                : AppColors.bgPage,
          ),
        ),
        const SizedBox(height: 10),
        Obx(
          () => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _c.communityCategories.map((cat) {
              final isSelected = _c.selectedCategory.value == cat;
              return InkWell(
                onTap: () => _c.selectedCategory.value = cat,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.textPrimary.withValues(alpha: 0.15)
                        : isDark
                        ? AppColors.bgPage
                        : AppColors.textPrimary,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.textPrimary
                          : isDark
                          ? AppColors.bgPage
                          : AppColors.textSecondary,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    cat,
                    style: GoogleFonts.roboto(
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.w500
                          : FontWeight.w500,
                      color: isSelected
                          ? AppColors.textPrimary
                          : isDark
                          ? AppColors.textPrimary60
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),

        // Schedule
        Obx(
          () => SwitchListTile.adaptive(
            title: Text(
              'Schedule Post',
              style: GoogleFonts.roboto(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? AppColors.textPrimary
                    : AppColors.bgPage,
              ),
            ),
            value: _c.isScheduled.value,
            onChanged: (v) => _c.isScheduled.value = v,
            activeTrackColor: AppColors.textPrimary,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        Obx(
          () => SwitchListTile.adaptive(
            title: Text(
              'Kid Friendly',
              style: GoogleFonts.roboto(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? AppColors.textPrimary
                    : AppColors.bgPage,
              ),
            ),
            value: _c.isKidFriendly.value,
            onChanged: (v) => _c.isKidFriendly.value = v,
            activeTrackColor: AppColors.textPrimary,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  // Ã¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€Â PREVIEW & PUBLISH Ã¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€Â

  Widget _buildPreviewPanel(bool isDark) {
    return Column(
      children: [
        _buildPreview(isDark),
        const SizedBox(height: 20),
        _buildDraftButton(isDark),
        const SizedBox(height: 12),
        Obx(
          () => UploadPublishButton(
            canPublish:
                _c.canPublish &&
                _titleCtrl.text.trim().isNotEmpty &&
                _descCtrl.text.trim().isNotEmpty,
            isUploading: _c.isUploading.value,
            uploadProgress: _c.overallProgress.value,
            onPublish: _handlePublish,
            accentColor: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildPreview(bool isDark) {
    return Obx(() {
      final imageCount = _c.pickedImages.length;
      return Container(
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.bgPage
              : AppColors.textPrimary,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark
                ? AppColors.bgPage
                : AppColors.textSecondary,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.bgPage.withValues(
                alpha: isDark ? 0.35 : 0.06,
              ),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.preview_rounded,
                  color: AppColors.textPrimary,
                ),
                const SizedBox(width: 10),
                Text(
                  'Preview',
                  style: GoogleFonts.roboto(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.textPrimary
                        : AppColors.bgPage,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // First image preview
            if (imageCount > 0 && _c.pickedImages.first.bytes != null)
              Container(
                height: 150,
                margin: EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  image: DecorationImage(
                    image: MemoryImage(_c.pickedImages.first.bytes!),
                    fit: BoxFit.cover,
                  ),
                ),
                child: imageCount > 1
                    ? Align(
                        alignment: Alignment.bottomRight,
                        child: Container(
                          margin: EdgeInsets.all(8),
                          padding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.bgPage54,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '+${imageCount - 1}',
                            style: GoogleFonts.roboto(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      )
                    : null,
              ),
            UploadPreviewItem(
              icon: Icons.image_rounded,
              label: 'Images',
              value: imageCount > 0 ? '$imageCount selected' : 'Not selected',
              isComplete: imageCount > 0,
            ),
            const SizedBox(height: 12),
            UploadPreviewItem(
              icon: Icons.poll_rounded,
              label: 'Poll',
              value: _c.hasPoll.value
                  ? (_c.pollType.value == PollType.yesNo
                        ? 'Yes/No'
                        : 'Multi-Choice')
                  : 'None',
              isComplete: _c.hasPoll.value,
            ),
            const SizedBox(height: 12),
            UploadPreviewItem(
              icon: Icons.title_rounded,
              label: 'Title',
              value: _titleCtrl.text.isNotEmpty ? _titleCtrl.text : 'Not added',
              isComplete: _titleCtrl.text.isNotEmpty,
            ),
            const SizedBox(height: 12),
            UploadPreviewItem(
              icon: Icons.account_circle_rounded,
              label: 'Channel',
              value: _c.selectedChannel.value?.channelName ?? 'Not selected',
              isComplete: _c.selectedChannel.value != null,
            ),
          ],
        ),
      );
    });
  }

  // Ã¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€Â SHARED COMPONENTS Ã¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€Â

  Widget _buildSidebarHeader(bool isDark) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? AppColors.bgSurface
                : AppColors.textSecondary,
          ),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.brand,
                  AppColors.textSecondary,
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.forum_rounded,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Community Post',
            style: GoogleFonts.roboto(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppColors.textPrimary
                  : AppColors.bgPage,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileAppBar(bool isDark) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.bgPage
            : AppColors.textPrimary,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? AppColors.bgSurface
                : AppColors.textSecondary,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Get.back(),
          ),
          const SizedBox(width: 8),
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.brand,
                  AppColors.textSecondary,
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.forum_rounded,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Community Post',
            style: GoogleFonts.roboto(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppColors.textPrimary
                  : AppColors.bgPage,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackButton(bool isDark) {
    return Padding(
      padding: EdgeInsets.all(20),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => Get.back(),
          icon: const Icon(Icons.arrow_back, size: 18),
          label: Text(
            'Back to Home',
            style: GoogleFonts.roboto(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: isDark
                ? AppColors.textPrimary60
                : AppColors.textSecondary,
            side: BorderSide(
              color: isDark
                  ? AppColors.bgPage
                  : AppColors.textSecondary,
            ),
            padding: EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDraftButton(bool isDark) {
    return Obx(() {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _c.isSavingDraft.value
              ? null
              : () {
                  // Sync poll question before saving
                  _c.pollQuestion.value = _pollQuestionCtrl.text;
                  _c.saveDraft(
                    title: _titleCtrl.text,
                    description: _descCtrl.text,
                    tagsRaw: _tagsCtrl.text,
                  );
                },
          icon: _c.isSavingDraft.value
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_rounded, size: 18),
          label: Text(
            _c.isSavingDraft.value ? 'Saving...' : 'Save as Draft',
            style: GoogleFonts.roboto(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: isDark
                ? AppColors.textPrimary
                : AppColors.bgPage,
            side: BorderSide(
              color: isDark
                  ? AppColors.bgPage
                  : AppColors.textSecondary,
            ),
            padding: EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    });
  }

  Widget _card(
    bool isDark, {
    required IconData icon,
    required String title,
    Color accentColor = AppColors.textSecondary,
    required List<Widget> children,
  }) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.bgPage
            : AppColors.textPrimary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? AppColors.bgPage
              : AppColors.textSecondary,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.bgPage.withValues(
              alpha: isDark ? 0.35 : 0.06,
            ),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: LinearGradient(
                    colors: [accentColor, accentColor.withValues(alpha: 0.7)],
                  ),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: GoogleFonts.roboto(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.textPrimary
                      : AppColors.bgPage,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  void _handlePublish() {
    if (_formKey.currentState?.validate() != true) {
      Get.snackbar(
        'Form Error',
        'Please fix the errors before publishing.',
        backgroundColor: AppColors.textSecondary,
        colorText: AppColors.textPrimary,
      );
      return;
    }

    // Sync poll question
    _c.pollQuestion.value = _pollQuestionCtrl.text;

    _c.publishPost(
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      tagsRaw: _tagsCtrl.text,
    );
  }
}





