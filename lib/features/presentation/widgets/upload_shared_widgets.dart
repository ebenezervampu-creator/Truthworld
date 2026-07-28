// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/theme/app_theme.dart';

// =============================================================================
// REUSABLE UPLOAD WIDGETS
// =============================================================================

/// Channel selector dropdown used by both upload flows.
class UploadChannelSelector extends StatelessWidget {

  const UploadChannelSelector({
    required this.channels, required this.selectedChannel, required this.onChanged, super.key,
  });
  final RxList<Channel> channels;
  final Rx<Channel?> selectedChannel;
  final void Function(Channel) onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Obx(() {
      if (channels.isEmpty) {
        return _buildNoChannels(isDark);
      }

      final channel = selectedChannel.value ?? channels.first;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.bgPage : AppColors.textPrimary,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppColors.bgPage : AppColors.textSecondary,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            UserAvatar(
              radius: 14,
              photoUrl: channel.avatarUrl,
              displayName: channel.channelName,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    channel.channelName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textPrimary : AppColors.bgPage,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Active Channel',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.textPrimary38
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildNoChannels(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.bgPage
            : AppColors.textPrimary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? AppColors.bgPage
              : AppColors.textSecondary,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.textPrimary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No channels found. Create one first.',
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? AppColors.textPrimary60
                    : AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Get.toNamed('/channelscreen'),
            child: const Text(
              'Create',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Visibility selector (Public / Unlisted / Private).
class UploadVisibilitySelector extends StatelessWidget {

  const UploadVisibilitySelector({
    required this.selectedVisibility, super.key,
    this.options = const ['Public', 'Members', 'Subscribers'],
    this.onChanged,
  });
  final RxString selectedVisibility;
  final List<String> options;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Obx(() {
      return Row(
        children: options.map((visibility) {
          final isSelected = selectedVisibility.value == visibility;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: () {
                  selectedVisibility.value = visibility;
                  HapticFeedback.selectionClick();
                  onChanged?.call();
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.12)
                        : isDark
                        ? AppColors.bgPage
                        : AppColors.textPrimary,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? Colors.white
                          : isDark
                          ? AppColors.bgPage
                          : AppColors.textSecondary,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _icon(visibility),
                        size: 20,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        visibility,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: isSelected
                              ? Colors.white
                              : isDark
                              ? AppColors.textPrimary60
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      );
    });
  }

  static IconData _icon(String v) {
    switch (v.toLowerCase()) {
      case 'public':
        return Icons.public_rounded;
      case 'members':
      case 'members only':
        return Icons.card_membership_rounded;
      case 'subscribers':
      case 'subscribers only':
        return Icons.subscriptions_rounded;
      case 'unlisted':
        return Icons.link_rounded;
      case 'private':
        return Icons.lock_rounded;
      default:
        return Icons.visibility_rounded;
    }
  }
}

/// Styled text field for upload forms.
class UploadInputField extends StatelessWidget {

  const UploadInputField({
    required this.controller, required this.hint, super.key,
    this.label,
    this.icon,
    this.maxLines = 1,
    this.maxLength,
    this.validator,
    this.onChanged,
  });
  final TextEditingController controller;
  final String hint;
  final String? label;
  final IconData? icon;
  final int maxLines;
  final int? maxLength;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
              ],
              Text(
                label!,
                style: TextStyle(
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
        ],
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          validator: validator,
          onChanged: onChanged,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDark
                ? AppColors.textPrimary
                : AppColors.bgPage,
            height: 1.5,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: isDark
                  ? AppColors.textPrimary.withValues(alpha: 0.3)
                  : AppColors.textSecondary,
              fontSize: 14,
            ),
            filled: true,
            fillColor: isDark
                ? AppColors.bgPage
                : AppColors.textPrimary,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark
                    ? AppColors.bgPage
                    : AppColors.textSecondary,
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark
                    ? AppColors.bgPage
                    : AppColors.textSecondary,
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: AppColors.textSecondary,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppTokens.colors.error, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}

/// Animated publish / schedule button.
class UploadPublishButton extends StatelessWidget {

  const UploadPublishButton({
    required this.canPublish, super.key,
    this.isUploading = false,
    this.isScheduled = false,
    this.uploadProgress = 0.0,
    this.onPublish,
    this.accentColor = AppColors.brand,
  });
  final bool canPublish;
  final bool isUploading;
  final bool isScheduled;
  final double uploadProgress;
  final VoidCallback? onPublish;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isUploading) {
      return _buildUploadingState(isDark);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: canPublish
            ? LinearGradient(
                colors: isScheduled
                    ? [
                        AppColors.textPrimary,
                        AppColors.textPrimary,
                      ]
                    : [accentColor, accentColor.withValues(alpha: 0.8)],
              )
            : null,
        color: canPublish
            ? null
            : isDark
            ? AppColors.bgSurface
            : AppColors.textSecondary,
        boxShadow: canPublish
            ? [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: canPublish ? onPublish : null,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isScheduled
                    ? Icons.schedule_rounded
                    : Icons.cloud_upload_rounded,
                size: 22,
                color: canPublish
                    ? AppColors.textPrimary
                    : isDark
                    ? AppColors.textPrimary.withValues(alpha: 0.3)
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 12),
              Text(
                isScheduled ? 'Schedule Upload' : 'Publish Now',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: canPublish
                      ? AppColors.textPrimary
                      : isDark
                      ? AppColors.textPrimary.withValues(alpha: 0.3)
                      : AppColors.textSecondary,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUploadingState(bool isDark) {
    final progressText = '${(uploadProgress * 100).toInt()}%';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.bgPage
            : AppColors.textPrimary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accentColor, accentColor.withValues(alpha: 0.8)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.textPrimary,
                    ),
                    value: uploadProgress,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Uploading...',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? AppColors.textPrimary
                            : AppColors.bgPage,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Processing your content',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? AppColors.textPrimary60
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                progressText,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: uploadProgress,
              minHeight: 8,
              backgroundColor: isDark
                  ? AppColors.bgSurface
                  : AppColors.textPrimary,
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            ),
          ),
        ],
      ),
    );
  }
}

/// Preview checklist item.
class UploadPreviewItem extends StatelessWidget {

  const UploadPreviewItem({
    required this.icon, required this.label, required this.value, required this.isComplete, super.key,
  });
  final IconData icon;
  final String label;
  final String value;
  final bool isComplete;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: isComplete
              ? AppColors.bgPage
              : isDark
              ? AppColors.textPrimary38
              : AppColors.textSecondary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark
                      ? AppColors.textPrimary60
                      : AppColors.textSecondary,
                ),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isComplete
                      ? (isDark
                            ? AppColors.textPrimary
                            : AppColors.bgPage)
                      : (isDark
                            ? AppColors.textPrimary38
                            : AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}







