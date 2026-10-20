import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/onboarding/presentation/controllers/onboarding_profile_controller.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Dedicated full-screen page for onboarding new Truthworld users.
///
/// Features:
/// - "Continue as [Google Display Name]" banner with Google Avatar preview
/// - Interactive options to change avatar photo (Camera / Gallery upload) and edit display name & handle
/// - Country / Region selector with international flags & pre-selected detected country
/// - Age group selection strictly 18+ (no under-18 groups)
/// - Gender selection (including self-describe)
/// - "Continue & Finish" button which saves profile and directly routes to Truthworld Home
class OnboardingProfileScreen extends StatelessWidget {
  const OnboardingProfileScreen({super.key});

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
      backgroundColor: AppColors.bgSurface,
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
                Text(
                  'Change Profile Photo',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined, color: Colors.white),
                  title: const Text(
                    'Choose from Gallery',
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    controller.pickAndChangeAvatar(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined, color: Colors.white),
                  title: const Text(
                    'Take a Photo',
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
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
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        backgroundColor: AppColors.bgPage,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.verified_user_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'TruthWorld',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Welcome & Continue-as Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.bgDivider),
                ),
                child: Column(
                  children: [
                    Text(
                      'Welcome to TruthWorld',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Confirm your profile details to personalize your experience, regional topics, and community presence.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.roboto(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Avatar with interactive edit badge
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Obx(() {
                          final photoUrl = controller.activeAvatarUrl.value;
                          final isUploading = controller.isUploadingPhoto.value;

                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              GestureDetector(
                                onTap: isUploading ? null : () => _showImageSourcePicker(context, controller),
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white.withAlpha(80), width: 3),
                                  ),
                                  child: UserAvatar(
                                    photoUrl: photoUrl.isNotEmpty ? photoUrl : null,
                                    displayName: controller.displayNameController.text,
                                    radius: 44,
                                    showBorder: false,
                                  ),
                                ),
                              ),
                              if (isUploading)
                                Container(
                                  width: 88,
                                  height: 88,
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
                          );
                        }),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: GestureDetector(
                            onTap: () => _showImageSourcePicker(context, controller),
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(80),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                size: 16,
                                color: Colors.black, // Rule: Black icon on white container
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    TextButton.icon(
                      onPressed: () => _showImageSourcePicker(context, controller),
                      icon: const Icon(Icons.edit_outlined, size: 14, color: Colors.white),
                      label: const Text(
                        'Change Photo',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    if (googleEmail.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.bgElevated,
                          borderRadius: BorderRadius.circular(12),
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
                                style: GoogleFonts.roboto(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
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
              const SizedBox(height: 20),

              // 2. Profile Details Form (Display Name & Handle)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.bgDivider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Account Details',
                      style: GoogleFonts.outfit(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Display Name Field
                    Text(
                      'Full Name / Display Name',
                      style: GoogleFonts.roboto(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
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
                        style: GoogleFonts.roboto(
                          fontSize: 15,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(
                            Icons.person_outline_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          hintText: 'Enter your name',
                          hintStyle: GoogleFonts.roboto(
                            fontSize: 14,
                            color: AppColors.textTertiary,
                          ),
                          errorText: err,
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
                    const SizedBox(height: 16),

                    // Username / Handle Field
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Username / Handle',
                          style: GoogleFonts.roboto(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          'Optional',
                          style: GoogleFonts.roboto(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
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
                        style: GoogleFonts.roboto(
                          fontSize: 15,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          prefixIcon: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                          errorText: err,
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
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 3. Country / Region Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.bgDivider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Country / Region',
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.bgElevated,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Country',
                            style: GoogleFonts.roboto(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Truthworld uses this to localize your content recommendations, currency, and payment options.',
                      style: GoogleFonts.roboto(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 14),

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
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 4. Age Group Section (Strictly 18+)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.bgDivider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Age Group',
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.bgElevated,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.bgDivider),
                          ),
                          child: Text(
                            '18+ Only',
                            style: GoogleFonts.roboto(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Truthworld is strictly for users aged 18 and older. Helps recommend age-appropriate content.',
                      style: GoogleFonts.roboto(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 14),

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
                                fontSize: 13,
                                color: isSelected ? Colors.black : AppColors.textPrimary,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 5. Gender Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.bgSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.bgDivider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Gender',
                          style: GoogleFonts.outfit(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.bgElevated,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Optional',
                            style: GoogleFonts.roboto(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Helps ensure diverse representation in content recommendations.',
                      style: GoogleFonts.roboto(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 14),

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
                                    fontSize: 13,
                                    color: isSelected ? Colors.black : AppColors.textPrimary,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
                              maxLength: 100,
                              buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                              inputFormatters: TruthworldTextInputFormatters.withLimit(100),
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
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // 6. Action Buttons: Finish & Go to Home
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
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black), // Rule: Black spinner on white button
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Continue & Finish',
                                    style: GoogleFonts.outfit(
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
                      child: TextButton(
                        onPressed: saving ? null : controller.skipAndGoToHome,
                        child: Text(
                          'Skip & Go to Home',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
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
