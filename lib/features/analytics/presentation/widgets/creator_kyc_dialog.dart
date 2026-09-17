import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/analytics/data/models/creator_kyc_verification.dart';
import 'package:truthworld/features/analytics/presentation/controllers/revenue_analytics_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Interactive modal dialog for Creator KYC Document Verification.
/// Collects PAN details, identity proof documents, and verifies name matching against the creator's bank account.
class CreatorKycDialog extends StatelessWidget {
  CreatorKycDialog({super.key}) {
    final existing = controller.creatorKyc.value;
    if (existing != null) {
      panNameController.text = existing.panLegalName;
      panNumberController.text = existing.panNumber;
      selectedDob.value = existing.dateOfBirth;
      selectedProofType.value = existing.identityProofType;
      idNumberController.text = existing.identityProofNumber;
    } else {
      // Default legal name to saved bank account holder name if available
      final savedBank = controller.savedBankAccount.value;
      if (savedBank != null && savedBank.accountHolderName.isNotEmpty) {
        panNameController.text = savedBank.accountHolderName;
      }
    }
  }

  final RevenueAnalyticsController controller = RevenueAnalyticsController.to;

  final TextEditingController panNameController = TextEditingController();
  final TextEditingController panNumberController = TextEditingController();
  final TextEditingController idNumberController = TextEditingController();

  final Rx<DateTime?> selectedDob = Rx<DateTime?>(null);
  final Rx<IdentityProofType> selectedProofType = IdentityProofType.maskedAadhaar.obs;

  final Rx<Uint8List?> panImageBytes = Rx<Uint8List?>(null);
  final RxString panImageName = ''.obs;

  final Rx<Uint8List?> idFrontBytes = Rx<Uint8List?>(null);
  final RxString idFrontName = ''.obs;

  final Rx<Uint8List?> idBackBytes = Rx<Uint8List?>(null);
  final RxString idBackName = ''.obs;

  final ImagePicker _picker = ImagePicker();

  static void show(BuildContext context) {
    Get.dialog<void>(
      CreatorKycDialog(),
    );
  }

  Future<void> _pickImage({
    required Function(Uint8List bytes, String name) onPicked,
    ImageSource source = ImageSource.gallery,
  }) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        AppSnackbar.error('Selected image is empty. Please choose another file.');
        return;
      }
      onPicked(bytes, file.name);
    } catch (e) {
      AppSnackbar.error('Unable to read selected photo. Please try another image.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF18181B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF27272A)),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 720),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.verified_user_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Creator Verification',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'KYC Document Verification for Withdrawals',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                    onPressed: Get.back,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Compliance & Privacy Notice
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.2)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.shield_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Financial regulations require PAN and identity proof before releasing creator payouts. All documents are encrypted and accessible only to verification compliance officers.',
                        style: TextStyle(
                          color: Color(0xFFBFDBFE),
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ─── SECTION 1: PAN CARD DETAILS ───
              _buildSectionTitle('1. Permanent Account Number (PAN)'),
              const SizedBox(height: 10),

              _buildInputLabel('Legal Name as per PAN'),
              const SizedBox(height: 6),
              _buildTextField(
                controller: panNameController,
                hint: 'e.g. Ramesh Kumar',
                icon: Icons.badge_outlined,
              ),
              const SizedBox(height: 12),

              _buildInputLabel('PAN Card Number (10 alphanumeric characters)'),
              const SizedBox(height: 6),
              _buildTextField(
                controller: panNumberController,
                hint: 'e.g. ABCDE1234F',
                icon: Icons.credit_card_rounded,
                isPan: true,
              ),
              const SizedBox(height: 12),

              _buildInputLabel('Date of Birth (Minimum 18 years old)'),
              const SizedBox(height: 6),
              _buildDobPicker(context),
              const SizedBox(height: 12),

              _buildInputLabel('PAN Card Photo Upload'),
              const SizedBox(height: 6),
              Obx(() => _buildUploadBox(
                    label: 'Upload PAN Card Photo',
                    imageBytes: panImageBytes.value,
                    fileName: panImageName.value,
                    existingUrl: controller.creatorKyc.value?.panDocumentUrl,
                    onTapPick: () => _pickImage(
                      onPicked: (bytes, name) {
                        panImageBytes.value = bytes;
                        panImageName.value = name;
                      },
                    ),
                    onClear: () {
                      panImageBytes.value = null;
                      panImageName.value = '';
                    },
                  )),
              const SizedBox(height: 20),

              // ─── SECTION 2: IDENTITY & ADDRESS PROOF ───
              _buildSectionTitle('2. Identity & Address Proof'),
              const SizedBox(height: 10),

              _buildInputLabel('Select Government ID Type'),
              const SizedBox(height: 6),
              Obx(_buildProofTypeSelector),
              const SizedBox(height: 12),

              Obx(() => _buildInputLabel('${selectedProofType.value.displayName} Number')),
              const SizedBox(height: 6),
              _buildTextField(
                controller: idNumberController,
                hint: 'Enter document number',
                icon: Icons.pin_rounded,
              ),
              const SizedBox(height: 12),

              _buildInputLabel('Document Front Side Photo'),
              const SizedBox(height: 6),
              Obx(() => _buildUploadBox(
                    label: 'Upload Document Front Photo',
                    imageBytes: idFrontBytes.value,
                    fileName: idFrontName.value,
                    existingUrl: controller.creatorKyc.value?.identityProofFrontUrl,
                    onTapPick: () => _pickImage(
                      onPicked: (bytes, name) {
                        idFrontBytes.value = bytes;
                        idFrontName.value = name;
                      },
                    ),
                    onClear: () {
                      idFrontBytes.value = null;
                      idFrontName.value = '';
                    },
                  )),
              const SizedBox(height: 12),

              _buildInputLabel('Document Back Side Photo (Optional for Passport)'),
              const SizedBox(height: 6),
              Obx(() => _buildUploadBox(
                    label: 'Upload Document Back Photo',
                    imageBytes: idBackBytes.value,
                    fileName: idBackName.value,
                    existingUrl: controller.creatorKyc.value?.identityProofBackUrl,
                    onTapPick: () => _pickImage(
                      onPicked: (bytes, name) {
                        idBackBytes.value = bytes;
                        idBackName.value = name;
                      },
                    ),
                    onClear: () {
                      idBackBytes.value = null;
                      idBackName.value = '';
                    },
                  )),
              const SizedBox(height: 20),

              // ─── SECTION 3: BANK ACCOUNT NAME MATCH ───
              _buildSectionTitle('3. Bank Account Name Matching'),
              const SizedBox(height: 8),
              _buildBankNameMatchWidget(),
              const SizedBox(height: 24),

              // Action Buttons
              Obx(() {
                final isSubmitting = controller.isSubmittingKyc.value;
                final progress = (controller.kycUploadProgress.value * 100).toInt();

                return Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: isSubmitting ? null : Get.back,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: isSubmitting ? null : _handleSubmitKyc,
                        icon: isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.check_circle_outline_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                        label: Text(
                          isSubmitting ? 'Uploading Documents ($progress%)...' : 'Submit for Verification',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
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
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPan = false,
  }) {
    return TextField(
      controller: controller,
      textCapitalization: isPan ? TextCapitalization.characters : TextCapitalization.words,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13),
        prefixIcon: Icon(icon, color: Colors.white, size: 18),
        filled: true,
        fillColor: const Color(0xFF27272A),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _buildDobPicker(BuildContext context) {
    return Obx(() {
      final dob = selectedDob.value;
      final text = dob != null
          ? '${dob.day.toString().padLeft(2, '0')}/${dob.month.toString().padLeft(2, '0')}/${dob.year}'
          : 'Select Date of Birth';

      return InkWell(
        onTap: () async {
          final initial = dob ?? DateTime(2000);
          final picked = await showDatePicker(
            context: context,
            initialDate: initial,
            firstDate: DateTime(1930),
            lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
            helpText: 'SELECT DATE OF BIRTH (18+ ONLY)',
          );
          if (picked != null) {
            selectedDob.value = picked;
          }
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF27272A),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Text(
                text,
                style: TextStyle(
                  color: dob != null ? AppColors.textPrimary : AppColors.textTertiary,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              const Icon(Icons.arrow_drop_down_rounded, color: Colors.white, size: 22),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildProofTypeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF27272A),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<IdentityProofType>(
          value: selectedProofType.value,
          dropdownColor: const Color(0xFF27272A),
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.white),
          items: IdentityProofType.values.map((type) {
            return DropdownMenuItem<IdentityProofType>(
              value: type,
              child: Text(
                type.displayName,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              ),
            );
          }).toList(),
          onChanged: (newType) {
            if (newType != null) selectedProofType.value = newType;
          },
        ),
      ),
    );
  }

  Widget _buildUploadBox({
    required String label,
    required Uint8List? imageBytes,
    required String fileName,
    required String? existingUrl,
    required VoidCallback onTapPick,
    required VoidCallback onClear,
  }) {
    final hasNewFile = imageBytes != null;
    final hasExisting = existingUrl != null && existingUrl.isNotEmpty;

    if (hasNewFile || hasExisting) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: Colors.black26,
              ),
              clipBehavior: Clip.antiAlias,
              child: hasNewFile
                  ? Image.memory(imageBytes, fit: BoxFit.cover)
                  : Image.network(existingUrl!, fit: BoxFit.cover),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasNewFile ? (fileName.isNotEmpty ? fileName : 'Selected Document') : 'Verified Photo on File',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Text(
                    'Ready for verification upload',
                    style: TextStyle(color: Color(0xFF10B981), fontSize: 11),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
              onPressed: onClear,
              tooltip: 'Remove',
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: onTapPick,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF27272A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF3F3F46)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_upload_outlined, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBankNameMatchWidget() {
    return Obx(() {
      final savedBank = controller.savedBankAccount.value;
      final bankHolder = savedBank?.accountHolderName ?? '';
      final panName = panNameController.text.trim();

      if (bankHolder.isEmpty) {
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF27272A),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'No direct bank account linked yet. After verification, your bank account name will be matched against your PAN.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
              ),
            ],
          ),
        );
      }

      final score = panName.isNotEmpty
          ? CreatorKycVerification.calculateNameMatchScore(bankHolder, panName)
          : 0.0;
      final isHighConfidence = score >= 0.70;

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isHighConfidence
              ? const Color(0xFF10B981).withValues(alpha: 0.1)
              : const Color(0xFFF59E0B).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isHighConfidence
                ? const Color(0xFF10B981).withValues(alpha: 0.3)
                : const Color(0xFFF59E0B).withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isHighConfidence ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isHighConfidence ? 'Bank Name Match: High Confidence' : 'Bank Name Discrepancy Check',
                    style: TextStyle(
                      color: isHighConfidence ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Bank Account Holder: "$bankHolder"',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
            Text(
              'PAN Card Legal Name: "${panName.isNotEmpty ? panName : 'Enter PAN Name'}"',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _handleSubmitKyc() async {
    final pan = panNumberController.text.trim().toUpperCase();
    final name = panNameController.text.trim();
    final dob = selectedDob.value;
    final idNum = idNumberController.text.trim();

    if (!CreatorKycVerification.isValidPan(pan)) {
      AppSnackbar.warning('Please enter a valid 10-character PAN number (e.g. ABCDE1234F).');
      return;
    }
    if (name.isEmpty) {
      AppSnackbar.warning('Please enter your Legal Name as shown on your PAN card.');
      return;
    }
    if (dob == null) {
      AppSnackbar.warning('Please select your Date of Birth.');
      return;
    }
    if (!CreatorKycVerification.isValidAge(dob)) {
      AppSnackbar.warning('You must be at least 18 years old to complete creator KYC.');
      return;
    }
    if (idNum.isEmpty) {
      AppSnackbar.warning('Please enter your government identity document number.');
      return;
    }

    final existing = controller.creatorKyc.value;
    final panBytes = panImageBytes.value;
    final idFront = idFrontBytes.value;

    if (panBytes == null && (existing == null || existing.panDocumentUrl.isEmpty)) {
      AppSnackbar.warning('Please upload a clear photo of your PAN Card.');
      return;
    }

    if (idFront == null && (existing == null || existing.identityProofFrontUrl.isEmpty)) {
      AppSnackbar.warning('Please upload a clear photo of your Government ID proof.');
      return;
    }

    final success = await controller.submitKycVerification(
      panNumber: pan,
      panLegalName: name,
      dateOfBirth: dob,
      panImageBytes: panBytes ?? Uint8List(0),
      idProofType: selectedProofType.value,
      idProofNumber: idNum,
      idFrontImageBytes: idFront ?? Uint8List(0),
      idBackImageBytes: idBackBytes.value,
    );

    if (success) {
      Get.back<void>();
    }
  }
}
