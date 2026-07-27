import 'dart:io' as io;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/community/community_post_upload_controller.dart';
import 'package:truthworld/features/community/data/models/community_draft.dart';
import 'package:truthworld/features/community/data/models/poll_model.dart';
import 'package:truthworld/features/presentation/widgets/upload_shared_widgets.dart';
import 'package:truthworld/theme/app_theme.dart';

// =============================================================================
// COMMUNITY POST UPLOAD SCREEN Ã¢â‚¬â€ 100% StatelessWidget + GetX
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

  // Ã¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€Â DESKTOP LAYOUT Ã¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€Â

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
          child: Column(
            children: [
              _buildSidebarHeader(context),
              const Spacer(),
              _buildBackButton(context),
            ],
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

  // Ã¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€Â MOBILE LAYOUT Ã¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€Â

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

  // Ã¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€Â IMAGE GALLERY (1-10, any ratio) Ã¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€Â

  Widget _buildImageGallerySection(BuildContext context) {
    return _card(
      context,
      icon: Icons.photo_library_rounded,
      title: 'Image',
      accentColor: context.colors.brand,
      children: [
        Text(
          'Add 1 image, any aspect ratio. Max 20 MB.',
          style: TextStyle(
            
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
                  children: [
                    ClipRRect(
                      borderRadius: context.radius.lg,
                      child: InkWell(
                        onTap: _c.pickImages,
                        child: Container(
                          width: double.infinity,
                          height: 200,
                          decoration: BoxDecoration(
                            borderRadius: context.radius.lg,
                            border: Border.all(
                              color: context.colors.divider,
                            ),
                          ),
                          child: kIsWeb || images.first.path != null
                              ? Image(
                                  image: kIsWeb
                                      ? NetworkImage(images.first.xFile.path)
                                      : FileImage(io.File(images.first.path!))
                                            as ImageProvider,
                                  fit: BoxFit.cover,
                                )
                              : const Center(
                                  child: Icon(Icons.broken_image_rounded),
                                ),
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
                            color: context.colors.background.withValues(alpha: 0.54),
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
                          child: Center(
                            child: Icon(
                              Icons.error_outline_rounded,
                              color: context.colors.error,
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
                            color: context.colors.background.withValues(alpha: 0.54),
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
                          color: context.colors.background.withValues(alpha: 0.54),
                          borderRadius: context.radius.sm,
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.edit_rounded,
                              color: AppColors.textPrimary,
                              size: 12,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Tap to change',
                              style: TextStyle(
                                
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
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.add_photo_alternate_rounded,
                          size: 36,
                          color: context.colors.textSecondary,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'JPEG, PNG, GIF • Any aspect ratio',
                          style: TextStyle(
                            
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
              style: TextStyle(
                
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: context.colors.textPrimary,
              ),
            ),
            subtitle: Text(
              'Let your community vote',
              style: TextStyle(
                
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
                style: TextStyle(
                  
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
                          color: context.colors.textSecondary.withValues(alpha: 0.1),
                          borderRadius: context.radius.sm,
                        ),
                        child: Center(
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              
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
                          style: TextStyle(
                            
                            fontSize: 14,
                            color: context.colors.textPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Option ${i + 1}',
                            hintStyle: TextStyle(
                              
                              color: context.colors.textSecondary.withValues(alpha: 0.5),
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
                          icon: Icon(
                            Icons.close_rounded,
                            color: context.colors.textSecondary,
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
                  icon: Icon(Icons.add_rounded, color: context.colors.textSecondary),
                  label: Text(
                    'Add Option',
                    style: TextStyle(
                      
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: context.colors.textSecondary,
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
                Icon(
                  Icons.timer_outlined,
                  size: 16,
                  color: context.colors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Poll Duration',
                  style: TextStyle(
                    
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
              children: [null, 1, 3, 7].map((days) {
                final isSelected = _c.pollDurationDays.value == days;
                return InkWell(
                  onTap: () => _c.pollDurationDays.value = days,
                  borderRadius: context.radius.lg,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                      style: TextStyle(
                        
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
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? context.colors.brand.withValues(alpha: 0.12)
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
                  color: isSelected
                      ? context.colors.brand
                      : context.colors.textSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isSelected
                        ? context.colors.brand
                        : context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _yesNoPill(BuildContext context, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: context.radius.lg,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              
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

  Widget _buildDetailsSection(BuildContext context) {
    return _card(
      context,
      icon: Icons.edit_rounded,
      title: 'Post Details',
      accentColor: context.colors.brand,
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

  Widget _buildSettingsSection(BuildContext context) {
    return _card(
      context,
      icon: Icons.tune_rounded,
      title: 'Settings',
      accentColor: context.colors.brand,
      children: [
        Text(
          'Visibility',
          style: TextStyle(
            
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
          style: TextStyle(
            
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
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                    style: TextStyle(
                      
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
              style: TextStyle(
                
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
              style: TextStyle(
                
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

  // Ã¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€Â PREVIEW & PUBLISH Ã¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€Â

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
                Icon(Icons.preview_rounded, color: context.colors.brand),
                const SizedBox(width: 10),
                Text(
                  'Preview',
                  style: TextStyle(
                    
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
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

  // Ã¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€Â SHARED COMPONENTS Ã¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€ÂÃ¢â€Â

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
            child: const Icon(Icons.forum_rounded, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          Text(
            'Community Post',
            style: TextStyle(
              
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: context.colors.textPrimary,
              letterSpacing: -0.5,
            ),
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
            icon: const Icon(Icons.arrow_back),
            onPressed: Get.back,
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: context.gradients.primary,
              borderRadius: context.radius.lg,
            ),
            child: const Icon(Icons.forum_rounded, color: AppColors.textPrimary),
          ),
          const SizedBox(width: 12),
          Text(
            'Community Post',
            style: TextStyle(
              
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: context.colors.textPrimary,
              letterSpacing: -0.5,
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
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text(
            'Back to Home',
            style: TextStyle(
              
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
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
                  // Sync poll question before saving
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
                    valueColor: AlwaysStoppedAnimation<Color>(context.colors.brand),
                  ),
                )
              : const Icon(Icons.save_rounded, size: 18),
          label: Text(
            _c.isSavingDraft.value ? 'Saving...' : 'Save as Draft',
            style: const TextStyle(
              
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
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
    required List<Widget> children, Color? accentColor,
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
              Text(
                title,
                style: TextStyle(
                  
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
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
      AppSnackbar.show(
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

  Widget _buildChannelVerificationBanner(Channel channel, BuildContext context) {
    final isUnderReview = channel.status == ChannelStatus.underReview;
    final isPending = channel.status == ChannelStatus.verificationPending;
    final isRejected =
        channel.status == ChannelStatus.verificationRejected;

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
      statusColor = AppColors.warning;
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
          Icon(statusIcon, color: statusColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    
                    color: statusColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    
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
