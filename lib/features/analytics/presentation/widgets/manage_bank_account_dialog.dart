import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/security/biometric_security_service.dart';
import 'package:truthworld/core/utils/truthworld_text_input_formatters.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/analytics/data/models/creator_bank_account.dart';
import 'package:truthworld/features/analytics/presentation/controllers/revenue_analytics_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Modal dialog for creators to link, view, and update their direct bank account details for revenue payouts.
class ManageBankAccountDialog extends StatelessWidget {
  ManageBankAccountDialog({super.key}) {
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

  final TextEditingController holderController = TextEditingController();
  final TextEditingController accountNumberController = TextEditingController();
  final TextEditingController confirmAccountController = TextEditingController();
  final TextEditingController ifscController = TextEditingController();
  final TextEditingController bankNameController = TextEditingController();
  final RxString selectedAccountType = 'Savings'.obs;
  final RxBool obscureAccountNumber = true.obs;

  static void show(BuildContext context) {
    Get.dialog<void>(
      ManageBankAccountDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.bgDivider),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
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
                            color: AppColors.bgSurfaceHover,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.textPrimary.withValues(alpha: 0.1)),
                          ),
                          child: const Icon(
                            Icons.account_balance_rounded,
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
                                'Direct Bank Account',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'For Direct NEFT / IMPS Creator Payouts',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                    onPressed: Get.back,
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Security notice
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.bgSurfaceHover,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.bgDivider),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Your bank information is encrypted and only used to credit earnings directly to your account.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11.5,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Account Holder Name
              _buildInputLabel('Account Holder Name (As per Bank)'),
              const SizedBox(height: 6),
              _buildTextField(
                controller: holderController,
                hint: 'e.g. Ebenezer Vampu',
                icon: Icons.person_outline_rounded,
                maxLength: 70,
              ),
              const SizedBox(height: 14),

              // Account Number
              _buildInputLabel('Bank Account Number'),
              const SizedBox(height: 6),
              Obx(() => _buildTextField(
                controller: accountNumberController,
                hint: 'Enter 9 to 18 digit account number',
                icon: Icons.pin_rounded,
                isNumeric: true,
                isObscure: obscureAccountNumber.value,
                suffixIcon: IconButton(
                  icon: Icon(
                    obscureAccountNumber.value ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  onPressed: obscureAccountNumber.toggle,
                ),
              )),
              const SizedBox(height: 14),

              // Confirm Account Number
              _buildInputLabel('Confirm Bank Account Number'),
              const SizedBox(height: 6),
              _buildTextField(
                controller: confirmAccountController,
                hint: 'Re-enter bank account number',
                icon: Icons.lock_outline_rounded,
                isNumeric: true,
              ),
              const SizedBox(height: 14),

              // IFSC Code
              _buildInputLabel('IFSC Code (11 Digits)'),
              const SizedBox(height: 6),
              _buildTextField(
                controller: ifscController,
                hint: 'e.g. SBIN0001234 or HDFC0000001',
                icon: Icons.account_balance_outlined,
                maxLength: 11,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(11),
                  FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
                ],
                onChanged: (val) {
                  final inferred = CreatorBankAccount.inferBankName(val);
                  if (inferred != 'Direct Bank Transfer' && bankNameController.text.isEmpty) {
                    bankNameController.text = inferred;
                  }
                },
              ),
              const SizedBox(height: 14),

              // Bank Name
              _buildInputLabel('Bank Name'),
              const SizedBox(height: 6),
              _buildTextField(
                controller: bankNameController,
                hint: 'e.g. State Bank of India, HDFC Bank, ICICI Bank',
                icon: Icons.account_balance_rounded,
              ),
              const SizedBox(height: 14),

              // Account Type (Savings / Current)
              _buildInputLabel('Account Type'),
              const SizedBox(height: 8),
              Obx(() => Row(
                children: [
                  Expanded(
                    child: _buildTypePill('Savings', Icons.savings_rounded),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildTypePill('Current', Icons.business_center_rounded),
                  ),
                ],
              )),
              const SizedBox(height: 24),

              // Save Button
              Obx(
                () => SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: controller.isLoadingBankAccount.value
                        ? null
                        : () async {
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

                            final account = CreatorBankAccount(
                              accountHolderName: holder,
                              accountNumber: acc,
                              ifscCode: ifsc,
                              bankName: bank,
                              accountType: selectedAccountType.value,
                            );

                            // 🔐 Biometric & Device PIN Re-Authentication Guard
                            final authenticated = await BiometricSecurityService.to.authenticateForHighValueAction(
                              reason: 'Please authenticate with your fingerprint, face, or device PIN to confirm updating your payout bank account.',
                            );
                            if (!authenticated) {
                              return;
                            }

                            final success = await controller.saveBankAccount(account);
                            if (success) {
                              Get.back<void>();
                            }
                          },
                    icon: controller.isLoadingBankAccount.value
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                    label: Text(
                      controller.isLoadingBankAccount.value ? 'Saving Account...' : 'Save Bank Account Details',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isNumeric = false,
    bool isObscure = false,
    Widget? suffixIcon,
    ValueChanged<String>? onChanged,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
  }) {
    final effectiveLimit = maxLength ?? (isNumeric ? 18 : 100);
    final effectiveFormatters = inputFormatters ??
        (isNumeric
            ? [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(18),
              ]
            : TruthworldTextInputFormatters.internationalWithLimit(effectiveLimit));

    return TextField(
      controller: controller,
      maxLength: effectiveLimit,
      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
      inputFormatters: effectiveFormatters,
      keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
      obscureText: isObscure,
      onChanged: onChanged,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.white, size: 18),
        suffixIcon: suffixIcon,
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
          borderSide: const BorderSide(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildTypePill(String type, IconData icon) {
    final isSelected = selectedAccountType.value == type;
    return InkWell(
      onTap: () => selectedAccountType.value = type,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : const Color(0xFF09090B),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? Colors.white : const Color(0xFF27272A),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? Colors.black : Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(
              type,
              style: TextStyle(
                color: isSelected ? Colors.black : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
