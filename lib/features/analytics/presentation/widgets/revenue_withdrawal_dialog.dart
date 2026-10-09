import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/security/biometric_security_service.dart';
import 'package:truthworld/core/services/currency_localization_service.dart';
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
    final isIndian = !Get.isRegistered<CurrencyLocalizationService>() || CurrencyLocalizationService.to.isIndianUser;
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
                  Expanded(
                    child: Row(
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Withdraw to Bank Account',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                isIndian ? 'Direct NEFT / IMPS Transfer' : 'Direct ACH / SWIFT Transfer',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
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
                        const SizedBox(width: 8),
                        Flexible(
                          child: Container(
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
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Payout Schedule',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              controller.isTodayPayoutDay
                                  ? (controller.isTodayGraceDay ? 'Grace Period (Day 2)' : 'Window Open (1st)')
                                  : '1st of Month (${RevenueAnalyticsStateBase.nextPayoutShortMonth})',
                              style: const TextStyle(
                                color: Color(0xFF60A5FA),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _buildPayoutScheduleBanner(),
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
              Obx(() {
                final isInd = !Get.isRegistered<CurrencyLocalizationService>() ||
                    CurrencyLocalizationService.to.isIndianUser;
                return Column(
                  children: [
                    _buildMethodTile(
                      'Direct Bank Transfer',
                      isInd
                          ? 'Direct NEFT / IMPS to Indian Bank Account & IFSC'
                          : 'Direct ACH / SWIFT Wire to Bank Account',
                      Icons.account_balance_rounded,
                    ),
                    const SizedBox(height: 6),
                    _buildMethodTile(
                      isInd ? 'UPI / Instant Payout' : 'PayPal / Direct Payout',
                      isInd
                          ? 'Instant mobile transfer to verified UPI ID'
                          : 'Direct payout to registered PayPal address',
                      isInd ? Icons.qr_code_rounded : Icons.payment_rounded,
                    ),
                  ],
                );
              }),
              const SizedBox(height: 16),

              // Dynamic Account Info Section based on Selected Method
              Obx(() {
                final isInd = !Get.isRegistered<CurrencyLocalizationService>() ||
                    CurrencyLocalizationService.to.isIndianUser;
                if (selectedMethod.value == 'Direct Bank Transfer') {
                  final savedBank = controller.savedBankAccount.value;
                  if (savedBank != null && !isEditingBankDetails.value) {
                    return _buildSavedBankCard(savedBank);
                  }
                  return _buildBankInputFields(isInd);
                } else {
                  return _buildSecondMethodInputField(isInd);
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

                final isPayoutDay = controller.isTodayPayoutDay;
                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () {
                            if (!isPayoutDay) {
                              AppSnackbar.warning(
                                'Revenue withdrawals are only permitted during the monthly payout window (1st and 2nd of each month). Next window opens on ${RevenueAnalyticsStateBase.upcomingFirstOfMonthFormatted}.',
                                title: 'Monthly Payout Schedule',
                              );
                              return;
                            }
                            _handleWithdrawalSubmit();
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isPayoutDay
                          ? const Color(0xFF10B981)
                          : const Color(0xFF3B82F6),
                      foregroundColor: isPayoutDay ? Colors.black : Colors.white,
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
                            !isPayoutDay
                                ? 'Withdrawals Open 1st of Month (Next: ${RevenueAnalyticsStateBase.nextPayoutShortMonth} 1st)'
                                : (selectedMethod.value == 'Direct Bank Transfer'
                                    ? (controller.isTodayGraceDay ? 'Withdraw (Grace Period Day 2)' : 'Withdraw Directly to Bank Account')
                                    : (isIndian ? 'Confirm UPI Withdrawal' : 'Confirm PayPal Withdrawal')),
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

  Widget _buildPayoutScheduleBanner() {
    if (controller.isTodayPayoutDay) return const SizedBox.shrink();

    final nextDate = RevenueAnalyticsStateBase.upcomingFirstOfMonthFormatted;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'YouTube-Style Monthly Payout & Rollover',
                  style: TextStyle(
                    color: Color(0xFFBFDBFE),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Cash withdrawals open on the 1st of every month with a 1-day grace period on Day 2. Your unwithdrawn earnings safely roll over to $nextDate.',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
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

  Widget _buildBankInputFields(bool isIndian) {
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
          hint: isIndian ? 'Bank Account Number' : 'Account Number / IBAN',
          icon: Icons.pin_rounded,
          isNumeric: isIndian,
        ),
        const SizedBox(height: 10),

        // Confirm Account Number
        _buildTextField(
          controller: confirmAccountController,
          hint: isIndian ? 'Confirm Bank Account Number' : 'Confirm Account / IBAN',
          icon: Icons.lock_outline_rounded,
          isNumeric: isIndian,
        ),
        const SizedBox(height: 10),

        // IFSC or SWIFT Code
        _buildTextField(
          controller: ifscController,
          hint: isIndian
              ? 'IFSC Code (e.g. SBIN0001234)'
              : 'SWIFT / BIC or Routing Code (e.g. CHASUS33)',
          icon: Icons.account_balance_outlined,
          onChanged: (val) {
            if (isIndian) {
              final inferred = CreatorBankAccount.inferBankName(val);
              if (inferred != 'Direct Bank Transfer' && bankNameController.text.isEmpty) {
                bankNameController.text = inferred;
              }
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

  Widget _buildSecondMethodInputField(bool isIndian) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isIndian
              ? 'UPI ID / Virtual Payment Address'
              : 'PayPal Email Address',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        _buildTextField(
          controller: upiController,
          hint: isIndian
              ? 'Enter UPI ID (e.g. yourname@upi, gpay, phonepe)'
              : 'Enter registered PayPal email (e.g. yourname@example.com)',
          icon: isIndian ? Icons.qr_code_rounded : Icons.email_outlined,
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
    if (!controller.isTodayPayoutDay) {
      AppSnackbar.warning(
        'Revenue withdrawals are only permitted during the monthly payout window (1st and 2nd of each month). The next window opens on ${RevenueAnalyticsStateBase.upcomingFirstOfMonthFormatted}.',
        title: 'Monthly Payout Schedule',
      );
      return;
    }

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

        final isInd = !Get.isRegistered<CurrencyLocalizationService>() ||
            CurrencyLocalizationService.to.isIndianUser;

        if (holder.isEmpty) {
          AppSnackbar.warning('Please enter Account Holder Name.');
          return;
        }
        if (isInd) {
          if (!CreatorBankAccount.isValidAccountNumber(acc)) {
            AppSnackbar.warning('Account number must be between 9 and 18 digits.');
            return;
          }
        } else {
          if (acc.length < 5) {
            AppSnackbar.warning('Please enter a valid Account Number or IBAN.');
            return;
          }
        }
        if (acc != confirmAcc) {
          AppSnackbar.warning('Bank Account numbers do not match.');
          return;
        }
        if (isInd) {
          if (!CreatorBankAccount.isValidIfsc(ifsc)) {
            AppSnackbar.warning('Please enter a valid 11-character Indian IFSC code.');
            return;
          }
        } else {
          if (ifsc.length < 4) {
            AppSnackbar.warning('Please enter a valid SWIFT, BIC, or Routing Code.');
            return;
          }
        }
        if (bank.isEmpty) {
          bank = isInd ? CreatorBankAccount.inferBankName(ifsc) : 'International Bank';
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
      final isInd = !Get.isRegistered<CurrencyLocalizationService>() ||
          CurrencyLocalizationService.to.isIndianUser;
      final accountVal = upiController.text.trim();
      if (accountVal.isEmpty) {
        AppSnackbar.warning(
          isInd ? 'Please enter your UPI ID.' : 'Please enter your PayPal email address.',
        );
        return;
      }
      if (!isInd && (!accountVal.contains('@') || !accountVal.contains('.'))) {
        AppSnackbar.warning('Please enter a valid PayPal email address.');
        return;
      }
      upiToUse = accountVal;
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
      final isInd = !Get.isRegistered<CurrencyLocalizationService>() ||
          CurrencyLocalizationService.to.isIndianUser;
      final success = await controller.submitWithdrawalRequest(
        amount: parsedAmount,
        paymentMethod: isInd ? 'UPI' : 'PayPal',
        accountDetails: upiToUse,
      );
      if (success) {
        Get.back<void>();
      }
    }
  }
}
