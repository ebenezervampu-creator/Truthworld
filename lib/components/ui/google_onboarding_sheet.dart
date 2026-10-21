import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/components/ui/google_onboarding_controller.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/cashfree/cashfree_country_support.dart';
import 'package:truthworld/features/library/presentation/views/library/widgets/library_constants.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Modal bottom sheet presented after a Google Sign-In or from Settings to collect / edit:
/// 1. Country / Region (all 240+ countries & territories worldwide)
/// 2. Primary Language (implemented exactly like Country selection with 130+ languages)
/// 3. Optional Age Group starting from 18+ (18–24, 25–34, 35–44, 45–54, 55–64, 65+, Prefer not to say)
/// 4. Optional Gender (Male, Female, Non-binary, Prefer not to say, Self-describe)
class GoogleOnboardingSheet extends StatelessWidget {
  const GoogleOnboardingSheet({super.key});

  static final List<DropdownMenuItem<String>> _cachedCountryDropdownItems =
      CashfreeCountrySupport.allCountries.map((country) {
    return DropdownMenuItem<String>(
      value: country.code,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(country.flagEmoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              '${country.name} (${country.code})',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, color: primaryText),
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
          const Text('🌐', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              hasNative ? '${lang.name} (${lang.nativeName})' : lang.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, color: primaryText),
            ),
          ),
        ],
      ),
    );
  }).toList(growable: false);

  /// Helper to route to the dedicated onboarding profile page
  static Future<void> show(BuildContext context) async {
    // Safety guard: Never show for unsigned, anonymous, or unauthenticated users
    final auth = AuthService.to;
    final currentUser = auth.user;
    if (currentUser == null ||
        currentUser.isAnonymous ||
        !auth.isAuthenticated.value) {
      return;
    }

    await Get.toNamed('/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.isRegistered<GoogleOnboardingController>()
        ? Get.find<GoogleOnboardingController>()
        : Get.put(GoogleOnboardingController());

    final isFirstTime = controller.isFirstTimeOnboarding;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle indicator
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.bgDivider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: buttonBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.bgDivider),
                  ),
                  child: const Icon(
                    Icons.person_outline,
                    color: primaryText,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isFirstTime
                        ? 'Complete Your Profile'
                        : (controller.isPhoneUser ? 'Profile Preferences' : 'Age Group & Gender'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: primaryText,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isFirstTime
                  ? (controller.isPhoneUser
                      ? 'Set up your username and preferences to personalize your experience on Truthworld.'
                      : 'Truthworld uses this to recommend age-appropriate content and build a more inclusive platform for everyone.')
                  : 'Update your preferences to help Truthworld recommend age-appropriate content.',
              style: const TextStyle(
                fontSize: 13,
                color: secondaryText,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),

            // Country / Region Section (All 240+ Countries Worldwide)
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
            const SizedBox(height: 4),
            const Text(
              'Truthworld localizes your content recommendations, currency, and payment options based on your country.',
              style: TextStyle(
                fontSize: 13,
                color: secondaryText,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
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
                              Text(country.flagEmoji, style: const TextStyle(fontSize: 18)),
                              const SizedBox(width: 10),
                              Flexible(
                                child: Text(
                                  '${country.name} (${country.code})',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14, color: primaryText),
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
            const SizedBox(height: 20),

            // Primary Language Section (Implemented Exactly Like Country Selection)
            _buildLanguageSection(context, controller),
            const SizedBox(height: 20),

            // Age Group Section (Optional - 18+ Only)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Which age group are you in?',
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
                    '18+',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: primaryText,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Truthworld is exclusively for users aged 18 and older. Helps recommend age-appropriate content.',
              style: TextStyle(
                fontSize: 13,
                color: secondaryText,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),

            // Age Group selection chips
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
                        color: isSelected
                            ? Colors.black
                            : primaryText,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
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
            const SizedBox(height: 20),

            // Gender Section (Optional)
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
            const SizedBox(height: 4),
            const Text(
              'Helps ensure diverse representation in content recommendations.',
              style: TextStyle(
                fontSize: 13,
                color: secondaryText,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),

            // Gender selection chips
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
                            color: isSelected
                                ? Colors.black
                                : primaryText,
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.normal,
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

                  // Self-describe custom input
                  if (selectedGender == 'Self-describe') ...[
                    const SizedBox(height: 12),
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
            const SizedBox(height: 24),

            // Action Buttons
            Obx(() {
              final saving = controller.isSaving.value;
              return Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: saving ? null : () => controller.onSave(context),
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
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.black),
                              ),
                            )
                          : const Text(
                              'Save Preferences',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                    ),
                  ),
                  if (isFirstTime) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: saving ? null : () => controller.onSkip(context),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: buttonBg,
                          side: const BorderSide(color: AppColors.bgDivider),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          'Skip for now',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: secondaryText,
                          ),
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
    );
  }

  /// Primary Language section implemented exactly like Country selection
  Widget _buildLanguageSection(BuildContext context, GoogleOnboardingController controller) {
    return Column(
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
        const SizedBox(height: 4),
        const Text(
          'TruthWorld welcomes creators and users from all languages and backgrounds worldwide. Select your primary language to personalize your experience.',
          style: TextStyle(
            fontSize: 13,
            color: secondaryText,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),

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
                          const Text('🌐', style: TextStyle(fontSize: 18)),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              hasNative ? '${lang.name} (${lang.nativeName})' : lang.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14, color: primaryText),
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
    );
  }
}
