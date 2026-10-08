import 'dart:io' as io;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Complete community post upload flow with media upload, post details, and publishing CTA
class CreateContentCommunityFlow extends StatelessWidget {
  const CreateContentCommunityFlow({
    required this.uploadController,
    required this.communityTitleController,
    required this.communityDescriptionController,
    required this.communityTagsController,
    required this.onPublishCommunity,
    this.isDark = true,
    this.isMobile = false,
    super.key,
  });

  final UploadController uploadController;
  final TextEditingController communityTitleController;
  final TextEditingController communityDescriptionController;
  final TextEditingController communityTagsController;
  final VoidCallback onPublishCommunity;
  final bool isDark;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMediaSection(context),
        const SizedBox(height: 32),
        _buildDetailsSection(context),
        const SizedBox(height: 32),
        _buildPublishSection(context),
      ],
    );
  }

  Widget _buildMediaSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Media',
          style: context.themeTypography.title.copyWith(
            color: isDark ? AppColors.textPrimary : const Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 12),
        _buildImageUpload(context),
      ],
    );
  }

  Widget _buildImageUpload(BuildContext context) {
    return Obx(() {
      final hasImage = uploadController.pickedCommunityImage.value != null;
      final isUploading = uploadController.isUploading.value;

      return InkWell(
        onTap: isUploading
            ? null
            : () {
                uploadController.pickImage(forCommunity: true);
                HapticFeedback.mediumImpact();
              },
        child: Container(
          height: isMobile ? 180 : 200,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161B22) : AppColors.textPrimary,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: hasImage
                  ? const Color(0xFFF59E0B).withValues(alpha: 0.3)
                  : isDark
                      ? const Color(0xFF30363D)
                      : const Color(0xFFE5E7EB),
              width: 2,
            ),
          ),
          child: hasImage
              ? _buildImagePreview(context)
              : _buildImagePlaceholder(context),
        ),
      );
    });
  }

  Widget _buildImagePreview(BuildContext context) {
    return Obx(() {
      final file = uploadController.pickedCommunityImage.value!;
      final isUploaded = uploadController.communityImageUrl.value.isNotEmpty;

      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                image: DecorationImage(
                  fit: BoxFit.cover,
                  image: (kIsWeb && file.bytes != null)
                      ? MemoryImage(file.bytes!) as ImageProvider
                      : (file.path != null
                          ? FileImage(io.File(file.path!))
                          : (file.bytes != null
                              ? MemoryImage(file.bytes!)
                              : const AssetImage('assets/logo.png')
                                  as ImageProvider)),
                ),
              ),
            ),
          ),
          if (isUploaded)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 16,
                      color: AppColors.textPrimary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Ready',
                      style: context.themeTypography.label.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            bottom: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.edit_rounded,
                size: 20,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildImagePlaceholder(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFFF59E0B).withValues(alpha: 0.1)
                  : const Color(0xFFF59E0B).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.add_photo_alternate_rounded,
              size: 32,
              color: Color(0xFFF59E0B),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Add Image',
            style: context.themeTypography.title.copyWith(
              color: isDark ? AppColors.textPrimary : const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'PNG, JPG up to 10MB',
            style: context.themeTypography.bodySmall.copyWith(
              color: isDark
                  ? AppColors.textPrimary.withValues(alpha: 0.6)
                  : const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Post Details',
          style: context.themeTypography.title.copyWith(
            color: isDark ? AppColors.textPrimary : const Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 12),
        _buildEnhancedTextField(
          context: context,
          controller: communityTitleController,
          label: 'Title',
          hint: "What's happening?",
          icon: Icons.campaign_rounded,
          isDark: isDark,
          maxLength: 100,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Title is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 20),
        _buildEnhancedTextField(
          context: context,
          controller: communityDescriptionController,
          label: 'Description',
          hint: 'Share more details with your community',
          icon: Icons.description_rounded,
          isDark: isDark,
          maxLines: 4,
          maxLength: 2000,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Description is required';
            }
            return null;
          },
        ),
        const SizedBox(height: 20),
        _buildEnhancedTextField(
          context: context,
          controller: communityTagsController,
          label: 'Tags (Max 5)',
          hint: 'Add tags separated by commas (max 5 tags)',
          icon: Icons.tag_rounded,
          isDark: isDark,
          maxLength: 200,
        ),
      ],
    );
  }

  Widget _buildEnhancedTextField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    int maxLines = 1,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 8),
            Text(
              label,
              style: context.themeTypography.body.copyWith(
                color: isDark
                    ? AppColors.textPrimary.withValues(alpha: 0.9)
                    : const Color(0xFF374151),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          validator: validator,
          style: context.themeTypography.body.copyWith(
            color: isDark ? AppColors.textPrimary : const Color(0xFF111827),
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: context.themeTypography.body.copyWith(
              color: isDark
                  ? AppColors.textPrimary.withValues(alpha: 0.4)
                  : const Color(0xFF9CA3AF),
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF161B22) : AppColors.textPrimary,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark
                    ? const Color(0xFF30363D)
                    : const Color(0xFFE5E7EB),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark
                    ? const Color(0xFF30363D)
                    : const Color(0xFFE5E7EB),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFF59E0B),
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPublishSection(BuildContext context) {
    return Obx(() {
      final isUploading = uploadController.isUploading.value;

      return SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          onPressed: onPublishCommunity,
          icon: isUploading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.textPrimary,
                    ),
                  ),
                )
              : const Icon(Icons.publish_rounded, size: 20, color: Colors.white),
          label: Text(
            isUploading ? 'Publishing...' : 'Publish Post',
            style: context.themeTypography.title.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF59E0B),
            foregroundColor: AppColors.textPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 4,
          ),
        ),
      );
    });
  }
}
