import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/security/biometric_security_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/analytics/data/models/creator_bank_account.dart';
import 'package:truthworld/features/analytics/presentation/controllers/revenue_analytics_controller.dart';
import 'package:truthworld/features/analytics/presentation/widgets/creator_kyc_dialog.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Modal dialog allowing creators to request cash withdrawals directly to their bank account once the 100 Rupees (₹100) threshold is met.
class RevenueWithdrawalDialog extends StatelessWidget {
  RevenueWithdrawalDialog({super.key}) {
    final existing = controller.savedBankAccount.value;
    if (existing != null) {
      holderController.text = existing.accountHolderName;
      accountNumberController.text = existing.accountNumber;
      confirmAccountController.text = existing.accountNumber;
      ifscController.text = existing.ifscCode;
      bankNameController.text = existing.bankName;
      selectedAccountType.value = existing.accountType;
    }
  }

  final RevenueAnalyticsController controller = RevenueAnalyticsController.to;

  final TextEditingController amountController = TextEditingController();
  final TextEditingController upiController = TextEditingController();

  // Bank transfer specific controllers
  final TextEditingController holderController = TextEditingController();
  final TextEditingController accountNumberController = TextEditingController();
  final TextEditingController confirmAccountController = TextEditingController();
  final TextEditingController ifscController = TextEditingController();
  final TextEditingController bankNameController = TextEditingController();
  final RxString selectedAccountType = 'Savings'.obs;
  final RxBool saveBankForFuture = true.obs;
  final RxBool isEditingBankDetails = false.obs;

  final RxString selectedMethod = 'Direct Bank Transfer'.obs;

  static void show(BuildContext context) {
    Get.dialog<void>(
      RevenueWithdrawalDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final available = controller.totalRevenue.value;
    amountController.text = available >= RevenueAnalyticsController.minimumWithdrawalAmount
        ? available.toStringAsFixed(2)
        : '100.00';

    return Dialog(
      backgroundColor: const Color(0xFF18181B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFF27272A)),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.account_balance_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Withdraw to Bank Account',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Direct NEFT / IMPS Transfer',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                    onPressed: Get.back,
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Balance summary card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF09090B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF27272A)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Available Balance',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '₹${available.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Minimum Withdrawal',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            '₹100 (100 Rupees Minimum)',
                            style: TextStyle(
                              color: Color(0xFFF59E0B),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // KYC Status & Verification Banner
              _buildKycStatusBanner(context),
              const SizedBox(height: 18),

              // Amount field
              const Text(
                'Withdrawal Amount (Rupees / ₹)',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  prefixStyle: const TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  hintText: '100.00',
                  hintStyle: const TextStyle(color: Color(0xFF71717A)),
                  filled: true,
                  fillColor: const Color(0xFF09090B),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF27272A)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF27272A)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF10B981)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  suffixIcon: TextButton(
                    onPressed: () {
                      amountController.text = available.toStringAsFixed(2);
                    },
                    child: const Text(
                      'MAX',
                      style: TextStyle(
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Quick amount pills
              Row(
                children: [
                  _buildQuickPill('₹100', 100),
                  const SizedBox(width: 8),
                  _buildQuickPill('₹500', 500),
                  const SizedBox(width: 8),
                  _buildQuickPill('₹1,000', 1000),
                  const SizedBox(width: 8),
                  _buildQuickPill('₹5,000', 5000),
                ],
              ),
              const SizedBox(height: 18),

              // Payment method selector
              const Text(
                'Payout Destination',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Obx(() => Column(
                children: [
                  _buildMethodTile(
                    'Direct Bank Transfer',
                    'Direct NEFT / IMPS to Indian Bank Account & IFSC',
                    Icons.account_balance_rounded,
                  ),
                  const SizedBox(height: 6),
                  _buildMethodTile(
                    'UPI / Instant Payout',
                    'Instant mobile transfer to verified UPI ID',
                    Icons.qr_code_rounded,
                  ),
                ],
              )),
              const SizedBox(height: 16),

              // Dynamic Account Info Section based on Selected Method
              Obx(() {
                if (selectedMethod.value == 'Direct Bank Transfer') {
                  final savedBank = controller.savedBankAccount.value;
                  if (savedBank != null && !isEditingBankDetails.value) {
                    return _buildSavedBankCard(savedBank);
                  }
                  return _buildBankInputFields();
                } else {
                  return _buildUpiInputField();
                }
              }),
              const SizedBox(height: 24),

              // Action buttons (Gated on KYC Verification)
              Obx(() {
                final isSubmitting = controller.isSubmittingWithdrawal.value;
                final isKycVerified = controller.isKycVerified;

                if (!isKycVerified) {
                  return SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => CreatorKycDialog.show(context),
                      icon: const Icon(Icons.verified_user_outlined, color: Colors.white, size: 18),
                      label: const Text(
                        'Complete KYC to Unlock Withdrawals',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
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
                  );
                }

                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isSubmitting ? null : _handleWithdrawalSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : Text(
                            selectedMethod.value == 'Direct Bank Transfer'
                                ? 'Withdraw Directly to Bank Account'
                                : 'Confirm UPI Withdrawal',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
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

  Widget _buildQuickPill(String label, double amount) {
    return Expanded(
      child: InkWell(
        onTap: () {
          amountController.text = amount.toStringAsFixed(0);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF27272A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKycStatusBanner(BuildContext context) {
    return Obx(() {
      final isVerified = controller.isKycVerified;
      final isPending = controller.isKycPending;
      final isRejected = controller.isKycRejected;
      final kyc = controller.creatorKyc.value;

      Color bgColor;
      Color borderColor;
      Color textColor;
      IconData icon;
      String title;
      String subtitle;
      Widget? action;

      if (isVerified) {
        bgColor = const Color(0xFF10B981).withValues(alpha: 0.12);
        borderColor = const Color(0xFF10B981).withValues(alpha: 0.3);
        textColor = const Color(0xFFD1FAE5);
        icon = Icons.verified_rounded;
        title = 'Identity & Bank Verified (KYC Complete)';
        subtitle = kyc != null && kyc.panNumber.isNotEmpty
            ? 'PAN: ${kyc.maskedPan} • Direct bank payouts are unlocked'
            : 'Your creator identity is verified for direct payouts';
      } else if (isPending) {
        bgColor = const Color(0xFFF59E0B).withValues(alpha: 0.12);
        borderColor = const Color(0xFFF59E0B).withValues(alpha: 0.3);
        textColor = const Color(0xFFFEF3C7);
        icon = Icons.hourglass_top_rounded;
        title = 'KYC Verification Under Review';
        subtitle = 'Your PAN and identity proofs are being reviewed. Payouts will unlock upon verification.';
      } else if (isRejected) {
        bgColor = const Color(0xFFEF4444).withValues(alpha: 0.12);
        borderColor = const Color(0xFFEF4444).withValues(alpha: 0.3);
        textColor = const Color(0xFFFEE2E2);
        icon = Icons.error_outline_rounded;
        title = 'KYC Verification Action Required';
        subtitle = kyc?.rejectionReason ?? 'Document verification check failed. Please re-upload your valid government ID.';
        action = TextButton(
          onPressed: () => CreatorKycDialog.show(context),
          child: const Text('Update KYC', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        );
      } else {
        bgColor = const Color(0xFF3B82F6).withValues(alpha: 0.12);
        borderColor = const Color(0xFF3B82F6).withValues(alpha: 0.3);
        textColor = const Color(0xFFBFDBFE);
        icon = Icons.assignment_ind_outlined;
        title = 'KYC Document Verification Required';
        subtitle = 'Financial compliance requires PAN & ID verification before withdrawing funds.';
        action = TextButton(
          onPressed: () => CreatorKycDialog.show(context),
          child: const Text('Verify Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        );
      }

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            ?action,
          ],
        ),
      );
    });
  }

  Widget _buildSavedBankCard(CreatorBankAccount bank) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    bank.bankName,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => isEditingBankDetails.value = true,
                child: const Text(
                  'Change Bank',
                  style: TextStyle(
                    color: Color(0xFF10B981),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Account: ${bank.maskedAccountNumber} • ${bank.accountType}',
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            'Beneficiary: ${bank.accountHolderName} • IFSC: ${bank.formattedIfsc}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildBankInputFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Bank Account Details',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (controller.savedBankAccount.value != null)
              InkWell(
                onTap: () => isEditingBankDetails.value = false,
                child: const Text(
                  'Use Saved Account',
                  style: TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),

        // Account Holder Name
        _buildTextField(
          controller: holderController,
          hint: 'Account Holder Name (As per Bank)',
          icon: Icons.person_outline_rounded,
        ),
        const SizedBox(height: 10),

        // Account Number
        _buildTextField(
          controller: accountNumberController,
          hint: 'Bank Account Number',
          icon: Icons.pin_rounded,
          isNumeric: true,
        ),
        const SizedBox(height: 10),

        // Confirm Account Number
        _buildTextField(
          controller: confirmAccountController,
          hint: 'Confirm Bank Account Number',
          icon: Icons.lock_outline_rounded,
          isNumeric: true,
        ),
        const SizedBox(height: 10),

        // IFSC Code
        _buildTextField(
          controller: ifscController,
          hint: 'IFSC Code (e.g. SBIN0001234)',
          icon: Icons.account_balance_outlined,
          onChanged: (val) {
            final inferred = CreatorBankAccount.inferBankName(val);
            if (inferred != 'Direct Bank Transfer' && bankNameController.text.isEmpty) {
              bankNameController.text = inferred;
            }
          },
        ),
        const SizedBox(height: 10),

        // Bank Name
        _buildTextField(
          controller: bankNameController,
          hint: 'Bank Name (e.g. State Bank of India)',
          icon: Icons.account_balance_rounded,
        ),
        const SizedBox(height: 10),

        // Save for future switch
        Obx(
          () => Row(
            children: [
              Checkbox(
                value: saveBankForFuture.value,
                onChanged: (val) => saveBankForFuture.value = val ?? true,
                activeColor: const Color(0xFF10B981),
                checkColor: Colors.black,
              ),
              const Expanded(
                child: Text(
                  'Save this bank account for future 1-click payouts',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUpiInputField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'UPI ID / Virtual Payment Address',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        _buildTextField(
          controller: upiController,
          hint: 'Enter UPI ID (e.g. yourname@upi, gpay, phonepe)',
          icon: Icons.qr_code_rounded,
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isNumeric = false,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
      onChanged: onChanged,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.white, size: 18),
        filled: true,
        fillColor: const Color(0xFF09090B),
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF71717A), fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF27272A)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF27272A)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF10B981)),
        ),
      ),
    );
  }

  Widget _buildMethodTile(String title, String subtitle, IconData icon) {
    final isSelected = selectedMethod.value == title;

    return InkWell(
      onTap: () => selectedMethod.value = title,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF10B981).withValues(alpha: 0.1) : const Color(0xFF09090B),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF10B981) : const Color(0xFF27272A),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleWithdrawalSubmit() async {
    final parsedAmount = double.tryParse(amountController.text.trim()) ?? 0.0;

    if (parsedAmount < RevenueAnalyticsController.minimumWithdrawalAmount) {
      AppSnackbar.warning(
        'Minimum withdrawal amount is ₹100 (100 Rupees).',
      );
      return;
    }

    if (parsedAmount > controller.totalRevenue.value) {
      AppSnackbar.warning(
        'Requested amount exceeds your available balance of ₹${controller.totalRevenue.value.toStringAsFixed(2)}.',
      );
      return;
    }

    CreatorBankAccount? bankAccountToUse;
    String? upiToUse;

    if (selectedMethod.value == 'Direct Bank Transfer') {
      final savedBank = controller.savedBankAccount.value;
      final useSaved = savedBank != null && !isEditingBankDetails.value;

      if (useSaved) {
        bankAccountToUse = savedBank;
      } else {
        final holder = holderController.text.trim();
        final acc = accountNumberController.text.trim();
        final confirmAcc = confirmAccountController.text.trim();
        final ifsc = ifscController.text.trim().toUpperCase();
        var bank = bankNameController.text.trim();

        if (holder.isEmpty) {
          AppSnackbar.warning('Please enter Account Holder Name.');
          return;
        }
        if (!CreatorBankAccount.isValidAccountNumber(acc)) {
          AppSnackbar.warning('Account number must be between 9 and 18 digits.');
          return;
        }
        if (acc != confirmAcc) {
          AppSnackbar.warning('Bank Account numbers do not match.');
          return;
        }
        if (!CreatorBankAccount.isValidIfsc(ifsc)) {
          AppSnackbar.warning('Please enter a valid 11-character Indian IFSC code.');
          return;
        }
        if (bank.isEmpty) {
          bank = CreatorBankAccount.inferBankName(ifsc);
        }

        bankAccountToUse = CreatorBankAccount(
          accountHolderName: holder,
          accountNumber: acc,
          ifscCode: ifsc,
          bankName: bank,
          accountType: selectedAccountType.value,
        );
      }
    } else {
      final upi = upiController.text.trim();
      if (upi.isEmpty) {
        AppSnackbar.warning('Please enter your UPI ID.');
        return;
      }
      upiToUse = upi;
    }

    // 🔐 Biometric & Device PIN Re-Authentication Guard
    final authenticated = await BiometricSecurityService.to.authenticateForHighValueAction(
      reason: 'Please authenticate with your fingerprint, face, or device PIN to confirm this ₹${parsedAmount.toStringAsFixed(2)} payout request.',
    );
    if (!authenticated) {
      return;
    }

    if (selectedMethod.value == 'Direct Bank Transfer' && bankAccountToUse != null) {
      final success = await controller.submitDirectBankWithdrawal(
        amount: parsedAmount,
        bankAccount: bankAccountToUse,
        saveAsDefault: saveBankForFuture.value,
      );
      if (success) {
        Get.back<void>();
      }
    } else if (upiToUse != null) {
      final success = await controller.submitWithdrawalRequest(
        amount: parsedAmount,
        paymentMethod: 'UPI',
        accountDetails: upiToUse,
      );
      if (success) {
        Get.back<void>();
      }
    }
  }
}
