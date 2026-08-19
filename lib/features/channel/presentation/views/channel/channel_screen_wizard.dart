import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Redesigned Channel Creation Screen
/// Supports Desktop (multi-column layout) and Mobile (responsive single column layout)
/// matching exact visual architecture from the reference design.
class ChannelScreen extends StatefulWidget {
  const ChannelScreen({super.key});

  @override
  State<ChannelScreen> createState() => _ChannelScreenState();
}

class _ChannelScreenState extends State<ChannelScreen> {
  ChannelController get controller {
    if (Get.isRegistered<ChannelController>()) {
      return Get.find<ChannelController>();
    }
    return Get.put(ChannelController());
  }

  // Local Controllers for Tag and Social Inputs
  final TextEditingController _tagInputController = TextEditingController();
  final Map<String, TextEditingController> _socialControllers = {};

  TextEditingController _getSocialController(String key) {
    if (!_socialControllers.containsKey(key)) {
      String initialText = controller.socialLinks[key] ?? '';
      if (key == 'website' && initialText.isEmpty) {
        initialText = controller.websiteUrl.text;
      } else if (key == 'email' && initialText.isEmpty) {
        initialText = controller.contactEmail.text;
      }
      final ctrl = TextEditingController(text: initialText);
      ctrl.addListener(() {
        final val = ctrl.text.trim();
        if (val.isEmpty) {
          controller.socialLinks.remove(key);
        } else {
          controller.socialLinks[key] = val;
        }
        if (key == 'website') controller.websiteUrl.text = val;
        if (key == 'email') controller.contactEmail.text = val;
      });
      _socialControllers[key] = ctrl;
    }
    return _socialControllers[key]!;
  }

  // Reactive Tag Chip List
  RxList<String>? _tagListObj;
  RxList<String> get _tagList => _tagListObj ??= <String>[].obs;

  RxString? _tagSearchQueryObj;
  RxString get _tagSearchQuery => _tagSearchQueryObj ??= ''.obs;
  String get _tagQueryText {
    try {
      return _tagSearchQuery.value;
    } catch (_) {
      return '';
    }
  }

  // Plan Highlights Toggle
  final RxBool _isHighlightsExpanded = true.obs;
  RxBool _showAllFeatures = false.obs;

  // Banner Multi-Device Preview State (YouTube Standard)
  final RxInt _bannerPreviewMode = 0.obs; // 0: TV/Full 16:9, 1: Desktop, 2: Mobile
  final RxBool _showBannerSafeArea = true.obs;

  bool get _isShowingAllFeatures {
    try {
      return _showAllFeatures.value;
    } catch (_) {
      return false;
    }
  }

  void _toggleShowAllFeatures() {
    try {
      _showAllFeatures.value = !_showAllFeatures.value;
    } catch (_) {
      _showAllFeatures = (!(_showAllFeatures.value)).obs;
    }
  }

  // Mobile Accordion Expansion States
  final RxBool _isChannelTypeExpanded = true.obs;
  final RxBool _isCategoryExpanded = true.obs;
  final RxBool _isLinksExpanded = true.obs;
  final RxBool _isVisibilityExpanded = true.obs;
  final RxBool _isCountryExpanded = true.obs;
  final RxBool _isLanguageExpanded = true.obs;
  final RxBool _isPlanExpanded = true.obs;
  final RxBool _isAgreementsExpanded = true.obs;

  final RxBool _draftDialogShown = false.obs;
  final RxBool _isExiting = false.obs;

  @override
  void initState() {
    super.initState();
    _initializeTagsAndSocials();
  }

  void _initializeTagsAndSocials() {
    if (controller.tags.text.trim().isNotEmpty) {
      final parsed = controller.tags.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      _tagList.assignAll(parsed);
    } else {
      _tagList.clear();
      controller.tags.text = '';
    }
  }

  @override
  void dispose() {
    _tagInputController.dispose();
    for (final ctrl in _socialControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _addTag(String rawTag) {
    final clean = rawTag.trim().replaceAll(',', '');
    if (clean.isEmpty) return;
    if (_tagList.length >= 5) {
      Get.snackbar(
        'Tag Limit',
        'You can add up to 5 tags.',
        backgroundColor: const Color(0xFF27272A),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
      return;
    }
    if (!_tagList.contains(clean)) {
      _tagList.add(clean);
      controller.tags.text = _tagList.join(', ');
    }
    _tagInputController.clear();
    _tagSearchQuery.value = '';
  }

  void _removeTag(String tag) {
    _tagList.remove(tag);
    controller.tags.text = _tagList.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Show draft dialog post-frame if draft exists
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.hasDraft.value &&
          !_draftDialogShown.value &&
          !AuthService.to.hasChannel.value) {
        _draftDialogShown.value = true;
        _showDraftAvailableDialog(isDarkMode);
      }
    });

    return PopScope(
      canPop: _isExiting.value ||
          (controller.channelName.text.trim().isEmpty &&
              controller.description.text.trim().isEmpty &&
              controller.selectedCategories.isEmpty),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleClose(isDarkMode);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F0F),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 900;
              return Obx(() {
                if (!controller.isSubmitting.value &&
                    (AuthService.to.hasChannel.value ||
                     AuthService.to.userChannel != null ||
                     controller.channels.isNotEmpty)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    Get.offAllNamed('/studio', arguments: {
                      if (AuthService.to.userChannel != null)
                        'channel': AuthService.to.userChannel,
                      if (controller.channels.isNotEmpty)
                        'channel': controller.channels.first,
                    });
                  });
                  return const Scaffold(
                    backgroundColor: AppColors.bgPage,
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                return Stack(
                  children: [
                    Column(
                      children: [
                        _buildTopHeader(context, isDesktop, isDarkMode),
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: EdgeInsets.symmetric(
                              horizontal: isDesktop ? 32 : 16,
                              vertical: isDesktop ? 24 : 16,
                            ),
                            child: Form(
                              key: controller.formKey,
                              child: isDesktop
                                  ? _buildDesktopLayout(isDarkMode)
                                  : _buildMobileLayout(isDarkMode),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (controller.isSubmitting.value)
                      Container(
                        color: Colors.black54,
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      ),
                  ],
                );
              });
            },
          ),
        ),
      ),
    );
  }

  // ========================================================================
  // TOP HEADER BAR & OVERFLOW MENU
  // ========================================================================
  Widget _buildTopHeader(BuildContext context, bool isDesktop, bool isDarkMode) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 32 : 16,
        vertical: 16,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F0F),
        border: Border(
          bottom: BorderSide(color: Color(0xFF27272A), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => _handleClose(false),
            tooltip: 'Back',
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  isDesktop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
              children: [
                const Text(
                  'Create Channel',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Build your brand. Share your story with the world.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            color: const Color(0xFF18181B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFF27272A)),
            ),
            onSelected: (value) async {
              if (value == 'save_draft') {
                await controller.saveDraft();
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
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(
                              Icons.bookmark_outline,
                              color: Colors.white,
                              size: 20,
                            ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Save draft',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete_draft',
                child: Row(
                  children: [
                    const Icon(
                      Icons.delete_outline,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Delete draft',
                      style: TextStyle(
                        color: AppColors.error,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ========================================================================
  // DESKTOP LAYOUT (2-COLUMN GRID)
  // ========================================================================
  Widget _buildDesktopLayout(bool isDarkMode) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column: Branding & Details
            Expanded(
              flex: 6,
              child: Column(
                children: [
                  _buildBrandingCard(isDarkMode),
                  const SizedBox(height: 24),
                  _buildDetailsCard(isDarkMode),
                ],
              ),
            ),
            const SizedBox(width: 24),
            // Right Column: Channel Type, Category & Links
            Expanded(
              flex: 6,
              child: Column(
                children: [
                  _buildChannelTypeCard(isDarkMode),
                  const SizedBox(height: 24),
                  _buildCategoryCard(isDarkMode),
                  const SizedBox(height: 24),
                  _buildLinksCard(isDarkMode),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Bottom Row: Visibility, Country, Language & Channel Plan
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildVisibilityCard(isDarkMode)),
            const SizedBox(width: 16),
            Expanded(child: _buildCountryCard(isDarkMode)),
            const SizedBox(width: 16),
            Expanded(child: _buildLanguageCard(isDarkMode)),
            const SizedBox(width: 16),
            Expanded(child: _buildPlanCard(isDarkMode)),
          ],
        ),
        const SizedBox(height: 24),
        // Agreements & Submit Button
        _buildAgreementsAndSubmitCard(isDarkMode),
      ],
    );
  }

  // ========================================================================
  // MOBILE LAYOUT (RESPONSIVE SINGLE COLUMN ACCORDION CARDS)
  // ========================================================================
  Widget _buildMobileLayout(bool isDarkMode) {
    return Column(
      children: [
        _buildBrandingCard(isDarkMode),
        const SizedBox(height: 16),
        _buildDetailsCard(isDarkMode),
        const SizedBox(height: 16),
        _buildAccordionCard(
          title: '3. Channel Type',
          isExpanded: _isChannelTypeExpanded,
          isDarkMode: isDarkMode,
          child: _buildChannelTypeContent(isDarkMode),
        ),
        const SizedBox(height: 16),
        _buildAccordionCard(
          title: '4. Category',
          isExpanded: _isCategoryExpanded,
          isDarkMode: isDarkMode,
          child: _buildCategoryContent(isDarkMode),
        ),
        const SizedBox(height: 16),
        Obx(
          () => _buildAccordionCard(
            title: controller.country.value.isNotEmpty
                ? '5. Links for ${controller.country.value} (Optional)'
                : '5. Links (Optional)',
            isExpanded: _isLinksExpanded,
            isDarkMode: isDarkMode,
            child: _buildLinksContent(isDarkMode),
          ),
        ),
        const SizedBox(height: 16),
        _buildAccordionCard(
          title: '6. Channel Visibility',
          isExpanded: _isVisibilityExpanded,
          isDarkMode: isDarkMode,
          child: _buildVisibilityContent(isDarkMode),
        ),
        const SizedBox(height: 16),
        _buildAccordionCard(
          title: '7. Country',
          isExpanded: _isCountryExpanded,
          isDarkMode: isDarkMode,
          child: _buildCountryContent(isDarkMode),
        ),
        const SizedBox(height: 16),
        _buildAccordionCard(
          title: '8. Language',
          isExpanded: _isLanguageExpanded,
          isDarkMode: isDarkMode,
          child: _buildLanguageContent(isDarkMode),
        ),
        const SizedBox(height: 16),
        _buildAccordionCard(
          title: '9. Channel Plan',
          isExpanded: _isPlanExpanded,
          isDarkMode: isDarkMode,
          child: _buildPlanContent(isDarkMode),
        ),
        const SizedBox(height: 16),
        _buildAccordionCard(
          title: '10. Agreements',
          isExpanded: _isAgreementsExpanded,
          isDarkMode: isDarkMode,
          child: _buildAgreementsAndSubmitContent(isDarkMode),
        ),
      ],
    );
  }

  Widget _buildAccordionCard({
    required String title,
    required RxBool isExpanded,
    required bool isDarkMode,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => isExpanded.value = !isExpanded.value,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Obx(
                    () => Icon(
                      isExpanded.value
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Obx(
            () => isExpanded.value
                ? Padding(
                    padding: const EdgeInsets.only(
                      left: 20,
                      right: 20,
                      bottom: 20,
                    ),
                    child: child,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  // ========================================================================
  // CARD 1: CHANNEL BRANDING
  // ========================================================================
  Widget _buildBrandingCard(bool isDarkMode) {
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
            '1. Channel Branding',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          // Channel Banner
          _buildFieldLabel('Channel Banner', isRequired: true),
          const SizedBox(height: 8),
          _buildBannerDropzone(isDarkMode),
          const SizedBox(height: 20),
          // Channel Avatar
          _buildFieldLabel('Channel Avatar', isRequired: true),
          const SizedBox(height: 8),
          _buildAvatarDropzone(isDarkMode),
        ],
      ),
    );
  }

  Widget _buildModerationStatusBadge(String status, String reason) {
    if (status.isEmpty) return const SizedBox.shrink();

    final isPending = status == 'PENDING';
    final isApproved = status == 'APPROVED';
    final isRejected = status == 'REJECTED';
    final isFlagged = status == 'FLAGGED';

    final Color badgeBg;
    final Color borderColor;
    final Color textColor;
    final IconData iconData;
    final String label;

    if (isPending) {
      badgeBg = const Color(0xFF1E293B);
      borderColor = const Color(0xFF38BDF8).withValues(alpha: 0.4);
      textColor = const Color(0xFF38BDF8);
      iconData = Icons.hourglass_top_rounded;
      label = 'Verifying...';
    } else if (isApproved) {
      badgeBg = const Color(0xFF064E3B);
      borderColor = const Color(0xFF10B981).withValues(alpha: 0.4);
      textColor = const Color(0xFF34D399);
      iconData = Icons.verified_rounded;
      label = 'Verified';
    } else if (isRejected) {
      badgeBg = const Color(0xFF450A0A);
      borderColor = const Color(0xFFEF4444).withValues(alpha: 0.4);
      textColor = const Color(0xFFF87171);
      iconData = Icons.error_outline_rounded;
      label = reason.isNotEmpty ? 'Rejected: $reason' : 'Image Rejected';
    } else if (isFlagged) {
      badgeBg = const Color(0xFF451A03);
      borderColor = const Color(0xFFF59E0B).withValues(alpha: 0.4);
      textColor = const Color(0xFFFBBF24);
      iconData = Icons.warning_amber_rounded;
      label = reason.isNotEmpty ? 'Flagged: $reason' : 'Flagged for Review';
    } else {
      badgeBg = const Color(0xFF064E3B);
      borderColor = const Color(0xFF10B981).withValues(alpha: 0.4);
      textColor = const Color(0xFF34D399);
      iconData = Icons.check_circle_outline_rounded;
      label = 'Verified';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPending)
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          else
            Icon(iconData, size: 13, color: Colors.white),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerDropzone(bool isDarkMode) {
    return Obx(() {
      final bannerData = controller.bannerImageData.value;
      final bannerUrl = controller.bannerUrl.value;
      final hasBanner = bannerData != null || bannerUrl.isNotEmpty;
      final currentMode = _bannerPreviewMode.value;
      final showGuides = _showBannerSafeArea.value;
      final isUploading = controller.isUploadingBanner.value;
      final status = controller.bannerStatus.value;
      final reason = controller.bannerStatusReason.value;

      if (!hasBanner) {
        return GestureDetector(
          onTap: isUploading ? null : () => controller.pickImage(true),
          child: CustomPaint(
            painter: DashedBorderPainter(),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF121212),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isUploading)
                    Column(
                      children: [
                        const SizedBox(
                          width: 36,
                          height: 36,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Uploading Banner (${(controller.bannerUploadProgress.value * 100).toStringAsFixed(0)}%)...',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    )
                  else ...[
                    const Icon(Icons.cloud_upload_outlined, color: Colors.white, size: 40),
                    const SizedBox(height: 12),
                    const Text(
                      'Upload Channel Banner',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Recommended: 2560 x 1440 px (16:9 canvas, Max 6MB)',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'YouTube Standard: Safe area ensures your logo & text look great across TV, Desktop, and Mobile.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      }

      // Banner Selected - Render YouTube-standard multi-device preview card
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF121212),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: status == 'REJECTED'
                ? const Color(0xFFEF4444)
                : const Color(0xFF27272A),
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Controls Bar: Device Selector + Guide Toggle
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Device Preview Chips
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F1F23),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF2E2E32)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildBannerPreviewChip(
                        icon: Icons.tv,
                        label: 'All Devices (16:9 Full)',
                        isSelected: currentMode == 0,
                        onTap: () => _bannerPreviewMode.value = 0,
                      ),
                      _buildBannerPreviewChip(
                        icon: Icons.desktop_windows,
                        label: 'Desktop',
                        isSelected: currentMode == 1,
                        onTap: () => _bannerPreviewMode.value = 1,
                      ),
                      _buildBannerPreviewChip(
                        icon: Icons.smartphone,
                        label: 'Mobile Safe Area',
                        isSelected: currentMode == 2,
                        onTap: () => _bannerPreviewMode.value = 2,
                      ),
                    ],
                  ),
                ),
                // Status Badge & Safe Area Toggle Button
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (status.isNotEmpty) ...[
                      _buildModerationStatusBadge(status, reason),
                      const SizedBox(width: 8),
                    ],
                    InkWell(
                      onTap: () => _showBannerSafeArea.value = !_showBannerSafeArea.value,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: showGuides ? const Color(0xFF2E2E32) : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: showGuides ? Colors.white70 : const Color(0xFF3F3F46),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.grid_on, size: 14, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(
                              'Safe Area Guides',
                              style: TextStyle(
                                fontSize: 11,
                                color: showGuides ? Colors.white : AppColors.textSecondary,
                                fontWeight: showGuides ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Banner Preview Display Area
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                color: Colors.black,
                child: _buildBannerPreviewContent(
                  bannerData: bannerData,
                  bannerUrl: bannerUrl,
                  mode: currentMode,
                  showGuides: showGuides,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Actions & Info Footer
            Row(
              children: [
                Expanded(
                  child: Text(
                    status == 'REJECTED'
                        ? 'Image Rejected: $reason. Please change this banner.'
                        : (currentMode == 0
                            ? 'Full 16:9 canvas (2560 x 1440). Displays on TV and full-bleed backgrounds.'
                            : (currentMode == 1
                                ? 'Desktop viewable strip (2560 x 423). Centered horizontally across computer screens.'
                                : 'Mobile safe area (1546 x 423). Viewable on all mobile smartphones without cropping.')),
                    style: TextStyle(
                      fontSize: 11,
                      color: status == 'REJECTED'
                          ? const Color(0xFFEF4444)
                          : AppColors.textTertiary,
                      fontWeight: status == 'REJECTED'
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => controller.pickImage(true),
                  icon: const Icon(Icons.edit, size: 14, color: Colors.white),
                  label: const Text('Change', style: TextStyle(color: Colors.white, fontSize: 12)),
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFF27272A),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Remove Banner',
                  onPressed: () {
                    controller.bannerImageData.value = null;
                    controller.bannerUrl.value = '';
                    controller.bannerFileId.value = '';
                    controller.bannerStatus.value = '';
                    controller.bannerStatusReason.value = '';
                  },
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.white),
                  splashRadius: 18,
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _buildBannerPreviewChip({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3F3F46) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: Colors.white),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerPreviewContent({
    required ImageData? bannerData,
    required String bannerUrl,
    required int mode,
    required bool showGuides,
  }) {
    Widget imageWidget = bannerData != null
        ? Image.memory(bannerData.bytes, fit: BoxFit.cover)
        : CachedNetworkImage(
            imageUrl: bannerUrl,
            fit: BoxFit.cover,
            errorWidget: (context, url, error) => const ColoredBox(
              color: Color(0xFF212121),
              child: Center(
                child: Icon(Icons.broken_image_rounded, color: Colors.white, size: 28),
              ),
            ),
          );

    if (mode == 1) {
      // Desktop View (2560 x 423, ratio 6.05:1)
      return AspectRatio(
        aspectRatio: 2560 / 423,
        child: Stack(
          fit: StackFit.expand,
          children: [
            imageWidget,
            if (showGuides)
              const Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _YouTubeDesktopSafeAreaPainter(),
                  ),
                ),
              ),
          ],
        ),
      );
    } else if (mode == 2) {
      // Mobile View (1546 x 423, ratio 3.65:1)
      return Center(
        child: AspectRatio(
          aspectRatio: 1546 / 423,
          child: imageWidget,
        ),
      );
    }

    // Default Mode 0: Full 16:9 View (2560 x 1440)
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          imageWidget,
          if (showGuides)
            const Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _YouTubeBannerSafeAreaPainter(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatarDropzone(bool isDarkMode) {
    return Obx(() {
      final avatarData = controller.avatarImageData.value;
      final avatarUrl = controller.avatarUrl.value;
      final hasAvatar = avatarData != null || avatarUrl.isNotEmpty;
      final isUploading = controller.isUploadingAvatar.value;
      final status = controller.avatarStatus.value;
      final reason = controller.avatarStatusReason.value;

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: isUploading ? null : () => controller.pickImage(false),
            child: CustomPaint(
              painter: DashedBorderPainter(
                color: status == 'REJECTED'
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF3F3F3F),
                borderRadius: 50,
              ),
              child: Container(
                width: 90,
                height: 90,
                decoration: const BoxDecoration(
                  color: Color(0xFF121212),
                  shape: BoxShape.circle,
                ),
                child: isUploading
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${(controller.avatarUploadProgress.value * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(fontSize: 10, color: Colors.white),
                            ),
                          ],
                        ),
                      )
                    : (hasAvatar
                        ? ClipOval(
                            child: avatarData != null
                                ? Image.memory(avatarData.bytes, fit: BoxFit.cover)
                                : Image.network(avatarUrl, fit: BoxFit.cover),
                          )
                        : const Center(
                            child: Icon(
                              Icons.image_outlined,
                              color: Colors.white,
                              size: 32,
                            ),
                          )),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: isUploading ? null : () => controller.pickImage(false),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasAvatar
                            ? 'Channel Avatar'
                            : 'Drag & drop avatar here\nor click to upload',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Recommended 800 x 800 px (Max 2MB)',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (status.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildModerationStatusBadge(status, reason),
                ],
                if (hasAvatar) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => controller.pickImage(false),
                        icon: const Icon(Icons.edit, size: 13, color: Colors.white),
                        label: const Text('Change', style: TextStyle(color: Colors.white, fontSize: 11)),
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFF27272A),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Remove Avatar',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          controller.avatarImageData.value = null;
                          controller.avatarUrl.value = '';
                          controller.avatarFileId.value = '';
                          controller.avatarStatus.value = '';
                          controller.avatarStatusReason.value = '';
                        },
                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    });
  }

  // ========================================================================
  // CARD 2: CHANNEL DETAILS
  // ========================================================================
  Widget _buildDetailsCard(bool isDarkMode) {
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
          _buildFieldLabel('Channel Name', isRequired: true),
          const SizedBox(height: 8),
          _buildInputField(
            controller: controller.channelName,
            hintText: 'Enter channel name',
            maxLength: 100,
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Channel name is required';
              }
              if (controller.profanityFilter.hasProfanity(val.trim())) {
                return 'Please avoid offensive or profane language';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          // Channel Handle
          _buildFieldLabel('Channel Handle', isRequired: true),
          const SizedBox(height: 8),
          _buildInputField(
            controller: controller.customUrl,
            hintText: 'Enter handle',
            prefixText: '@',
            maxLength: 50,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9_-]')),
            ],
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Channel handle is required';
              }
              if (controller.profanityFilter.hasProfanity(val.trim())) {
                return 'Please avoid offensive or profane language';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          // Description
          _buildFieldLabel('Description', isRequired: true),
          const SizedBox(height: 8),
          _buildInputField(
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
          _buildFieldLabel('Tags', isRequired: false),
          const SizedBox(height: 8),
          _buildTagInputField(),
          _buildTagAutocompleteSuggestions(),
          const SizedBox(height: 12),
          _buildTagChipsWrap(),
          _buildSuggestedTagsSection(),
        ],
      ),
    );
  }

  RxMap<String, int>? _realTagUsageMapObj;
  RxMap<String, int> get _realTagUsageMap => _realTagUsageMapObj ??= <String, int>{}.obs;

  RxList<Map<String, dynamic>>? _liveFirestoreSuggestionsObj;
  RxList<Map<String, dynamic>> get _liveFirestoreSuggestions => _liveFirestoreSuggestionsObj ??= <Map<String, dynamic>>[].obs;

  RxBool? _isSearchingTagsObj;
  RxBool get _isSearchingTags => _isSearchingTagsObj ??= false.obs;

  Future<void> _fetchRealMatchingTagsFromFirestore(String query) async {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) {
      _liveFirestoreSuggestions.clear();
      _isSearchingTags.value = false;
      return;
    }

    _isSearchingTags.value = true;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(FirestoreCollections.hashtags)
          .where('tagLowercase', isGreaterThanOrEqualTo: cleanQuery)
          .where('tagLowercase', isLessThanOrEqualTo: '$cleanQuery\uf8ff')
          .limit(8)
          .get();

      final results = snapshot.docs.map((doc) {
        final data = doc.data();
        final name = data['name'] as String? ?? doc.id;
        final count = (data['usageCount'] as num?)?.toInt() ?? 1;
        _realTagUsageMap[name] = count;
        return {
          'name': name,
          'usageCount': count,
        };
      }).toList();

      _liveFirestoreSuggestions.assignAll(results);
    } on FirebaseException catch (e) {
      _liveFirestoreSuggestions.clear();
      if (e.code != 'permission-denied') {
        debugPrint('Firestore tag search error: ${e.message}');
      }
    } catch (_) {
      _liveFirestoreSuggestions.clear();
    } finally {
      _isSearchingTags.value = false;
    }
  }

  String _getTagUsageCountFormatted(String tag) {
    final count = _realTagUsageMap[tag] ?? 1;
    if (count >= 1000000) {
      final val = (count / 1000000).toStringAsFixed(1);
      return '${val.endsWith('.0') ? val.substring(0, val.length - 2) : val}M';
    }
    if (count >= 1000) {
      final val = (count / 1000).toStringAsFixed(1);
      return '${val.endsWith('.0') ? val.substring(0, val.length - 2) : val}k';
    }
    return '$count';
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
        controller: _tagInputController,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        onChanged: (val) {
          _tagSearchQuery.value = val.trim();
          _fetchRealMatchingTagsFromFirestore(val);
          if (val.contains(',')) {
            _addTag(val);
          }
        },
        onSubmitted: (val) {
          _addTag(val);
        },
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

  Widget _buildTagAutocompleteSuggestions() {
    return Obx(() {
      final query = _tagQueryText.toLowerCase().trim();
      if (query.isEmpty) return const SizedBox.shrink();

      final currentTags = _tagList.toList();

      // ONLY use real Firestore suggestions from the database
      final List<Map<String, dynamic>> realMatches = [];
      for (final item in _liveFirestoreSuggestions) {
        final name = item['name'] as String;
        if (!currentTags.contains(name)) {
          realMatches.add(item);
        }
      }

      if (_isSearchingTags.value && realMatches.isEmpty) {
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF18181B),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF27272A)),
            ),
            child: Row(
              children: const [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                SizedBox(width: 8),
                Text('Searching tags...', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        );
      }

      if (realMatches.isEmpty) {
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: GestureDetector(
            onTap: () {
              _addTag(_tagInputController.text);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF18181B),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF27272A)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.add_circle_outline, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Add "$_tagQueryText"',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      final displayList = realMatches.take(6).toList();

      return Container(
        margin: const EdgeInsets.only(top: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF18181B),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF27272A)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                'Matching Tags (${displayList.length})',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textTertiary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const Divider(color: Color(0xFF27272A), height: 1),
            ...displayList.map((item) {
              final tag = item['name'] as String;
              final usage = _getTagUsageCountFormatted(tag);
              return InkWell(
                onTap: () => _addTag(tag),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.tag, size: 15, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            tag,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF27272A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF3F3F46)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.trending_up, size: 11, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              '$usage used',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      );
    });
  }

  Widget _buildTagChipsWrap() {
    return Obx(() {
      final tags = _tagList.toList();
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ...tags.map((tag) => Container(
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
                      onTap: () => _removeTag(tag),
                      child: const Icon(
                        Icons.close,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              )),
          GestureDetector(
            onTap: () {
              if (_tagInputController.text.trim().isNotEmpty) {
                _addTag(_tagInputController.text);
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

  static const Map<String, List<String>> _categoryRecommendedTags = {
    'Business': ['Startup India', 'Startup', 'Entrepreneur', 'Investing', 'Stocks', 'Leadership', 'Marketing'],
    'History': ['World History', 'Ancient Civilizations', 'Documentaries', 'Biographies', 'Archaeology'],
    'News': ['Politics', 'Breaking News', 'World News', 'Journalism', 'Current Events', 'Analysis'],
    'Education': ['Tutorials', 'Lectures', 'Courses', 'Self Improvement', 'Study Tips'],
    'Science': ['Astronomy', 'Physics', 'Biology', 'Space', 'Chemistry', 'Research'],
    'Technology': ['AI', 'Coding', 'Gadgets', 'Software', 'Tech Reviews', 'Cybersecurity'],
    'Finance': ['Cryptocurrency', 'Wealth', 'Real Estate', 'Personal Finance', 'Trading', 'Stocks'],
    'Health': ['Wellness', 'Mental Health', 'Nutrition', 'Medicine', 'Healthcare'],
    'Documentary': ['Deep Dives', 'Investigation', 'True Stories', 'Real Life', 'Expose'],
    'Fitness': ['Workout', 'Gym', 'Bodybuilding', 'Yoga', 'Crossfit', 'Exercise'],
    'Music': ['Covers', 'Live Performance', 'Beats', 'EDM', 'HipHop', 'Acoustic', 'Songwriting'],
    'Entertainment': ['Vlogs', 'Reactions', 'Reviews', 'Pop Culture', 'Shorts', 'Podcast'],
    'Sports': ['Football', 'Basketball', 'Cricket', 'Highlights', 'Training', 'Match Analysis'],
    'Lifestyle': ['Vlogging', 'Daily Routine', 'Minimalism', 'Self Care', 'Home Decor'],
    'Travel': ['Backpacking', 'Guides', 'Travel Vlogs', 'Culture', 'Exploration', 'Hotels'],
    'Food': ['Cooking', 'Recipes', 'Street Food', 'Restaurant Reviews', 'Baking', 'Chef'],
    'Fashion': ['Style', 'Outfits', 'Beauty', 'Makeup', 'Trends', 'Hauls'],
    'Comedy': ['Standup', 'Skits', 'Parody', 'Memes', 'Satire', 'Humor'],
    'Art': ['Drawing', 'Digital Art', 'Painting', 'Design', 'Illustration', 'Crafting'],
    'Animation': ['3D Animation', 'Motion Graphics', 'Cartoons', 'Anime', 'VFX'],
    'Automotive': ['Cars', 'Motorcycles', 'EV', 'Reviews', 'Racing', 'Supercars'],
    'Pets & Animals': ['Dogs', 'Cats', 'Wildlife', 'Rescue', 'Pet Care'],
    'DIY & How-to': ['Life Hacks', 'Home Improvement', 'Woodworking', 'Fix It', 'Crafting'],
    'Nature': ['Environment', 'Wildlife', 'Wilderness', 'Conservation', 'Hiking'],
    'Spirituality': ['Meditation', 'Mindfulness', 'Philosophy', 'Wisdom', 'Faith'],
    'People & Blogs': ['Vlogs', 'Daily Life', 'Personal Stories', 'Q&A', 'Life Updates', 'Behind the Scenes'],
    'Kids & Family': ['Parenting', 'Toys', 'Kids Songs', 'Family Vlogs', 'Storytime', 'Education for Kids'],
    'Movies': ['Film Reviews', 'Trailers', 'Film Analysis', 'Behind the Scenes', 'Ratings', 'Cinema'],
    'TV Shows': ['Recaps', 'Reviews', 'Binge Guides', 'Series Analysis', 'Casting News', 'Season Reviews'],
    'Vlogs': ['Daily Vlogs', 'Travel Vlogs', 'Food Vlogs', 'Challenge Vlogs', 'Life Updates', 'Day in My Life'],
    'Other': ['General', 'Miscellaneous', 'Mixed Content', 'Community'],
  };

  Widget _buildSuggestedTagsSection() {
    return Obx(() {
      final selectedCats = controller.selectedCategories;
      // Do not show recommended tags if user has not selected any channel category
      if (selectedCats.isEmpty) {
        return const SizedBox.shrink();
      }

      // Gather recommended tags based on selected categories
      final Set<String> recommendedSet = {};
      for (final cat in selectedCats) {
        final tags = _categoryRecommendedTags[cat];
        if (tags != null) {
          recommendedSet.addAll(tags);
        }
      }

      // Fallback if selected categories do not have explicit tags
      if (recommendedSet.isEmpty) {
        recommendedSet.addAll(['Podcast', 'Vlog', 'Tutorials', 'Shorts', 'Guides']);
      }

      final current = _tagList.toList();
      final available = recommendedSet.where((s) => !current.contains(s)).toList();
      if (available.isEmpty) return const SizedBox.shrink();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Text(
            'Recommended Tags for ${selectedCats.join(", ")} (tap to add):',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: available.map((sTag) {
              final usage = _getTagUsageCountFormatted(sTag);
              return GestureDetector(
                onTap: () => _addTag(sTag),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF18181B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF27272A)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add, size: 12, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        '$sTag ',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        usage,
                        style: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      );
    });
  }

  // ========================================================================
  // CARD 3: CHANNEL TYPE
  // ========================================================================
  Widget _buildChannelTypeCard(bool isDarkMode) {
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
            '3. Channel Type',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          _buildChannelTypeContent(isDarkMode),
        ],
      ),
    );
  }

  Widget _buildChannelTypeContent(bool isDarkMode) {
    final types = [
      'Individual',
      'Business / Small Business',
      'Organization / Company',
      'Educational',
      'News / Media',
      'Creator',
      'Community',
      'Other',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select the entity type for your channel.',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        Obx(
          () => GestureDetector(
            onTap: () => _showChannelTypePicker(context, types),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF121212),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF27272A)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.category_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      controller.channelTypeCategory.value.isNotEmpty
                          ? controller.channelTypeCategory.value
                          : 'Select Channel Type',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showChannelTypePicker(BuildContext context, List<String> types) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Material(
          color: const Color(0xFF18181B),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF3F3F46),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.category_outlined,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Select Channel Type',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(color: Color(0xFF27272A), height: 1),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: types.length,
                separatorBuilder: (ctx, i) =>
                    const Divider(color: Color(0xFF27272A), height: 1),
                itemBuilder: (ctx, i) {
                  final typeName = types[i];
                  final isSelected =
                      controller.channelTypeCategory.value == typeName;
                  return ListTile(
                    onTap: () {
                      controller.channelTypeCategory.value = typeName;
                      Navigator.pop(context);
                    },
                    leading: const Icon(
                      Icons.work_outline,
                      color: Colors.white,
                      size: 20,
                    ),
                    title: Text(
                      typeName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        color: Colors.white,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 20,
                          )
                        : null,
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  // ========================================================================
  // CARD 4: CATEGORY
  // ========================================================================
  Widget _buildCategoryCard(bool isDarkMode) {
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
            '4. Category',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          _buildCategoryContent(isDarkMode),
        ],
      ),
    );
  }

  Widget _buildCategoryContent(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select one or more categories that best describe your channel.',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => _showCategoryPickerBottomSheet(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF121212),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF27272A)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.category_outlined,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Obx(
                    () {
                      if (controller.selectedCategories.isEmpty) {
                        return const Text(
                          'Select categories',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textTertiary,
                          ),
                        );
                      }
                      return Text(
                        controller.selectedCategories.join(', '),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),
        Obx(() {
          if (controller.selectedCategories.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: controller.selectedCategories.map((cat) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF27272A),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF3F3F46)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        cat,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => controller.toggleCategory(cat),
                        child: const Icon(
                          Icons.close,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          );
        }),
      ],
    );
  }

  void _showCategoryPickerBottomSheet(BuildContext context) {
    Get.bottomSheet(
      Material(
        color: const Color(0xFF18181B),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Container(
          height: 480,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Obx(() => Text(
                      'Select Categories (${controller.selectedCategories.length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    )),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Get.back(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'You can pick multiple categories for your channel.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: controller.categories.length,
                itemBuilder: (context, index) {
                  final cat = controller.categories[index];
                  return Obx(() {
                    final isSelected = controller.selectedCategories.contains(cat);
                    return ListTile(
                      title: Text(
                        cat,
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: Checkbox(
                        value: isSelected,
                        onChanged: (val) {
                          controller.toggleCategory(cat);
                        },
                        activeColor: Colors.white,
                        checkColor: Colors.black,
                        side: const BorderSide(color: Color(0xFF52525B)),
                      ),
                      onTap: () {
                        controller.toggleCategory(cat);
                      },
                    );
                  });
                },
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () => Get.back(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    isScrollControlled: true,
  );
}

  // ========================================================================
  // CARD 4: LINKS (OPTIONAL)
  // ========================================================================
  Widget _buildLinksCard(bool isDarkMode) {
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
          Obx(
            () => Text(
              controller.country.value.isNotEmpty
                  ? '5. Links for ${controller.country.value} (Optional)'
                  : '5. Links (Optional)',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildLinksContent(isDarkMode),
        ],
      ),
    );
  }

  final RxBool _showMoreLinks = false.obs;

  static const Map<String, List<String>> _bannedSocialPlatformsByCountry = {
    'India': ['tiktok'],
    'China': ['youtube', 'facebook', 'twitter', 'instagram', 'tiktok'],
    'Iran': ['facebook', 'twitter', 'youtube'],
    'North Korea': ['youtube', 'facebook', 'twitter', 'instagram', 'tiktok'],
  };

  static final Map<String, List<Map<String, dynamic>>> _countrySpecificSocialPlatforms = {
    'China': [
      {'key': 'wechat', 'label': 'WeChat (微信)', 'icon': Icons.chat_bubble_outline, 'placeholder': 'https://weixin.qq.com/... or WeChat ID'},
      {'key': 'weibo', 'label': 'Weibo (微博)', 'icon': Icons.share_outlined, 'placeholder': 'https://weibo.com/yourhandle'},
      {'key': 'bilibili', 'label': 'Bilibili (哔哩哔哩)', 'icon': Icons.tv_outlined, 'placeholder': 'https://space.bilibili.com/yourid'},
      {'key': 'douyin', 'label': 'Douyin (抖音)', 'icon': Icons.music_note_outlined, 'placeholder': 'https://v.douyin.com/yourhandle'},
      {'key': 'xiaohongshu', 'label': 'RED (小红书)', 'icon': Icons.book_outlined, 'placeholder': 'https://xiaohongshu.com/user/...'},
      {'key': 'zhihu', 'label': 'Zhihu (知乎)', 'icon': Icons.help_outline, 'placeholder': 'https://zhihu.com/people/yourhandle'},
      {'key': 'qq', 'label': 'QQ (腾讯QQ)', 'icon': Icons.forum_outlined, 'placeholder': 'QQ Number or https://qq.com'},
    ],
    'Russia': [
      {'key': 'vk', 'label': 'VKontakte (VK)', 'icon': Icons.groups_outlined, 'placeholder': 'https://vk.com/yourhandle'},
      {'key': 'rutube', 'label': 'Rutube', 'icon': Icons.video_library_outlined, 'placeholder': 'https://rutube.ru/channel/...'},
      {'key': 'yandex', 'label': 'Yandex Zen', 'icon': Icons.article_outlined, 'placeholder': 'https://dzen.ru/yourchannel'},
    ],
    'Japan': [
      {'key': 'line', 'label': 'LINE', 'icon': Icons.chat_outlined, 'placeholder': 'https://line.me/ti/p/...'},
      {'key': 'note', 'label': 'Note', 'icon': Icons.edit_note_outlined, 'placeholder': 'https://note.com/yourhandle'},
    ],
    'South Korea': [
      {'key': 'naver', 'label': 'Naver Blog', 'icon': Icons.language, 'placeholder': 'https://blog.naver.com/yourid'},
      {'key': 'kakao', 'label': 'KakaoTalk', 'icon': Icons.chat_bubble_outline, 'placeholder': 'https://pf.kakao.com/...'},
    ],
    'Germany': [
      {'key': 'xing', 'label': 'XING', 'icon': Icons.work_outline, 'placeholder': 'https://xing.com/profile/yourname'},
    ],
    'United States': [
      {'key': 'threads', 'label': 'Threads', 'icon': Icons.alternate_email, 'placeholder': 'https://threads.net/@yourhandle'},
      {'key': 'reddit', 'label': 'Reddit', 'icon': Icons.forum_outlined, 'placeholder': 'https://reddit.com/r/yourcommunity'},
      {'key': 'discord', 'label': 'Discord', 'icon': Icons.headset_mic_outlined, 'placeholder': 'https://discord.gg/invitecode'},
      {'key': 'twitch', 'label': 'Twitch', 'icon': Icons.live_tv_outlined, 'placeholder': 'https://twitch.tv/yourchannel'},
    ],
  };

  static const Map<String, String> _socialBrandSlugMap = {
    'youtube': 'youtube',
    'facebook': 'facebook',
    'twitter': 'x',
    'instagram': 'instagram',
    'linkedin': 'linkedin',
    'tiktok': 'tiktok',
    'whatsapp': 'whatsapp',
    'telegram': 'telegram',
    'wechat': 'wechat',
    'weibo': 'sinaweibo',
    'bilibili': 'bilibili',
    'douyin': 'douyin',
    'xiaohongshu': 'xiaohongshu',
    'zhihu': 'zhihu',
    'qq': 'tencentqq',
    'vk': 'vk',
    'rutube': 'rutube',
    'yandex': 'yandex',
    'line': 'line',
    'naver': 'naver',
    'kakao': 'kakaotalk',
    'xing': 'xing',
    'threads': 'threads',
    'reddit': 'reddit',
    'discord': 'discord',
    'twitch': 'twitch',
  };

  static const Map<String, IconData> _socialIconMap = {
    'website': Icons.language,
    'email': Icons.email_outlined,
    'youtube': Icons.play_circle_fill,
    'facebook': Icons.facebook,
    'twitter': Icons.tag,
    'instagram': Icons.camera_alt,
    'linkedin': Icons.work,
    'tiktok': Icons.music_note,
    'whatsapp': Icons.chat,
    'telegram': Icons.send,
    'reddit': Icons.forum,
    'discord': Icons.discord,
    'twitch': Icons.live_tv,
    'wechat': Icons.chat_bubble_outline,
    'weibo': Icons.public,
    'bilibili': Icons.tv,
    'douyin': Icons.music_video,
    'xiaohongshu': Icons.auto_awesome,
    'zhihu': Icons.help_outline,
    'qq': Icons.message,
    'vk': Icons.group,
    'rutube': Icons.video_library,
    'yandex': Icons.search,
    'line': Icons.chat_bubble,
    'naver': Icons.language,
    'kakao': Icons.forum,
    'xing': Icons.business,
    'threads': Icons.alternate_email,
  };

  Widget _buildSocialBrandIcon(String key, IconData fallbackIcon) {
    final iconData = _socialIconMap[key] ?? fallbackIcon;
    return Icon(iconData, size: 18, color: Colors.white);
  }

  Widget _buildLinksContent(bool isDarkMode) {
    return Obx(() {
      final isOrg = controller.channelTypeCategory.value == 'Organization / Company';
      final selectedCountry = controller.country.value;
      final bannedPlatforms = _bannedSocialPlatformsByCountry[selectedCountry] ?? const [];

      // Clean up any banned platform links from controller state if present
      for (final bannedKey in bannedPlatforms) {
        if (controller.socialLinks.containsKey(bannedKey)) {
          controller.socialLinks.remove(bannedKey);
        }
        if (_socialControllers.containsKey(bannedKey)) {
          _socialControllers[bannedKey]?.clear();
        }
      }

      final standardLinks = [
        {'key': 'website', 'label': 'Website', 'icon': Icons.language, 'placeholder': 'https://yourwebsite.com'},
        {
          'key': 'email',
          'label': isOrg ? 'Email *' : 'Email',
          'icon': Icons.email_outlined,
          'placeholder': isOrg ? 'contact@yourcompany.com (Custom domain required)' : 'youremail@example.com'
        },
        {'key': 'youtube', 'label': 'YouTube', 'icon': Icons.play_circle_outline, 'placeholder': 'https://youtube.com/yourchannel'},
        {'key': 'facebook', 'label': 'Facebook', 'icon': Icons.facebook, 'placeholder': 'https://facebook.com/yourpage'},
        {'key': 'twitter', 'label': 'X (Twitter)', 'icon': Icons.alternate_email, 'placeholder': 'https://x.com/yourhandle'},
        {'key': 'instagram', 'label': 'Instagram', 'icon': Icons.camera_alt_outlined, 'placeholder': 'https://instagram.com/yourhandle'},
        {'key': 'linkedin', 'label': 'LinkedIn', 'icon': Icons.work_outline, 'placeholder': 'https://linkedin.com/in/yourprofile'},
        {'key': 'tiktok', 'label': 'TikTok', 'icon': Icons.music_note_outlined, 'placeholder': 'https://tiktok.com/@yourhandle'},
        {'key': 'whatsapp', 'label': 'WhatsApp Channel', 'icon': Icons.chat_outlined, 'placeholder': 'https://whatsapp.com/channel/...'},
        {'key': 'telegram', 'label': 'Telegram', 'icon': Icons.send_outlined, 'placeholder': 'https://t.me/yourchannel'},
      ];

      final filteredStandard = standardLinks.where((item) => !bannedPlatforms.contains(item['key'])).toList();
      final countrySpecific = _countrySpecificSocialPlatforms[selectedCountry] ?? const [];

      final existingKeys = filteredStandard.map((e) => e['key']).toSet();
      final extraLinks = countrySpecific.where((e) => !existingKeys.contains(e['key'])).toList();

      final allLinksList = [...filteredStandard, ...extraLinks];

      // Show top 6 links by default (Website + Email + top 4 social links), or any filled link
      final visibleLinksList = _showMoreLinks.value
          ? allLinksList
          : allLinksList.where((item) {
              final idx = allLinksList.indexOf(item);
              final key = item['key']! as String;
              final hasValue = _socialControllers[key]?.text.trim().isNotEmpty ?? false;
              return idx < 6 || hasValue;
            }).toList();

      final hasHiddenLinks = allLinksList.length > visibleLinksList.length || _showMoreLinks.value;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isOrg) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3F3F46),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Custom Email Required',
                    style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              '⚠️ Organization / Company channels require a custom business domain email (e.g. info@company.com). Free emails (@gmail.com, @yahoo.com) are not allowed.',
              style: TextStyle(fontSize: 12, color: Color(0xFFFBBF24), height: 1.4),
            ),
            const SizedBox(height: 16),
          ],
          const SizedBox(height: 16),
          ...visibleLinksList.map((item) {
            final itemKey = item['key']! as String;
            final ctrl = _getSocialController(itemKey);
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: Row(
                      children: [
                        _buildSocialBrandIcon(
                          itemKey,
                          item['icon']! as IconData,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item['label']! as String,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF121212),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF27272A)),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: TextField(
                        controller: ctrl,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: item['placeholder']! as String,
                          hintStyle: const TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 12,
                          ),
                          border: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          if (hasHiddenLinks) ...[
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => _showMoreLinks.value = !_showMoreLinks.value,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF18181B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF27272A)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _showMoreLinks.value ? Icons.keyboard_arrow_up : Icons.add,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _showMoreLinks.value ? 'Show Less Links' : 'Add More Links',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      );
    });
  }

  // ========================================================================
  // CARD 5: CHANNEL VISIBILITY
  // ========================================================================
  Widget _buildVisibilityCard(bool isDarkMode) {
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
            '6. Channel Visibility',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          _buildVisibilityContent(isDarkMode),
        ],
      ),
    );
  }

  Widget _buildVisibilityContent(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Choose who can view your channel.',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        Obx(
          () => GestureDetector(
            onTap: () {
              controller.isPublic.value = !controller.isPublic.value;
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF121212),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF27272A)),
              ),
              child: Row(
                children: [
                  Icon(
                    controller.isPublic.value ? Icons.public : Icons.lock,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          controller.isPublic.value ? 'Public' : 'Private',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          controller.isPublic.value
                              ? 'Anyone can find and view your channel'
                              : 'Only approved users can view your channel',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ========================================================================
  // CARD 6: COUNTRY
  // ========================================================================
  Widget _buildCountryCard(bool isDarkMode) {
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
            '7. Country',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          _buildCountryContent(isDarkMode),
        ],
      ),
    );
  }

  Widget _buildCountryContent(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select your channel primary country location.',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        Obx(
          () => GestureDetector(
            onTap: () => _showCountryPicker(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF121212),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF27272A)),
              ),
              child: Row(
                children: [
                  _buildCountryFlag(controller.country.value),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      controller.country.value.isNotEmpty
                          ? controller.country.value
                          : 'Select Country',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ========================================================================
  // CARD 7: LANGUAGE
  // ========================================================================
  Widget _buildLanguageCard(bool isDarkMode) {
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
            '8. Language',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          _buildLanguageContent(isDarkMode),
        ],
      ),
    );
  }

  Widget _buildLanguageContent(bool isDarkMode) {
    final languageNames = {
      'en': 'English',
      'es': 'Spanish',
      'fr': 'French',
      'de': 'German',
      'zh': 'Chinese',
      'ja': 'Japanese',
      'ar': 'Arabic',
      'hi': 'Hindi',
      'pt': 'Portuguese',
      'ru': 'Russian',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select your channel language.',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        Obx(
          () => GestureDetector(
            onTap: () => _showLanguagePicker(context, languageNames),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF121212),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF27272A)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.language,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      languageNames[controller.language.value] ?? 'English',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showLanguagePicker(
      BuildContext context, Map<String, String> languageNames) {
    Get.bottomSheet(
      Material(
        color: const Color(0xFF18181B),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Container(
          height: 480,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Language',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Get.back(),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: controller.languages.length,
                itemBuilder: (context, index) {
                  final code = controller.languages[index];
                  final name = languageNames[code] ?? code;
                  return Obx(() {
                    final isSelected = controller.language.value == code;
                    return ListTile(
                      title: Text(
                        name,
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: Colors.white)
                          : null,
                      onTap: () {
                        controller.language.value = code;
                        Get.back();
                      },
                    );
                  });
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  // ========================================================================
  // CARD 9: CHANNEL PLAN
  // ========================================================================
  Widget _buildPlanCard(bool isDarkMode) {
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
            '9. Channel Plan',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          _buildPlanContent(isDarkMode),
        ],
      ),
    );
  }

  Widget _buildPlanContent(bool isDarkMode) {
    final planNames = {
      'standard': 'Standard',
      'custom': 'Custom plan',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select your channel plan.',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        Obx(
          () => GestureDetector(
            onTap: () => _showPlanPicker(context, planNames),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF121212),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF27272A)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.workspace_premium_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      planNames[controller.selectedPlan.value] ?? 'Standard',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showPlanPicker(
      BuildContext context, Map<String, String> planNames) {
    Get.bottomSheet(
      Material(
        color: const Color(0xFF18181B),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Channel Plan',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Get.back(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...planNames.entries.map((entry) {
                return Obx(() {
                  final isSelected = controller.selectedPlan.value == entry.key;
                  return ListTile(
                    title: Text(
                      entry.value,
                      style: TextStyle(
                        color:
                            isSelected ? Colors.white : AppColors.textSecondary,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                    onTap: () {
                      controller.selectedPlan.value = entry.key;
                      controller.planSelectionError.value = false;
                      Get.back();
                    },
                  );
                });
              }),
            ],
          ),
        ),
      ),
    );
  }

  // ========================================================================
  // CARD 10: AGREEMENTS & SUBMIT BUTTON
  // ========================================================================
  Widget _buildAgreementsAndSubmitCard(bool isDarkMode) {
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
            '10. Agreements',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          _buildAgreementsAndSubmitContent(isDarkMode),
        ],
      ),
    );
  }

  Future<void> _openTermsPage() async {
    final result = await Get.toNamed('/terms', arguments: {'requireAgreement': true});
    if (result == true) {
      controller.agreeTerms.value = true;
      controller.isAgreed.value =
          controller.agreeTerms.value && controller.agreeGuidelines.value;
    }
  }

  Future<void> _openGuidelinesPage() async {
    final result = await Get.toNamed('/community-guidelines', arguments: {'requireAgreement': true});
    if (result == true) {
      controller.agreeGuidelines.value = true;
      controller.isAgreed.value =
          controller.agreeTerms.value && controller.agreeGuidelines.value;
    }
  }

  Widget _buildAgreementsAndSubmitContent(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Obx(
          () => _buildCheckboxRow(
            value: controller.agreeTerms.value,
            onChanged: (val) {
              if (controller.agreeTerms.value && val == false) {
                controller.agreeTerms.value = false;
                controller.isAgreed.value = false;
              } else {
                _openTermsPage();
              }
            },
            text: 'I agree to the ',
            linkText: 'Terms and Conditions',
            onLinkTap: _openTermsPage,
          ),
        ),
        const SizedBox(height: 8),
        Obx(
          () => _buildCheckboxRow(
            value: controller.agreeGuidelines.value,
            onChanged: (val) {
              if (controller.agreeGuidelines.value && val == false) {
                controller.agreeGuidelines.value = false;
                controller.isAgreed.value = false;
              } else {
                _openGuidelinesPage();
              }
            },
            text: 'I agree to the ',
            linkText: 'Community Guidelines',
            onLinkTap: _openGuidelinesPage,
          ),
        ),
        const SizedBox(height: 24),
        // Create Channel Button (Full width button with progress indication & white icon)
        Obx(
          () => SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: controller.isSubmitting.value
                  ? null
                  : _validateAndSubmitChannel,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.brand.withOpacity(0.6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: controller.isSubmitting.value
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Creating Channel...',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.play_arrow, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Create Channel',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCheckboxRow({
    required bool value,
    required ValueChanged<bool?> onChanged,
    required String text,
    required String linkText,
    required VoidCallback onLinkTap,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            checkColor: Colors.black,
            side: const BorderSide(color: Color(0xFF52525B)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            onTap: () => onChanged(!value),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.white, fontSize: 13),
                children: [
                  TextSpan(text: text),
                  WidgetSpan(
                    child: GestureDetector(
                      onTap: onLinkTap,
                      child: Text(
                        linkText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          decoration: TextDecoration.underline,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ========================================================================
  // REUSABLE FIELD HELPERS
  // ========================================================================
  Widget _buildFieldLabel(String label, {required bool isRequired}) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        if (isRequired) ...[
          const SizedBox(width: 4),
          const Text(
            '*',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFFEF4444),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    String? prefixText,
    int maxLines = 1,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: maxLines > 1
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              if (prefixText != null)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    prefixText,
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 13,
                    ),
                  ),
                ),
              Expanded(
                child: TextFormField(
                  controller: controller,
                  maxLines: maxLines,
                  inputFormatters: inputFormatters,
                  validator: validator,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 13,
                    ),
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              if (maxLength != null && maxLines == 1)
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, child) {
                    return Text(
                      '${value.text.length}/$maxLength',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    );
                  },
                ),
            ],
          ),
          if (maxLength != null && maxLines > 1)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, child) {
                    return Text(
                      '${value.text.length}/$maxLength',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ========================================================================
  // DRAFT & CLOSE DIALOGS
  // ========================================================================
  void _handleClose(bool isDarkMode) {
    if (controller.channelName.text.trim().isEmpty &&
        controller.description.text.trim().isEmpty &&
        controller.selectedCategories.isEmpty) {
      Get.back();
      return;
    }

    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        title: const Text(
          'Save Draft?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'You have unsaved changes. Would you like to save a draft before exiting?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _isExiting.value = true;
              Get.back();
              Get.back();
            },
            child: const Text('Discard', style: TextStyle(color: AppColors.error)),
          ),
          TextButton(
            onPressed: () async {
              await controller.saveDraft();
              _isExiting.value = true;
              Get.back();
              Get.back();
            },
            child: const Text('Save Draft', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDraftAvailableDialog(bool isDarkMode) {
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        title: const Text(
          'Draft Available',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'You have a saved channel creation draft. Would you like to restore it?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () {
              controller.deleteDraft();
              Get.back();
            },
            child: const Text('Discard', style: TextStyle(color: AppColors.error)),
          ),
          TextButton(
            onPressed: () {
              Get.back();
            },
            child: const Text('Restore', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeleteDraftDialog(bool isDarkMode) {
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        title: const Text(
          'Delete Draft?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to delete your saved draft? This action cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () async {
              await controller.deleteDraft();
              Get.back();
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _validateAndSubmitChannel() {
    // Sync tags and social inputs from local controllers to ChannelController
    if (_tagList.isNotEmpty) {
      controller.tags.text = _tagList.join(', ');
    }
    for (final entry in _socialControllers.entries) {
      final val = entry.value.text.trim();
      if (val.isNotEmpty) {
        controller.socialLinks[entry.key] = val;
      }
    }
    if (_socialControllers.containsKey('website')) {
      controller.websiteUrl.text = _socialControllers['website']!.text.trim();
    }
    if (_socialControllers.containsKey('email')) {
      controller.contactEmail.text = _socialControllers['email']!.text.trim();
    }

    // 1. Channel Banner
    if (controller.bannerImageData.value == null && controller.bannerUrl.value.isEmpty) {
      Get.snackbar(
        'Action Required',
        'Please select and upload a Channel Banner image.',
        backgroundColor: const Color(0xFFEF4444),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        icon: const Icon(Icons.error_outline, color: Colors.white),
      );
      return;
    }

    if (controller.bannerStatus.value == 'REJECTED') {
      Get.snackbar(
        'Banner Rejected',
        'Your banner was rejected: ${controller.bannerStatusReason.value}. Please upload a different image.',
        backgroundColor: const Color(0xFFEF4444),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        icon: const Icon(Icons.error_outline, color: Colors.white),
      );
      return;
    }

    // 2. Channel Avatar
    if (controller.avatarImageData.value == null && controller.avatarUrl.value.isEmpty) {
      Get.snackbar(
        'Action Required',
        'Please select and upload a Channel Avatar image.',
        backgroundColor: const Color(0xFFEF4444),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        icon: const Icon(Icons.error_outline, color: Colors.white),
      );
      return;
    }

    if (controller.avatarStatus.value == 'REJECTED') {
      Get.snackbar(
        'Avatar Rejected',
        'Your avatar was rejected: ${controller.avatarStatusReason.value}. Please upload a different image.',
        backgroundColor: const Color(0xFFEF4444),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        icon: const Icon(Icons.error_outline, color: Colors.white),
      );
      return;
    }

    // 3. Channel Name
    if (controller.channelName.text.trim().isEmpty) {
      Get.snackbar(
        'Action Required',
        'Please enter a Channel Name.',
        backgroundColor: const Color(0xFFEF4444),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
      return;
    }

    // 4. Channel Handle
    if (controller.customUrl.text.trim().isEmpty) {
      Get.snackbar(
        'Action Required',
        'Please enter a Channel Handle.',
        backgroundColor: const Color(0xFFEF4444),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
      return;
    }

    // 5. Description
    if (controller.description.text.trim().isEmpty) {
      Get.snackbar(
        'Action Required',
        'Please enter a Channel Description.',
        backgroundColor: const Color(0xFFEF4444),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
      return;
    }

    // 6. Tags (at least 1 required)
    final parsedTags = controller.tags.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    if (parsedTags.isEmpty && _tagList.isEmpty) {
      Get.snackbar(
        'Action Required',
        'Please add at least 1 Tag.',
        backgroundColor: const Color(0xFFEF4444),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
      return;
    }

    // 7. Category (at least 1 required)
    if (controller.selectedCategories.isEmpty &&
        (controller.selectedCategory.value == null ||
            controller.selectedCategory.value!.trim().isEmpty)) {
      Get.snackbar(
        'Action Required',
        'Please select at least 1 Category.',
        backgroundColor: const Color(0xFFEF4444),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
      return;
    }

    // 8. Agreements
    if (!controller.agreeTerms.value || !controller.agreeGuidelines.value) {
      Get.snackbar(
        'Action Required',
        'Please agree to both Terms & Conditions and Community Guidelines.',
        backgroundColor: const Color(0xFFEF4444),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
      return;
    }

    // 9. Plan Selection Default
    if (controller.selectedPlan.value.isEmpty) {
      controller.selectedPlan.value = 'standard';
    }
    controller.planSelectionError.value = false;

    // 10. Organization / Company Custom Email Domain Check
    if (controller.channelTypeCategory.value == 'Organization / Company') {
      final emailText = _getSocialController('email').text.trim();
      if (emailText.isEmpty) {
        Get.snackbar(
          'Action Required',
          'Please enter a custom business domain email (e.g. contact@yourcompany.com).',
          backgroundColor: const Color(0xFFEF4444),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16),
        );
        return;
      }
      if (!controller.isCustomBusinessEmail(emailText)) {
        Get.snackbar(
          'Action Required',
          'Please enter a custom business domain email. Free email services (@gmail.com, @yahoo.com) are not allowed for Organization / Company channels.',
          backgroundColor: const Color(0xFFEF4444),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16),
        );
        return;
      }
    }

    controller.isAgreed.value = true;
    controller.createChannel();
  }



  // ========================================================================
  // PLAN SELECTION SCREEN (STEP 1 BEFORE CHANNEL SETUP)
  // ========================================================================
  Widget _buildStandard3DGraphic(bool isDesktop) {
    final double scale = isDesktop ? 0.75 : 1.0;
    return Transform.scale(
      scale: scale,
      child: SizedBox(
        height: isDesktop ? 75 : 120,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF6366F1).withOpacity(0.35),
                    const Color(0xFF7C3AED).withOpacity(0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              child: Container(
                width: 100,
                height: 28,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(Radius.elliptical(100, 28)),
                  color: const Color(0xFF1E1B4B),
                  border: Border.all(color: const Color(0xFF4C1D95), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.4),
                      blurRadius: 15,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 22,
              child: Container(
                width: 80,
                height: 22,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(Radius.elliptical(80, 22)),
                  color: const Color(0xFF311042),
                  border: Border.all(color: const Color(0xFF7C3AED), width: 1.5),
                ),
              ),
            ),
            Positioned(
              top: 10,
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF4C1D95),
                      Color(0xFF1E1B4B),
                    ],
                  ),
                  border: Border.all(color: const Color(0xFFA855F7), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withOpacity(0.5),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.shield_outlined,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomRocket3DGraphic(bool isDesktop) {
    final double scale = isDesktop ? 0.75 : 1.0;
    return Transform.scale(
      scale: scale,
      child: SizedBox(
        height: isDesktop ? 75 : 120,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF8B5CF6).withOpacity(0.4),
                    const Color(0xFF6366F1).withOpacity(0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 8,
              child: Container(
                width: 76,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFA855F7).withOpacity(0.6),
                      const Color(0xFF4C1D95).withOpacity(0.2),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF6D28D9),
                      Color(0xFF311042),
                    ],
                  ),
                  border: Border.all(color: const Color(0xFFC084FC), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFA855F7).withOpacity(0.6),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.rocket_launch,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              top: 24,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF4C1D95),
                  border: Border.all(color: const Color(0xFFA855F7)),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF8B5CF6).withOpacity(0.4), blurRadius: 8),
                  ],
                ),
                child: const Icon(Icons.play_arrow, color: Colors.white, size: 12),
              ),
            ),
            Positioned(
              right: 14,
              bottom: 24,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF5B21B6),
                  border: Border.all(color: const Color(0xFFC084FC)),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF8B5CF6).withOpacity(0.4), blurRadius: 8),
                  ],
                ),
                child: const Icon(Icons.attach_money, color: Colors.white, size: 12),
              ),
            ),
            Positioned(
              right: 18,
              top: 18,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF311042),
                  border: Border.all(color: const Color(0xFFA855F7)),
                ),
                child: const Icon(Icons.bar_chart, color: Colors.white, size: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard3DGraphic(bool isDesktop) {
    final double scale = isDesktop ? 0.75 : 1.0;
    return Transform.scale(
      scale: scale,
      child: SizedBox(
        height: isDesktop ? 110 : 180,
        width: isDesktop ? 160 : 220,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 180,
              height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF7C3AED).withOpacity(0.35),
                    const Color(0xFF4C1D95).withOpacity(0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Transform(
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(-0.15)
                ..rotateX(0.1),
              alignment: FractionalOffset.center,
              child: Container(
                width: 170,
                height: 115,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF161528),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF7C3AED), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFEF4444))),
                        const SizedBox(width: 4),
                        Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFF59E0B))),
                        const SizedBox(width: 4),
                        Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF6366F1))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(width: 12, height: 20, decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), color: const Color(0xFF4C1D95))),
                        Container(width: 12, height: 35, decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), color: const Color(0xFF6D28D9))),
                        Container(width: 12, height: 28, decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), color: const Color(0xFF7C3AED))),
                        Container(width: 12, height: 48, decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), color: const Color(0xFFA855F7))),
                        Container(width: 12, height: 60, decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), color: const Color(0xFFC084FC))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 8,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                  ),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFFF59E0B).withOpacity(0.5), blurRadius: 10),
                  ],
                ),
                child: const Icon(Icons.attach_money, color: Colors.white, size: 16),
              ),
            ),
            Positioned(
              right: 12,
              top: 16,
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFB45309)],
                  ),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFFF59E0B).withOpacity(0.4), blurRadius: 8),
                  ],
                ),
                child: const Icon(Icons.workspace_premium, color: Colors.white, size: 15),
              ),
            ),
            Positioned(
              left: 4,
              top: 40,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFEC4899),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFFEC4899).withOpacity(0.4), blurRadius: 8),
                  ],
                ),
                child: const Icon(Icons.favorite, color: Colors.white, size: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanHeader(bool isDesktop) {
    if (isDesktop) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Select Channel Plan',
                style: TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Choose your monetization & features plan before creating your channel.',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => _handleClose(false),
          ),
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => _handleClose(false),
            ),
            const Expanded(
              child: Text(
                'Select Channel Plan',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Choose your monetization & features plan before creating your channel.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: TWTypography.uiFamily,
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildPlanSelectionScreen(BuildContext context, bool isDesktop, bool isDarkMode) {
    final bodyContent = Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: isDesktop ? 1040 : 600),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: isDesktop ? MainAxisSize.min : MainAxisSize.max,
          children: [
            _buildPlanHeader(isDesktop),
            SizedBox(height: isDesktop ? 10 : 20),

            if (isDesktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildStandardPlanCard(isDarkMode, isDesktop)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildCustomPlanCard(isDarkMode, isDesktop)),
                ],
              )
            else
              Column(
                children: [
                  _buildStandardPlanCard(isDarkMode, isDesktop),
                  const SizedBox(height: 16),
                  _buildCustomPlanCard(isDarkMode, isDesktop),
                ],
              ),

            SizedBox(height: isDesktop ? 10 : 16),

            _buildWhyChoosePlanCard(isDesktop),

            _buildCustomTierBreakdownTable(isDesktop),

            SizedBox(height: isDesktop ? 8 : 16),

            _buildPlanNoticeCard(isDesktop),

            Obx(
              () => _isShowingAllFeatures
                  ? Column(
                      children: [
                        SizedBox(height: isDesktop ? 10 : 16),
                        _buildPlanHighlightsCard(isDesktop, isDarkMode),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),

            SizedBox(height: isDesktop ? 12 : 20),

            _buildPlanFooterAction(isDesktop),
          ],
        ),
      ),
    );

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 24 : 16,
        vertical: isDesktop ? 16 : 16,
      ),
      child: bodyContent,
    );
  }

  Widget _buildStandardPlanCard(bool isDarkMode, bool isDesktop) {
    return Obx(() {
      final isSelected = controller.selectedPlan.value == 'standard';
      final isError = controller.planSelectionError.value && controller.selectedPlan.value.isEmpty;
      return GestureDetector(
        onTap: () {
          controller.selectedPlan.value = 'standard';
          controller.planSelectionError.value = false;
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.all(isDesktop ? 12 : 20),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF12121B) : AppColors.appBarSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF7C3AED)
                  : isError
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF27272A),
              width: (isSelected || isError) ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withOpacity(0.25),
                      blurRadius: 20,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? const Color(0xFF7C3AED) : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? const Color(0xFF7C3AED) : const Color(0xFF3F3F46),
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
              ),
              Column(
                children: [
                  SizedBox(height: isDesktop ? 0 : 4),
                  _buildStandard3DGraphic(isDesktop),
                  SizedBox(height: isDesktop ? 6 : 12),
                  const Text(
                    'Standard Channel',
                    style: TextStyle(
                      fontFamily: TWTypography.brandFamily,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Ideal for creators who are starting out',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: isDesktop ? 8 : 16),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: isDesktop ? 6 : 8,
                    runSpacing: isDesktop ? 6 : 8,
                    children: const [
                      _PlanBadgeItem(text: '70% Revenue Share (Ads & Premium)'),
                      _PlanBadgeItem(text: '100% Memberships & Superchats'),
                      _PlanBadgeItem(text: '20 min/day upload'),
                      _PlanBadgeItem(text: 'Up to 1080p'),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildCustomPlanCard(bool isDarkMode, bool isDesktop) {
    return Obx(() {
      final isSelected = controller.selectedPlan.value == 'custom';
      final isError = controller.planSelectionError.value && controller.selectedPlan.value.isEmpty;
      return GestureDetector(
        onTap: () {
          controller.selectedPlan.value = 'custom';
          controller.planSelectionError.value = false;
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.all(isDesktop ? 12 : 20),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF12121B) : AppColors.appBarSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF7C3AED)
                  : isError
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF27272A),
              width: (isSelected || isError) ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF7C3AED).withOpacity(0.25),
                      blurRadius: 20,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? const Color(0xFF7C3AED) : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? const Color(0xFF7C3AED) : const Color(0xFF3F3F46),
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
              ),
              Column(
                children: [
                  SizedBox(height: isDesktop ? 0 : 4),
                  _buildCustomRocket3DGraphic(isDesktop),
                  SizedBox(height: isDesktop ? 6 : 12),
                  const Text(
                    'Custom Channel',
                    style: TextStyle(
                      fontFamily: TWTypography.brandFamily,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Advanced features • Higher revenue share • More control',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: isDesktop ? 6 : 14),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: isDesktop ? 10 : 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4C1D95).withOpacity(0.4),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFA855F7)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.card_giftcard, size: 13, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          '\$10 FREE Bonus Credit Included',
                          style: TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFC084FC),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: isDesktop ? 4 : 10),
                  const Text(
                    'Select Custom Pricing Tier:',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [r'$15', r'$30', r'$45', r'Custom'].map((tier) {
                      return Obx(() {
                        final isTierSelected = controller.customPricingTier.value == tier;
                        final label = tier == r'Custom' ? 'Custom' : '$tier/mo';
                        return GestureDetector(
                          onTap: () {
                            controller.selectedPlan.value = 'custom';
                            controller.customPricingTier.value = tier;
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: EdgeInsets.symmetric(horizontal: isDesktop ? 10 : 14, vertical: isDesktop ? 4 : 6),
                            decoration: BoxDecoration(
                              color: isTierSelected ? const Color(0xFF7C3AED) : const Color(0xFF27272A),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isTierSelected ? const Color(0xFFA855F7) : const Color(0xFF3F3F46),
                              ),
                              boxShadow: isTierSelected
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF7C3AED).withOpacity(0.4),
                                        blurRadius: 8,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                fontSize: 12,
                                fontWeight: isTierSelected ? FontWeight.bold : FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        );
                      });
                    }).toList(),
                  ),
                  SizedBox(height: isDesktop ? 6 : 14),
                  Obx(() {
                    final selectedTier = controller.customPricingTier.value;
                    List<String> tierBadges;
                    if (selectedTier == r'Custom') {
                      tierBadges = [
                        'Flexible Storage & CDN',
                        'Dedicated VIP Support & SLA',
                        'Custom Integration',
                        '100% Revenue Share',
                      ];
                    } else if (selectedTier == r'$45') {
                      tierBadges = [
                        '1 TB Cloud Storage',
                        '5 TB Global CDN Bandwidth',
                        '4K HDR Video',
                        '\$20 Monthly Bonus Credit',
                        '100% Revenue Share',
                      ];
                    } else if (selectedTier == r'$30') {
                      tierBadges = [
                        '300 GB Cloud Storage',
                        '1.5 TB Global CDN Bandwidth',
                        '4K Ultra HD',
                        '\$10 Monthly Bonus Credit',
                        '100% Revenue Share',
                      ];
                    } else {
                      tierBadges = [
                        '100 GB Cloud Storage',
                        '500 GB Global CDN Bandwidth',
                        '4K Ultra HD',
                        'Unlimited Uploads',
                        '100% Revenue Share',
                      ];
                    }

                    return Wrap(
                      alignment: WrapAlignment.center,
                      spacing: isDesktop ? 6 : 8,
                      runSpacing: isDesktop ? 6 : 8,
                      children: tierBadges.map((badge) => _PlanBadgeItem(text: badge)).toList(),
                    );
                  }),
                ],
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildWhyChoosePlanCard(bool isDesktop) {
    return Obx(() {
      final planVal = controller.selectedPlan.value;
      final isCustom = planVal == 'custom';
      final isStandard = planVal == 'standard';

      final planTitle = isCustom
          ? 'Why Choose Custom Channel?'
          : isStandard
              ? 'Why Choose Standard Channel?'
              : 'Why Choose TruthWorld Channel Plans?';

      final selectedTier = controller.customPricingTier.value;
      List<String> customBullets;
      if (selectedTier == r'Custom') {
        customBullets = [
          '100% Revenue Share: Keep 100% from Ads, Subscriptions & Superchats',
          'Flexible Cloud Storage & Global CDN Bandwidth scaled to your audience',
          'Dedicated 24/7 VIP Account Manager & Direct Technical Support',
          '4K HDR Video Encoding & Custom Transcoding Pipelines',
          'Custom Integration & Payout Contract SLAs',
          '100% Free Premium Features (Value ₹25,999/year included)',
        ];
      } else if (selectedTier == r'$45') {
        customBullets = [
          '100% Revenue Share: Keep 100% from Ads, Subscriptions & Superchats',
          '1 TB Cloud Storage: Space for ~3,000+ HD/4K videos',
          '5 TB High-Speed Global CDN: Fast global streaming (~15,000+ hrs)',
          '4K HDR Video & Lossless Audio encoding',
          '\$20 FREE Monthly Bonus Credit included',
          'VIP Priority 24/7 Account Support & HD Transcoding',
          '100% Free Premium Features (Value ₹25,999/year included)',
        ];
      } else if (selectedTier == r'$30') {
        customBullets = [
          '100% Revenue Share: Keep 100% from Ads, Subscriptions & Superchats',
          '300 GB Cloud Storage: Space for ~1,000 HD/4K videos',
          '1.5 TB High-Speed Global CDN: Fast streaming (~5,000 hrs)',
          '4K Ultra HD Uploads (3840x2160) + High Bitrate',
          '\$10 FREE Monthly Bonus Credit included',
          'Priority Live Support & Fast HD Transcoding',
          '100% Free Premium Features (Value ₹25,999/year included)',
        ];
      } else {
        customBullets = [
          '100% Revenue Share: Keep 100% from Ads, Subscriptions & Superchats',
          '100 GB Cloud Storage: Space for ~300 HD/4K videos',
          '500 GB High-Speed Global CDN: Ultra-fast streaming (~1,500+ hrs)',
          '4K Ultra HD Uploads (3840x2160) & Unlimited Uploads/Day',
          'Google Cloud & Firebase Backend Egress Included',
          'Standard Priority Support & Fast Transcoding',
          '100% Free Premium Features (Value ₹25,999/year included)',
        ];
      }

      final standardBullets = [
        '100% Forever Free: \$0/month — Zero subscription fee',
        'TruthWorld Covers Hosting: Free video transcoding & storage',
        '70% Revenue Share: Earn 70% from ads & subscriptions',
        '100% Direct Fan Revenue: Keep 100% Memberships & Superchats',
        'Up to 1080p Full HD Uploads: High quality video playback',
        '20 Min/Day Upload Limit: Ideal for starting out creators',
        'Easy Upgrade Anytime: Switch to Custom plan whenever you grow',
      ];

      final overviewBullets = [
        'Select between 100% Free Standard Channel or Scalable Custom Channel',
        'Earn 70% to 100% Revenue Share on Ads & Premium Subscriptions',
        'Keep 100% Direct Fan Revenue: 0% Platform Commission on Memberships & Superchats',
        'Standard Plan: 100% Free with 20 min/day uploads in 1080p Full HD',
        'Custom Plan: Unlimited uploads, 4K Ultra HD & Cloud Storage up to 1 TB',
        'Custom Bonus: Instant \$10 FREE Monthly Bonus Credit included',
        'Easy Upgrade: Switch or upgrade your plan anytime from Channel Settings',
      ];

      final bullets = isCustom
          ? customBullets
          : isStandard
              ? standardBullets
              : overviewBullets;

      return Container(
        padding: EdgeInsets.all(isDesktop ? 12 : 18),
        decoration: BoxDecoration(
          color: const Color(0xFF121215),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF27272A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCustom ? const Color(0xFF7C3AED) : const Color(0xFF6366F1),
                      ),
                      child: Icon(
                        isCustom ? Icons.auto_awesome : Icons.verified_user,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      planTitle,
                      style: const TextStyle(
                        fontFamily: TWTypography.brandFamily,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                if (!isDesktop)
                  IconButton(
                    icon: Icon(
                      _isHighlightsExpanded.value
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: Colors.white,
                    ),
                    onPressed: () =>
                        _isHighlightsExpanded.value = !_isHighlightsExpanded.value,
                  ),
              ],
            ),
            SizedBox(height: isDesktop ? 8 : 16),

            Builder(builder: (context) {
              final isExpanded = _isHighlightsExpanded.value;
              if (!isDesktop && !isExpanded) {
                return const SizedBox.shrink();
              }

              if (isDesktop) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Center(child: _buildDashboard3DGraphic(isDesktop)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: bullets
                                  .take(4)
                                  .map((b) => _buildWhyChooseBulletItem(b, isDesktop))
                                  .toList(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: bullets
                                  .skip(4)
                                  .map((b) => _buildWhyChooseBulletItem(b, isDesktop))
                                  .toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }

              return Column(
                children: [
                  Center(child: _buildDashboard3DGraphic(isDesktop)),
                  const SizedBox(height: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: bullets
                        .map((b) => _buildWhyChooseBulletItem(b, isDesktop))
                        .toList(),
                  ),
                ],
              );
            }),
          ],
        ),
      );
    });
  }

  Widget _buildCustomTierBreakdownTable(bool isDesktop) {
    return Obx(() {
      if (controller.selectedPlan.value != 'custom') {
        return const SizedBox.shrink();
      }

      final activeTier = controller.customPricingTier.value;

      final tiers = [
        {
          'id': r'$15',
          'name': r'$15/mo (Starter)',
          'storage': '100 GB Cloud Storage',
          'cdn': '500 GB Global CDN',
          'capacity': '~300 HD/4K videos (~1,500 hrs)',
        },
        {
          'id': r'$30',
          'name': r'$30/mo (Pro)',
          'storage': '300 GB Cloud Storage',
          'cdn': '1.5 TB (1,500 GB) Global CDN',
          'capacity': '~1,000 HD/4K videos (~5,000 hrs)',
        },
        {
          'id': r'$45',
          'name': r'$45/mo (Enterprise)',
          'storage': '1 TB (1,000 GB) Storage',
          'cdn': '5 TB (5,000 GB) Global CDN',
          'capacity': '~3,000+ HD/4K videos (~15,000+ hrs)',
        },
        {
          'id': r'Custom',
          'name': r'Custom Quote',
          'storage': 'Flexible Storage Limit',
          'cdn': 'Custom Global CDN',
          'capacity': 'Enterprise Level (Custom SLA)',
        },
      ];

      return Container(
        margin: const EdgeInsets.only(top: 14),
        padding: EdgeInsets.all(isDesktop ? 16 : 14),
        decoration: BoxDecoration(
          color: const Color(0xFF141418),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF7C3AED),
                  ),
                  child: const Icon(Icons.cloud_done_outlined, color: Colors.white, size: 14),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Custom Plan Tier Capacity & Storage Breakdown',
                        style: TextStyle(
                          fontFamily: TWTypography.brandFamily,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Powered by Google Cloud Storage & Firebase Global CDN Infrastructure',
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: isDesktop ? 680 : 580,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        color: const Color(0xFF1F1F24),
                        child: Row(
                          children: const [
                            Expanded(flex: 3, child: Text('Custom Tier', style: TextStyle(fontFamily: TWTypography.uiFamily, color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                            Expanded(flex: 3, child: Text('Storage Included', style: TextStyle(fontFamily: TWTypography.uiFamily, color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                            Expanded(flex: 3, child: Text('Monthly Global CDN', style: TextStyle(fontFamily: TWTypography.uiFamily, color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                            Expanded(flex: 4, child: Text('Est. Video Capacity', style: TextStyle(fontFamily: TWTypography.uiFamily, color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
                          ],
                        ),
                      ),
                      const Divider(color: Color(0xFF27272A), height: 1),
                      ...tiers.map((tier) {
                        final isSelected = activeTier == tier['id'];
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          color: isSelected ? const Color(0xFF2E1065) : Colors.transparent,
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Row(
                                  children: [
                                    if (isSelected) const Icon(Icons.check_circle, size: 14, color: Colors.white),
                                    if (isSelected) const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        tier['name']!,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontFamily: TWTypography.uiFamily,
                                          color: isSelected ? Colors.white : AppColors.textPrimary,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(tier['storage']!, style: const TextStyle(fontFamily: TWTypography.uiFamily, color: Colors.white, fontSize: 12)),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(tier['cdn']!, style: const TextStyle(fontFamily: TWTypography.uiFamily, color: Colors.white, fontSize: 12)),
                              ),
                              Expanded(
                                flex: 4,
                                child: Text(tier['capacity']!, style: const TextStyle(fontFamily: TWTypography.uiFamily, color: AppColors.textSecondary, fontSize: 11)),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildWhyChooseBulletItem(String text, bool isDesktop) {
    return Padding(
      padding: EdgeInsets.only(bottom: isDesktop ? 4 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            width: 15,
            height: 15,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF7C3AED),
            ),
            child: const Icon(
              Icons.check,
              color: Colors.white,
              size: 10,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                fontSize: isDesktop ? 11 : 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanNoticeCard(bool isDesktop) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: isDesktop ? 8 : 14),
      decoration: BoxDecoration(
        color: const Color(0xFF141418),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF4C1D95).withOpacity(0.4),
              border: Border.all(color: const Color(0xFF7C3AED)),
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: Colors.white,
              size: 13,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Note: You can upgrade or switch between Standard and Custom plans anytime from Settings. All plan upgrades and tier changes take effect on your next monthly billing date (next month).',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                fontSize: 11,
                color: AppColors.textSecondary,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanHighlightsCard(bool isDesktop, bool isDarkMode) {
    final planVal = controller.selectedPlan.value;
    final isCustom = planVal == 'custom';
    final isStandard = planVal == 'standard';

    final customChecklist = [
      {
        'title': 'Custom Tier Pricing: ${controller.customPricingTier.value}/month',
        'subtitle': '\$10 FREE credit applied automatically upon channel creation!',
      },
      {
        'title': '100% Revenue Share from Ads & Premium Subscriptions',
        'subtitle': 'Earn 100% revenue and power your growth with Custom Channel',
      },
      {
        'title': '100% Direct Revenue from Memberships & Superchats!',
        'subtitle': 'Keep 100% of fan support with zero commissions or transaction fees',
      },
      {
        'title': 'Unlimited video upload duration | up to 4K (3840x2160)',
        'subtitle': '2-5 times faster processing speed & ultra HD playback',
      },
      {
        'title': '30+ Premium Features & Tools',
        'subtitle': 'Advanced analytics, custom branding, live priority & priority CDN',
      },
      {
        'title': 'Advanced support: Live priority + HD',
        'subtitle': '',
      },
      {
        'title': '100% Free premium features (Value ₹25,999/year)',
        'subtitle': '',
      },
    ];

    final standardChecklist = [
      {
        'title': '70% Revenue Share from Ads & Premium Subscriptions',
        'subtitle': 'Earn 70% revenue share on all ad views and premium subscription revenues',
      },
      {
        'title': '100% Revenue from Memberships & Superchats',
        'subtitle': 'Keep 100% of direct fan support from your community',
      },
      {
        'title': '20 min/day Upload Limit (Up to 1080p Full HD)',
        'subtitle': 'Fast processing and crisp Full HD streaming',
      },
      {
        'title': '10+ Essential Creator Tools',
        'subtitle': 'Standard analytics, community posts, standard uploads',
      },
      {
        'title': '100% Free to Operate',
        'subtitle': 'TruthWorld covers video hosting & transcoding costs completely',
      },
      {
        'title': 'Upgrade or Switch Plan Once Every 1 Month',
        'subtitle': 'You can upgrade from Standard to Custom or switch plans once per month from Settings',
      },
    ];

    final allFeaturesChecklist = [
      {
        'title': '70% to 100% Revenue Share from Ads & Subscriptions',
        'subtitle': 'Standard offers 70% revenue share; Custom offers 100% revenue share.',
      },
      {
        'title': '100% Direct Fan Support (Memberships & Superchats)',
        'subtitle': '0% platform commissions on direct fan support across both Standard & Custom channels.',
      },
      {
        'title': '20 Min/Day (Standard) vs Unlimited Upload Duration & 4K (Custom)',
        'subtitle': 'Standard uploads up to 1080p Full HD; Custom supports 4K Ultra HD & unlimited duration.',
      },
      {
        'title': 'Storage & Global CDN Infrastructure Tiers',
        'subtitle': 'Standard: Free hosting. Custom: 100 GB, 300 GB, 1 TB Cloud Storage & 500 GB to 5 TB CDN.',
      },
      {
        'title': '\$10 FREE Monthly Bonus Credit Included on Custom',
        'subtitle': '\$10 credit applied automatically upon Custom Channel creation.',
      },
      {
        'title': '10+ Essential Creator Tools vs 30+ Premium Tools & VIP Support',
        'subtitle': 'Standard includes essential analytics; Custom adds VIP priority live support & fast transcoding.',
      },
      {
        'title': 'Monthly Plan Upgrade & Switch Policy',
        'subtitle': 'You can upgrade or switch between Standard and Custom plans anytime from Settings once per month.',
      },
    ];

    final checklistItems = isCustom
        ? customChecklist
        : isStandard
            ? standardChecklist
            : allFeaturesChecklist;

    final highlightsTitle = isCustom
        ? 'Custom Channel Plan Highlights'
        : isStandard
            ? 'Standard Channel Plan Highlights'
            : 'All Channel Features & Comparison';

    return Container(
      padding: EdgeInsets.all(isDesktop ? 24 : 18),
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.15),
                    ),
                    child: const Icon(
                      Icons.star,
                      color: Colors.white,
                      size: 15,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    highlightsTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              if (!isDesktop)
                IconButton(
                  icon: Icon(
                    _isHighlightsExpanded.value
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.white,
                  ),
                  onPressed: () =>
                      _isHighlightsExpanded.value = !_isHighlightsExpanded.value,
                ),
            ],
          ),
          const SizedBox(height: 20),

          if (isDesktop || _isHighlightsExpanded.value) ...[
            if (isDesktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: _buildDashboard3DGraphic(isDesktop),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 6,
                    child: _buildChecklistColumn(checklistItems),
                  ),
                ],
              )
            else ...[
              _buildDashboard3DGraphic(isDesktop),
              const SizedBox(height: 20),
              _buildChecklistColumn(checklistItems),
            ],
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF18181B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF3F3F46)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF27272A),
                    ),
                    child: const Icon(
                      Icons.verified_user_outlined,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Note: We have Standard channels as 100% free to operate. TruthWorld covers video hosting & transcoding. You earn a 90% revenue share and as a partner tier, you pay 10% of direct fan support (Memberships, Superchats, etc.) as a platform commission.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFFD4D4D8),
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDashboardGraphic() {
    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withOpacity(0.12),
                    Colors.transparent,
                  ],
                  radius: 0.8,
                ),
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.analytics_outlined, color: Colors.white, size: 36),
                  SizedBox(width: 12),
                  Icon(Icons.trending_up, color: Colors.white, size: 40),
                  SizedBox(width: 12),
                  Icon(Icons.monetization_on_outlined, color: Colors.white, size: 32),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'TruthWorld Analytics & Monetization',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Unlock 100% Revenue Share & Priority Growth',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistColumn(List<Map<String, String>> items) {
    return Column(
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF3F3F46),
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 12,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['title']!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (item['subtitle']!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        item['subtitle']!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPlanFooterAction(bool isDesktop) {
    return Obx(() {
      final selectedPlan = controller.selectedPlan.value;
      final hasSelected = selectedPlan.isNotEmpty;
      final isCustom = selectedPlan == 'custom';
      final buttonText = hasSelected
          ? 'Continue with ${isCustom ? 'Custom' : 'Standard'} Channel'
          : 'Select Standard or Custom Plan';

      final toggleText = _isShowingAllFeatures
          ? 'Hide All Features'
          : 'Show More / Compare All Features';

      void handleProceed() {
        if (!hasSelected) {
          Get.snackbar(
            'Select Channel Plan',
            'Please tap on either Standard or Custom channel plan to select your plan.',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: const Color(0xFF18181B),
            colorText: Colors.white,
            borderColor: const Color(0xFF7C3AED),
            borderWidth: 1,
            duration: const Duration(seconds: 3),
          );
          return;
        }
      }

      if (isDesktop) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: _toggleShowAllFeatures,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF18181B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF3F3F46)),
                ),
                child: Row(
                  children: [
                    Icon(_isShowingAllFeatures ? Icons.keyboard_arrow_up : Icons.insert_chart_outlined, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      toggleText,
                      style: const TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: handleProceed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasSelected ? const Color(0xFF6366F1) : const Color(0xFF3F3F46),
                  foregroundColor: Colors.white,
                  elevation: hasSelected ? 6 : 1,
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      buttonText,
                      style: const TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward,
                      color: Colors.white,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }

      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: handleProceed,
              style: ElevatedButton.styleFrom(
                backgroundColor: hasSelected ? const Color(0xFF6366F1) : const Color(0xFF3F3F46),
                foregroundColor: Colors.white,
                elevation: hasSelected ? 6 : 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    buttonText,
                    style: const TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward,
                    color: Colors.white,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _toggleShowAllFeatures,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF18181B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF3F3F46)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_isShowingAllFeatures ? Icons.keyboard_arrow_up : Icons.insert_chart_outlined, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    toggleText,
                    style: const TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }

  final List<String> _allCountries = const [
    'Afghanistan', 'Albania', 'Algeria', 'Andorra', 'Angola', 'Argentina', 'Armenia', 'Australia', 'Austria', 'Azerbaijan',
    'Bahamas', 'Bahrain', 'Bangladesh', 'Barbados', 'Belarus', 'Belgium', 'Belize', 'Benin', 'Bhutan', 'Bolivia',
    'Bosnia and Herzegovina', 'Botswana', 'Brazil', 'Brunei', 'Bulgaria', 'Burkina Faso', 'Burundi',
    'Cambodia', 'Cameroon', 'Canada', 'Cape Verde', 'Central African Republic', 'Chad', 'Chile', 'China', 'Colombia',
    'Comoros', 'Congo', 'Costa Rica', 'Croatia', 'Cuba', 'Cyprus', 'Czech Republic',
    'Denmark', 'Djibouti', 'Dominica', 'Dominican Republic',
    'Ecuador', 'Egypt', 'El Salvador', 'Equatorial Guinea', 'Eritrea', 'Estonia', 'Eswatini', 'Ethiopia',
    'Fiji', 'Finland', 'France',
    'Gabon', 'Gambia', 'Georgia', 'Germany', 'Ghana', 'Greece', 'Grenada', 'Guatemala', 'Guinea', 'Guyana',
    'Haiti', 'Honduras', 'Hungary',
    'Iceland', 'India', 'Indonesia', 'Iran', 'Iraq', 'Ireland', 'Israel', 'Italy', 'Ivory Coast',
    'Jamaica', 'Japan', 'Jordan',
    'Kazakhstan', 'Kenya', 'Kiribati', 'Kuwait', 'Kyrgyzstan',
    'Laos', 'Latvia', 'Lebanon', 'Lesotho', 'Liberia', 'Libya', 'Liechtenstein', 'Lithuania', 'Luxembourg',
    'Madagascar', 'Malawi', 'Malaysia', 'Maldives', 'Mali', 'Malta', 'Marshall Islands', 'Mauritania', 'Mauritius', 'Mexico',
    'Micronesia', 'Moldova', 'Monaco', 'Mongolia', 'Montenegro', 'Morocco', 'Mozambique', 'Myanmar',
    'Namibia', 'Nauru', 'Nepal', 'Netherlands', 'New Zealand', 'Nicaragua', 'Niger', 'Nigeria', 'North Korea', 'North Macedonia', 'Norway',
    'Oman',
    'Pakistan', 'Palau', 'Palestine', 'Panama', 'Papua New Guinea', 'Paraguay', 'Peru', 'Philippines', 'Poland', 'Portugal',
    'Qatar',
    'Romania', 'Russia', 'Rwanda',
    'Saint Kitts and Nevis', 'Saint Lucia', 'Saint Vincent', 'Samoa', 'San Marino', 'Saudi Arabia', 'Senegal', 'Serbia', 'Seychelles',
    'Sierra Leone', 'Singapore', 'Slovakia', 'Slovenia', 'Solomon Islands', 'Somalia', 'South Africa', 'South Korea', 'South Sudan', 'Spain', 'Sri Lanka', 'Sudan', 'Suriname', 'Sweden', 'Switzerland', 'Syria',
    'Taiwan', 'Tajikistan', 'Tanzania', 'Thailand', 'Timor-Leste', 'Togo', 'Tonga', 'Trinidad and Tobago', 'Tunisia', 'Turkey', 'Turkmenistan', 'Tuvalu',
    'Uganda', 'Ukraine', 'United Arab Emirates', 'United Kingdom', 'United States', 'Uruguay', 'Uzbekistan',
    'Vanuatu', 'Vatican City', 'Venezuela', 'Vietnam',
    'Yemen',
    'Zambia', 'Zimbabwe'
  ];

  static const Map<String, String> _countryCodeMap = {
    'Afghanistan': 'AF',
    'Albania': 'AL',
    'Algeria': 'DZ',
    'Andorra': 'AD',
    'Angola': 'AO',
    'Argentina': 'AR',
    'Armenia': 'AM',
    'Australia': 'AU',
    'Austria': 'AT',
    'Azerbaijan': 'AZ',
    'Bahamas': 'BS',
    'Bahrain': 'BH',
    'Bangladesh': 'BD',
    'Barbados': 'BB',
    'Belarus': 'BY',
    'Belgium': 'BE',
    'Belize': 'BZ',
    'Benin': 'BJ',
    'Bhutan': 'BT',
    'Bolivia': 'BO',
    'Bosnia and Herzegovina': 'BA',
    'Botswana': 'BW',
    'Brazil': 'BR',
    'Brunei': 'BN',
    'Bulgaria': 'BG',
    'Burkina Faso': 'BF',
    'Burundi': 'BI',
    'Cambodia': 'KH',
    'Cameroon': 'CM',
    'Canada': 'CA',
    'Cape Verde': 'CV',
    'Central African Republic': 'CF',
    'Chad': 'TD',
    'Chile': 'CL',
    'China': 'CN',
    'Colombia': 'CO',
    'Comoros': 'KM',
    'Congo': 'CG',
    'Costa Rica': 'CR',
    'Croatia': 'HR',
    'Cuba': 'CU',
    'Cyprus': 'CY',
    'Czech Republic': 'CZ',
    'Denmark': 'DK',
    'Djibouti': 'DJ',
    'Dominica': 'DM',
    'Dominican Republic': 'DO',
    'Ecuador': 'EC',
    'Egypt': 'EG',
    'El Salvador': 'SV',
    'Equatorial Guinea': 'GQ',
    'Eritrea': 'ER',
    'Estonia': 'EE',
    'Eswatini': 'SZ',
    'Ethiopia': 'ET',
    'Fiji': 'FJ',
    'Finland': 'FI',
    'France': 'FR',
    'Gabon': 'GA',
    'Gambia': 'GM',
    'Georgia': 'GE',
    'Germany': 'DE',
    'Ghana': 'GH',
    'Greece': 'GR',
    'Grenada': 'GD',
    'Guatemala': 'GT',
    'Guinea': 'GN',
    'Guyana': 'GY',
    'Haiti': 'HT',
    'Honduras': 'HN',
    'Hungary': 'HU',
    'Iceland': 'IS',
    'India': 'IN',
    'Indonesia': 'ID',
    'Iran': 'IR',
    'Iraq': 'IQ',
    'Ireland': 'IE',
    'Israel': 'IL',
    'Italy': 'IT',
    'Ivory Coast': 'CI',
    'Jamaica': 'JM',
    'Japan': 'JP',
    'Jordan': 'JO',
    'Kazakhstan': 'KZ',
    'Kenya': 'KE',
    'Kiribati': 'KI',
    'Kuwait': 'KW',
    'Kyrgyzstan': 'KG',
    'Laos': 'LA',
    'Latvia': 'LV',
    'Lebanon': 'LB',
    'Lesotho': 'LS',
    'Liberia': 'LR',
    'Libya': 'LY',
    'Liechtenstein': 'LI',
    'Lithuania': 'LT',
    'Luxembourg': 'LU',
    'Madagascar': 'MG',
    'Malawi': 'MW',
    'Malaysia': 'MY',
    'Maldives': 'MV',
    'Mali': 'ML',
    'Malta': 'MT',
    'Marshall Islands': 'MH',
    'Mauritania': 'MR',
    'Mauritius': 'MU',
    'Mexico': 'MX',
    'Micronesia': 'FM',
    'Moldova': 'MD',
    'Monaco': 'MC',
    'Mongolia': 'MN',
    'Montenegro': 'ME',
    'Morocco': 'MA',
    'Mozambique': 'MZ',
    'Myanmar': 'MM',
    'Namibia': 'NA',
    'Nauru': 'NR',
    'Nepal': 'NP',
    'Netherlands': 'NL',
    'New Zealand': 'NZ',
    'Nicaragua': 'NI',
    'Niger': 'NE',
    'Nigeria': 'NG',
    'North Korea': 'KP',
    'North Macedonia': 'MK',
    'Norway': 'NO',
    'Oman': 'OM',
    'Pakistan': 'PK',
    'Palau': 'PW',
    'Palestine': 'PS',
    'Panama': 'PA',
    'Papua New Guinea': 'PG',
    'Paraguay': 'PY',
    'Peru': 'PE',
    'Philippines': 'PH',
    'Poland': 'PL',
    'Portugal': 'PT',
    'Qatar': 'QA',
    'Romania': 'RO',
    'Russia': 'RU',
    'Rwanda': 'RW',
    'Saint Kitts and Nevis': 'KN',
    'Saint Lucia': 'LC',
    'Saint Vincent': 'VC',
    'Samoa': 'WS',
    'San Marino': 'SM',
    'Saudi Arabia': 'SA',
    'Senegal': 'SN',
    'Serbia': 'RS',
    'Seychelles': 'SC',
    'Sierra Leone': 'SL',
    'Singapore': 'SG',
    'Slovakia': 'SK',
    'Slovenia': 'SI',
    'Solomon Islands': 'SB',
    'Somalia': 'SO',
    'South Africa': 'ZA',
    'South Korea': 'KR',
    'South Sudan': 'SS',
    'Spain': 'ES',
    'Sri Lanka': 'LK',
    'Sudan': 'SD',
    'Suriname': 'SR',
    'Sweden': 'SE',
    'Switzerland': 'CH',
    'Syria': 'SY',
    'Taiwan': 'TW',
    'Tajikistan': 'TJ',
    'Tanzania': 'TZ',
    'Thailand': 'TH',
    'Timor-Leste': 'TL',
    'Togo': 'TG',
    'Tonga': 'TO',
    'Trinidad and Tobago': 'TT',
    'Tunisia': 'TN',
    'Turkey': 'TR',
    'Turkmenistan': 'TM',
    'Tuvalu': 'TV',
    'Uganda': 'UG',
    'Ukraine': 'UA',
    'United Arab Emirates': 'AE',
    'United Kingdom': 'GB',
    'United States': 'US',
    'Uruguay': 'UY',
    'Uzbekistan': 'UZ',
    'Vanuatu': 'VU',
    'Vatican City': 'VA',
    'Venezuela': 'VE',
    'Vietnam': 'VN',
    'Yemen': 'YE',
    'Zambia': 'ZM',
    'Zimbabwe': 'ZW',
  };

  static String _countryCodeToEmoji(String countryCode) {
    if (countryCode.length != 2) return '🏳️';
    final int firstLetter = countryCode.codeUnitAt(0) - 0x41 + 0x1F1E6;
    final int secondLetter = countryCode.codeUnitAt(1) - 0x41 + 0x1F1E6;
    return String.fromCharCodes([firstLetter, secondLetter]);
  }

  Widget _buildCountryFlag(String countryName, {double width = 24, double height = 16}) {
    final code = _countryCodeMap[countryName];
    if (code == null) {
      return const Icon(
        Icons.location_on_outlined,
        color: Colors.white,
        size: 20,
      );
    }

    final flagUrl = 'https://flagcdn.com/w40/${code.toLowerCase()}.png';
    final flagEmoji = _countryCodeToEmoji(code);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: const Color(0xFF3F3F46), width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: CachedNetworkImage(
        imageUrl: flagUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        placeholder: (context, url) => Center(
          child: Text(
            flagEmoji,
            style: TextStyle(fontSize: height * 0.75, height: 1),
          ),
        ),
        errorWidget: (context, url, error) => Center(
          child: Text(
            flagEmoji,
            style: TextStyle(fontSize: height * 0.75, height: 1),
          ),
        ),
      ),
    );
  }

  void _showCountryPicker(BuildContext context) {
    final TextEditingController searchController = TextEditingController();
    final RxList<String> filteredCountries = RxList<String>(_allCountries);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Material(
          color: const Color(0xFF18181B),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.75,
            child: Column(
              children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF3F3F46),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.public_outlined,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Select Country',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF121212),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF27272A)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TextField(
                    controller: searchController,
                    onChanged: (query) {
                      final q = query.trim().toLowerCase();
                      if (q.isEmpty) {
                        filteredCountries.assignAll(_allCountries);
                      } else {
                        filteredCountries.assignAll(
                          _allCountries.where((c) => c.toLowerCase().contains(q)),
                        );
                      }
                    },
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Search country...',
                      hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                      border: InputBorder.none,
                      icon: Icon(Icons.search, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Divider(color: Color(0xFF27272A), height: 1),
              Expanded(
                child: Obx(
                  () => filteredCountries.isEmpty
                      ? const Center(
                          child: Text(
                            'No country found',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        )
                      : ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          itemCount: filteredCountries.length,
                          separatorBuilder: (ctx, i) =>
                              const Divider(color: Color(0xFF27272A), height: 1),
                          itemBuilder: (ctx, i) {
                            final countryName = filteredCountries[i];
                            final isSelected = controller.country.value == countryName;
                            return ListTile(
                              onTap: () {
                                controller.country.value = countryName;
                                Navigator.pop(context);
                              },
                              leading: _buildCountryFlag(countryName, width: 26, height: 18),
                              title: Text(
                                countryName,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight:
                                      isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: Colors.white,
                                ),
                              ),
                              trailing: isSelected
                                  ? const Icon(
                                      Icons.check_circle,
                                      color: Colors.white,
                                      size: 20,
                                    )
                                  : null,
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
}

/// Custom Painter to draw a clean dashed border around upload dropzones
class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;
  final double dash;
  final double borderRadius;

  DashedBorderPainter({
    this.color = const Color(0xFF3F3F3F),
    this.strokeWidth = 1.5,
    this.gap = 4.0,
    this.dash = 6.0,
    this.borderRadius = 12.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );
    final Path path = Path()..addRRect(rrect);

    for (final PathMetric metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final double len = (distance + dash > metric.length)
            ? metric.length - distance
            : dash;
        canvas.drawPath(metric.extractPath(distance, distance + len), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Helper badge item for Channel Plan feature tags
class _PlanBadgeItem extends StatelessWidget {
  final String text;
  const _PlanBadgeItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF27272A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF3F3F46)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check, size: 12, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontFamily: TWTypography.uiFamily,
              fontSize: 11,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// CustomPainter to overlay YouTube standard safe area zones across a 16:9 Banner canvas.
/// Visualizes:
/// - TV Viewable (Full 16:9 - 2560 x 1440)
/// - Desktop Viewable (2560 x 423 band)
/// - All Devices Safe Area (1546 x 423 box for logos & text)
class _YouTubeBannerSafeAreaPainter extends CustomPainter {
  const _YouTubeBannerSafeAreaPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Desktop band (height: 29.375% = 423 / 1440, centered vertically)
    final desktopTop = h * 0.353125;
    final desktopBottom = h * 0.646875;

    // Safe area (width: 60.39% = 1546 / 2560, centered horizontally)
    final safeLeft = w * 0.198047;
    final safeRight = w * 0.801953;

    final shadePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.38)
      ..style = PaintingStyle.fill;

    // Shaded TV regions (top and bottom)
    canvas.drawRect(Rect.fromLTRB(0, 0, w, desktopTop), shadePaint);
    canvas.drawRect(Rect.fromLTRB(0, desktopBottom, w, h), shadePaint);

    // Shaded Desktop side regions (left and right)
    canvas.drawRect(Rect.fromLTRB(0, desktopTop, safeLeft, desktopBottom), shadePaint);
    canvas.drawRect(Rect.fromLTRB(safeRight, desktopTop, w, desktopBottom), shadePaint);

    // Safe Area boundary
    final safeBorderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    canvas.drawRect(Rect.fromLTRB(safeLeft, desktopTop, safeRight, desktopBottom), safeBorderPaint);

    // Desktop boundary lines (horizontal across canvas)
    final guideLinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(0, desktopTop), Offset(safeLeft, desktopTop), guideLinePaint);
    canvas.drawLine(Offset(safeRight, desktopTop), Offset(w, desktopTop), guideLinePaint);
    canvas.drawLine(Offset(0, desktopBottom), Offset(safeLeft, desktopBottom), guideLinePaint);
    canvas.drawLine(Offset(safeRight, desktopBottom), Offset(w, desktopBottom), guideLinePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// CustomPainter to overlay Mobile Safe Area over Desktop 2560x423 strip.
class _YouTubeDesktopSafeAreaPainter extends CustomPainter {
  const _YouTubeDesktopSafeAreaPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final safeLeft = w * 0.198047;
    final safeRight = w * 0.801953;

    final shadePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..style = PaintingStyle.fill;

    canvas.drawRect(Rect.fromLTRB(0, 0, safeLeft, h), shadePaint);
    canvas.drawRect(Rect.fromLTRB(safeRight, 0, w, h), shadePaint);

    final safeBorderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    canvas.drawRect(Rect.fromLTRB(safeLeft, 0, safeRight, h), safeBorderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
