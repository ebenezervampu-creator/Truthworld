import 'dart:io' as io;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/community/community_post_upload_controller.dart';
import 'package:truthworld/features/community/data/models/community_draft.dart';
import 'package:truthworld/theme/app_theme.dart';

// =============================================================================
// COMMUNITY POST UPLOAD SCREEN — 100% AppTheme, 100% AppFonts, White Icons Only
// =============================================================================

class CommunityPostUploadScreen extends StatefulWidget {
  final CommunityDraft? draftToLoad;

  const CommunityPostUploadScreen({super.key, this.draftToLoad});

  @override
  State<CommunityPostUploadScreen> createState() =>
      _CommunityPostUploadScreenState();
}

class _CommunityPostUploadScreenState extends State<CommunityPostUploadScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  CommunityPostUploadController get _c =>
      Get.find<CommunityPostUploadController>();

  @override
  void initState() {
    super.initState();
    if (widget.draftToLoad != null) {
      _c.loadDraft(widget.draftToLoad!);
      _titleCtrl.text = widget.draftToLoad!.title;
      _descCtrl.text = widget.draftToLoad!.description;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  bool _isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 900;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(_isMobile(context) ? 16.0 : 28.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1280),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context),
                    const SizedBox(height: 24),
                    if (_isMobile(context)) _buildMobileLayout(context) else _buildDesktopLayout(context),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── HEADER ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            InkWell(
              onTap: () {
                if (Navigator.of(context).canPop()) {
                  Get.back();
                } else {
                  Get.offAllNamed('/studio');
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF141414),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.colors.divider),
                ),
                child: const Icon(
                  Icons.arrow_back,
                  color: AppColors.textPrimary, // White icon only
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Create Community Post',
                style: context.twTypography.display.copyWith(
                  fontSize: _isMobile(context) ? 20 : 26,
                  fontWeight: FontWeight.bold,
                  color: context.colors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Share updates, thoughts, or important announcements with your community.',
          style: context.twTypography.body.copyWith(
            fontSize: 14,
            color: context.colors.textSecondary,
          ),
        ),
      ],
    );
  }

  // ── DESKTOP LAYOUT (2 Columns) ─────────────────────────────────────────────

  Widget _buildDesktopLayout(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column (Post Content)
            Expanded(
              flex: 65,
              child: _buildPostContentSection(context),
            ),
            const SizedBox(width: 28),
            // Right Column (Visibility + Additional Options)
            Expanded(
              flex: 35,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildVisibilitySection(context),
                  const SizedBox(height: 24),
                  _buildAdditionalOptionsSection(context),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        _buildActionButtons(context),
      ],
    );
  }

  // ── MOBILE LAYOUT (1 Column Stacked) ───────────────────────────────────────

  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPostContentSection(context),
        const SizedBox(height: 20),
        _buildVisibilitySection(context),
        const SizedBox(height: 20),
        _buildAdditionalOptionsSection(context),
        const SizedBox(height: 28),
        _buildActionButtons(context),
      ],
    );
  }

  // ── SECTION CONTAINER WRAPPER ──────────────────────────────────────────────

  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required List<Widget> children,
    String? subtitle,
    Widget? titleAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.colors.divider.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: context.twTypography.title.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: context.colors.textPrimary,
                  ),
                ),
              ),
              ?titleAction,
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: context.twTypography.caption.copyWith(
                fontSize: 12,
                color: context.colors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }

  // ── SECTION 1: POST CONTENT ────────────────────────────────────────────────

  Widget _buildPostContentSection(BuildContext context) {
    return _buildSectionCard(
      context,
      title: '1. Post Content',
      children: [
        // Image Label
        RichText(
          text: TextSpan(
            text: 'Post Image ',
            style: context.twTypography.label.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.colors.textPrimary,
            ),
            children: const [
              TextSpan(
                text: '*',
                style: TextStyle(color: Color(0xFFEF4444)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Add an image to make your post more engaging.',
          style: context.twTypography.caption.copyWith(
            fontSize: 12,
            color: context.colors.textSecondary,
          ),
        ),
        const SizedBox(height: 12),

        // Dropzone / Image Picker Box
        Obx(() {
          final images = _c.pickedImages;
          final imageUrls = _c.imageUrls;

          if (images.isNotEmpty || imageUrls.isNotEmpty) {
            return _buildSelectedImagePreview(context);
          }

          return CustomPaint(
            painter: DashedBorderPainter(
              color: context.colors.divider,
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF141414),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.colors.surfaceContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.image_outlined,
                      color: AppColors.textPrimary, // White icon only
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Drag & drop your image here',
                    style: context.twTypography.body.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'or',
                    style: context.twTypography.caption.copyWith(
                      fontSize: 12,
                      color: context.colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: _c.pickImages,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.colors.surfaceContainerHigh,
                      foregroundColor: context.colors.textPrimary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: context.colors.divider,
                        ),
                      ),
                    ),
                    child: Text(
                      'Choose file',
                      style: context.twTypography.button.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.colors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'JPG, PNG, WEBP up to 10MB',
                    style: context.twTypography.caption.copyWith(
                      fontSize: 11,
                      color: context.colors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),

        const SizedBox(height: 20),

        // Title Input
        RichText(
          text: TextSpan(
            text: 'Title ',
            style: context.twTypography.label.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.colors.textPrimary,
            ),
            children: const [
              TextSpan(
                text: '*',
                style: TextStyle(color: Color(0xFFEF4444)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _titleCtrl,
          builder: (context, value, _) {
            return TextFormField(
              controller: _titleCtrl,
              maxLength: 100,
              style: context.twTypography.body.copyWith(
                color: context.colors.textPrimary,
                fontSize: 14,
              ),
              validator: (v) {
                final val = v?.trim() ?? '';
                if (val.isEmpty) {
                  return 'Enter Title';
                }
                if (val.length < 5) {
                  return 'Title is too short (min 5 characters)';
                }
                return null;
              },
              decoration: InputDecoration(
                hintText: 'Enter a title for your post',
                hintStyle: context.twTypography.body.copyWith(
                  color: context.colors.textTertiary,
                  fontSize: 14,
                ),
                filled: true,
                fillColor: const Color(0xFF121212),
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: context.colors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: context.colors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.white, width: 1.5),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: context.colors.error, width: 1.5),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: context.colors.error, width: 1.5),
                ),
                errorStyle: context.twTypography.caption.copyWith(
                  color: context.colors.error,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                suffixIcon: UnconstrainedBox(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Text(
                      '${value.text.length}/100',
                      style: context.twTypography.caption.copyWith(
                        fontSize: 12,
                        color: context.colors.textTertiary,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 16),

        // Description Input
        RichText(
          text: TextSpan(
            text: 'Description ',
            style: context.twTypography.label.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.colors.textPrimary,
            ),
            children: const [
              TextSpan(
                text: '*',
                style: TextStyle(color: Color(0xFFEF4444)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _descCtrl,
          maxLines: 5,
          minLines: 4,
          maxLength: 2000,
          onChanged: (val) => _c.descriptionText.value = val,
          style: context.twTypography.body.copyWith(
            color: context.colors.textPrimary,
            fontSize: 14,
          ),
          validator: (v) {
            final val = v?.trim() ?? '';
            if (val.isEmpty) {
              return 'Enter Description';
            }
            if (val.length < 10) {
              return 'Description is too short (min 10 characters)';
            }
            return null;
          },
          decoration: InputDecoration(
            hintText: 'Write your post description...',
            hintStyle: context.twTypography.body.copyWith(
              color: context.colors.textTertiary,
              fontSize: 14,
            ),
            filled: true,
            fillColor: const Color(0xFF121212),
            counterText: '',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: context.colors.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: context.colors.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Colors.white, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: context.colors.error, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: context.colors.error, width: 1.5),
            ),
            errorStyle: context.twTypography.caption.copyWith(
              color: context.colors.error,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${_descCtrl.text.length}/2000',
            style: context.twTypography.caption.copyWith(
              fontSize: 12,
              color: context.colors.textTertiary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedImagePreview(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.divider),
      ),
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 80,
                  height: 80,
                  color: context.colors.surfaceContainer,
                  child: _c.pickedImages.isNotEmpty
                      ? (kIsWeb
                          ? Image.network(
                              _c.pickedImages.first.path ?? '',
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.image_outlined,
                                color: AppColors.textPrimary,
                              ),
                            )
                          : Image.file(
                              io.File(_c.pickedImages.first.path!),
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.image_outlined,
                                color: AppColors.textPrimary,
                              ),
                            ))
                      : (_c.imageUrls.isNotEmpty
                          ? Image.network(
                              _c.imageUrls.first,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.image_outlined,
                                color: AppColors.textPrimary,
                              ),
                            )
                          : const Icon(
                              Icons.image_outlined,
                              color: AppColors.textPrimary,
                            )),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _c.pickedImages.isNotEmpty
                          ? _c.pickedImages.first.name
                          : 'Uploaded Image',
                      style: context.twTypography.title.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.colors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _c.pickedImages.isNotEmpty
                          ? '${(_c.pickedImages.first.size / (1024 * 1024)).toStringAsFixed(2)} MB'
                          : 'Ready',
                      style: context.twTypography.caption.copyWith(
                        fontSize: 12,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _c.removeImage(0),
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppColors.textPrimary, // White icon
                  size: 20,
                ),
                tooltip: 'Remove image',
              ),
            ],
          ),
          if (_c.isUploading.value) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: _c.overallProgress.value,
              backgroundColor: context.colors.surfaceContainer,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ],
      ),
    );
  }

  // ── SECTION 2: VISIBILITY ──────────────────────────────────────────────────

  Widget _buildVisibilitySection(BuildContext context) {
    final visibilityOptions = [
      {
        'key': 'Public',
        'title': 'Public',
        'desc': 'Anyone can see this post',
        'icon': Icons.public_outlined,
      },
      {
        'key': 'Private',
        'title': 'Private',
        'desc': 'Only you can see this post',
        'icon': Icons.lock_outlined,
      },
      {
        'key': 'Members',
        'title': 'Members',
        'desc': 'Only members can see this post',
        'icon': Icons.people_outline_rounded,
      },
      {
        'key': 'Subscribers only',
        'title': 'Subscribers only',
        'desc': 'Only subscribers can see this post',
        'icon': Icons.star_outline_rounded,
      },
      {
        'key': 'Made for kids',
        'title': 'Made for kids',
        'desc': 'Safe content for kids',
        'icon': Icons.sentiment_satisfied_alt_outlined,
        'hasInfo': true,
      },
    ];

    return Obx(() {
      final currentVis = _c.selectedVisibility.value;

      return _buildSectionCard(
        context,
        title: '2. Visibility',
        subtitle: 'Choose who can see your post.',
        children: visibilityOptions.map((opt) {
          final key = opt['key']! as String;
          final title = opt['title']! as String;
          final desc = opt['desc']! as String;
          final icon = opt['icon']! as IconData;
          final hasInfo = opt['hasInfo'] == true;
          final isSelected = currentVis == key;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              onTap: () {
                _c.selectedVisibility.value = key;
                if (key == 'Made for kids') {
                  _c.isKidFriendly.value = true;
                }
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF141414),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.8)
                        : context.colors.divider,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      color: AppColors.textPrimary, // Always white icon
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: context.twTypography.title.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: context.colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            desc,
                            style: context.twTypography.caption.copyWith(
                              fontSize: 11,
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasInfo)
                      const Icon(
                        Icons.info_outline,
                        color: AppColors.textPrimary, // White icon
                        size: 18,
                      )
                    else if (isSelected)
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.textPrimary, // White icon
                        size: 20,
                      )
                    else
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: context.colors.textTertiary,
                            width: 1.5,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      );
    });
  }

  // ── SECTION 3: ADDITIONAL OPTIONS ─────────────────────────────────────────

  Widget _buildAdditionalOptionsSection(BuildContext context) {
    return Obx(() {
      return _buildSectionCard(
        context,
        title: '3. Additional Options',
        subtitle: 'More settings for your post.',
        children: [
          // Made for kids
          _buildOptionToggleRow(
            context,
            title: 'Made for kids',
            subtitle: 'Mark this post as made for kids content',
            value: _c.isKidFriendly.value,
            onChanged: (val) => _c.isKidFriendly.value = val,
          ),
          const SizedBox(height: 14),

          // Allow comments
          _buildOptionToggleRow(
            context,
            title: 'Allow comments',
            subtitle: 'Let others comment on this post',
            value: _c.isCommentsEnabled.value,
            onChanged: (val) => _c.isCommentsEnabled.value = val,
          ),
          const SizedBox(height: 14),

          // Pin this post
          _buildOptionToggleRow(
            context,
            title: 'Pin this post',
            subtitle: 'Pin to the top of community feed',
            value: _c.isPinnedPost.value,
            onChanged: (val) => _c.isPinnedPost.value = val,
          ),
        ],
      );
    });
  }

  Widget _buildOptionToggleRow(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: context.twTypography.title.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: context.twTypography.caption.copyWith(
                  fontSize: 11,
                  color: context.colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.white,
          activeTrackColor: context.colors.surfaceContainerHigh,
          inactiveThumbColor: context.colors.textTertiary,
          inactiveTrackColor: context.colors.surfaceContainer,
        ),
      ],
    );
  }

  // ── ACTION BUTTONS & SCHEDULE CONTROL ─────────────────────────────────────

  Widget _buildActionButtons(BuildContext context) {
    return Obx(() {
      final isScheduled = _c.isScheduled.value;
      final scheduledDate = _c.scheduledDate.value;
      final isUploading = _c.isUploading.value;

      return Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          // 1. Save as draft button
          OutlinedButton(
            onPressed: () {
              _c.saveDraft(
                title: _titleCtrl.text.trim(),
                description: _descCtrl.text.trim(),
                tagsRaw: '',
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: context.colors.textPrimary,
              backgroundColor: const Color(0xFF141414),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              side: BorderSide(color: context.colors.divider),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Save as draft',
              style: context.twTypography.button.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary,
              ),
            ),
          ),

          // 2. Schedule for Later (In between Save as draft & Review & Publish)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isScheduled
                    ? Colors.white.withValues(alpha: 0.6)
                    : context.colors.divider,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: isScheduled,
                  onChanged: (val) => _c.isScheduled.value = val,
                  activeColor: Colors.white,
                  activeTrackColor: context.colors.surfaceContainerHigh,
                  inactiveThumbColor: context.colors.textTertiary,
                  inactiveTrackColor: context.colors.surfaceContainer,
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: isScheduled
                      ? () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: scheduledDate,
                            firstDate: DateTime.now(),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null && context.mounted) {
                            final time = await showTimePicker(
                              context: context,
                              initialTime:
                                  TimeOfDay.fromDateTime(scheduledDate),
                            );
                            if (time != null) {
                              _c.scheduledDate.value = DateTime(
                                picked.year,
                                picked.month,
                                picked.day,
                                time.hour,
                                time.minute,
                              );
                            }
                          }
                        }
                      : null,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          color: AppColors.textPrimary, // White icon
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isScheduled
                              ? DateFormat('dd MMM, hh:mm a')
                                  .format(scheduledDate)
                              : 'Schedule for later',
                          style: context.twTypography.body.copyWith(
                            fontSize: 12,
                            fontWeight: isScheduled
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: isScheduled
                                ? context.colors.textPrimary
                                : context.colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. Review & Publish button
          ElevatedButton(
            onPressed: isUploading ? null : _handlePublish,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: isUploading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    ),
                  )
                : Text(
                    isScheduled ? 'Schedule & Publish' : 'Review & Publish',
                    style: context.twTypography.button.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
          ),
        ],
      );
    });
  }

  void _handlePublish() {
    if (_c.pickedImages.isEmpty && _c.imageUrls.isEmpty) {
      AppSnackbar.show(
        'Image Required',
        'Please upload an image for your post.',
        backgroundColor: context.colors.error,
        colorText: AppColors.textPrimary,
      );
      return;
    }

    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      _formKey.currentState?.validate();
      AppSnackbar.show(
        'Title Required',
        'Enter Title',
        backgroundColor: context.colors.error,
        colorText: AppColors.textPrimary,
      );
      return;
    } else if (title.length < 5) {
      _formKey.currentState?.validate();
      AppSnackbar.show(
        'Invalid Title',
        'Title is too short (min 5 characters)',
        backgroundColor: context.colors.error,
        colorText: AppColors.textPrimary,
      );
      return;
    }

    final desc = _descCtrl.text.trim();
    if (desc.isEmpty) {
      _formKey.currentState?.validate();
      AppSnackbar.show(
        'Description Required',
        'Enter Description',
        backgroundColor: context.colors.error,
        colorText: AppColors.textPrimary,
      );
      return;
    } else if (desc.length < 10) {
      _formKey.currentState?.validate();
      AppSnackbar.show(
        'Invalid Description',
        'Description is too short (min 10 characters)',
        backgroundColor: context.colors.error,
        colorText: AppColors.textPrimary,
      );
      return;
    }

    if (_formKey.currentState?.validate() != true) {
      return;
    }

    _c.publishPost(
      title: title,
      description: desc,
      tagsRaw: '',
    );
  }
}

// ── CUSTOM DASHED BORDER PAINTER ─────────────────────────────────────────────

class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double radius;
  final double gap;

  DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.5,
    this.radius = 12,
    this.gap = 5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Radius.circular(radius),
        ),
      );

    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      var distance = 0.0;
      while (distance < metric.length) {
        final length = gap;
        canvas.drawPath(
          metric.extractPath(distance, distance + length),
          paint,
        );
        distance += length * 2;
      }
    }
  }

  @override
  bool shouldRepaint(covariant DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.radius != radius ||
        oldDelegate.gap != gap;
  }
}
