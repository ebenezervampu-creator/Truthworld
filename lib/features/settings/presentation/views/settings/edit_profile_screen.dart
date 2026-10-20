import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/components/ui/avatar_options_sheet.dart';
import 'package:truthworld/components/ui/user_avatar.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/location/verified_location.dart';
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
              maxLength: ContentValidator.defaultMaxDisplayNameLength,
              buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
              inputFormatters: TruthworldTextInputFormatters.internationalWithLimit(
                ContentValidator.defaultMaxDisplayNameLength,
              ),
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
              maxLength: ContentValidator.defaultMaxHandleLength,
              buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
              inputFormatters: TruthworldTextInputFormatters.withLimit(
                ContentValidator.defaultMaxHandleLength,
              ),
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
              maxLength: ContentValidator.defaultMaxBioLength,
              buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
              inputFormatters: TruthworldTextInputFormatters.withLimit(
                ContentValidator.defaultMaxBioLength,
              ),
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
                maxLength: 3,
                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
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
              'Search and select your town, city, or village, or pin your exact location on Google Maps.',
              style: GoogleFonts.roboto(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),

            // Verified Locality Badge (if currently verified)
            Obx(() {
              if (!controller.isLocationVerified.value || controller.verifiedLocation.value == null) {
                return const SizedBox.shrink();
              }
              final loc = controller.verifiedLocation.value!;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.greenAccent, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Verified ${loc.typeLabel}: ${loc.formattedAddress}',
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }),

            // Location input field
            Obx(() {
              final errorText = controller.locationErrorText.value;
              final isSearching = controller.isSearchingLocation.value;
              return TextField(
                controller: controller.locationController,
                maxLength: ContentValidator.defaultMaxLocationLength,
                buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                inputFormatters: TruthworldTextInputFormatters.withLimit(
                  ContentValidator.defaultMaxLocationLength,
                ),
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Locality (Town, City, or Village)',
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  hintText: 'Search town, city, or village...',
                  hintStyle: const TextStyle(color: AppColors.textTertiary),
                  helperText: 'Select a verified locality or pin your location below',
                  helperStyle: const TextStyle(color: AppColors.textTertiary),
                  errorText: errorText,
                  errorStyle: const TextStyle(color: AppColors.error),
                  filled: true,
                  fillColor: AppColors.bgInput,
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSearching)
                        const Padding(
                          padding: EdgeInsets.only(right: 8.0),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                        ),
                      IconButton(
                        icon: const Icon(
                          Icons.clear,
                          color: Colors.white,
                          size: 18,
                        ),
                        onPressed: controller.locationController.clear,
                      ),
                    ],
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
              );
            }),

            // Real-time Search Suggestions Dropdown List
            Obx(() {
              final suggestions = controller.locationSuggestions;
              if (suggestions.isEmpty) return const SizedBox.shrink();

              return Container(
                margin: const EdgeInsets.only(top: 6),
                constraints: const BoxConstraints(maxHeight: 220),
                decoration: BoxDecoration(
                  color: AppColors.bgElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.bgDivider),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: suggestions.length,
                  separatorBuilder: (_, _) => const Divider(
                    color: AppColors.bgDivider,
                    height: 1,
                  ),
                  itemBuilder: (context, index) {
                    final loc = suggestions[index];
                    final iconData = loc.localityType == LocalityType.village
                        ? Icons.holiday_village
                        : (loc.localityType == LocalityType.town
                            ? Icons.location_city_outlined
                            : Icons.location_city);

                    return ListTile(
                      dense: true,
                      leading: Icon(iconData, color: Colors.white, size: 18),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              loc.name,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              loc.typeLabel,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        loc.formattedAddress,
                        style: const TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => controller.selectLocationSuggestion(loc),
                    );
                  },
                ),
              );
            }),

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
              // 1. Pin on Map
              ActionChip(
                avatar: const Icon(
                  Icons.pin_drop,
                  color: Colors.white,
                  size: 16,
                ),
                label: const Text('Pin on Map'),
                labelStyle: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                backgroundColor: AppColors.bgSurface,
                side: const BorderSide(color: AppColors.bgDivider),
                onPressed: () => controller.openMapPinPicker(context),
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

              // 4. Open Google Maps
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
              'Paste a Google Maps share link or coordinates (e.g. 40.7128, -74.0060). It will resolve to the nearest verified town, city, or village.',
              style: GoogleFonts.roboto(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: pasteCtrl,
              maxLength: 500,
              buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
              inputFormatters: [
                LengthLimitingTextInputFormatter(500),
                FilteringTextInputFormatter.deny(RegExp(r'\s')),
              ],
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
              foregroundColor: Colors.black, // Rule: Black foreground on white button
            ),
            child: const Text('Apply & Verify', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }
}
