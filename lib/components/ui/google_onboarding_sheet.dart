import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/components/ui/google_onboarding_controller.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Modal bottom sheet presented after a Google Sign-In or from Settings to collect / edit:
/// 1. Country / Region (India, United States, United Kingdom, etc.)
/// 2. Optional Age Group starting from 18+ (18–24, 25–34, 35–44, 45–54, 55–64, 65+, Prefer not to say)
/// 3. Optional Gender (Male, Female, Non-binary, Prefer not to say, Self-describe)
class GoogleOnboardingSheet extends StatelessWidget {
  const GoogleOnboardingSheet({super.key});

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
        color: AppColors.bgSurface,
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
                  color: AppColors.textTertiary.withAlpha(100),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Row(
              children: [
                const Icon(
                  Icons.person_outline,
                  color: Colors.white, // Rule: Icon must be white / textPrimary
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isFirstTime
                        ? 'Complete Your Profile'
                        : (controller.isPhoneUser ? 'Profile Preferences' : 'Age Group & Gender'),
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
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
              style: GoogleFonts.roboto(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),

            if (controller.isPhoneUser) ...[
              // Username Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Choose Your Username',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.bgElevated,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Optional',
                      style: GoogleFonts.roboto(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Choose a unique handle for your profile (e.g. @yourname).',
                style: GoogleFonts.roboto(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 12),
              Obx(() {
                final errorText = controller.usernameError.value;
                return TextField(
                  controller: controller.usernameController,
                  maxLength: 30,
                  buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9_.]')),
                    LengthLimitingTextInputFormatter(30),
                    TruthworldTextInputFormatters.profanityFilter,
                  ],
                  style: GoogleFonts.roboto(
                    fontSize: 15,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    prefixIcon: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Text(
                        '@',
                        style: GoogleFonts.roboto(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(),
                    hintText: 'username',
                    hintStyle: GoogleFonts.roboto(
                      fontSize: 14,
                      color: AppColors.textTertiary,
                    ),
                    errorText: errorText,
                    errorStyle: GoogleFonts.roboto(
                      fontSize: 12,
                      color: AppColors.error,
                    ),
                    filled: true,
                    fillColor: AppColors.bgInput,
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
                      borderSide: const BorderSide(color: Colors.white),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 24),
            ],

            // Country / Region Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Country / Region',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.bgElevated,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Country',
                    style: GoogleFonts.roboto(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Truthworld localizes your content recommendations, currency, and payment options based on your country.',
              style: GoogleFonts.roboto(
                fontSize: 12,
                color: AppColors.textTertiary,
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
                value: effectiveVal,
                dropdownColor: AppColors.bgSurface,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.white,
                ),
                style: GoogleFonts.roboto(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  prefixIcon: const Icon(
                    Icons.public_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  filled: true,
                  fillColor: AppColors.bgInput,
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
                    borderSide: const BorderSide(color: Colors.white),
                  ),
                ),
                items: countryList.map((country) {
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
                            style: GoogleFonts.roboto(
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    controller.selectCountry(val);
                  }
                },
              );
            }),
            const SizedBox(height: 24),

            // Age Group Section (Optional - 18+ Only)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Which age group are you in?',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.bgElevated,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '18+',
                    style: GoogleFonts.roboto(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Truthworld is exclusively for users aged 18 and older. Helps recommend age-appropriate content.',
              style: GoogleFonts.roboto(
                fontSize: 12,
                color: AppColors.textTertiary,
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
                      style: GoogleFonts.roboto(
                        fontSize: 14,
                        color: isSelected
                            ? AppColors.bgPage
                            : AppColors.textPrimary,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: Colors.white,
                    backgroundColor: AppColors.bgInput,
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

            const SizedBox(height: 24),

            // Gender Section (Optional)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Gender',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.bgElevated,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Optional',
                    style: GoogleFonts.roboto(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Helps Truthworld ensure diverse representation in content recommendations.',
              style: GoogleFonts.roboto(
                fontSize: 12,
                color: AppColors.textTertiary,
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
                          style: GoogleFonts.roboto(
                            fontSize: 14,
                            color: isSelected
                                ? AppColors.bgPage
                                : AppColors.textPrimary,
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: Colors.white,
                        backgroundColor: AppColors.bgInput,
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
                      maxLength: 50,
                      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                      inputFormatters: TruthworldTextInputFormatters.withLimit(50),
                      style: GoogleFonts.roboto(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Self-describe (optional)',
                        hintStyle: GoogleFonts.roboto(
                          fontSize: 14,
                          color: AppColors.textTertiary,
                        ),
                        filled: true,
                        fillColor: AppColors.bgInput,
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
                          borderSide: const BorderSide(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            }),

            const SizedBox(height: 32),

            // Action buttons
            Obx(() {
              final saving = controller.isSaving.value;
              return Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: saving
                          ? null
                          : () {
                              if (isFirstTime) {
                                controller.onSkip(context);
                              } else {
                                Navigator.of(context).pop();
                              }
                            },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: AppColors.bgDivider),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        isFirstTime ? 'Skip for now' : 'Cancel',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: saving ? null : () => controller.onSave(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.bgPage,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.bgPage,
                                ),
                              ),
                            )
                          : Text(
                              isFirstTime ? 'Save & Continue' : 'Save Changes',
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.bgPage,
                              ),
                            ),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}
