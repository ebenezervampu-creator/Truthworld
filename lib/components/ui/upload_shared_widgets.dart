import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/theme/app_theme.dart';

// =============================================================================
// REUSABLE UPLOAD WIDGETS (100% AppTheme & AppFonts)
// =============================================================================

/// Channel selector dropdown used by upload flows.
class UploadChannelSelector extends StatelessWidget {
  const UploadChannelSelector({
    required this.channels,
    required this.selectedChannel,
    required this.onChanged,
    super.key,
  });
  final RxList<Channel> channels;
  final Rx<Channel?> selectedChannel;
  final void Function(Channel) onChanged;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (channels.isEmpty) {
        return _buildNoChannels(context);
      }

      final channel = selectedChannel.value ?? channels.first;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: context.radius.lg,
          border: Border.all(
            color: context.colors.divider,
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
                    style: context.twTypography.title.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Active Channel',
                    style: context.twTypography.caption.copyWith(
                      fontSize: 11,
                      color: context.colors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildNoChannels(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: context.radius.lg,
        border: Border.all(
          color: context.colors.divider,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.textPrimary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'No channels found. Create one first.',
              style: context.twTypography.bodySmall.copyWith(
                fontSize: 13,
                color: context.colors.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: () => Get.toNamed('/channelscreen'),
            child: Text(
              'Create',
              style: context.twTypography.button.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: context.colors.brand,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Visibility selector (Public / Members / Subscribers).
class UploadVisibilitySelector extends StatelessWidget {
  const UploadVisibilitySelector({
    required this.selectedVisibility,
    super.key,
    this.options = const ['Public', 'Members', 'Subscribers'],
    this.onChanged,
  });
  final RxString selectedVisibility;
  final List<String> options;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
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
                borderRadius: context.radius.md,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? context.colors.brand.withValues(alpha: 0.15)
                        : context.colors.surface,
                    borderRadius: context.radius.md,
                    border: Border.all(
                      color: isSelected
                          ? context.colors.brand
                          : context.colors.divider,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _icon(visibility),
                        size: 20,
                        color: AppColors.textPrimary,
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          visibility,
                          maxLines: 1,
                          style: context.twTypography.label.copyWith(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: isSelected
                                ? context.colors.brand
                                : context.colors.textSecondary,
                          ),
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
    required this.controller,
    required this.hint,
    super.key,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: AppColors.textPrimary),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  label!,
                  style: context.twTypography.label.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: context.colors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
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
          style: context.twTypography.body.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: context.colors.textPrimary,
            height: 1.5,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: context.twTypography.body.copyWith(
              color: context.colors.textSecondary.withValues(alpha: 0.5),
              fontSize: 14,
            ),
            filled: true,
            fillColor: context.colors.surface,
            border: OutlineInputBorder(
              borderRadius: context.radius.lg,
              borderSide: BorderSide(
                color: context.colors.divider,
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: context.radius.lg,
              borderSide: BorderSide(
                color: context.colors.divider,
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: context.radius.lg,
              borderSide: BorderSide(
                color: context.colors.brand,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: context.radius.lg,
              borderSide: BorderSide(color: context.colors.error, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: context.radius.lg,
              borderSide: BorderSide(color: context.colors.error, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }
}

/// Animated publish / schedule button.
class UploadPublishButton extends StatelessWidget {
  const UploadPublishButton({
    required this.canPublish,
    super.key,
    this.isUploading = false,
    this.isScheduled = false,
    this.uploadProgress = 0.0,
    this.onPublish,
    this.accentColor,
  });
  final bool canPublish;
  final bool isUploading;
  final bool isScheduled;
  final double uploadProgress;
  final VoidCallback? onPublish;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final effectiveAccent = accentColor ?? context.colors.brand;

    if (isUploading) {
      return _buildUploadingState(context, effectiveAccent);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: context.radius.lg,
        gradient: canPublish
            ? LinearGradient(
                colors: [
                  effectiveAccent,
                  effectiveAccent.withValues(alpha: 0.8),
                ],
              )
            : null,
        color: canPublish ? null : context.colors.surface,
        border: canPublish ? null : Border.all(color: context.colors.divider),
        boxShadow: canPublish
            ? [
                BoxShadow(
                  color: effectiveAccent.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: context.radius.lg,
          onTap: canPublish ? onPublish : null,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isScheduled
                    ? Icons.schedule_rounded
                    : Icons.cloud_upload_rounded,
                size: 22,
                color: AppColors.textPrimary,
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  isScheduled ? 'Schedule Upload' : 'Publish Now',
                  style: context.twTypography.button.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: canPublish
                        ? AppColors.textPrimary
                        : context.colors.textSecondary,
                    letterSpacing: -0.3,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUploadingState(BuildContext context, Color effectiveAccent) {
    final progressText = '${(uploadProgress * 100).toInt()}%';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: context.radius.lg,
        border: Border.all(
          color: effectiveAccent.withValues(alpha: 0.3),
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
                    colors: [
                      effectiveAccent,
                      effectiveAccent.withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: context.radius.md,
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
                      style: context.twTypography.title.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: context.colors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Processing your content',
                      style: context.twTypography.caption.copyWith(
                        fontSize: 13,
                        color: context.colors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Text(
                progressText,
                style: context.twTypography.title.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: effectiveAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: context.radius.sm,
            child: LinearProgressIndicator(
              value: uploadProgress,
              minHeight: 8,
              backgroundColor: context.colors.background,
              valueColor: AlwaysStoppedAnimation<Color>(effectiveAccent),
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
    required this.icon,
    required this.label,
    required this.value,
    required this.isComplete,
    super.key,
  });
  final IconData icon;
  final String label;
  final String value;
  final bool isComplete;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: AppColors.textPrimary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: context.twTypography.caption.copyWith(
                  fontSize: 11,
                  color: context.colors.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.twTypography.label.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isComplete
                      ? context.colors.textPrimary
                      : context.colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
