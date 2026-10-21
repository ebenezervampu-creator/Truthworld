import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:truthworld/components/ui/google_onboarding_controller.dart';
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/cashfree/cashfree_country_support.dart';
import 'package:truthworld/features/library/presentation/views/library/widgets/library_constants.dart';
import 'package:truthworld/features/onboarding/presentation/controllers/onboarding_profile_controller.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Dedicated full-screen page for onboarding new TruthWorld users.
///
/// Designed with Library Page theme, fonts, and UI styling:
/// - Library native typography and dark surface hierarchy (bgColor, cardColor, buttonBg)
/// - Profile header with avatar, user details, and photo customization
/// - Account details (Full Name & Handle)
/// - Complete Country / Region selector with all 240+ countries and flag emojis
/// - Primary Language selector implemented exactly like Country selection with 130+ languages
/// - 18+ Age group selection and Gender selection
/// - Clean high-contrast action buttons leading to TruthWorld Home
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
                color: primaryText,
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
                color: primaryText,
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
      backgroundColor: cardColor,
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
                    color: AppColors.bgDivider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Text(
                  'Change Profile Photo',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryText,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined, color: primaryText),
                  title: const Text(
                    'Choose from Gallery',
                    style: TextStyle(color: primaryText, fontWeight: FontWeight.w500),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    controller.pickAndChangeAvatar(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined, color: primaryText),
                  title: const Text(
                    'Take a Photo',
                    style: TextStyle(color: primaryText, fontWeight: FontWeight.w500),
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

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: surfaceColor.withValues(alpha: 0.95),
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: buttonBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.bgDivider),
              ),
              child: const Icon(
                Icons.verified_user_rounded,
                color: primaryText,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Welcome to TruthWorld',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: primaryText,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Profile Header Card (Library Profile Header Style)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.bgDivider),
                ),
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
                                backgroundColor: buttonBg,
                                textColor: primaryText,
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
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: primaryText,
                                  ),
                                ),

                                if (googleEmail.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: buttonBg,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppColors.bgDivider),
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
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: secondaryText,
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
                        icon: const Icon(Icons.camera_alt_outlined, size: 16, color: primaryText),
                        label: const Text(
                          'Change Photo',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: primaryText,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: buttonBg,
                          side: const BorderSide(color: AppColors.bgDivider),
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
              const SizedBox(height: 16),

              // 2. Account Details Card (Full Name & Handle)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.bgDivider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Account Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: primaryText,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Display Name Field
                    const Text(
                      'Full Name / Display Name',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: secondaryText,
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
                        style: const TextStyle(
                          fontSize: 15,
                          color: primaryText,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(
                            Icons.person_outline_rounded,
                            color: primaryText,
                            size: 20,
                          ),
                          hintText: 'Enter your name',
                          hintStyle: const TextStyle(
                            fontSize: 14,
                            color: secondaryText,
                          ),
                          errorText: err,
                          errorStyle: const TextStyle(
                            fontSize: 12,
                            color: AppColors.error,
                          ),
                          filled: true,
                          fillColor: buttonBg,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.bgDivider),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.bgDivider),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: primaryText),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),

                    // Username / Handle Field
                    const Text(
                      'Username / Handle',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: secondaryText,
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
                        style: const TextStyle(
                          fontSize: 15,
                          color: primaryText,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          prefixIcon: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: const Text(
                              '@',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: primaryText,
                              ),
                            ),
                          ),
                          hintText: 'your_username',
                          hintStyle: const TextStyle(
                            fontSize: 14,
                            color: secondaryText,
                          ),
                          errorText: err,
                          errorStyle: const TextStyle(
                            fontSize: 12,
                            color: AppColors.error,
                          ),
                          filled: true,
                          fillColor: buttonBg,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.bgDivider),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.bgDivider),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: primaryText),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 3. Country / Region Section (All 240+ Countries Worldwide)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.bgDivider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Country / Region',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: primaryText,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: buttonBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.bgDivider),
                          ),
                          child: const Text(
                            'Country',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: secondaryText,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Truthworld uses this to localize your content recommendations, currency, and payment options.',
                      style: TextStyle(
                        fontSize: 13,
                        color: secondaryText,
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
                        dropdownColor: cardColor,
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: primaryText,
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          color: primaryText,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(
                            Icons.public_rounded,
                            color: primaryText,
                            size: 20,
                          ),
                          filled: true,
                          fillColor: buttonBg,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.bgDivider),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.bgDivider),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: primaryText),
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
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: primaryText,
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
              const SizedBox(height: 16),

              // 4. Primary Language Section (Implemented Exactly Like Country Selection)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.bgDivider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Primary Language',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: primaryText,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: buttonBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.bgDivider),
                          ),
                          child: const Text(
                            '130+ Global',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: secondaryText,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'TruthWorld welcomes creators and users from all languages and backgrounds worldwide. Select your primary language to personalize your experience.',
                      style: TextStyle(
                        fontSize: 13,
                        color: secondaryText,
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
                        dropdownColor: cardColor,
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: primaryText,
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          color: primaryText,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(
                            Icons.language_rounded,
                            color: primaryText,
                            size: 20,
                          ),
                          filled: true,
                          fillColor: buttonBg,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.bgDivider),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.bgDivider),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: primaryText),
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
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: primaryText,
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
              const SizedBox(height: 16),

              // 5. Age Group Section (Strictly 18+)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.bgDivider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Age Group',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: primaryText,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: buttonBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.bgDivider),
                          ),
                          child: const Text(
                            '18+ Only',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: primaryText,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Truthworld is strictly for users aged 18 and older. Helps recommend age-appropriate content.',
                      style: TextStyle(
                        fontSize: 13,
                        color: secondaryText,
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
                                color: isSelected ? Colors.black : primaryText,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: Colors.white,
                            backgroundColor: buttonBg,
                            side: BorderSide(
                              color: isSelected ? Colors.white : AppColors.bgDivider,
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
              const SizedBox(height: 16),

              // 6. Gender Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.bgDivider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Gender',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: primaryText,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: buttonBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.bgDivider),
                          ),
                          child: const Text(
                            'Optional',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: secondaryText,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Helps ensure diverse representation in content recommendations.',
                      style: TextStyle(
                        fontSize: 13,
                        color: secondaryText,
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
                                    color: isSelected ? Colors.black : primaryText,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                                selected: isSelected,
                                selectedColor: Colors.white,
                                backgroundColor: buttonBg,
                                side: BorderSide(
                                  color: isSelected ? Colors.white : AppColors.bgDivider,
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
                              style: const TextStyle(
                                fontSize: 14,
                                color: primaryText,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Self-describe (optional)',
                                hintStyle: const TextStyle(
                                  fontSize: 14,
                                  color: secondaryText,
                                ),
                                filled: true,
                                fillColor: buttonBg,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppColors.bgDivider),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: primaryText),
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
              const SizedBox(height: 24),

              // 7. Action Buttons: Finish & Go to Home
              Obx(() {
                final saving = controller.isSaving.value;
                return Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: saving ? null : () => controller.finishAndGoToHome(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryText,
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
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Continue & Finish',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.black),
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
                          backgroundColor: buttonBg,
                          side: const BorderSide(color: AppColors.bgDivider),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Skip & Go to Home',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: secondaryText,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}