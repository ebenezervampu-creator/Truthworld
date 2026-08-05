import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Modal bottom sheet presented after a Google Sign-In to collect:
/// 1. Optional Age Group (Under 13, 13–17, 18–24, 25–34, 35–44, 45–54, 55–64, 65+, Prefer not to say)
/// 2. Optional Gender (Male, Female, Non-binary, Prefer not to say, Self-describe)
class GoogleOnboardingSheet extends StatefulWidget {
  const GoogleOnboardingSheet({super.key});

  /// Helper to display the onboarding sheet as a modal bottom sheet
  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const GoogleOnboardingSheet(),
    );
  }

  @override
  State<GoogleOnboardingSheet> createState() => _GoogleOnboardingSheetState();
}

class _GoogleOnboardingSheetState extends State<GoogleOnboardingSheet> {
  String? _selectedAgeGroup;
  String? _selectedGender;
  final TextEditingController _selfDescribeController =
      TextEditingController();
  bool _isSaving = false;

  final List<String> _ageGroupOptions = const [
    'Under 13',
    '13–17',
    '18–24',
    '25–34',
    '35–44',
    '45–54',
    '55–64',
    '65+',
    'Prefer not to say',
  ];

  final List<String> _genderOptions = const [
    'Male',
    'Female',
    'Non-binary',
    'Prefer not to say',
    'Self-describe',
  ];

  Future<void> _onSave() async {
    setState(() {
      _isSaving = true;
    });

    try {
      String? genderValue;
      if (_selectedGender != null) {
        if (_selectedGender == 'Self-describe') {
          final customText = _selfDescribeController.text.trim();
          genderValue = customText.isNotEmpty
              ? 'Self-describe: $customText'
              : 'Self-describe';
        } else {
          genderValue = _selectedGender;
        }
      }

      await AuthService.to.updateUserProfileOnboarding(
        ageGroup: _selectedAgeGroup,
        gender: genderValue,
      );

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to save profile: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppColors.errorContainer,
        colorText: AppColors.textPrimary,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _onSkip() async {
    setState(() {
      _isSaving = true;
    });

    try {
      await AuthService.to.skipUserOnboarding();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  void dispose() {
    _selfDescribeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                    'Complete Your Profile',
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
              'Truthworld uses this to recommend age-appropriate content and build a more inclusive platform for everyone.',
              style: GoogleFonts.roboto(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),

            // Age Group Section (Optional)
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
              'Helps Truthworld recommend age-appropriate videos and comply with content safety guidelines.',
              style: GoogleFonts.roboto(
                fontSize: 12,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 12),

            // Age Group selection chips
            Wrap(
              spacing: 8,
              runSpacing: 10,
              children: _ageGroupOptions.map((option) {
                final isSelected = _selectedAgeGroup == option;
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
                    setState(() {
                      _selectedAgeGroup = selected ? option : null;
                    });
                  },
                );
              }).toList(),
            ),

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
            Wrap(
              spacing: 8,
              runSpacing: 10,
              children: _genderOptions.map((option) {
                final isSelected = _selectedGender == option;
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
                    setState(() {
                      _selectedGender = selected ? option : null;
                    });
                  },
                );
              }).toList(),
            ),

            // Optional self-describe text field if selected
            if (_selectedGender == 'Self-describe') ...[
              const SizedBox(height: 14),
              TextField(
                controller: _selfDescribeController,
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

            const SizedBox(height: 32),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : _onSkip,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppColors.bgDivider),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Skip for now',
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
                    onPressed: _isSaving ? null : _onSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.bgPage,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSaving
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
                            'Save & Continue',
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.bgPage,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
