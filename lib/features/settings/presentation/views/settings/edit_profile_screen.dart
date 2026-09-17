import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/components/ui/avatar_options_sheet.dart';
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/settings/presentation/controllers/edit_profile_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Dedicated screen for editing user profile details, avatar, handle, age, and location.
class EditProfileScreen extends GetView<EditProfileController> {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService.to;

    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: AppBar(
        backgroundColor: context.colors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: Get.back,
        ),
        title: Text(
          'Edit Profile Details',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          Obx(() {
            final saving = controller.isSaving.value;
            return TextButton(
              onPressed: saving ? null : controller.saveProfile,
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Save',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            );
          }),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            // Avatar & Display Name preview header
            Center(
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Obx(
                        () => UserAvatar(
                          radius: 46,
                          photoUrl: auth.activePhotoUrl,
                          displayName: controller.liveDisplayName.value,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () => AvatarOptionsSheet.show(context),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E1E),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.4),
                              ),
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Obx(
                    () => Text(
                      controller.liveDisplayName.value,
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: () => AvatarOptionsSheet.show(context),
                    icon: const Icon(
                      Icons.edit_outlined,
                      color: Colors.white,
                      size: 16,
                    ),
                    label: const Text(
                      'Change Avatar',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Form Fields Section
            _buildSectionHeader('Basic Information'),
            const SizedBox(height: 12),

            // Display Name
            TextField(
              controller: controller.nameController,
              inputFormatters: const [TruthworldTextInputFormatters.profanityFilter],
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Display Name',
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                helperText: 'International names & accents supported',
                helperStyle: const TextStyle(color: AppColors.textTertiary),
                filled: true,
                fillColor: AppColors.bgInput,
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
            const SizedBox(height: 16),

            // Handle
            TextField(
              controller: controller.handleController,
              inputFormatters: TruthworldTextInputFormatters.standard,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Handle',
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                prefixText: '@',
                prefixStyle: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
                filled: true,
                fillColor: AppColors.bgInput,
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
            const SizedBox(height: 16),

            // Bio
            TextField(
              controller: controller.bioController,
              inputFormatters: TruthworldTextInputFormatters.standard,
              maxLines: 3,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Bio',
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                hintText: 'Tell the Truthworld community about yourself...',
                hintStyle: const TextStyle(color: AppColors.textTertiary),
                filled: true,
                fillColor: AppColors.bgInput,
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

            const SizedBox(height: 24),
            _buildSectionHeader('Personal Details'),
            const SizedBox(height: 12),

            // Gender
            Obx(() {
              final currentGender = controller.selectedGender.value;
              final options = controller.genderOptions;
              return DropdownButtonFormField<String>(
                dropdownColor: context.colors.surface,
                value: currentGender,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Gender',
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.bgInput,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.bgDivider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white),
                  ),
                ),
                items: options
                    .map(
                      (g) => DropdownMenuItem(
                        value: g,
                        child: Text(
                          g,
                          style: const TextStyle(color: AppColors.textPrimary),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) controller.selectedGender.value = val;
                },
              );
            }),
            const SizedBox(height: 16),

            // Age Field with <= 120 constraint
            Obx(() {
              final errorText = controller.ageErrorText.value;
              return TextField(
                controller: controller.ageController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(3),
                ],
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Age (Years)',
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  helperText: 'Allowed age range: 1–120 years',
                  helperStyle: const TextStyle(color: AppColors.textTertiary),
                  errorText: errorText,
                  errorStyle: const TextStyle(color: AppColors.error),
                  filled: true,
                  fillColor: AppColors.bgInput,
                  border: OutlineInputBorder(
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
            _buildSectionHeader('Location Settings & Google Maps'),
            const SizedBox(height: 6),
            Text(
              'Share your city or exact Google Maps location to help Truthworld personalize your content recommendations.',
              style: GoogleFonts.roboto(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),

            // Location input field
            TextField(
              controller: controller.locationController,
              inputFormatters: TruthworldTextInputFormatters.standard,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Location (City, Country)',
                labelStyle: const TextStyle(color: AppColors.textSecondary),
                hintText: 'e.g. London, UK or 51.5074, -0.1278',
                hintStyle: const TextStyle(color: AppColors.textTertiary),
                helperText: 'Tap below to pick or share from Google Maps',
                helperStyle: const TextStyle(color: AppColors.textTertiary),
                filled: true,
                fillColor: AppColors.bgInput,
                suffixIcon: IconButton(
                  icon: const Icon(
                    Icons.clear,
                    color: Colors.white,
                    size: 18,
                  ),
                  onPressed: controller.locationController.clear,
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

            const SizedBox(height: 14),

            // Google Maps location action cards
            _buildGoogleMapsActions(context),

            const SizedBox(height: 36),

            // Save button
            Obx(() {
              final saving = controller.isSaving.value;
              return SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: saving ? null : controller.saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.bgPage,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: saving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.bgPage,
                            ),
                          ),
                        )
                      : Text(
                          'Save Profile Details',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.bgPage,
                          ),
                        ),
                ),
              );
            }),

            const SizedBox(height: 24),
          ],
        ),
      ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildGoogleMapsActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Google Maps Location Tools',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // 1. Open Google Maps
              ActionChip(
                avatar: const Icon(
                  Icons.map_outlined,
                  color: Colors.white,
                  size: 16,
                ),
                label: const Text('Open Google Maps'),
                labelStyle: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                backgroundColor: AppColors.bgSurface,
                side: const BorderSide(color: AppColors.bgDivider),
                onPressed: controller.openGoogleMaps,
              ),

              // 2. Use Current Location
              Obx(() {
                final detecting = controller.isDetectingLocation.value;
                return ActionChip(
                  avatar: detecting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(
                          Icons.my_location,
                          color: Colors.white,
                          size: 16,
                        ),
                  label: Text(
                    detecting ? 'Detecting...' : 'Use Current Location',
                  ),
                  labelStyle: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  backgroundColor: AppColors.bgSurface,
                  side: const BorderSide(color: AppColors.bgDivider),
                  onPressed: detecting ? null : controller.detectCurrentLocation,
                );
              }),

              // 3. Paste Maps Link or Coordinates
              ActionChip(
                avatar: const Icon(
                  Icons.link,
                  color: Colors.white,
                  size: 16,
                ),
                label: const Text('Paste Maps Link / Coords'),
                labelStyle: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                backgroundColor: AppColors.bgSurface,
                side: const BorderSide(color: AppColors.bgDivider),
                onPressed: () => _showPasteMapLocationDialog(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showPasteMapLocationDialog(BuildContext context) {
    final pasteCtrl = TextEditingController();

    Get.dialog(
      AlertDialog(
        backgroundColor: context.colors.surface,
        title: Text(
          'Paste Google Maps Location',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Paste a Google Maps share link, query, or latitude/longitude coordinates (e.g. 40.7128, -74.0060).',
              style: GoogleFonts.roboto(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: pasteCtrl,
              inputFormatters: TruthworldTextInputFormatters.standard,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'https://maps.app.goo.gl/... or 37.77, -122.41',
                hintStyle: const TextStyle(color: AppColors.textTertiary),
                filled: true,
                fillColor: AppColors.bgInput,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.bgDivider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final text = pasteCtrl.text.trim();
              if (text.isNotEmpty) {
                controller.parseAndSetMapLocation(text);
                Get.back();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.bgPage,
            ),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}
