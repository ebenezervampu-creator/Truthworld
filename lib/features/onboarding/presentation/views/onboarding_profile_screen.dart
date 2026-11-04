import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:truthworld/components/ui/google_onboarding_controller.dart';
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/cashfree/cashfree_country_support.dart';
import 'package:truthworld/features/onboarding/presentation/controllers/onboarding_profile_controller.dart';
import 'package:truthworld/features/settings/presentation/views/settings/widgets/settings_theme.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Dedicated full-screen page for onboarding new TruthWorld users.
///
/// Designed to exactly meet Settings Page 100% theme, colors, and fonts:
/// - Settings theme tokens via getSettingsTheme(context)
/// - Responsive layout hierarchy with ResponsiveContainer and ResponsiveBuilder
/// - Surface hierarchy (surface 0xFF121212, surfaceContainer 0xFF1E1E1E, background 0xFF0F0F0F, divider 0xFF1E1E1E)
/// - Standard typography using TWTypography (Roboto UI family + international fallback families)
/// - High-contrast action buttons following TruthWorld Zero White-on-White Policy
class OnboardingProfileScreen extends StatelessWidget {
  const OnboardingProfileScreen({super.key});

  static final List<DropdownMenuItem<String>> _cachedCountryDropdownItems =
      CashfreeCountrySupport.allCountries.map((country) {
    return DropdownMenuItem<String>(
      value: country.code,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            country.flagEmoji,
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              '${country.name} (${country.code})',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFFE8E8E8),
                fontFamily: TWTypography.uiFamily,
                fontFamilyFallback: TWTypography.fallbackFamilies,
              ),
            ),
          ),
        ],
      ),
    );
  }).toList(growable: false);

  static final List<DropdownMenuItem<String>> _cachedLanguageDropdownItems =
      GoogleOnboardingController.staticLanguageOptions.map((lang) {
    final hasNative = lang.nativeName.isNotEmpty &&
        lang.nativeName.toLowerCase() != lang.name.toLowerCase();
    return DropdownMenuItem<String>(
      value: lang.name,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '🌐',
            style: TextStyle(fontSize: 18),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              hasNative ? '${lang.name} (${lang.nativeName})' : lang.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFFE8E8E8),
                fontFamily: TWTypography.uiFamily,
                fontFamilyFallback: TWTypography.fallbackFamilies,
              ),
            ),
          ),
        ],
      ),
    );
  }).toList(growable: false);

  static Future<void> open() async {
    if (!Get.isRegistered<OnboardingProfileController>()) {
      Get.put(OnboardingProfileController());
    } else {
      Get.find<OnboardingProfileController>().reinitialize();
    }
    await Get.toNamed('/onboarding');
  }

  void _showImageSourcePicker(BuildContext context, OnboardingProfileController controller) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: context.colors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(
                  'Change Profile Photo',
                  style: context.typography.title.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Icon(Icons.photo_library_outlined, color: context.colors.textPrimary),
                  title: Text(
                    'Choose from Gallery',
                    style: context.typography.body.copyWith(
                      color: context.colors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    controller.pickAndChangeAvatar(context);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.camera_alt_outlined, color: context.colors.textPrimary),
                  title: Text(
                    'Take a Photo',
                    style: context.typography.body.copyWith(
                      color: context.colors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    controller.pickAndChangeAvatar(context, source: ImageSource.camera);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<OnboardingProfileController>()
        ? Get.find<OnboardingProfileController>()
        : Get.put(OnboardingProfileController());

    final auth = AuthService.to;
    final googleEmail = auth.user?.email ?? '';

    return Theme(
      data: getSettingsTheme(context),
      child: Builder(
        builder: (context) {
          return ResponsiveBuilder(
            builder: (context, deviceType) {
              return Scaffold(
                backgroundColor: context.colors.background,
                appBar: _buildAppBar(context),
                body: SafeArea(
                  child: ResponsiveContainer(
                    child: ListView(
                      padding: EdgeInsets.symmetric(vertical: context.layoutSpacing),
                      children: [
                        _buildProfileHeaderCard(context, controller, auth, googleEmail),
                        SizedBox(height: context.layoutSpacing),
                        _buildAccountDetailsCard(context, controller),
                        SizedBox(height: context.layoutSpacing),
                        _buildCountryCard(context, controller),
                        SizedBox(height: context.layoutSpacing),
                        _buildLanguageCard(context, controller),
                        SizedBox(height: context.layoutSpacing),
                        _buildAgeGroupCard(context, controller),
                        SizedBox(height: context.layoutSpacing),
                        _buildGenderCard(context, controller),
                        SizedBox(height: context.layoutSpacing),
                        _buildActionButtons(context, controller),
                        SizedBox(height: context.layoutSpacing),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: context.colors.background,
      elevation: 0,
      centerTitle: false,
      automaticallyImplyLeading: false,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: context.colors.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.colors.divider),
            ),
            child: Icon(
              Icons.verified_user_rounded,
              color: context.colors.textPrimary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Welcome to TruthWorld',
            style: context.typography.headline.copyWith(
              color: context.colors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeaderCard(
    BuildContext context,
    OnboardingProfileController controller,
    AuthService auth,
    String googleEmail,
  ) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: context.layoutSpacing),
      decoration: BoxDecoration(
        borderRadius: context.radius.lg,
        border: Border.all(color: context.colors.divider),
      ),
      child: Material(
        color: context.colors.surface,
        borderRadius: context.radius.lg,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.all(context.layoutSpacing),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Obx(() {
                final photoUrl = controller.activeAvatarUrl.value;
                final isUploading = controller.isUploadingPhoto.value;
                final authName = auth.activeDisplayName;
                final name = controller.displayNameController.text.isNotEmpty
                    ? controller.displayNameController.text
                    : (authName.isNotEmpty ? authName : 'New TruthSeeker');

                return Row(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        UserAvatar(
                          radius: 36,
                          photoUrl: photoUrl.isNotEmpty ? photoUrl : null,
                          displayName: name,
                          backgroundColor: context.colors.surfaceContainer,
                          textColor: context.colors.textPrimary,
                          fontSize: 28,
                        ),
                        if (isUploading)
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(160),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: context.typography.title.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: context.colors.textPrimary,
                            ),
                          ),
                          if (googleEmail.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: context.colors.surfaceContainer,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: context.colors.divider),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle, size: 12, color: AppColors.success),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      googleEmail,
                                      overflow: TextOverflow.ellipsis,
                                      style: context.typography.caption.copyWith(
                                        fontSize: 11,
                                        color: context.colors.textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              }),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showImageSourcePicker(context, controller),
                  icon: Icon(Icons.camera_alt_outlined, size: 16, color: context.colors.textPrimary),
                  label: Text(
                    'Change Photo',
                    style: context.typography.button.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: context.colors.surfaceContainer,
                    side: BorderSide(color: context.colors.divider),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountDetailsCard(BuildContext context, OnboardingProfileController controller) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: context.layoutSpacing),
      decoration: BoxDecoration(
        borderRadius: context.radius.lg,
        border: Border.all(color: context.colors.divider),
      ),
      child: Material(
        color: context.colors.surface,
        borderRadius: context.radius.lg,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.all(context.layoutSpacing),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Account Details',
                style: context.typography.title.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),

              // Display Name Field
              Text(
                'Full Name / Display Name',
                style: context.typography.bodySmall.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: context.colors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Obx(() {
                final err = controller.displayNameError.value;
                return TextField(
                  controller: controller.displayNameController,
                  maxLength: ContentValidator.defaultMaxDisplayNameLength,
                  buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                  inputFormatters: TruthworldTextInputFormatters.internationalWithLimit(
                    ContentValidator.defaultMaxDisplayNameLength,
                  ),
                  style: context.typography.body.copyWith(
                    fontSize: 15,
                    color: context.colors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    prefixIcon: Icon(
                      Icons.person_outline_rounded,
                      color: context.colors.textPrimary,
                      size: 20,
                    ),
                    hintText: 'Enter your name',
                    hintStyle: context.typography.body.copyWith(
                      fontSize: 14,
                      color: context.colors.textTertiary,
                    ),
                    errorText: err,
                    errorStyle: const TextStyle(
                      fontSize: 12,
                      color: AppColors.error,
                    ),
                    filled: true,
                    fillColor: context.colors.surfaceContainer,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: context.colors.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: context.colors.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: context.colors.brand, width: 1.5),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),

              // Username / Handle Field
              Text(
                'Username / Handle',
                style: context.typography.bodySmall.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: context.colors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Obx(() {
                final err = controller.usernameError.value;
                return TextField(
                  controller: controller.usernameController,
                  maxLength: ContentValidator.defaultMaxHandleLength,
                  buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9_.]')),
                    TruthworldTextInputFormatters.profanityFilter,
                    LengthLimitingTextInputFormatter(ContentValidator.defaultMaxHandleLength),
                  ],
                  style: context.typography.body.copyWith(
                    fontSize: 15,
                    color: context.colors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    prefixIcon: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Text(
                        '@',
                        style: context.typography.title.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: context.colors.textPrimary,
                        ),
                      ),
                    ),
                    hintText: 'your_username',
                    hintStyle: context.typography.body.copyWith(
                      fontSize: 14,
                      color: context.colors.textTertiary,
                    ),
                    errorText: err,
                    errorStyle: const TextStyle(
                      fontSize: 12,
                      color: AppColors.error,
                    ),
                    filled: true,
                    fillColor: context.colors.surfaceContainer,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: context.colors.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: context.colors.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: context.colors.brand, width: 1.5),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCountryCard(BuildContext context, OnboardingProfileController controller) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: context.layoutSpacing),
      decoration: BoxDecoration(
        borderRadius: context.radius.lg,
        border: Border.all(color: context.colors.divider),
      ),
      child: Material(
        color: context.colors.surface,
        borderRadius: context.radius.lg,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.all(context.layoutSpacing),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Country / Region',
                    style: context.typography.title.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: context.colors.surfaceContainer,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: context.colors.divider),
                    ),
                    child: Text(
                      'Country',
                      style: context.typography.caption.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Truthworld uses this to localize your content recommendations, currency, and payment options.',
                style: context.typography.bodySmall.copyWith(
                  fontSize: 13,
                  color: context.colors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Obx(() {
                final selectedCode = controller.selectedCountry.value;
                final countryList = controller.countryOptions;
                final hasSelected = selectedCode != null &&
                    countryList.any((c) => c.code == selectedCode);
                final effectiveVal = hasSelected
                    ? selectedCode
                    : (countryList.isNotEmpty ? countryList.first.code : null);

                return DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: effectiveVal,
                  dropdownColor: context.colors.surfaceContainer,
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: context.colors.textPrimary,
                  ),
                  style: context.typography.body.copyWith(
                    fontSize: 14,
                    color: context.colors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    prefixIcon: Icon(
                      Icons.public_rounded,
                      color: context.colors.textPrimary,
                      size: 20,
                    ),
                    filled: true,
                    fillColor: context.colors.surfaceContainer,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: context.colors.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: context.colors.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: context.colors.brand, width: 1.5),
                    ),
                  ),
                  items: countryList.length == _cachedCountryDropdownItems.length
                      ? _cachedCountryDropdownItems
                      : countryList.map((country) {
                          return DropdownMenuItem<String>(
                            value: country.code,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  country.flagEmoji,
                                  style: const TextStyle(fontSize: 18),
                                ),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    '${country.name} (${country.code})',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: context.colors.textPrimary,
                                      fontFamily: TWTypography.uiFamily,
                                      fontFamilyFallback: TWTypography.fallbackFamilies,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(growable: false),
                  onChanged: (val) {
                    if (val != null) {
                      controller.selectCountry(val);
                    }
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageCard(BuildContext context, OnboardingProfileController controller) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: context.layoutSpacing),
      decoration: BoxDecoration(
        borderRadius: context.radius.lg,
        border: Border.all(color: context.colors.divider),
      ),
      child: Material(
        color: context.colors.surface,
        borderRadius: context.radius.lg,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.all(context.layoutSpacing),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Primary Language',
                    style: context.typography.title.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: context.colors.surfaceContainer,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: context.colors.divider),
                    ),
                    child: Text(
                      '130+ Global',
                      style: context.typography.caption.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'TruthWorld welcomes creators and users from all languages and backgrounds worldwide. Select your primary language to personalize your experience.',
                style: context.typography.bodySmall.copyWith(
                  fontSize: 13,
                  color: context.colors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Obx(() {
                final currentLang = controller.selectedLanguage.value;
                final languageList = controller.languageOptions;
                final hasSelected = languageList.any((l) => l.name.toLowerCase() == currentLang.toLowerCase());
                final effectiveVal = hasSelected
                    ? languageList.firstWhere((l) => l.name.toLowerCase() == currentLang.toLowerCase()).name
                    : (languageList.isNotEmpty ? languageList.first.name : 'English');

                return DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: effectiveVal,
                  dropdownColor: context.colors.surfaceContainer,
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: context.colors.textPrimary,
                  ),
                  style: context.typography.body.copyWith(
                    fontSize: 14,
                    color: context.colors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    prefixIcon: Icon(
                      Icons.language_rounded,
                      color: context.colors.textPrimary,
                      size: 20,
                    ),
                    filled: true,
                    fillColor: context.colors.surfaceContainer,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: context.colors.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: context.colors.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: context.colors.brand, width: 1.5),
                    ),
                  ),
                  items: languageList.length == _cachedLanguageDropdownItems.length
                      ? _cachedLanguageDropdownItems
                      : languageList.map((lang) {
                          final hasNative = lang.nativeName.isNotEmpty &&
                              lang.nativeName.toLowerCase() != lang.name.toLowerCase();
                          return DropdownMenuItem<String>(
                            value: lang.name,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  '🌐',
                                  style: TextStyle(fontSize: 18),
                                ),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    hasNative ? '${lang.name} (${lang.nativeName})' : lang.name,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: context.colors.textPrimary,
                                      fontFamily: TWTypography.uiFamily,
                                      fontFamilyFallback: TWTypography.fallbackFamilies,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(growable: false),
                  onChanged: (val) {
                    if (val != null) {
                      controller.selectLanguage(val);
                    }
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAgeGroupCard(BuildContext context, OnboardingProfileController controller) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: context.layoutSpacing),
      decoration: BoxDecoration(
        borderRadius: context.radius.lg,
        border: Border.all(color: context.colors.divider),
      ),
      child: Material(
        color: context.colors.surface,
        borderRadius: context.radius.lg,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.all(context.layoutSpacing),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Age Group',
                    style: context.typography.title.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: context.colors.surfaceContainer,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: context.colors.divider),
                    ),
                    child: Text(
                      '18+ Only',
                      style: context.typography.caption.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: context.colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Truthworld is strictly for users aged 18 and older. Helps recommend age-appropriate content.',
                style: context.typography.bodySmall.copyWith(
                  fontSize: 13,
                  color: context.colors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Obx(() {
                final selectedAge = controller.selectedAgeGroup.value;
                return Wrap(
                  spacing: 8,
                  runSpacing: 10,
                  children: controller.ageGroups.map((option) {
                    final isSelected = selectedAge == option;
                    return ChoiceChip(
                      label: Text(
                        option,
                        style: TextStyle(
                          fontSize: 13,
                          color: isSelected ? Colors.black : context.colors.textPrimary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontFamily: TWTypography.uiFamily,
                          fontFamilyFallback: TWTypography.fallbackFamilies,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: Colors.white,
                      backgroundColor: context.colors.surfaceContainer,
                      side: BorderSide(
                        color: isSelected ? Colors.white : context.colors.divider,
                      ),
                      onSelected: (selected) {
                        controller.selectAgeGroup(selected ? option : null);
                      },
                    );
                  }).toList(),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenderCard(BuildContext context, OnboardingProfileController controller) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: context.layoutSpacing),
      decoration: BoxDecoration(
        borderRadius: context.radius.lg,
        border: Border.all(color: context.colors.divider),
      ),
      child: Material(
        color: context.colors.surface,
        borderRadius: context.radius.lg,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.all(context.layoutSpacing),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Gender',
                    style: context.typography.title.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: context.colors.surfaceContainer,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: context.colors.divider),
                    ),
                    child: Text(
                      'Optional',
                      style: context.typography.caption.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Helps ensure diverse representation in content recommendations.',
                style: context.typography.bodySmall.copyWith(
                  fontSize: 13,
                  color: context.colors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Obx(() {
                final selectedGender = controller.selectedGender.value;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 10,
                      children: controller.genders.map((option) {
                        final isSelected = selectedGender == option;
                        return ChoiceChip(
                          label: Text(
                            option,
                            style: TextStyle(
                              fontSize: 13,
                              color: isSelected ? Colors.black : context.colors.textPrimary,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontFamily: TWTypography.uiFamily,
                              fontFamilyFallback: TWTypography.fallbackFamilies,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: Colors.white,
                          backgroundColor: context.colors.surfaceContainer,
                          side: BorderSide(
                            color: isSelected ? Colors.white : context.colors.divider,
                          ),
                          onSelected: (selected) {
                            controller.selectGender(selected ? option : null);
                          },
                        );
                      }).toList(),
                    ),
                    if (selectedGender == 'Self-describe') ...[
                      const SizedBox(height: 14),
                      TextField(
                        controller: controller.selfDescribeController,
                        maxLength: 100,
                        buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                        inputFormatters: TruthworldTextInputFormatters.withLimit(100),
                        style: context.typography.body.copyWith(
                          fontSize: 14,
                          color: context.colors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Self-describe (optional)',
                          hintStyle: context.typography.body.copyWith(
                            fontSize: 14,
                            color: context.colors.textTertiary,
                          ),
                          filled: true,
                          fillColor: context.colors.surfaceContainer,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: context.colors.divider),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: context.colors.divider),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: context.colors.brand, width: 1.5),
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, OnboardingProfileController controller) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.layoutSpacing),
      child: Obx(() {
        final saving = controller.isSaving.value;
        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: saving ? null : () => controller.finishAndGoToHome(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black, // Rule: Black on white
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: saving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Continue & Finish',
                            style: context.typography.button.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.black),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: saving ? null : controller.skipAndGoToHome,
                style: OutlinedButton.styleFrom(
                  backgroundColor: context.colors.surfaceContainer,
                  side: BorderSide(color: context.colors.divider),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Skip & Go to Home',
                  style: context.typography.button.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: context.colors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}
