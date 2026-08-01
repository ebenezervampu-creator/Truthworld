import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/category/presentation/views/category/tandc_for_channel.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/analytics/availability_indicator_widget.dart';
import 'package:truthworld/theme/app_theme.dart';

class ChannelScreen extends StatelessWidget {
  ChannelScreen({super.key});

  bool get isMobile => Get.width < 600;
  bool get isTablet => Get.width >= 600 && Get.width < 1200;
  bool get isDesktop => Get.width >= 1200;
  final controller = Get.find<ChannelController>();
  final RxInt currentStep = 0.obs; // 0-3 for 4 steps
  final RxBool draftDialogShown = false.obs; // Track if dialog was shown
  final RxBool forceValidationUpdate =
      false.obs; // Force rebuild for validation
  final RxBool _isExiting =
      false.obs; // Track if we are programmatically exiting

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Show draft dialog after frame builds (only once)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.hasDraft.value &&
          !draftDialogShown.value &&
          !AuthService.to.hasChannel.value) {
        draftDialogShown.value = true;
        _showDraftAvailableDialog(isDarkMode);
      }
    });

    return Obx(
      () {
        if (AuthService.to.hasChannel.value) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Get.offAllNamed('/studio');
          });
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        return PopScope(
          canPop:
              _isExiting.value ||
              (controller.channelName.text.trim().isEmpty &&
                  controller.description.text.trim().isEmpty &&
                  controller.selectedCategories.isEmpty),
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            _handleClose(isDarkMode);
          },
          child: Scaffold(
            backgroundColor: isDarkMode
                ? AppColors.bgPage
                : const Color(0xFFFAFAFA),
            body: Stack(
              children: [
                Column(
                  children: [
                    _buildProgressHeader(isDarkMode),
                    Expanded(
                      child: isDesktop
                          ? _buildDesktopSplitView(isDarkMode)
                          : _buildMobileView(isDarkMode),
                    ),
                    _buildNavigationDock(isDarkMode),
                  ],
                ),
                Obx(
                  () => controller.uploadProgress.value == 1.0
                      ? _buildSuccessOverlay(controller, isDarkMode)
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ========================================================================
  // PROGRESS HEADER
  // ========================================================================
  Widget _buildProgressHeader(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.bgInput : AppColors.textPrimary,
        boxShadow: [
          BoxShadow(
            color: AppColors.bgPage.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(
                  Icons.close,
                  color: isDarkMode
                      ? AppColors.textSecondary
                      : const Color(0xFF718096),
                ),
                onPressed: () => _handleClose(isDarkMode),
              ),
              Expanded(
                child: Obx(
                  () => Text(
                    _getStepTitle(currentStep.value),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode
                          ? AppColors.textPrimary
                          : const Color(0xFF2D3748),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  color: isDarkMode
                      ? AppColors.textSecondary
                      : const Color(0xFF718096),
                ),
                onSelected: (value) async {
                  if (value == 'save_draft') {
                    await controller.saveDraft(currentStep: currentStep.value);
                  } else if (value == 'delete_draft') {
                    _showDeleteDraftDialog(isDarkMode);
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'save_draft',
                    child: Row(
                      children: [
                        Obx(
                          () => controller.isSavingDraft.value
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                        ),
                        const SizedBox(width: 12),
                        const Text('Save Draft'),
                      ],
                    ),
                  ),
                  if (controller.hasDraft.value)
                    const PopupMenuItem(
                      value: 'delete_draft',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: AppColors.error),
                          SizedBox(width: 12),
                          Text(
                            'Delete Draft',
                            style: TextStyle(color: AppColors.error),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Obx(
            () => Column(
              children: [
                Row(
                  children: List.generate(3, (index) {
                    final isActive = index == currentStep.value;
                    final isCompleted = index < currentStep.value;
                    return Expanded(
                      child: Container(
                        height: 4,
                        margin: EdgeInsets.only(left: index > 0 ? 8 : 0),
                        decoration: BoxDecoration(
                          color: isCompleted || isActive
                              ? const Color(0xFF6B46C1)
                              : (isDarkMode
                                    ? const Color(0xFF2D3748)
                                    : AppColors.bgDivider),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Step ${currentStep.value + 1} of 3',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B46C1),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${((currentStep.value + 1) * 33.3).toInt()}% Complete',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDarkMode
                            ? AppColors.textSecondary
                            : const Color(0xFF718096),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getStepTitle(int step) {
    switch (step) {
      case 0:
        return 'Channel Identity';
      case 1:
        return 'Customization';
      case 2:
        return 'Finalize';
      default:
        return 'Create Channel';
    }
  }

  // ========================================================================
  // DESKTOP SPLIT VIEW
  // ========================================================================
  Widget _buildDesktopSplitView(bool isDarkMode) {
    return Row(
      children: [
        // Left: Form (60%)
        Expanded(flex: 6, child: _buildStepContent(isDarkMode)),
        // Right: Live Preview (40%)
        Expanded(
          flex: 4,
          child: Container(
            color: isDarkMode ? AppColors.bgInput : const Color(0xFFF7FAFC),
            padding: const EdgeInsets.all(32),
            child: _buildLivePreviewCard(isDarkMode),
          ),
        ),
      ],
    );
  }

  // ========================================================================
  // MOBILE VIEW
  // ========================================================================
  Widget _buildMobileView(bool isDarkMode) {
    return Obx(() {
      if (currentStep.value == 2) {
        // Show preview in final step
        return SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: _buildLivePreviewCard(isDarkMode),
              ),
              _buildStepContent(isDarkMode),
            ],
          ),
        );
      }
      return _buildStepContent(isDarkMode);
    });
  }

  // ========================================================================
  // STEP CONTENT ROUTER
  // ========================================================================
  Widget _buildStepContent(bool isDarkMode) {
    return Obx(() {
      Widget stepWidget;
      switch (currentStep.value) {
        case 0:
          stepWidget = Column(
            children: [
              _buildStepBasics(isDarkMode),
              const SizedBox(height: 32),
              _buildChannelTypeSelectionSection(isDarkMode),
              const SizedBox(height: 32),
              _buildStepBranding(isDarkMode),
              const SizedBox(height: 48),
              _buildQuickCreateSection(isDarkMode),
              const SizedBox(height: 24),
            ],
          );
        case 1:
          stepWidget = _buildStepSocial(isDarkMode);
        case 2:
          stepWidget = _buildStepReview(isDarkMode);
        default:
          stepWidget = _buildStepBasics(isDarkMode);
      }

      return SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 32),
        child: FadeTransition(
          opacity: controller.fadeAnimation,
          child: Form(key: controller.formKey, child: stepWidget),
        ),
      );
    });
  }

  // ========================================================================
  // STEP 1: BASICS
  // ========================================================================
  Widget _buildStepBasics(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(
          'Basic Information',
          "Let's start with the essentials for your channel",
          Icons.edit_rounded,
          isDarkMode,
        ),
        const SizedBox(height: 32),
        Obx(
          () => AvailabilityTextField(
            controller: controller.channelName,
            labelText: 'Channel Name',
            hintText: 'Enter a unique channel name',
            icon: Icons.video_camera_back_rounded,
            isDarkMode: isDarkMode,
            onChanged: (value) {},
            availabilityStatus: controller.channelNameAvailability.value,
            maxLength: ChannelController.maxChannelNameLength,
            isRequired: true,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Channel name is required';
              }
              if (value.trim().length <
                  ChannelController.minChannelNameLength) {
                return 'Must be at least ${ChannelController.minChannelNameLength} characters';
              }
              return null;
            },
          ),
        ),
        Obx(
          () => AvailabilityMessageWidget(
            status: controller.channelNameAvailability.value,
            isDarkMode: isDarkMode,
          ),
        ),
        const SizedBox(height: 24),
        Obx(
          () => AvailabilityTextField(
            controller: controller.customUrl,
            labelText: 'Channel Handle',
            hintText: 'your-unique-handle',
            icon: Icons.alternate_email_rounded,
            isDarkMode: isDarkMode,
            prefixText: '@',
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9_-]')),
            ],
            onChanged: (value) {},
            availabilityStatus: controller.customUrlAvailability.value,
            maxLength: ChannelController.maxCustomUrlLength,
            isRequired: true,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Channel handle is required';
              }
              if (value.length < ChannelController.minCustomUrlLength) {
                return 'Must be at least ${ChannelController.minCustomUrlLength} characters';
              }
              if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(value)) {
                return 'Invalid characters';
              }
              return null;
            },
          ),
        ),
        Obx(
          () => AvailabilityMessageWidget(
            status: controller.customUrlAvailability.value,
            isDarkMode: isDarkMode,
          ),
        ),
        Obx(() {
          if (controller.handleSuggestions.isEmpty)
            return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                'Suggested Handles:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode
                      ? AppColors.textSecondary
                      : const Color(0xFF718096),
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: controller.handleSuggestions.map((suggestion) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(
                          '@$suggestion',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B46C1),
                          ),
                        ),
                        backgroundColor: const Color(
                          0xFF6B46C1,
                        ).withValues(alpha: 0.1),
                        side: BorderSide(
                          color: const Color(0xFF6B46C1).withValues(alpha: 0.3),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onPressed: () {
                          controller.customUrl.text = suggestion;
                          controller.checkCustomUrlAvailability(suggestion);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          );
        }),
        const SizedBox(height: 24),
        _buildModernTextField(
          controller: controller.description,
          labelText: 'Description',
          hintText: 'Tell others what this channel is about',
          icon: Icons.description_outlined,
          maxLines: 4,
          isDarkMode: isDarkMode,
          isRequired: true,
          validator: (value) => (value == null || value.trim().isEmpty)
              ? 'Description is required'
              : null,
        ),
        const SizedBox(height: 24),
        _buildModernTextField(
          controller: controller.tags,
          labelText: 'Tags',
          hintText: 'gaming, tutorial (comma-separated)',
          icon: Icons.tag_rounded,
          isDarkMode: isDarkMode,
        ),
        const SizedBox(height: 24),
        _buildCategorySelection(isDarkMode),
      ],
    );
  }

  // ========================================================================
  // CHANNEL TYPE SELECTION
  // ========================================================================
  Widget _buildChannelTypeSelectionSection(bool isDarkMode) {
    return Obx(() {
      final selectedType = controller.selectedChannelType.value;
      final isStandard = selectedType == ChannelType.standard;
      final isCustom = selectedType == ChannelType.custom;

      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDarkMode ? AppColors.bgInput : AppColors.textPrimary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDarkMode
                ? const Color(0xFF334155)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tune_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Channel Type & Plan',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode
                              ? AppColors.textPrimary
                              : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Choose your monetization & infrastructure tier before creating your channel.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode
                              ? AppColors.textSecondary
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildChannelTypeCardOption(
                    type: ChannelType.standard,
                    title: 'Standard Channel',
                    subtitle:
                        '55% Net Revenue • Zero hosting fees • Up to 5 Videos limit',
                    icon: Icons.play_circle_filled,
                    primaryColor: const Color(0xFF3B82F6),
                    isSelected: isStandard,
                    isDarkMode: isDarkMode,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildChannelTypeCardOption(
                    type: ChannelType.custom,
                    title: 'Custom Channel',
                    subtitle:
                        '100% Gross - Infra • Unlimited Videos • Instant Cashout',
                    icon: Icons.rocket_launch,
                    primaryColor: const Color(0xFF8B5CF6),
                    isSelected: isCustom,
                    isDarkMode: isDarkMode,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Detailed Benefits & How It Works breakdown for selected option
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    (isStandard
                            ? const Color(0xFF3B82F6)
                            : const Color(0xFF8B5CF6))
                        .withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      (isStandard
                              ? const Color(0xFF3B82F6)
                              : const Color(0xFF8B5CF6))
                          .withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.stars_rounded, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        isStandard
                            ? 'Standard Channel Plan Highlights:'
                            : 'Custom Channel Plan Highlights:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isStandard
                              ? const Color(0xFF3B82F6)
                              : const Color(0xFF8B5CF6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (isStandard) ...[
                    _buildWizardBullet(
                      '55% Net Creator Revenue Share (\$0 Upfront Fees)',
                    ),
                    _buildWizardBullet(
                      'Up to 5 Videos Upload limit (Min 2 min per video, 10 min total duration)',
                    ),
                    _buildWizardBullet(
                      '10 Hours watch-time cash-out threshold per video',
                    ),
                    _buildWizardBullet(
                      '100% Free platform hosting and video transcoding',
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'How It Works: Standard channels are zero-maintenance. The platform hosts your content and handles streaming. Earnings start from Day 1 and become withdrawable per video after 10 hours watch time.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode
                            ? AppColors.textSecondary
                            : const Color(0xFF475569),
                        height: 1.4,
                      ),
                    ),
                  ] else ...[
                    _buildWizardBullet(
                      '100% Gross Creator Revenue Share (minus raw infrastructure usage)',
                    ),
                    _buildWizardBullet(
                      'Unlimited Video Uploads (up to 24 Hours video length)',
                    ),
                    _buildWizardBullet(
                      'Instant Cash Withdrawals without watch-time gates',
                    ),
                    _buildWizardBullet(
                      'Full control over media storage and streaming bandwidth',
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'How It Works: Custom channels provide 100% gross earnings retention. You pay only for raw cloud bandwidth & storage consumed, with instant cash out availability.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode
                            ? AppColors.textSecondary
                            : const Color(0xFF475569),
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildChannelTypeCardOption({
    required ChannelType type,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color primaryColor,
    required bool isSelected,
    required bool isDarkMode,
  }) {
    return GestureDetector(
      onTap: () => controller.selectedChannelType.value = type,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDarkMode
              ? (isSelected ? const Color(0xFF1E293B) : AppColors.bgPage)
              : (isSelected
                    ? const Color(0xFFF1F5F9)
                    : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? primaryColor
                : (isDarkMode
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0)),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? primaryColor : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? primaryColor
                          : (isDarkMode
                                ? AppColors.textTertiary
                                : Colors.black26),
                      width: 1.5,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDarkMode
                    ? AppColors.textPrimary
                    : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: isDarkMode
                    ? AppColors.textSecondary
                    : const Color(0xFF64748B),
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWizardBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========================================================================
  // STEP 2: BRANDING
  // ========================================================================
  Widget _buildStepBranding(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(
          'Branding & Images',
          'Upload your channel banner and avatar',
          Icons.palette_rounded,
          isDarkMode,
        ),
        const SizedBox(height: 32),
        Text(
          'Channel Banner (16:9)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: isDarkMode ? AppColors.textPrimary : const Color(0xFF2D3748),
          ),
        ),
        const SizedBox(height: 12),
        _buildBannerPicker(controller, isDarkMode),
        Obx(() {
          if (controller.bannerStatus.value == 'PENDING' &&
              controller.bannerUrl.value.isNotEmpty) {
            return const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF3B82F6),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Banner verification pending',
                    style: TextStyle(
                      color: Color(0xFF3B82F6),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          } else if (controller.bannerStatus.value == 'REJECTED') {
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_rounded,
                    color: Color(0xFFEF4444),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Banner rejected: ${controller.bannerStatusReason.value}',
                      style: const TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            );
          } else if (controller.bannerStatus.value == 'FLAGGED') {
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_rounded,
                    color: Color(0xFFF59E0B),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Banner review needed: ${controller.bannerStatusReason.value}',
                      style: const TextStyle(
                        color: Color(0xFFF59E0B),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        }),
        const SizedBox(height: 32),
        Text(
          'Channel Avatar (1:1)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: isDarkMode ? AppColors.textPrimary : const Color(0xFF2D3748),
          ),
        ),
        const SizedBox(height: 12),
        _buildAvatarPicker(controller, isDarkMode),
        Obx(() {
          if (controller.avatarStatus.value == 'PENDING' &&
              controller.avatarUrl.value.isNotEmpty) {
            return const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF3B82F6),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Avatar verification pending',
                    style: TextStyle(
                      color: Color(0xFF3B82F6),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          } else if (controller.avatarStatus.value == 'REJECTED') {
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_rounded,
                    color: Color(0xFFEF4444),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Avatar rejected: ${controller.avatarStatusReason.value}',
                      style: const TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            );
          } else if (controller.avatarStatus.value == 'FLAGGED') {
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_rounded,
                    color: Color(0xFFF59E0B),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Avatar review needed: ${controller.avatarStatusReason.value}',
                      style: const TextStyle(
                        color: Color(0xFFF59E0B),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        }),
      ],
    );
  }

  // ========================================================================
  // STEP 3: SOCIAL
  // ========================================================================
  Widget _buildStepSocial(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(
          'Social Links',
          'Connect your social media and contact information',
          Icons.share_rounded,
          isDarkMode,
        ),
        const SizedBox(height: 32),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isMobile ? 1 : 2,
          childAspectRatio: isMobile ? 8 : 6,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildSocialLinkField(
              controller,
              'Twitter',
              Icons.alternate_email,
              'twitter',
              isDarkMode,
            ),
            _buildSocialLinkField(
              controller,
              'Instagram',
              Icons.camera_alt_outlined,
              'instagram',
              isDarkMode,
            ),
            _buildSocialLinkField(
              controller,
              'YouTube',
              Icons.play_circle_outline,
              'youtube',
              isDarkMode,
            ),
            _buildSocialLinkField(
              controller,
              'Website',
              Icons.web_outlined,
              'website',
              isDarkMode,
            ),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _buildModernTextField(
                controller: controller.contactEmail,
                labelText: 'Contact Email',
                hintText: 'contact@example.com',
                icon: Icons.email_outlined,
                isDarkMode: isDarkMode,
                validator: (value) {
                  if (value != null &&
                      value.isNotEmpty &&
                      !GetUtils.isEmail(value)) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
            ),
            if (!isMobile) ...[
              const SizedBox(width: 16),
              Expanded(
                child: _buildModernTextField(
                  controller: controller.websiteUrl,
                  labelText: 'Website URL',
                  hintText: 'https://example.com',
                  icon: Icons.web_rounded,
                  isDarkMode: isDarkMode,
                  validator: (value) {
                    if (value != null &&
                        value.isNotEmpty &&
                        !GetUtils.isURL(value)) {
                      return 'Please enter a valid URL';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ],
        ),
        if (isMobile) ...[
          const SizedBox(height: 16),
          _buildModernTextField(
            controller: controller.websiteUrl,
            labelText: 'Website URL',
            hintText: 'https://example.com',
            icon: Icons.web_rounded,
            isDarkMode: isDarkMode,
            validator: (value) {
              if (value != null && value.isNotEmpty && !GetUtils.isURL(value)) {
                return 'Please enter a valid URL';
              }
              return null;
            },
          ),
        ],
        // Custom URL field moved to Step 0
      ],
    );
  }

  // ========================================================================
  // STEP 4: REVIEW
  // ========================================================================
  Widget _buildStepReview(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(
          'Review & Finish',
          'Review your channel settings and create',
          Icons.done_all_rounded,
          isDarkMode,
        ),
        const SizedBox(height: 32),
        _buildVisibilitySwitch(controller, isDarkMode),
        const SizedBox(height: 20),
        _buildLanguageDropdown(controller, isDarkMode),
        const SizedBox(height: 32),
        Obx(
          () => AdvancedSettingsSection(
            isDarkMode: isDarkMode,
            settings: Map<String, dynamic>.from(controller.advancedSettings),
            onSettingsChanged: (settings) {
              controller.advancedSettings.clear();
              controller.advancedSettings.addAll(settings);
            },
          ),
        ),
        const SizedBox(height: 32),
        Obx(
          () => TermsAndConditionsWidget(
            isDarkMode: isDarkMode,
            value: controller.isAgreed.value,
            onChanged: (agreed) {
              controller.isAgreed.value = agreed;
            },
          ),
        ),
      ],
    );
  }

  // ========================================================================
  // STEP HEADER
  // ========================================================================
  Widget _buildStepHeader(
    String title,
    String subtitle,
    IconData icon,
    bool isDarkMode,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode
              ? [
                  const Color(0xFF6B46C1).withValues(alpha: 0.15),
                  const Color(0xFF9333EA).withValues(alpha: 0.08),
                ]
              : [
                  const Color(0xFF6B46C1).withValues(alpha: 0.08),
                  const Color(0xFF9333EA).withValues(alpha: 0.04),
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF6B46C1).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF6B46C1).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF6B46C1), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode
                        ? AppColors.textPrimary
                        : const Color(0xFF2D3748),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode
                        ? AppColors.textSecondary
                        : const Color(0xFF718096),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ========================================================================
  // LIVE PREVIEW CARD
  // ========================================================================
  Widget _buildLivePreviewCard(bool isDarkMode) {
    return Obx(() {
      final hasName = controller.channelName.text.isNotEmpty;
      final hasDescription = controller.description.text.isNotEmpty;
      final hasBanner = controller.bannerImageData.value != null;
      final hasAvatar = controller.avatarImageData.value != null;

      return Container(
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1E1E1E) : AppColors.textPrimary,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFF6B46C1).withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.bgPage.withValues(alpha: 0.1),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Preview Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF6B46C1).withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.visibility_rounded,
                    color: Color(0xFF6B46C1),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Live Preview',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF6B46C1),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6B46C1).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF6B46C1),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'LIVE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6B46C1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Banner
            Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDarkMode
                    ? const Color(0xFF2D3748)
                    : AppColors.bgDivider,
              ),
              child: hasBanner && controller.bannerImageData.value != null
                  ? Image.memory(
                      controller.bannerImageData.value!.bytes,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                    )
                  : Center(
                      child: Icon(
                        Icons.image_outlined,
                        size: 48,
                        color: isDarkMode
                            ? AppColors.textDisabled
                            : Colors.black26,
                      ),
                    ),
            ),
            // Avatar & Info
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDarkMode
                              ? const Color(0xFF2D3748)
                              : AppColors.bgDivider,
                          border: Border.all(
                            color: isDarkMode
                                ? const Color(0xFF1E1E1E)
                                : AppColors.textPrimary,
                            width: 4,
                          ),
                        ),
                        child:
                            hasAvatar &&
                                controller.avatarImageData.value != null
                            ? ClipOval(
                                child: Image.memory(
                                  controller.avatarImageData.value!.bytes,
                                  fit: BoxFit.cover,
                                  filterQuality: FilterQuality.high,
                                ),
                              )
                            : Icon(
                                Icons.person_outline,
                                size: 40,
                                color: isDarkMode
                                    ? AppColors.textDisabled
                                    : Colors.black26,
                              ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hasName
                                  ? controller.channelName.text
                                  : 'Your Channel Name',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: hasName
                                    ? (isDarkMode
                                          ? AppColors.textPrimary
                                          : const Color(0xFF2D3748))
                                    : (isDarkMode
                                          ? AppColors.textDisabled
                                          : Colors.black26),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (controller.customUrl.text.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                '@${controller.customUrl.text}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF6B46C1),
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  controller.isPublic.value
                                      ? Icons.public
                                      : Icons.lock,
                                  size: 14,
                                  color: isDarkMode
                                      ? AppColors.textTertiary
                                      : const Color(0xFF718096),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  controller.isPublic.value
                                      ? 'Public'
                                      : 'Private',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDarkMode
                                        ? AppColors.textTertiary
                                        : const Color(0xFF718096),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (hasDescription) ...[
                    const SizedBox(height: 16),
                    Text(
                      controller.description.text,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode
                            ? AppColors.textSecondary
                            : const Color(0xFF718096),
                        height: 1.5,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (controller.selectedCategories.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: controller.selectedCategories.take(3).map((
                        category,
                      ) {
                        return Chip(
                          label: Text(
                            category,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          backgroundColor: const Color(
                            0xFF6B46C1,
                          ).withValues(alpha: 0.1),
                          labelStyle: const TextStyle(color: Color(0xFF6B46C1)),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  // ========================================================================
  // NAVIGATION DOCK
  // ========================================================================
  Widget _buildNavigationDock(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.bgInput : AppColors.textPrimary,
        boxShadow: [
          BoxShadow(
            color: AppColors.bgPage.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Obx(() {
        final isFirstStep = currentStep.value == 0;
        final isLastStep = currentStep.value == 2;
        // Recalculate on every Obx rebuild to react to field changes
        final canProceed = _canProceedFromCurrentStep();
        final isCreating = controller.isSubmitting.value;

        return Row(
          children: [
            if (!isFirstStep) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    currentStep.value--;
                    HapticFeedback.lightImpact();
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(
                      color: isDarkMode
                          ? AppColors.textDisabled
                          : AppColors.bgDivider,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.arrow_back,
                        color: isDarkMode
                            ? AppColors.textPrimary
                            : const Color(0xFF2D3748),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Back',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: isDarkMode
                              ? AppColors.textPrimary
                              : const Color(0xFF2D3748),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
            ],
            Expanded(
              flex: isFirstStep ? 1 : 2,
              child: ElevatedButton(
                onPressed: canProceed && !isCreating
                    ? () async {
                        if (isLastStep) {
                          _handleCreateChannel();
                        } else {
                          // Auto-save draft before moving to next step
                          await controller.saveDraft(
                            currentStep: currentStep.value,
                          );
                          currentStep.value++;
                          HapticFeedback.lightImpact();
                        }
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFF6B46C1),
                  disabledBackgroundColor: isDarkMode
                      ? const Color(0xFF2D3748)
                      : AppColors.bgDivider,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: canProceed ? 2 : 0,
                ),
                child: isCreating
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.textPrimary,
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Creating...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isLastStep ? 'Create Channel' : 'Next',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: canProceed
                                  ? AppColors.textPrimary
                                  : (isDarkMode
                                        ? AppColors.textDisabled
                                        : Colors.black26),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            isLastStep
                                ? Icons.rocket_launch
                                : Icons.arrow_forward,
                            color: canProceed
                                ? AppColors.textPrimary
                                : (isDarkMode
                                      ? AppColors.textDisabled
                                      : Colors.black26),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        );
      }),
    );
  }

  // ========================================================================
  // CATEGORY SELECTION WIDGET
  // ========================================================================
  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'gaming':
        return Icons.sports_esports_rounded;
      case 'music':
        return Icons.music_note_rounded;
      case 'entertainment':
        return Icons.movie_rounded;
      case 'education':
        return Icons.school_rounded;
      case 'technology':
        return Icons.computer_rounded;
      case 'sports':
        return Icons.sports_soccer_rounded;
      case 'news':
        return Icons.newspaper_rounded;
      case 'lifestyle':
        return Icons.style_rounded;
      case 'travel':
        return Icons.flight_takeoff_rounded;
      case 'food':
        return Icons.restaurant_rounded;
      case 'fashion':
        return Icons.checkroom_rounded;
      case 'health':
        return Icons.health_and_safety_rounded;
      case 'business':
        return Icons.business_center_rounded;
      case 'comedy':
        return Icons.sentiment_very_satisfied_rounded;
      case 'science':
        return Icons.science_rounded;
      case 'art':
        return Icons.palette_rounded;
      case 'documentary':
        return Icons.videocam_rounded;
      case 'animation':
        return Icons.animation_rounded;
      case 'automotive':
        return Icons.directions_car_rounded;
      case 'pets & animals':
        return Icons.pets_rounded;
      case 'diy & how-to':
        return Icons.build_rounded;
      case 'fitness':
        return Icons.fitness_center_rounded;
      case 'beauty':
        return Icons.face_rounded;
      case 'finance':
        return Icons.attach_money_rounded;
      case 'history':
        return Icons.menu_book_rounded;
      case 'nature':
        return Icons.forest_rounded;
      case 'spirituality':
        return Icons.self_improvement_rounded;
      case 'kids & family':
        return Icons.child_care_rounded;
      default:
        return Icons.category_rounded;
    }
  }

  Widget _buildCategorySelection(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.category_rounded,
                  size: 18,
                  color: isDarkMode
                      ? AppColors.textSecondary
                      : const Color(0xFF718096),
                ),
                const SizedBox(width: 8),
                Text(
                  'Channel Categories',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode
                        ? AppColors.textPrimary
                        : const Color(0xFF2D3748),
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  '*',
                  style: TextStyle(
                    color: Color(0xFFE53E3E),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Obx(() {
              final isAll = controller.isAllCategoriesSelected;
              return InkWell(
                onTap: () {
                  if (isAll) {
                    controller.deselectAllCategories();
                  } else {
                    controller.selectAllCategories();
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isAll
                        ? const Color(0xFF6B46C1).withValues(alpha: 0.15)
                        : (isDarkMode
                              ? Colors.white.withValues(alpha: 0.05)
                              : const Color(0xFFEDF2F7)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isAll
                          ? const Color(0xFF6B46C1)
                          : (isDarkMode
                                ? Colors.white.withValues(alpha: 0.1)
                                : const Color(0xFFCBD5E0)),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isAll
                            ? Icons.done_all_rounded
                            : Icons.select_all_rounded,
                        size: 14,
                        color: isAll
                            ? const Color(0xFF6B46C1)
                            : (isDarkMode
                                  ? AppColors.textSecondary
                                  : const Color(0xFF4A5568)),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isAll ? 'Selected All' : 'Select All Categories',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isAll
                              ? const Color(0xFF6B46C1)
                              : (isDarkMode
                                    ? AppColors.textSecondary
                                    : const Color(0xFF4A5568)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Select one, multiple, or all categories that describe your channel.',
          style: TextStyle(
            fontSize: 12,
            color: isDarkMode
                ? AppColors.textSecondary
                : const Color(0xFF718096),
          ),
        ),
        const SizedBox(height: 12),
        Obx(() {
          final count = controller.selectedCategories.length;
          final total = controller.categories.length;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: count > 0
                      ? const Color(0xFF6B46C1).withValues(alpha: 0.1)
                      : const Color(0xFFE53E3E).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  count == total
                      ? 'All Categories Selected ($total/$total)'
                      : (count > 0
                            ? '$count of $total Categories Selected'
                            : 'No category selected - please pick at least one'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: count > 0
                        ? const Color(0xFF6B46C1)
                        : const Color(0xFFE53E3E),
                  ),
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: controller.categories.map((category) {
                  final isSelected = controller.isCategorySelected(category);
                  return FilterChip(
                    avatar: Icon(
                      _getCategoryIcon(category),
                      size: 16,
                      color: isSelected
                          ? Colors.white
                          : (isDarkMode
                                ? AppColors.textSecondary
                                : const Color(0xFF4A5568)),
                    ),
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (_) => controller.toggleCategory(category),
                    selectedColor: const Color(0xFF6B46C1),
                    backgroundColor: isDarkMode
                        ? Colors.white.withValues(alpha: 0.05)
                        : const Color(0xFFF7FAFC),
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : (isDarkMode
                                ? AppColors.textPrimary
                                : const Color(0xFF2D3748)),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected
                            ? const Color(0xFF6B46C1)
                            : (isDarkMode
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : const Color(0xFFE2E8F0)),
                      ),
                    ),
                    elevation: isSelected ? 2 : 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        }),
      ],
    );
  }

  // ========================================================================
  // VALIDATION LOGIC
  // ========================================================================
  bool _canProceedFromCurrentStep() {
    // Trigger rebuild when form changes
    controller.formChangeTrigger.value;
    forceValidationUpdate.value;

    switch (currentStep.value) {
      case 0: // Identity
        return controller.channelName.text.trim().length >= 3 &&
            controller.customUrl.text.trim().length >=
                ChannelController.minCustomUrlLength &&
            controller.description.text.trim().isNotEmpty &&
            controller.selectedCategories.isNotEmpty;

      case 1: // Customization
        return true; // Optional

      case 2: // Finalize
        return true; // Always allow

      default:
        return false;
    }
  }

  void _handleCreateChannel() {
    if (!controller.canCreateMoreChannels) {
      Get.snackbar(
        'Limit Reached',
        'You can only create one channel per Google account.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: const Color(0xFFE53E3E),
        colorText: AppColors.textPrimary,
        borderRadius: 12,
        margin: const EdgeInsets.all(16),
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: AppColors.textPrimary,
        ),
      );
      return;
    }

    if (controller.formKey.currentState?.validate() ?? false) {
      controller.createChannel();
    }
  }

  Widget _buildQuickCreateSection(bool isDarkMode) {
    return Obx(() {
      // Access formChangeTrigger to ensure reactivity and prevent Obx error
      controller.formChangeTrigger.value;
      forceValidationUpdate.value;

      final canProceed =
          controller.channelName.text.trim().length >= 3 &&
          controller.customUrl.text.trim().length >=
              ChannelController.minCustomUrlLength &&
          controller.description.text.trim().isNotEmpty;

      if (!canProceed) return const SizedBox.shrink();

      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1A202C) : const Color(0xFFF7FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF6B46C1).withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          children: [
            Text(
              'Ready to go?',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDarkMode
                    ? AppColors.textSecondary
                    : const Color(0xFF4A5568),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _handleCreateChannel,
                icon: const Icon(Icons.flash_on_rounded, size: 20),
                label: const Text('Quick Create (Skip optional steps)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: const Color(0xFF6B46C1),
                  elevation: 0,
                  side: const BorderSide(color: Color(0xFF6B46C1), width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  // ========================================================================
  // REUSABLE COMPONENTS
  // ========================================================================

  Widget _buildBannerPicker(ChannelController controller, bool isDarkMode) {
    return Obx(() {
      final imageData = controller.bannerImageData.value;
      final isUploading = controller.isUploadingBanner.value;
      final progress = controller.bannerUploadProgress.value;

      return InkWell(
        onTap: () => controller.pickImage(true),
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 200,
          decoration: BoxDecoration(
            color: isDarkMode
                ? const Color(0xFF1E1E1E)
                : const Color(0xFFF7FAFC),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: imageData != null
                  ? const Color(0xFF6B46C1)
                  : (isDarkMode
                        ? const Color(0xFF2D3748)
                        : AppColors.bgDivider),
              width: 2,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: imageData != null
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(
                        imageData.bytes,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.high,
                      ),
                      if (isUploading)
                        ColoredBox(
                          color: AppColors.bgPage54,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(
                                  value: progress,
                                  color: AppColors.textPrimary,
                                  strokeWidth: 3,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '${(progress * 100).toInt()}%',
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // Moderation Status Indicator
                      Positioned(
                        top: 12,
                        right: 12,
                        child: _buildModerationStatusChip(
                          controller.bannerStatus.value,
                          controller.bannerStatusReason.value,
                        ),
                      ),
                    ],
                  )
                : _buildPickerPlaceholder(
                    icon: Icons.add_photo_alternate_outlined,
                    title: 'Select Banner',
                    subtitle: '16:9 • Max: 5MB',
                    isDarkMode: isDarkMode,
                  ),
          ),
        ),
      );
    });
  }

  Widget _buildAvatarPicker(ChannelController controller, bool isDarkMode) {
    return Center(
      child: Obx(() {
        final imageData = controller.avatarImageData.value;
        final isUploading = controller.isUploadingAvatar.value;
        final progress = controller.avatarUploadProgress.value;

        return InkWell(
          onTap: () => controller.pickImage(false),
          borderRadius: BorderRadius.circular(70),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 140,
            width: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDarkMode
                  ? const Color(0xFF1E1E1E)
                  : const Color(0xFFF7FAFC),
              border: Border.all(
                color: imageData != null
                    ? const Color(0xFF6B46C1)
                    : (isDarkMode
                          ? const Color(0xFF2D3748)
                          : AppColors.bgDivider),
                width: 3,
              ),
            ),
            child: ClipOval(
              child: imageData != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.memory(
                          imageData.bytes,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.high,
                        ),
                        if (isUploading)
                          ColoredBox(
                            color: AppColors.bgPage54,
                            child: Center(
                              child: CircularProgressIndicator(
                                value: progress,
                                color: AppColors.textPrimary,
                                strokeWidth: 3,
                              ),
                            ),
                          ),
                        // Moderation Status Indicator
                        Positioned(
                          top: 8,
                          right: 8,
                          child: _buildModerationStatusChip(
                            controller.avatarStatus.value,
                            controller.avatarStatusReason.value,
                            small: true,
                          ),
                        ),
                      ],
                    )
                  : _buildPickerPlaceholder(
                      icon: Icons.person_add_alt_1_outlined,
                      title: 'Avatar',
                      subtitle: '1:1 • 2MB',
                      iconSize: 36,
                      isDarkMode: isDarkMode,
                    ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildModerationStatusChip(
    String status,
    String reason, {
    bool small = false,
  }) {
    Color color;
    IconData icon;
    String label;

    switch (status) {
      case 'APPROVED':
        color = const Color(0xFF10B981);
        icon = Icons.check_circle_rounded;
        label = 'Approved';
      case 'REJECTED':
        color = const Color(0xFFEF4444);
        icon = Icons.error_rounded;
        label = 'Rejected';
      case 'FLAGGED':
        color = const Color(0xFFF59E0B);
        icon = Icons.warning_rounded;
        label = 'Review Needed';
      case 'PENDING':
        color = const Color(0xFF3B82F6);
        icon = Icons.sync_rounded;
        label = 'Verifying...';
      default:
        return const SizedBox.shrink();
    }

    final chip = Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 6 : 8,
        vertical: small ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == 'PENDING')
            SizedBox(
              width: small ? 10 : 12,
              height: small ? 10 : 12,
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.textPrimary,
                ),
              ),
            )
          else
            Icon(icon, size: small ? 10 : 12, color: AppColors.textPrimary),
          if (!small) ...[
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );

    if (status == 'REJECTED' && !small) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          chip,
          const SizedBox(height: 6),
          Container(
            constraints: const BoxConstraints(maxWidth: 160),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.bgPage.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.textPrimary.withValues(alpha: 0.1),
                width: 0.5,
              ),
            ),
            child: Text(
              reason,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    return chip;
  }

  Widget _buildPickerPlaceholder({
    required IconData icon,
    required String title,
    required bool isDarkMode,
    String? subtitle,
    double iconSize = 48,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF6B46C1).withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: iconSize, color: const Color(0xFF6B46C1)),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF6B46C1),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: isDarkMode
                  ? AppColors.textSecondary
                  : const Color(0xFF718096),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSocialLinkField(
    ChannelController controller,
    String label,
    IconData icon,
    String key,
    bool isDarkMode,
  ) {
    return TextFormField(
      initialValue: controller.socialLinks[key],
      style: TextStyle(
        fontSize: 14,
        color: isDarkMode ? AppColors.textPrimary : const Color(0xFF2D3748),
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: 'Enter $label URL',
        prefixIcon: Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF6B46C1).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: const Color(0xFF6B46C1), size: 16),
        ),
        labelStyle: TextStyle(
          color: isDarkMode ? AppColors.textSecondary : const Color(0xFF718096),
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        hintStyle: TextStyle(
          color: isDarkMode ? AppColors.textTertiary : const Color(0xFFA0AEC0),
          fontSize: 14,
        ),
        filled: true,
        fillColor: isDarkMode ? const Color(0xFF1E1E1E) : AppColors.textPrimary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF6B46C1), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      onChanged: (value) => controller.socialLinks[key] = value,
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    required IconData icon,
    required bool isDarkMode,
    int maxLines = 1,
    bool isRequired = false,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black26
                : AppColors.bgPage.withValues(alpha: 0.08),
            blurRadius: 12,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        style: TextStyle(
          fontSize: 16,
          color: isDarkMode ? AppColors.textPrimary : const Color(0xFF2D3748),
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: isRequired ? '$labelText *' : labelText,
          hintText: hintText,
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF6B46C1).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF6B46C1), size: 20),
          ),
          labelStyle: TextStyle(
            color: isDarkMode
                ? AppColors.textSecondary
                : const Color(0xFF718096),
            fontWeight: FontWeight.w500,
          ),
          hintStyle: TextStyle(
            color: isDarkMode
                ? AppColors.textTertiary
                : const Color(0xFFA0AEC0),
          ),
          filled: true,
          fillColor: isDarkMode
              ? const Color(0xFF1E1E1E)
              : AppColors.textPrimary,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF6B46C1), width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.error, width: 2),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.error, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 20,
          ),
        ),
        validator: validator,
        textInputAction: maxLines > 1
            ? TextInputAction.newline
            : TextInputAction.next,
      ),
    );
  }

  Widget _buildVisibilitySwitch(ChannelController controller, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E1E1E) : AppColors.textPrimary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black26
                : AppColors.bgPage.withValues(alpha: 0.08),
            blurRadius: 12,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Obx(
            () => Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF6B46C1).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                controller.isPublic.value
                    ? Icons.public_rounded
                    : Icons.lock_rounded,
                color: const Color(0xFF6B46C1),
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Obx(
              () => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Channel Visibility',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDarkMode
                          ? AppColors.textPrimary
                          : const Color(0xFF2D3748),
                    ),
                  ),
                  Text(
                    controller.isPublic.value
                        ? 'Public - Anyone can find and view'
                        : 'Private - Only you can view',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode
                          ? AppColors.textSecondary
                          : const Color(0xFF718096),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Obx(
            () => Switch(
              value: controller.isPublic.value,
              onChanged: (value) {
                controller.isPublic.value = value;
                HapticFeedback.lightImpact();
              },
              activeThumbColor: const Color(0xFF6B46C1),
              activeTrackColor: const Color(0xFF6B46C1).withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageDropdown(ChannelController controller, bool isDarkMode) {
    return Obx(
      () => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isDarkMode
                  ? Colors.black26
                  : AppColors.bgPage.withValues(alpha: 0.08),
              blurRadius: 12,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: DropdownButtonFormField<String>(
          initialValue: controller.language.value,
          decoration: InputDecoration(
            labelText: 'Language',
            prefixIcon: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF6B46C1).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.language_rounded,
                color: Color(0xFF6B46C1),
                size: 20,
              ),
            ),
            labelStyle: TextStyle(
              color: isDarkMode
                  ? AppColors.textSecondary
                  : const Color(0xFF718096),
              fontWeight: FontWeight.w500,
            ),
            filled: true,
            fillColor: isDarkMode
                ? const Color(0xFF1E1E1E)
                : AppColors.textPrimary,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF6B46C1), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 20,
            ),
          ),
          dropdownColor: isDarkMode
              ? const Color(0xFF1E1E1E)
              : AppColors.textPrimary,
          style: TextStyle(
            color: isDarkMode ? AppColors.textPrimary : const Color(0xFF2D3748),
            fontSize: 16,
          ),
          items: controller.languages
              .map(
                (String lang) => DropdownMenuItem<String>(
                  value: lang,
                  child: Text(lang.toUpperCase()),
                ),
              )
              .toList(),
          onChanged: (String? newValue) {
            controller.language.value = newValue ?? 'en';
            HapticFeedback.lightImpact();
          },
        ),
      ),
    );
  }

  Widget _buildSuccessOverlay(ChannelController controller, bool isDarkMode) {
    return AnimatedBuilder(
      animation: controller.successScaleAnimation,
      builder: (context, child) {
        return ColoredBox(
          color: AppColors.bgPage.withValues(alpha: 0.8),
          child: Center(
            child: Transform.scale(
              scale: controller.successScaleAnimation.value,
              child: Container(
                margin: const EdgeInsets.all(32),
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? const Color(0xFF1E1E1E)
                      : AppColors.textPrimary,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.bgPage.withValues(alpha: 0.3),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.hoverAccent.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        size: 64,
                        color: AppTheme.hoverAccent,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Channel Created!',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode
                            ? AppColors.textPrimary
                            : const Color(0xFF2D3748),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Your channel is ready.\nYou can now start uploading content!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: isDarkMode
                            ? AppColors.textSecondary
                            : const Color(0xFF718096),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ========================================================================
  // HELPER METHODS
  // ========================================================================

  void _handleClose(bool isDarkMode) {
    if (controller.channelName.text.trim().isNotEmpty ||
        controller.description.text.trim().isNotEmpty ||
        controller.selectedCategories.isNotEmpty) {
      Get.dialog(
        AlertDialog(
          backgroundColor: isDarkMode
              ? const Color(0xFF1E1E1E)
              : AppColors.textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Save your progress?',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDarkMode
                  ? AppColors.textPrimary
                  : const Color(0xFF2D3748),
            ),
          ),
          content: Text(
            'You have unsaved changes. Would you like to save as draft before leaving?',
            style: TextStyle(
              color: isDarkMode
                  ? AppColors.textSecondary
                  : const Color(0xFF718096),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Get.back(); // Close dialog
                _isExiting.value = true;
                Get.back(); // Close wizard
              },
              child: const Text(
                'Discard',
                style: TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                Get.back(); // Close dialog
                await controller.saveDraft(currentStep: currentStep.value);
                _isExiting.value = true;
                Get.back(); // Close wizard
              },
              child: const Text(
                'Save Draft',
                style: TextStyle(
                  color: Color(0xFF6B46C1),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      _isExiting.value = true;
      Future.delayed(Duration.zero, Get.back);
    }
  }

  void _showDeleteDraftDialog(bool isDarkMode) {
    Get.dialog(
      AlertDialog(
        backgroundColor: isDarkMode
            ? const Color(0xFF1E1E1E)
            : AppColors.textPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Draft?',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? AppColors.textPrimary : const Color(0xFF2D3748),
          ),
        ),
        content: Text(
          'This will permanently delete your draft and any uploaded images. This action cannot be undone.',
          style: TextStyle(
            color: isDarkMode
                ? AppColors.textSecondary
                : const Color(0xFF718096),
          ),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDarkMode
                    ? AppColors.textSecondary
                    : const Color(0xFF718096),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Get.back(); // Close dialog
              await controller.deleteDraft();
              controller.formChangeTrigger.value++;
            },
            child: const Text(
              'Delete',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDraftTime() {
    final lastSave = controller.lastDraftSaveTime.value;
    if (lastSave == null) return '';

    final now = DateTime.now();
    final diff = now.difference(lastSave);

    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  void _showDraftAvailableDialog(bool isDarkMode) {
    Get.dialog(
      PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: isDarkMode
              ? const Color(0xFF1E1E1E)
              : AppColors.textPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.restore,
                  color: AppColors.brand,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Continue Draft?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: isDarkMode
                        ? AppColors.textPrimary
                        : const Color(0xFF2D3748),
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You have an unfinished channel creation draft.',
                style: TextStyle(
                  fontSize: 15,
                  color: isDarkMode
                      ? AppColors.textSecondary
                      : const Color(0xFF718096),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? const Color(0xFF2D3748)
                      : const Color(0xFFF7FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.brand.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (controller.channelName.text.isNotEmpty) ...[
                      Row(
                        children: [
                          const Icon(
                            Icons.label,
                            size: 16,
                            color: AppColors.brand,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              controller.channelName.text,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: isDarkMode
                                    ? AppColors.textPrimary
                                    : const Color(0xFF2D3748),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 14,
                          color: AppColors.brand,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Last saved: ${_formatDraftTime()}',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDarkMode
                                ? AppColors.textSecondary
                                : const Color(0xFF718096),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Get.back(); // Close dialog
                await controller.deleteDraft();
                controller.formChangeTrigger.value++;
              },
              child: const Text(
                'Start Fresh',
                style: TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: Get.back,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B46C1),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Continue Draft',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
      barrierDismissible: false,
    );
  }
}
