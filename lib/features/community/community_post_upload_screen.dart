import 'dart:io' as io;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/upload_shared_widgets.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/utils/format_utils.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/community/community_post_upload_controller.dart';
import 'package:truthworld/features/community/data/models/community_draft.dart';
import 'package:truthworld/features/community/data/models/poll_model.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/presentation/widgets/create_topic_dialog.dart';
import 'package:truthworld/features/video/presentation/views/upload/widgets/topic_selection_bottom_sheet.dart';
import 'package:truthworld/theme/app_theme.dart';

// =============================================================================
// COMMUNITY POST UPLOAD SCREEN — 100% AppTheme, 100% AppFonts, Overflow Safe
// =============================================================================

class CommunityPostUploadScreen extends StatelessWidget {
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
  final CommunityDraft? draftToLoad;

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
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: _isMobile(context)
            ? _buildMobileLayout(context)
            : _buildDesktopLayout(context),
      ),
    );
  }

  // ── DESKTOP LAYOUT ─────────────────────────────────────────────────────────

  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      children: [
        // Sidebar
        Container(
          width: 280,
          decoration: BoxDecoration(
            color: context.colors.background,
            border: Border(
              right: BorderSide(
                color: context.colors.divider,
              ),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        _buildSidebarHeader(context),
                        const Spacer(),
                        _buildBackButton(context),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // Main content
        Expanded(
          child: SingleChildScrollView(
            padding: context.insets.xl,
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
                        _buildImageGallerySection(context),
                        const SizedBox(height: 24),
                        _buildDetailsSection(context),
                        const SizedBox(height: 24),
                        _buildPollSection(context),
                        const SizedBox(height: 24),
                        _buildSettingsSection(context),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 32),
                Expanded(child: _buildPreviewPanel(context)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── MOBILE LAYOUT ──────────────────────────────────────────────────────────

  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      children: [
        _buildMobileAppBar(context),
        Expanded(
          child: SingleChildScrollView(
            padding: context.insets.md,
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildImageGallerySection(context),
                  const SizedBox(height: 20),
                  _buildDetailsSection(context),
                  const SizedBox(height: 20),
                  _buildPollSection(context),
                  const SizedBox(height: 20),
                  _buildSettingsSection(context),
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
                      accentColor: context.colors.brand,
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

  // ── IMAGE GALLERY (1 Image, Any Ratio) ─────────────────────────────────────

  Widget _buildImageGallerySection(BuildContext context) {
    return _card(
      context,
      icon: Icons.photo_library_rounded,
      title: 'Image',
      accentColor: context.colors.brand,
      children: [
        Text(
          'Add 1 image, any aspect ratio. Max 20 MB.',
          style: context.twTypography.caption.copyWith(
            fontSize: 12,
            color: context.colors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),

        Obx(() {
          final images = _c.pickedImages;
          return Column(
            children: [
              if (images.isNotEmpty)
                Stack(
                  clipBehavior: Clip.antiAlias,
                  children: [
                    ClipRRect(
                      borderRadius: context.radius.lg,
                      child: InkWell(
                        onTap: _c.pickImages,
                        child: Container(
                          width: double.infinity,
                          height: 200,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            borderRadius: context.radius.lg,
                            border: Border.all(
                              color: context.colors.divider,
                              width: 1.5,
                            ),
                          ),
                          child: _buildPickedImageWidget(images.first),
                        ),
                      ),
                    ),
                    // Upload progress overlay
                    Obx(() {
                      final progress = _c.imageUploadProgress[0] ?? 0.0;
                      if (progress >= 1.0 || progress < 0) {
                        return const SizedBox.shrink();
                      }
                      return Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: context.colors.background.withValues(
                              alpha: 0.54,
                            ),
                            borderRadius: context.radius.lg,
                          ),
                          child: Center(
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                context.colors.brand,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    // Error indicator
                    Obx(() {
                      final progress = _c.imageUploadProgress[0] ?? 0.0;
                      if (progress != -1.0) {
                        return const SizedBox.shrink();
                      }
                      return Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: context.colors.divider.withValues(
                              alpha: 0.7,
                            ),
                            borderRadius: context.radius.lg,
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.error_outline_rounded,
                              color: AppColors.textPrimary,
                              size: 28,
                            ),
                          ),
                        ),
                      );
                    }),
                    // Remove button
                    Positioned(
                      top: 8,
                      right: 8,
                      child: InkWell(
                        onTap: () => _c.removeImage(0),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: context.colors.background.withValues(
                              alpha: 0.6,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: AppColors.textPrimary,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                    // Tap to change hint
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: context.colors.background.withValues(
                            alpha: 0.6,
                          ),
                          borderRadius: context.radius.sm,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.edit_rounded,
                              color: AppColors.textPrimary,
                              size: 12,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Tap to change',
                              style: context.twTypography.caption.copyWith(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              if (images.isEmpty)
                InkWell(
                  onTap: _c.pickImages,
                  borderRadius: context.radius.lg,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: context.radius.lg,
                      border: Border.all(
                        color: context.colors.divider,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.add_photo_alternate_rounded,
                          size: 36,
                          color: AppColors.textPrimary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'JPEG, PNG, GIF • Any aspect ratio',
                          style: context.twTypography.caption.copyWith(
                            fontSize: 12,
                            color: context.colors.textSecondary,
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

  Widget _buildPollSection(BuildContext context) {
    return Obx(() {
      return _card(
        context,
        icon: Icons.poll_rounded,
        title: 'Poll',
        accentColor: context.colors.brand,
        children: [
          // Toggle
          SwitchListTile.adaptive(
            title: Text(
              'Add a poll',
              style: context.twTypography.title.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: context.colors.textPrimary,
              ),
            ),
            subtitle: Text(
              'Let your community vote',
              style: context.twTypography.caption.copyWith(
                fontSize: 12,
                color: context.colors.textSecondary,
              ),
            ),
            value: _c.hasPoll.value,
            onChanged: _c.togglePoll,
            activeTrackColor: context.colors.brand,
            contentPadding: EdgeInsets.zero,
          ),

          if (_c.hasPoll.value) ...[
            const SizedBox(height: 16),

            // Poll type selector
            Row(
              children: [
                _pollTypeChip(
                  context,
                  PollType.yesNo,
                  'Yes / No',
                  Icons.thumbs_up_down_rounded,
                ),
                const SizedBox(width: 10),
                _pollTypeChip(
                  context,
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
                'Options (3–5)',
                style: context.twTypography.label.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: context.colors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              ...List.generate(_c.pollOptions.length, (i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: context.colors.surfaceContainer,
                          borderRadius: context.radius.sm,
                        ),
                        child: Center(
                          child: Text(
                            '${i + 1}',
                            style: context.twTypography.label.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          initialValue: _c.pollOptions[i],
                          onChanged: (v) => _c.updatePollOption(i, v),
                          style: context.twTypography.body.copyWith(
                            fontSize: 14,
                            color: context.colors.textPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Option ${i + 1}',
                            hintStyle: context.twTypography.body.copyWith(
                              color: context.colors.textSecondary.withValues(
                                alpha: 0.5,
                              ),
                              fontSize: 14,
                            ),
                            filled: true,
                            fillColor: context.colors.surface,
                            border: OutlineInputBorder(
                              borderRadius: context.radius.sm,
                              borderSide: BorderSide(
                                color: context.colors.divider,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: context.radius.sm,
                              borderSide: BorderSide(
                                color: context.colors.divider,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: context.radius.sm,
                              borderSide: BorderSide(
                                color: context.colors.brand,
                                width: 2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            isDense: true,
                          ),
                        ),
                      ),
                      if (_c.pollOptions.length > 3)
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            color: AppColors.textPrimary,
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
                  icon: const Icon(
                    Icons.add_rounded,
                    color: AppColors.textPrimary,
                  ),
                  label: Text(
                    'Add Option',
                    style: context.twTypography.button.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: context.colors.brand,
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
                      context,
                      'Yes',
                      Icons.check_rounded,
                      context.colors.brand,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _yesNoPill(
                      context,
                      'No',
                      Icons.close_rounded,
                      context.colors.textSecondary,
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 16),

            // Poll duration
            Row(
              children: [
                const Icon(
                  Icons.timer_outlined,
                  size: 16,
                  color: AppColors.textPrimary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Poll Duration',
                  style: context.twTypography.label.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [null, 1, 3, 7].map((days) {
                final isSelected = _c.pollDurationDays.value == days;
                return InkWell(
                  onTap: () => _c.pollDurationDays.value = days,
                  borderRadius: context.radius.lg,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? context.colors.brand.withValues(alpha: 0.15)
                          : context.colors.surface,
                      borderRadius: context.radius.lg,
                      border: Border.all(
                        color: isSelected
                            ? context.colors.brand
                            : context.colors.divider,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Text(
                      days == null
                          ? 'No limit'
                          : days == 1
                          ? '1 day'
                          : '$days days',
                      style: context.twTypography.label.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isSelected
                            ? context.colors.brand
                            : context.colors.textSecondary,
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
    BuildContext context,
    PollType type,
    String label,
    IconData icon,
  ) {
    return Obx(() {
      final isSelected = _c.pollType.value == type;
      return Expanded(
        child: InkWell(
          onTap: () => _c.setPollType(type),
          borderRadius: context.radius.lg,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? context.colors.brand.withValues(alpha: 0.15)
                  : context.colors.surface,
              borderRadius: context.radius.lg,
              border: Border.all(
                color: isSelected
                    ? context.colors.brand
                    : context.colors.divider,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: AppColors.textPrimary,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    style: context.twTypography.label.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? context.colors.brand
                          : context.colors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _yesNoPill(
    BuildContext context,
    String label,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: context.radius.lg,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: AppColors.textPrimary),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: context.twTypography.label.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickedImageWidget(PlatformFile file) {
    try {
      if (kIsWeb) {
        return Image.network(
          file.xFile.path,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const Center(
            child: Icon(
              Icons.broken_image_rounded,
              color: AppColors.textPrimary,
            ),
          ),
        );
      } else if (file.path != null && file.path!.isNotEmpty) {
        return Image.file(
          io.File(file.path!),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const Center(
            child: Icon(
              Icons.broken_image_rounded,
              color: AppColors.textPrimary,
            ),
          ),
        );
      } else if (file.bytes != null) {
        return Image.memory(
          file.bytes!,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const Center(
            child: Icon(
              Icons.broken_image_rounded,
              color: AppColors.textPrimary,
            ),
          ),
        );
      }
    } catch (_) {}
    return const Center(
      child: Icon(Icons.broken_image_rounded, color: AppColors.textPrimary),
    );
  }

  void _showSettingsBottomSheet(BuildContext context) {
    Get.bottomSheet<void>(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.tune_rounded,
                      color: AppColors.textPrimary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Post Interactive Settings',
                        style: context.twTypography.title.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: context.colors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.textPrimary,
                      ),
                      onPressed: () => Get.back<void>(),
                    ),
                  ],
                ),
                Divider(color: context.colors.divider),
                Obx(
                  () => SwitchListTile.adaptive(
                    title: Text(
                      'Dislike Option',
                      style: context.twTypography.body.copyWith(
                        color: context.colors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      'Allow users to dislike this post',
                      style: context.twTypography.caption.copyWith(
                        color: context.colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    value: _c.isDislikeEnabled.value,
                    onChanged: (v) => _c.isDislikeEnabled.value = v,
                    activeTrackColor: context.colors.brand,
                  ),
                ),
                Obx(
                  () => SwitchListTile.adaptive(
                    title: Text(
                      'Dislike Count',
                      style: context.twTypography.body.copyWith(
                        color: context.colors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      'Show dislike count to users',
                      style: context.twTypography.caption.copyWith(
                        color: context.colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    value: _c.showDislikeCount.value,
                    onChanged: (v) => _c.showDislikeCount.value = v,
                    activeTrackColor: context.colors.brand,
                  ),
                ),
                Obx(
                  () => SwitchListTile.adaptive(
                    title: Text(
                      'Comments',
                      style: context.twTypography.body.copyWith(
                        color: context.colors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      'Allow users to comment on this post',
                      style: context.twTypography.caption.copyWith(
                        color: context.colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    value: _c.isCommentsEnabled.value,
                    onChanged: (v) => _c.isCommentsEnabled.value = v,
                    activeTrackColor: context.colors.brand,
                  ),
                ),
                Obx(
                  () => SwitchListTile.adaptive(
                    title: Text(
                      'Like Option',
                      style: context.twTypography.body.copyWith(
                        color: context.colors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      'Allow users to like this post',
                      style: context.twTypography.caption.copyWith(
                        color: context.colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    value: _c.isLikeEnabled.value,
                    onChanged: (v) => _c.isLikeEnabled.value = v,
                    activeTrackColor: context.colors.brand,
                  ),
                ),
                Obx(
                  () => SwitchListTile.adaptive(
                    title: Text(
                      'Like Count',
                      style: context.twTypography.body.copyWith(
                        color: context.colors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      'Show like count to users',
                      style: context.twTypography.caption.copyWith(
                        color: context.colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    value: _c.showLikeCount.value,
                    onChanged: (v) => _c.showLikeCount.value = v,
                    activeTrackColor: context.colors.brand,
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── DETAILS ────────────────────────────────────────────────────────────────

  Widget _buildDetailsSection(BuildContext context) {
    return _card(
      context,
      icon: Icons.edit_rounded,
      title: 'Post Details',
      accentColor: context.colors.brand,
      trailingHeader: IconButton(
        icon: const Icon(Icons.tune_rounded, color: AppColors.textPrimary),
        tooltip: 'Post Options Settings',
        onPressed: () => _showSettingsBottomSheet(context),
      ),
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
          label: 'Tags (Max 5)',
          icon: Icons.tag_rounded,
          hint: 'Add tags separated by commas (max 5 tags)',
          maxLength: 200,
          validator: (val) {
            if (val != null && val.trim().isNotEmpty) {
              final count = val.split(',').where((e) => e.trim().isNotEmpty).length;
              if (count > 5) {
                return 'Maximum 5 tags allowed';
              }
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        Text(
          'Visibility',
          style: context.twTypography.label.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: context.colors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        UploadVisibilitySelector(
          selectedVisibility: _c.selectedVisibility,
        ),
        const SizedBox(height: 16),
        _buildTopicSelection(context),
      ],
    );
  }

  Widget _buildTopicSelection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Obx(() {
      final selectedSlug = _c.selectedTopicId.value;
      final hasDraft = _c.newTopicData.isNotEmpty;
      final topics = _c.availableTopics;

      Topic? selectedTopic;
      if (selectedSlug.isNotEmpty && selectedSlug != 'new_topic_draft') {
        for (final t in topics) {
          if (t.slug == selectedSlug) {
            selectedTopic = t;
            break;
          }
        }
      }

      final draftTitle = hasDraft
          ? (_c.newTopicData['title'] as String? ?? 'New Draft')
          : '';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Add to Topic',
                style: context.twTypography.title.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textPrimary : const Color(0xFF111827),
                ),
              ),
              const Spacer(),
              if (_c.isTopicsLoading.value)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                TextButton.icon(
                  onPressed: () => _showCreateTopicModal(context, isDark),
                  icon: const Icon(Icons.add_rounded, size: 16, color: AppColors.textPrimary),
                  label: const Text('+ New Topic'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF3B82F6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Selected Topic Trigger Card
          InkWell(
            onTap: () => TopicSelectionBottomSheet.show(
              context,
              _c,
              onCreateNewTopic: (isDark) => _showCreateTopicModal(context, isDark),
            ),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161B22) : AppColors.textPrimary,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: (selectedTopic != null || hasDraft)
                      ? const Color(0xFF3B82F6)
                      : (isDark
                          ? const Color(0xFF30363D)
                          : const Color(0xFFE5E7EB)),
                  width: (selectedTopic != null || hasDraft) ? 1.5 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.bgPage.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Topic Thumbnail or Icon
                  if (hasDraft)
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.edit_document,
                        color: AppColors.textPrimary,
                        size: 22,
                      ),
                    )
                  else if (selectedTopic != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 46,
                        height: 46,
                        color: isDark
                            ? const Color(0xFF21262D)
                            : const Color(0xFFE5E7EB),
                        child: (selectedTopic.thumbnailUrl ?? selectedTopic.coverImage) != null &&
                                (selectedTopic.thumbnailUrl ?? selectedTopic.coverImage)!.isNotEmpty
                            ? Image.network(
                                (selectedTopic.thumbnailUrl ?? selectedTopic.coverImage)!,
                                width: 46,
                                height: 46,
                                fit: BoxFit.cover,
                              )
                            : ColoredBox(
                                color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                                child: const Icon(
                                  Icons.topic_rounded,
                                  color: AppColors.textPrimary,
                                  size: 22,
                                ),
                              ),
                      ),
                    )
                  else
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF21262D)
                            : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.topic_rounded,
                        color: AppColors.textPrimary,
                        size: 22,
                      ),
                    ),

                  const SizedBox(width: 14),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hasDraft) ...[
                          Text(
                            'Draft: $draftTitle',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF3B82F6),
                            ),
                          ),
                          Text(
                            'Will be created upon upload',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ] else if (selectedTopic != null) ...[
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  selectedTopic.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              if (selectedTopic.visibilityType == TopicVisibilityType.private)
                                const Icon(
                                  Icons.lock_rounded,
                                  size: 14,
                                  color: AppColors.textPrimary,
                                )
                              else if (selectedTopic.visibilityType == TopicVisibilityType.channelOnly)
                                const Icon(
                                  Icons.group_rounded,
                                  size: 14,
                                  color: AppColors.textPrimary,
                                )
                              else
                                const Icon(
                                  Icons.public_rounded,
                                  size: 14,
                                  color: AppColors.textPrimary,
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                '${FormatUtils.formatCount(selectedTopic.followerCount)} followers • ${FormatUtils.formatCount(selectedTopic.videoCount)} videos',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          Text(
                            'Select Topic knowledge hub',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tap to search and select a topic or create new',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(width: 10),

                  if (selectedTopic != null || hasDraft)
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textPrimary),
                      onPressed: () {
                        _c.selectedTopicId.value = '';
                        _c.newTopicData.clear();
                      },
                    )
                  else
                    const Icon(Icons.chevron_right_rounded, size: 22, color: AppColors.textPrimary),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }

  void _showCreateTopicModal(BuildContext context, bool isDark) {
    final currentChannelId = _c.selectedChannel.value?.channelId ?? '';
    CreateTopicDialog.show(
      context: context,
      isDarkMode: isDark,
      channelVideosFuture: currentChannelId.isNotEmpty
          ? FirebaseFirestore.instance
                .collection(FirestoreCollections.videos)
                .where('channelId', isEqualTo: currentChannelId)
                .get()
                .then(
                  (snap) => snap.docs
                      .map((doc) => {'id': doc.id, ...doc.data()})
                      .toList(),
                )
          : Future.value([]),
      onCreateTopicSubmitted: (createCtrl) async {
        final title = createCtrl.titleController.text.trim();
        var rawHandle = createCtrl.handleController.text.trim();
        if (rawHandle.startsWith('T/') || rawHandle.startsWith('t/')) {
          rawHandle = rawHandle.substring(2);
        }
        final cleanHandle = rawHandle
            .replaceAll(RegExp('[^a-zA-Z0-9_-]'), '-')
            .replaceAll(RegExp('-+'), '-');
        final finalHandle = 'T/$cleanHandle';
        final finalHandleLowercase = finalHandle.toLowerCase();

        // Check handle uniqueness in Firestore
        final existingHandle = await FirebaseFirestore.instance
            .collection(FirestoreCollections.topics)
            .where('handleLowercase', isEqualTo: finalHandleLowercase)
            .limit(1)
            .get();

        if (existingHandle.docs.isNotEmpty) {
          AppSnackbar.show(
            'Error',
            'Topic handle is already taken. Please choose a different one.',
          );
          throw Exception('Handle already taken');
        }

        _c.newTopicData.value = {
          'title': title,
          'handle': finalHandle,
          'description': createCtrl.descriptionController.text.trim(),
          'category': createCtrl.categoryController.text,
          'visibilityType': createCtrl.selectedVisibility.value,
          'accessCode': createCtrl.accessCodeController.text.trim(),
          'thumbnailSource': createCtrl.thumbnailSource.value,
          'customThumbnailBytes': createCtrl.pickedCustomImageBytes.value,
          'customThumbnailName': createCtrl.pickedCustomImageName.value,
        };

        _c.selectedTopicId.value = 'new_topic_draft';
        AppSnackbar.show(
          'Success',
          'Topic draft created! It will be published along with your post.',
        );
      },
    );
  }

  // ── SETTINGS ───────────────────────────────────────────────────────────────

  Widget _buildSettingsSection(BuildContext context) {
    return _card(
      context,
      icon: Icons.tune_rounded,
      title: 'Settings',
      accentColor: context.colors.brand,
      children: [
        Text(
          'Visibility',
          style: context.twTypography.label.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: context.colors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),
        UploadVisibilitySelector(selectedVisibility: _c.selectedVisibility),
        const SizedBox(height: 16),

        // Category
        Text(
          'Category',
          style: context.twTypography.label.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: context.colors.textSecondary,
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
                borderRadius: context.radius.lg,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? context.colors.brand.withValues(alpha: 0.15)
                        : context.colors.surface,
                    borderRadius: context.radius.lg,
                    border: Border.all(
                      color: isSelected
                          ? context.colors.brand
                          : context.colors.divider,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    cat,
                    style: context.twTypography.label.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? context.colors.brand
                          : context.colors.textSecondary,
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
              style: context.twTypography.title.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: context.colors.textPrimary,
              ),
            ),
            value: _c.isScheduled.value,
            onChanged: (v) => _c.isScheduled.value = v,
            activeTrackColor: context.colors.brand,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        Obx(
          () => SwitchListTile.adaptive(
            title: Text(
              'Kid Friendly',
              style: context.twTypography.title.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: context.colors.textPrimary,
              ),
            ),
            value: _c.isKidFriendly.value,
            onChanged: (v) => _c.isKidFriendly.value = v,
            activeTrackColor: context.colors.brand,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  // ── PREVIEW & PUBLISH ──────────────────────────────────────────────────────

  Widget _buildPreviewPanel(BuildContext context) {
    return Column(
      children: [
        _buildPreview(context),
        const SizedBox(height: 20),
        _buildDraftButton(context),
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
            accentColor: context.colors.brand,
          ),
        ),
      ],
    );
  }

  Widget _buildPreview(BuildContext context) {
    return Obx(() {
      final imageCount = _c.pickedImages.length;
      return Container(
        padding: context.insets.lg,
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: context.radius.lg,
          border: Border.all(
            color: context.colors.divider,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.preview_rounded, color: AppColors.textPrimary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Preview',
                    style: context.twTypography.title.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // First image preview
            if (imageCount > 0 && _c.pickedImages.first.path != null)
              Container(
                height: 150,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  borderRadius: context.radius.lg,
                  image: DecorationImage(
                    image: kIsWeb
                        ? NetworkImage(_c.pickedImages.first.xFile.path)
                        : FileImage(io.File(_c.pickedImages.first.path!))
                              as ImageProvider,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            UploadPreviewItem(
              icon: Icons.image_rounded,
              label: 'Image',
              value: imageCount > 0 ? 'Selected' : 'Not selected',
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
          ],
        ),
      );
    });
  }

  // ── SHARED COMPONENTS ──────────────────────────────────────────────────────

  Widget _buildSidebarHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: context.colors.divider,
          ),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: context.gradients.primary,
              borderRadius: context.radius.lg,
            ),
            child: const Icon(
              Icons.forum_rounded,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Community Post',
            style: context.twTypography.title.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: context.colors.textPrimary,
              letterSpacing: -0.5,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMobileAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: context.colors.appBarSurface,
        border: Border(
          bottom: BorderSide(
            color: context.colors.divider,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: Get.back,
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: context.gradients.primary,
              borderRadius: context.radius.lg,
            ),
            child: const Icon(
              Icons.forum_rounded,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Community Post',
              style: context.twTypography.title.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.colors.textPrimary,
                letterSpacing: -0.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: Get.back,
          icon: const Icon(
            Icons.arrow_back,
            color: AppColors.textPrimary,
            size: 18,
          ),
          label: Text(
            'Back to Home',
            style: context.twTypography.button.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: context.colors.textSecondary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: context.colors.textSecondary,
            side: BorderSide(
              color: context.colors.divider,
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: context.radius.lg,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDraftButton(BuildContext context) {
    return Obx(() {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _c.isSavingDraft.value
              ? null
              : () {
                  _c.pollQuestion.value = _pollQuestionCtrl.text;
                  _c.saveDraft(
                    title: _titleCtrl.text,
                    description: _descCtrl.text,
                    tagsRaw: _tagsCtrl.text,
                  );
                },
          icon: _c.isSavingDraft.value
              ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      context.colors.brand,
                    ),
                  ),
                )
              : const Icon(
                  Icons.save_rounded,
                  color: AppColors.textPrimary,
                  size: 18,
                ),
          label: Text(
            _c.isSavingDraft.value ? 'Saving...' : 'Save as Draft',
            style: context.twTypography.button.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: context.colors.textPrimary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: context.colors.textPrimary,
            side: BorderSide(
              color: context.colors.divider,
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: context.radius.lg,
            ),
          ),
        ),
      );
    });
  }

  Widget _card(
    BuildContext context, {
    required IconData icon,
    required String title,
    required List<Widget> children,
    Color? accentColor,
    Widget? trailingHeader,
  }) {
    final effectiveAccentColor = accentColor ?? context.colors.brand;
    return Container(
      padding: context.insets.lg,
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: context.radius.lg,
        border: Border.all(
          color: context.colors.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: context.radius.sm,
                  gradient: LinearGradient(
                    colors: [
                      effectiveAccentColor,
                      effectiveAccentColor.withValues(alpha: 0.7),
                    ],
                  ),
                ),
                child: Icon(icon, size: 18, color: AppColors.textPrimary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: context.twTypography.title.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trailingHeader != null) ...[
                trailingHeader,
              ],
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
      AppSnackbar.show(
        'Form Error',
        'Please fix the errors before publishing.',
        backgroundColor: AppColors.textSecondary,
        colorText: AppColors.textPrimary,
      );
      return;
    }

    _c.pollQuestion.value = _pollQuestionCtrl.text;

    _c.publishPost(
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      tagsRaw: _tagsCtrl.text,
    );
  }

  Widget _buildChannelVerificationBanner(
    Channel channel,
    BuildContext context,
  ) {
    final isUnderReview = channel.status == ChannelStatus.underReview;
    final isPending = channel.status == ChannelStatus.verificationPending;
    final isRejected = channel.status == ChannelStatus.verificationRejected;

    var statusColor = context.colors.error;
    var statusIcon = Icons.gpp_bad_rounded;
    var title = 'Channel Blocked';
    var message = 'Your channel is not active.';

    if (isUnderReview) {
      statusColor = context.colors.brand;
      statusIcon = Icons.hourglass_empty_rounded;
      title = 'Moderation Pending';
      message =
          'Your channel details are currently under review by Gemini. You can publish once approved.';
    } else if (isPending) {
      statusColor = context.colors.warning;
      statusIcon = Icons.pending_actions_rounded;
      title = 'Verification Pending';
      message =
          'Your channel is currently verification pending. You can publish once your branding is verified.';
    } else if (isRejected) {
      if (channel.moderationReason != null &&
          channel.moderationReason!.isNotEmpty) {
        title = 'Details Rejected';
        message =
            'Your channel details were rejected by Gemini: ${channel.moderationReason}. Please update them in customization.';
      } else {
        title = 'Branding Rejected';
        message =
            'Your channel branding was rejected. Please update your avatar/banner in customization to re-verify.';
      }
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.15),
        borderRadius: context.radius.lg,
        border: Border.all(
          color: statusColor.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(statusIcon, color: AppColors.textPrimary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: context.twTypography.title.copyWith(
                    color: statusColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: context.twTypography.bodySmall.copyWith(
                    color: context.colors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
