import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/features/analytics/presentation/controllers/revenue_analytics_controller.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Controller managing monetization application form inputs, validation, and Firestore persistence.
class MonetizationApplicationController extends GetxController {
  MonetizationApplicationController({
    required this.channel,
    required this.qualifiedVideo,
  });

  final Channel channel;
  final Video qualifiedVideo;

  final TextEditingController legalNameController = TextEditingController();
  final TextEditingController idNumberController = TextEditingController();
  final TextEditingController dobController = TextEditingController();
  final TextEditingController accountHolderController = TextEditingController();
  final TextEditingController bankNameController = TextEditingController();
  final TextEditingController accountNumberController = TextEditingController();
  final TextEditingController confirmAccountNumberController = TextEditingController();
  final TextEditingController ifscController = TextEditingController();

  final RxString selectedIdType = 'PAN Card'.obs;
  final RxString selectedCountry = 'India (IN)'.obs;
  final RxString selectedAccountType = 'Savings'.obs;
  final RxBool agreedToTerms = false.obs;
  final RxBool isSubmitting = false.obs;

  static const List<String> idTypes = [
    'PAN Card',
    'Aadhaar Card',
    'Passport',
    'National ID',
    'Voter ID',
    'Driving License',
  ];

  static const List<String> countries = [
    'India (IN)',
    'United States (US)',
    'United Kingdom (GB)',
    'Canada (CA)',
    'Australia (AU)',
    'Germany (DE)',
    'United Arab Emirates (AE)',
    'Singapore (SG)',
  ];

  static const List<String> accountTypes = [
    'Savings',
    'Current',
  ];

  @override
  void onInit() {
    super.onInit();
    // Pre-populate with existing data if available
    accountHolderController.text = channel.name;
    legalNameController.text = channel.name;

    if (Get.isRegistered<RevenueAnalyticsController>()) {
      final rev = Get.find<RevenueAnalyticsController>();
      final savedBank = rev.savedBankAccount.value;
      if (savedBank != null) {
        if (savedBank.accountHolderName.isNotEmpty) {
          accountHolderController.text = savedBank.accountHolderName;
        }
        if (savedBank.bankName.isNotEmpty) {
          bankNameController.text = savedBank.bankName;
        }
        if (savedBank.accountNumber.isNotEmpty) {
          accountNumberController.text = savedBank.accountNumber;
          confirmAccountNumberController.text = savedBank.accountNumber;
        }
        if (savedBank.ifscCode.isNotEmpty) {
          ifscController.text = savedBank.ifscCode;
        }
        if (savedBank.accountType.isNotEmpty &&
            accountTypes.contains(savedBank.accountType)) {
          selectedAccountType.value = savedBank.accountType;
        }
      }

      final savedKyc = rev.creatorKyc.value;
      if (savedKyc != null) {
        if (savedKyc.panLegalName.isNotEmpty) {
          legalNameController.text = savedKyc.panLegalName;
        }
        if (savedKyc.panNumber.isNotEmpty) {
          idNumberController.text = savedKyc.panNumber;
        }
        if (savedKyc.dateOfBirth != null) {
          dobController.text =
              '${savedKyc.dateOfBirth!.year}-${savedKyc.dateOfBirth!.month.toString().padLeft(2, '0')}-${savedKyc.dateOfBirth!.day.toString().padLeft(2, '0')}';
        }
      }
    }
  }

  @override
  void onClose() {
    legalNameController.dispose();
    idNumberController.dispose();
    dobController.dispose();
    accountHolderController.dispose();
    bankNameController.dispose();
    accountNumberController.dispose();
    confirmAccountNumberController.dispose();
    ifscController.dispose();
    super.onClose();
  }

  Future<void> submitApplication(BuildContext context) async {
    final legalName = legalNameController.text.trim();
    final idNumber = idNumberController.text.trim();
    final accountHolder = accountHolderController.text.trim();
    final bankName = bankNameController.text.trim();
    final accNum = accountNumberController.text.trim();
    final confirmAccNum = confirmAccountNumberController.text.trim();
    final ifsc = ifscController.text.trim().toUpperCase();

    if (legalName.isEmpty || legalName.length < 2) {
      AppSnackbar.warning(
        'Please enter your full legal name matching your government ID.',
      );
      return;
    }

    if (idNumber.isEmpty || idNumber.length < 4) {
      AppSnackbar.warning(
        'Please enter a valid government identification number.',
      );
      return;
    }

    if (accountHolder.isEmpty) {
      AppSnackbar.warning(
        'Please enter the primary bank account holder name.',
      );
      return;
    }

    if (bankName.isEmpty) {
      AppSnackbar.warning(
        'Please enter your financial institution or bank name.',
      );
      return;
    }

    if (accNum.isEmpty || accNum.length < 6) {
      AppSnackbar.warning(
        'Please enter a valid bank account number.',
      );
      return;
    }

    if (accNum != confirmAccNum) {
      AppSnackbar.warning(
        'The confirmation account number does not match. Please verify both entries.',
      );
      return;
    }

    if (ifsc.isEmpty || ifsc.length < 4) {
      AppSnackbar.warning(
        'Please enter a valid IFSC or SWIFT routing code.',
      );
      return;
    }

    if (!agreedToTerms.value) {
      AppSnackbar.warning(
        'Please confirm that all verification details are accurate and agree to monetization terms.',
      );
      return;
    }

    isSubmitting.value = true;
    try {
      final firestore = FirebaseFirestore.instance;
      final channelId = channel.id;
      final watchHours = qualifiedVideo.totalWatchTimeSeconds / 3600.0;
      final maskedAccount = accNum.length > 4
          ? '•••• ${accNum.substring(accNum.length - 4)}'
          : accNum;

      final applicationData = <String, dynamic>{
        'channelId': channelId,
        'channelName': channel.name,
        'ownerId': channel.ownerId,
        'status': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
        'qualifiedVideoId': qualifiedVideo.id,
        'qualifiedVideoTitle': qualifiedVideo.title,
        'qualifiedVideoViews': qualifiedVideo.viewCount,
        'qualifiedVideoWatchHours': watchHours,
        'legalName': legalName,
        'idType': selectedIdType.value,
        'idNumber': idNumber,
        'dob': dobController.text.trim(),
        'country': selectedCountry.value,
        'bankName': bankName,
        'accountHolderName': accountHolder,
        'accountNumber': accNum,
        'accountNumberMasked': maskedAccount,
        'ifscCode': ifsc,
        'accountType': selectedAccountType.value,
      };

      // 1. Write to monetization_applications collection for Admin verification queue
      await firestore
          .collection('monetization_applications')
          .doc(channelId)
          .set(applicationData, SetOptions(merge: true));

      // 2. Save Bank Account subcollection
      await firestore
          .collection(FirestoreCollections.channels)
          .doc(channelId)
          .collection('bank_accounts')
          .doc('primary')
          .set({
        'accountHolderName': accountHolder,
        'bankName': bankName,
        'accountNumber': accNum,
        'accountNumberMasked': maskedAccount,
        'ifscCode': ifsc,
        'accountType': selectedAccountType.value,
        'currency': 'INR',
        'isPrimary': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 3. Save KYC subcollection
      await firestore
          .collection(FirestoreCollections.channels)
          .doc(channelId)
          .collection('kyc')
          .doc('identity')
          .set({
        'legalName': legalName,
        'idType': selectedIdType.value,
        'idNumber': idNumber,
        'dob': dobController.text.trim(),
        'country': selectedCountry.value,
        'status': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 4. Update the channel root document with underReview status
      final channelUpdate = <String, dynamic>{
        'status': ChannelStatus.underReview.name,
        'monetizationStatus': 'underReview',
        'monetizationApplication': {
          'status': 'pending',
          'submittedAt': FieldValue.serverTimestamp(),
          'qualifiedVideoId': qualifiedVideo.id,
          'qualifiedVideoTitle': qualifiedVideo.title,
          'qualifiedVideoViews': qualifiedVideo.viewCount,
          'qualifiedVideoWatchHours': watchHours,
          'applicantName': legalName,
          'bankName': bankName,
          'accountNumberMasked': maskedAccount,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await firestore
          .collection(FirestoreCollections.channels)
          .doc(channelId)
          .update(channelUpdate);

      // 5. Update local controllers optimistically
      if (Get.isRegistered<DashboardController>()) {
        final dash = Get.find<DashboardController>();
        final current = dash.currentChannel.value;
        if (current != null) {
          dash.currentChannel.value = current.copyWith(
            status: ChannelStatus.underReview,
            monetizationStatus: 'underReview',
            monetizationApplication: {
              'status': 'pending',
              'submittedAt': Timestamp.now(),
              'qualifiedVideoId': qualifiedVideo.id,
              'qualifiedVideoTitle': qualifiedVideo.title,
              'qualifiedVideoViews': qualifiedVideo.viewCount,
              'qualifiedVideoWatchHours': watchHours,
              'applicantName': legalName,
              'bankName': bankName,
              'accountNumberMasked': maskedAccount,
            },
          );
        }
      }

      if (Get.isRegistered<RevenueAnalyticsController>()) {
        final rev = Get.find<RevenueAnalyticsController>();
        rev.channelKycStatus.value = 'pending';
      }

      AppSnackbar.success(
        'Monetization application submitted successfully! Our admin team will verify your details.',
      );

      Get.back<void>();
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'MonetizationApplicationController.submitApplication',
      );
      AppSnackbar.error(
        'Unable to submit monetization application right now. Please check your connection and try again.',
      );
    } finally {
      isSubmitting.value = false;
    }
  }
}

/// Separate dedicated screen for collecting Creator KYC and Bank Account details for monetization review.
class MonetizationApplicationPage extends StatelessWidget {
  const MonetizationApplicationPage({
    required this.channel,
    required this.qualifiedVideo,
    super.key,
  });

  final Channel channel;
  final Video qualifiedVideo;

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(
      MonetizationApplicationController(
        channel: channel,
        qualifiedVideo: qualifiedVideo,
      ),
    );

    final watchHours = qualifiedVideo.totalWatchTimeSeconds / 3600.0;

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        backgroundColor: AppColors.bgPage,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Get.back<void>(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Monetization Application',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              channel.name,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Qualification Milestone Showcase
            _buildQualifiedVideoBanner(qualifiedVideo, watchHours),
            const SizedBox(height: 20),

            // 2. Creator Identity & KYC Section
            _buildSectionContainer(
              title: 'Creator Identity & Verification (KYC)',
              icon: Icons.verified_user_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Provide government-issued identity details to verify ownership and ensure compliant creator earnings.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    label: 'Full Legal Name (as per Govt ID)',
                    controller: controller.legalNameController,
                    hint: 'e.g. Johnathan Doe',
                    icon: Icons.person_outline_rounded,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Obx(() => _buildDropdown(
                              label: 'ID Document Type',
                              value: controller.selectedIdType.value,
                              items: MonetizationApplicationController.idTypes,
                              onChanged: (val) {
                                if (val != null) controller.selectedIdType.value = val;
                              },
                            )),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(
                          label: 'Document / ID Number',
                          controller: controller.idNumberController,
                          hint: 'e.g. ABCDE1234F',
                          icon: Icons.badge_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          label: 'Date of Birth (Optional)',
                          controller: controller.dobController,
                          hint: 'DD/MM/YYYY',
                          icon: Icons.calendar_today_outlined,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Obx(() => _buildDropdown(
                              label: 'Country of Residence',
                              value: controller.selectedCountry.value,
                              items: MonetizationApplicationController.countries,
                              onChanged: (val) {
                                if (val != null) controller.selectedCountry.value = val;
                              },
                            )),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 3. Bank Account for Direct Payouts Section
            _buildSectionContainer(
              title: 'Direct Payout Bank Account',
              icon: Icons.account_balance_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter your authorized bank account details for direct revenue disbursements once monetization is approved.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    label: 'Bank Account Holder Name',
                    controller: controller.accountHolderController,
                    hint: 'Name as on bank passbook / statement',
                    icon: Icons.badge_outlined,
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    label: 'Bank Name',
                    controller: controller.bankNameController,
                    hint: 'e.g. State Bank of India, HDFC Bank',
                    icon: Icons.account_balance_outlined,
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    label: 'Account Number',
                    controller: controller.accountNumberController,
                    hint: 'Enter your bank account number',
                    icon: Icons.numbers_rounded,
                    isNumber: true,
                    isSecret: true,
                  ),
                  const SizedBox(height: 14),
                  _buildTextField(
                    label: 'Confirm Account Number',
                    controller: controller.confirmAccountNumberController,
                    hint: 'Re-enter bank account number',
                    icon: Icons.lock_outline_rounded,
                    isNumber: true,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          label: 'IFSC / SWIFT Code',
                          controller: controller.ifscController,
                          hint: 'e.g. SBIN0001234',
                          icon: Icons.domain_rounded,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Obx(() => _buildDropdown(
                              label: 'Account Type',
                              value: controller.selectedAccountType.value,
                              items: MonetizationApplicationController.accountTypes,
                              onChanged: (val) {
                                if (val != null) controller.selectedAccountType.value = val;
                              },
                            )),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 4. Terms and Declaration
            _buildTermsSection(controller),
            const SizedBox(height: 24),

            // 5. Submit Button
            Obx(() {
              final submitting = controller.isSubmitting.value;
              return SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: submitting
                      ? null
                      : () => controller.submitApplication(context),
                  icon: submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                          ),
                        )
                      : const Icon(
                          Icons.send_rounded,
                          color: Colors.black,
                          size: 18,
                        ),
                  label: Text(
                    submitting
                        ? 'Submitting Application...'
                        : 'Submit Application for Admin Review',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: Colors.white60,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              );
            }),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildQualifiedVideoBanner(Video video, double watchHours) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.bgSurfaceHover,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'THRESHOLD MET',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const Text(
                '1k Views & 10h Gate',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            video.title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildMetricChip(
                Icons.visibility_outlined,
                '${video.viewCount} views',
              ),
              const SizedBox(width: 10),
              _buildMetricChip(
                Icons.schedule_rounded,
                '${watchHours.toStringAsFixed(1)} hours watch time',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.bgPage,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 13),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionContainer({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.bgSurfaceHover,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.textPrimary.withValues(alpha: 0.1)),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isNumber = false,
    bool isSecret = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          obscureText: isSecret,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13.5,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: AppColors.textTertiary.withValues(alpha: 0.6),
              fontSize: 13,
            ),
            prefixIcon: Icon(icon, color: Colors.white70, size: 18),
            filled: true,
            fillColor: AppColors.bgPage,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(
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
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.bgPage,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.bgDivider),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: AppColors.bgSurface,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
              ),
              items: items.map((item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(
                    item,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTermsSection(MonetizationApplicationController controller) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Obx(() => Checkbox(
                value: controller.agreedToTerms.value,
                onChanged: (v) => controller.agreedToTerms.value = v ?? false,
                activeColor: Colors.white,
                checkColor: Colors.black,
                side: const BorderSide(color: Colors.white),
              )),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'I confirm that all identity and bank account details provided are accurate and belong to me. I understand that an administrator will verify these details before monetization is activated for this channel.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
