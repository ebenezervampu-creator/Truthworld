import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/channel/presentation/controllers/channel_controller_unified.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_branding_card.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_country_card.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_details_card.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_input_fields.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_language_card.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_links_visibility_cards.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_plan_agreements_cards.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_plan_selection_view.dart';
import 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_type_category_cards.dart';
import 'package:truthworld/theme/app_theme.dart';

export 'package:truthworld/features/channel/presentation/views/channel/wizard/painters/channel_banner_painters.dart';
export 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_plan_badge_item.dart';
export 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_country_card.dart';
export 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_language_card.dart';
export 'package:truthworld/features/channel/presentation/views/channel/wizard/widgets/channel_wizard_plan_selection_view.dart';
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
      var initialText = controller.socialLinks[key] ?? '';
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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (AuthService.to.hasChannel.value && AuthService.to.userChannel != null) {
        Get.offAllNamed('/studio', arguments: {
          'channel': AuthService.to.userChannel,
        });
        return;
      }
      final ch = await AuthService.to.ensureChannelLoaded();
      if (ch != null && mounted) {
        Get.offAllNamed('/studio', arguments: {
          'channel': ch,
        });
      }
    });
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
      AppSnackbar.warning(
        'You can add up to 5 tags.',
        title: 'Tag Limit',
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
                  Obx(
                    () => controller.isSubmitting.value
                        ? const ColoredBox(
                            color: Colors.black54,
                            child: Center(
                              child: CircularProgressIndicator(),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              );
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
          bottom: BorderSide(color: Color(0xFF27272A)),
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
              children: const [
                Text(
                  'Create Channel',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 2),
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
              const PopupMenuItem(
                value: 'delete_draft',
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline,
                      color: Colors.white,
                      size: 20,
                    ),
                    SizedBox(width: 12),
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
  // ========================================================================
  // MODULAR CHANNEL WIZARD CARDS (CARDS 1-10)
  // ========================================================================

  // CARD 1: BRANDING
  Widget _buildBrandingCard(bool isDarkMode) {
    return ChannelWizardBrandingCard(
      controller: controller,
      isDarkMode: isDarkMode,
    );
  }

  // CARD 2: DETAILS
  Widget _buildDetailsCard(bool isDarkMode) {
    return ChannelWizardDetailsCard(
      controller: controller,
      tagList: _tagList,
      isDarkMode: isDarkMode,
    );
  }

  // CARD 3: CHANNEL TYPE
  Widget _buildChannelTypeCard(bool isDarkMode) {
    return ChannelWizardTypeCard(
      controller: controller,
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildChannelTypeContent(bool isDarkMode) {
    return ChannelWizardTypeCard(
      controller: controller,
      isDarkMode: isDarkMode,
      contentOnly: true,
    );
  }

  // CARD 4: CATEGORY
  Widget _buildCategoryCard(bool isDarkMode) {
    return ChannelWizardCategoryCard(
      controller: controller,
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildCategoryContent(bool isDarkMode) {
    return ChannelWizardCategoryCard(
      controller: controller,
      isDarkMode: isDarkMode,
      contentOnly: true,
    );
  }

  // CARD 5: LINKS
  Widget _buildLinksCard(bool isDarkMode) {
    return ChannelWizardLinksCard(
      controller: controller,
      isDarkMode: isDarkMode,
      getSocialController: _getSocialController,
    );
  }

  Widget _buildLinksContent(bool isDarkMode) {
    return ChannelWizardLinksCard(
      controller: controller,
      isDarkMode: isDarkMode,
      getSocialController: _getSocialController,
      contentOnly: true,
    );
  }

  // CARD 6: VISIBILITY
  Widget _buildVisibilityCard(bool isDarkMode) {
    return ChannelWizardVisibilityCard(
      controller: controller,
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildVisibilityContent(bool isDarkMode) {
    return ChannelWizardVisibilityCard(
      controller: controller,
      isDarkMode: isDarkMode,
      contentOnly: true,
    );
  }

  // CARD 7: COUNTRY
  Widget _buildCountryCard(bool isDarkMode) {
    return ChannelWizardCountryCard(
      controller: controller,
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildCountryContent(bool isDarkMode) {
    return ChannelWizardCountryCard(
      controller: controller,
      isDarkMode: isDarkMode,
      contentOnly: true,
    );
  }

  Widget _buildCountryFlag(String countryName, {double width = 24, double height = 16}) {
    return ChannelWizardCountryCard.buildCountryFlag(countryName, width: width, height: height);
  }

  void _showCountryPicker(BuildContext context) {
    ChannelWizardCountryCard.showCountryPicker(context, controller);
  }

  // CARD 8: LANGUAGE
  Widget _buildLanguageCard(bool isDarkMode) {
    return ChannelWizardLanguageCard(
      controller: controller,
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildLanguageContent(bool isDarkMode) {
    return ChannelWizardLanguageCard(
      controller: controller,
      isDarkMode: isDarkMode,
      contentOnly: true,
    );
  }

  // CARD 9: PLAN
  Widget _buildPlanCard(bool isDarkMode) {
    return ChannelWizardPlanCard(
      controller: controller,
      isDarkMode: isDarkMode,
    );
  }

  Widget _buildPlanContent(bool isDarkMode) {
    return ChannelWizardPlanCard(
      controller: controller,
      isDarkMode: isDarkMode,
      contentOnly: true,
    );
  }

  // CARD 10: AGREEMENTS & SUBMIT
  Widget _buildAgreementsAndSubmitCard(bool isDarkMode) {
    return ChannelWizardAgreementsCard(
      controller: controller,
      isDarkMode: isDarkMode,
      onSubmit: _validateAndSubmitChannel,
    );
  }

  Widget _buildAgreementsAndSubmitContent(bool isDarkMode) {
    return ChannelWizardAgreementsCard(
      controller: controller,
      isDarkMode: isDarkMode,
      onSubmit: _validateAndSubmitChannel,
      contentOnly: true,
    );
  }

  // ========================================================================
  // INPUT HELPERS
  // ========================================================================
  Widget _buildFieldLabel(String label, {required bool isRequired}) {
    return ChannelWizardFieldLabel(label, isRequired: isRequired);
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
    return ChannelWizardInputField(
      controller: controller,
      hintText: hintText,
      prefixText: prefixText,
      maxLines: maxLines,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      validator: validator,
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
            onPressed: Get.back,
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
            onPressed: Get.back,
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
      AppSnackbar.warning('Please select and upload a Channel Banner image.');
      return;
    }

    if (controller.bannerStatus.value == 'REJECTED') {
      AppSnackbar.warning(
        'Your banner was rejected: ${controller.bannerStatusReason.value}. Please upload a different image.',
        title: 'Banner Rejected',
      );
      return;
    }

    // 2. Channel Avatar
    if (controller.avatarImageData.value == null && controller.avatarUrl.value.isEmpty) {
      AppSnackbar.warning('Please select and upload a Channel Avatar image.');
      return;
    }

    if (controller.avatarStatus.value == 'REJECTED') {
      AppSnackbar.warning(
        'Your avatar was rejected: ${controller.avatarStatusReason.value}. Please upload a different image.',
        title: 'Avatar Rejected',
      );
      return;
    }

    // 3. Channel Name
    if (controller.channelName.text.trim().isEmpty) {
      AppSnackbar.warning('Please enter a Channel Name.');
      return;
    }

    // 4. Channel Handle
    if (controller.customUrl.text.trim().isEmpty) {
      AppSnackbar.warning('Please enter a Channel Handle.');
      return;
    }

    // 5. Description
    if (controller.description.text.trim().isEmpty) {
      AppSnackbar.warning('Please enter a Channel Description.');
      return;
    }

    // 6. Tags (at least 1 required)
    final parsedTags = controller.tags.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    if (parsedTags.isEmpty && _tagList.isEmpty) {
      AppSnackbar.warning('Please add at least 1 Tag.');
      return;
    }

    // 7. Category (at least 1 required)
    if (controller.selectedCategories.isEmpty &&
        (controller.selectedCategory.value == null ||
            controller.selectedCategory.value!.trim().isEmpty)) {
      AppSnackbar.warning('Please select at least 1 Category.');
      return;
    }

    // 8. Agreements
    if (!controller.agreeTerms.value || !controller.agreeGuidelines.value) {
      AppSnackbar.warning('Please agree to both Terms & Conditions and Community Guidelines.');
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
        AppSnackbar.warning('Please enter a custom business domain email (e.g. contact@yourcompany.com).');
        return;
      }
      if (!controller.isCustomBusinessEmail(emailText)) {
        AppSnackbar.warning('Please enter a custom business domain email. Free email services (@gmail.com, @yahoo.com) are not allowed for Organization / Company channels.');
        return;
      }
    }

    controller.isAgreed.value = true;
    controller.createChannel();
  }



  // ========================================================================
  // PLAN SELECTION SCREEN (STEP 1 BEFORE CHANNEL SETUP)
  // ========================================================================
  // ========================================================================
  // PLAN SELECTION SCREEN (STEP 1 BEFORE CHANNEL SETUP)
  // ========================================================================
  Widget _buildPlanSelectionScreen(
    BuildContext context,
    bool isDesktop,
    bool isDarkMode,
  ) {
    return ChannelWizardPlanSelectionView(
      controller: controller,
      isDesktop: isDesktop,
      isDarkMode: isDarkMode,
      onClose: () => _handleClose(isDarkMode),
    );
  }
}
