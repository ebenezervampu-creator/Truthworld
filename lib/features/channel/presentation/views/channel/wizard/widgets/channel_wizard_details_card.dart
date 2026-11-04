import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_input_fields.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_view_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

class ChannelWizardDetailsCard extends StatelessWidget {
  final ChannelController controller;
  final RxList<String> tagList;
  final bool isDarkMode;
  final ChannelWizardViewController? wizardController;

  const ChannelWizardDetailsCard({
    required this.controller,
    required this.tagList,
    required this.isDarkMode,
    this.wizardController,
    super.key,
  });

  ChannelWizardViewController get _wc =>
      wizardController ?? Get.find<ChannelWizardViewController>();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '2. Channel Details',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          // Channel Name
          const ChannelWizardFieldLabel('Channel Name', isRequired: true),
          const SizedBox(height: 8),
          Obx(() {
            Color? borderColor;
            switch (controller.channelNameAvailability.value) {
              case AvailabilityStatus.available:
                borderColor = const Color(0xFF10B981).withValues(alpha: 0.6);
              case AvailabilityStatus.taken:
              case AvailabilityStatus.error:
                borderColor = const Color(0xFFEF4444).withValues(alpha: 0.6);
              default:
                borderColor = null;
            }

            return ChannelWizardInputField(
              controller: controller.channelName,
              hintText: 'Enter channel name',
              maxLength: 100,
              borderColor: borderColor,
              suffix: _buildAvailabilityStatusSuffix(
                controller.channelNameAvailability.value,
                onRetry: () => controller.checkChannelNameAvailability(
                  controller.channelName.text,
                  forceRefresh: true,
                ),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Channel name is required';
                }
                if (controller.profanityFilter.hasProfanity(val.trim())) {
                  return 'Please avoid offensive or profane language';
                }
                return null;
              },
            );
          }),
          Obx(() => _buildAvailabilityStatusMessage(
            status: controller.channelNameAvailability.value,
            message: controller.channelNameAvailabilityMessage.value,
            fieldLabel: 'Channel name',
            onRetry: () => controller.checkChannelNameAvailability(
              controller.channelName.text,
              forceRefresh: true,
            ),
          )),
          const SizedBox(height: 16),
          // Channel Handle
          const ChannelWizardFieldLabel('Channel Handle', isRequired: true),
          const SizedBox(height: 8),
          Obx(() {
            Color? borderColor;
            switch (controller.customUrlAvailability.value) {
              case AvailabilityStatus.available:
                borderColor = const Color(0xFF10B981).withValues(alpha: 0.6);
              case AvailabilityStatus.taken:
              case AvailabilityStatus.error:
                borderColor = const Color(0xFFEF4444).withValues(alpha: 0.6);
              default:
                borderColor = null;
            }

            return ChannelWizardInputField(
              controller: controller.customUrl,
              hintText: 'Enter handle',
              prefixText: '@',
              maxLength: 30,
              borderColor: borderColor,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9_-]')),
              ],
              suffix: _buildAvailabilityStatusSuffix(
                controller.customUrlAvailability.value,
                onRetry: () => controller.checkCustomUrlAvailability(
                  controller.customUrl.text,
                  forceRefresh: true,
                ),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Channel handle is required';
                }
                if (controller.profanityFilter.hasProfanity(val.trim())) {
                  return 'Please avoid offensive or profane language';
                }
                return null;
              },
            );
          }),
          Obx(() => _buildAvailabilityStatusMessage(
            status: controller.customUrlAvailability.value,
            message: controller.customUrlAvailabilityMessage.value,
            fieldLabel: 'Handle',
            onRetry: () => controller.checkCustomUrlAvailability(
              controller.customUrl.text,
              forceRefresh: true,
            ),
          )),
          Obx(() {
            if (controller.customUrlAvailability.value == AvailabilityStatus.taken &&
                controller.handleSuggestions.isNotEmpty) {
              return _buildHandleSuggestionsSection();
            }
            return const SizedBox.shrink();
          }),
          const SizedBox(height: 16),
          // Description
          const ChannelWizardFieldLabel('Description', isRequired: true),
          const SizedBox(height: 8),
          ChannelWizardInputField(
            controller: controller.description,
            hintText: 'Tell viewers about your channel...',
            maxLines: 4,
            maxLength: 5000,
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Description is required';
              }
              if (controller.profanityFilter.hasProfanity(val.trim())) {
                return 'Please avoid offensive or profane language';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          // Tags
          const ChannelWizardFieldLabel('Tags', isRequired: false),
          const SizedBox(height: 8),
          _buildTagInputField(),
          const SizedBox(height: 12),
          _buildTagChipsWrap(),
        ],
      ),
    );
  }

  Widget _buildTagInputField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        controller: _wc.tagInputController,
        maxLength: 30,
        buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
        inputFormatters: TruthworldTextInputFormatters.withLimit(30),
        style: const TextStyle(color: Colors.white, fontSize: 14),
        onChanged: (val) {
          if (val.contains(',')) {
            _wc.addTag(val);
          }
        },
        onSubmitted: _wc.addTag,
        decoration: const InputDecoration(
          hintText: 'Add tags (type & press Enter or comma)',
          hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13),
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildTagChipsWrap() {
    return Obx(() {
      final tags = tagList.toList();
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ...tags.map(
            (tag) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF212124),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF3F3F46)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tag,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => _wc.removeTag(tag),
                    child: const Icon(
                      Icons.close,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              if (_wc.tagInputController.text.trim().isNotEmpty) {
                _wc.addTag(_wc.tagInputController.text);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF212124),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF3F3F46)),
              ),
              child: const Icon(Icons.add, size: 14, color: Colors.white),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildAvailabilityStatusSuffix(
    AvailabilityStatus status, {
    VoidCallback? onRetry,
  }) {
    switch (status) {
      case AvailabilityStatus.checking:
        return const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFFF59E0B),
          ),
        );
      case AvailabilityStatus.available:
        return const Icon(
          Icons.check_circle_rounded,
          color: AppColors.success,
          size: 16,
        );
      case AvailabilityStatus.taken:
        return const Icon(
          Icons.cancel_rounded,
          color: AppColors.error,
          size: 16,
        );
      case AvailabilityStatus.invalid:
        return const Icon(
          Icons.info_outline_rounded,
          color: Color(0xFFF59E0B),
          size: 16,
        );
      case AvailabilityStatus.error:
        if (onRetry != null) {
          return IconButton(
            icon: const Icon(
              Icons.refresh_rounded,
              color: AppColors.error,
              size: 16,
            ),
            tooltip: 'Tap to retry',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: onRetry,
          );
        }
        return const Icon(
          Icons.error_outline_rounded,
          color: AppColors.error,
          size: 16,
        );
      case AvailabilityStatus.unknown:
        return const SizedBox.shrink();
    }
  }

  Widget _buildAvailabilityStatusMessage({
    required AvailabilityStatus status,
    required String message,
    required String fieldLabel,
    VoidCallback? onRetry,
  }) {
    if (status == AvailabilityStatus.unknown || message.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final Color statusColor;
    final IconData statusIcon;

    switch (status) {
      case AvailabilityStatus.checking:
        statusColor = const Color(0xFFF59E0B);
        statusIcon = Icons.hourglass_top_rounded;
      case AvailabilityStatus.available:
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle_outline_rounded;
      case AvailabilityStatus.taken:
        statusColor = AppColors.error;
        statusIcon = Icons.cancel_outlined;
      case AvailabilityStatus.invalid:
        statusColor = const Color(0xFFF59E0B);
        statusIcon = Icons.info_outline_rounded;
      case AvailabilityStatus.error:
        statusColor = AppColors.error;
        statusIcon = Icons.error_outline_rounded;
      case AvailabilityStatus.unknown:
        return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, color: statusColor, size: 14),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              message,
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (status == AvailabilityStatus.error && onRetry != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onRetry,
              child: const MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.refresh_rounded,
                      color: AppColors.textPrimary,
                      size: 13,
                    ),
                    SizedBox(width: 3),
                    Text(
                      'Retry',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHandleSuggestionsSection() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Suggested handles:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: controller.handleSuggestions.map((suggestion) {
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => controller.applyHandleSuggestion(suggestion),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E22),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF3F3F46)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '@',
                          style: TextStyle(
                            color: Color(0xFF60A5FA),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          suggestion,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
