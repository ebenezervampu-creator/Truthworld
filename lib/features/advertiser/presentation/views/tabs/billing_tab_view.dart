import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/advertiser/presentation/controllers/advertiser_portal_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Billing & Invoices / Wallet management tab for Truthworld Advertiser Studio.
class BillingTabView extends StatelessWidget {
  const BillingTabView({required this.controller, super.key});

  final AdvertiserPortalController controller;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildWalletSection(context),
          const SizedBox(height: 24),
          _buildPaymentMethodsSection(context),
          const SizedBox(height: 24),
          _buildTaxProfileSection(context),
          const SizedBox(height: 24),
          _buildInvoicesSection(context),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Billing, Invoices & Wallet',
          style: TextStyle(
            fontFamily: TWTypography.brandFamily,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Manage prepaid ad balance, automated reloads, tax invoices, and payment methods.',
          style: TextStyle(
            fontFamily: TWTypography.uiFamily,
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildWalletSection(BuildContext context) {
    return Obx(() {
      final balance = controller.walletBalance.value;
      final autoReload = controller.autoReloadEnabled.value;
      final threshold = controller.autoReloadThreshold.value;
      final reloadAmount = controller.autoReloadAmount.value;

      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF161618),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF27272A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF27272A),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Prepaid Advertiser Balance',
                          style: TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '₹${balance.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontFamily: TWTypography.brandFamily,
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _showTopUpDialog(context),
                  icon: const Icon(
                    Icons.add_circle_outline_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  label: const Text(
                    'Add Funds',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(color: Color(0xFF27272A), height: 1),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text(
                  'Quick Top-Up:',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [1000, 2500, 5000, 10000].map((amt) {
                    return InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        controller.topUpWallet(amt.toDouble());
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E22),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF323238)),
                        ),
                        child: Text(
                          '+₹$amt',
                          style: const TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF121214),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF27272A)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.bolt_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Auto-Reload on Low Balance',
                          style: TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          autoReload
                              ? 'Automatically charges your default card ₹${reloadAmount.toStringAsFixed(0)} when balance falls under ₹${threshold.toStringAsFixed(0)}.'
                              : 'Auto-reload is turned off. Your campaigns may pause if balance reaches zero.',
                          style: const TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: autoReload,
                    activeColor: AppColors.brand,
                    onChanged: (val) {
                      controller.autoReloadEnabled.value = val;
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildPaymentMethodsSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Payment Gateway & Security',
                style: TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _showTopUpDialog(context),
                icon: const Icon(
                  Icons.add_circle_outline_rounded,
                  color: Colors.white,
                  size: 16,
                ),
                label: const Text(
                  'Recharge Balance',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontSize: 13,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF3F3F46)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1F),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2E2E33)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.brand.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.security_rounded,
                    color: AppColors.textPrimary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cashfree Payment Gateway (RBI Tokenized)',
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Supports Instant UPI (Google Pay, PhonePe, Paytm, BHIM), Netbanking (50+ banks), Debit/Credit Cards, and Wallets with 256-bit SSL encryption.',
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaxProfileSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'GST & Business Invoicing Profile',
                style: TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              TextButton.icon(
                onPressed: () => _showEditTaxInfoDialog(context),
                icon: const Icon(
                  Icons.edit_note_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                label: const Text(
                  'Edit Details',
                  style: TextStyle(
                    fontFamily: TWTypography.uiFamily,
                    fontSize: 13,
                    color: AppColors.brand,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Obx(() {
            return Row(
              children: [
                Expanded(
                  child: _buildInfoTile(
                    label: 'Registered Entity',
                    value: controller.billingCompanyName.value,
                  ),
                ),
                Expanded(
                  child: _buildInfoTile(
                    label: 'GSTIN / Tax ID',
                    value: controller.billingGstin.value,
                  ),
                ),
                Expanded(
                  child: _buildInfoTile(
                    label: 'Billing Email',
                    value: controller.billingEmail.value,
                  ),
                ),
              ],
            );
          }),
          const SizedBox(height: 12),
          Obx(() {
            return _buildInfoTile(
              label: 'Registered Address',
              value: controller.billingAddress.value,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildInfoTile({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: TWTypography.uiFamily,
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value.isEmpty ? '—' : value,
          style: const TextStyle(
            fontFamily: TWTypography.uiFamily,
            fontSize: 13,
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildInvoicesSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Invoices & Payment History',
                style: TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                '18% GST itemized breakdown',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Obx(() {
            final txs = controller.transactions;
            if (txs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No transaction history found.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              );
            }

            return Column(
              children: txs.map((tx) {
                final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
                final tax = (tx['tax'] as num?)?.toDouble() ?? 0.0;
                final net = (tx['net'] as num?)?.toDouble() ?? 0.0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121214),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF27272A)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E22),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.receipt_long_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  tx['id'] as String? ?? '',
                                  style: const TextStyle(
                                    fontFamily: TWTypography.uiFamily,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    tx['status'] as String? ?? 'Paid',
                                    style: const TextStyle(
                                      fontFamily: TWTypography.uiFamily,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.success,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${tx['description']} • ${tx['paymentMethod']}',
                              style: const TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${amount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Net: ₹${net.toStringAsFixed(0)} + GST: ₹${tax.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      IconButton(
                        icon: const Icon(
                          Icons.download_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                        tooltip: 'Download Tax Invoice PDF',
                        onPressed: () {
                          AppSnackbar.show(
                            'Invoice Downloaded',
                            'Tax invoice ${tx['id']} generated and downloaded.',
                            backgroundColor: AppColors.success,
                            colorText: AppColors.textPrimary,
                          );
                        },
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          }),
        ],
      ),
    );
  }

  void _showTopUpDialog(BuildContext context) {
    final customAmountController = TextEditingController(text: '2000');
    final selectedAmount = 2000.0.obs;

    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF161618),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF27272A)),
        ),
        title: const Text(
          'Recharge Advertiser Balance',
          style: TextStyle(
            fontFamily: TWTypography.brandFamily,
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Prepaid credits are used directly to run video & banner campaigns.',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select Amount (INR)',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [1000, 2000, 5000, 10000].map((amt) {
                  return Obx(() {
                    final isSel = selectedAmount.value == amt.toDouble();
                    return InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        selectedAmount.value = amt.toDouble();
                        customAmountController.text = amt.toString();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSel ? AppColors.brand : const Color(0xFF1C1C1F),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSel ? AppColors.brand : const Color(0xFF323238),
                          ),
                        ),
                        child: Text(
                          '₹$amt',
                          style: TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isSel ? Colors.black : Colors.white,
                          ),
                        ),
                      ),
                    );
                  });
                }).toList(),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: customAmountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white, fontFamily: TWTypography.uiFamily),
                onChanged: (val) {
                  final parsed = double.tryParse(val);
                  if (parsed != null) {
                    selectedAmount.value = parsed;
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Custom Amount (₹)',
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  prefixText: '₹ ',
                  prefixStyle: const TextStyle(color: Colors.white),
                  filled: true,
                  fillColor: const Color(0xFF121214),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF27272A)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Obx(() {
                final amt = selectedAmount.value;
                final gst = amt * 0.18;
                final total = amt + gst;
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121214),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF27272A)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Wallet Credit:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          Text('₹${amt.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('GST (18%):', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          Text('₹${gst.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                        ],
                      ),
                      const Divider(color: Color(0xFF27272A), height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Payable:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          Text('₹${total.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.brand, fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              final amt = selectedAmount.value;
              if (amt > 0) {
                controller.topUpWallet(amt);
                Get.back();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.black,
            ),
            child: const Text(
              'Pay with Cashfree',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }



  void _showEditTaxInfoDialog(BuildContext context) {
    final companyController = TextEditingController(text: controller.billingCompanyName.value);
    final gstinController = TextEditingController(text: controller.billingGstin.value);
    final addressController = TextEditingController(text: controller.billingAddress.value);
    final emailController = TextEditingController(text: controller.billingEmail.value);

    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF161618),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF27272A)),
        ),
        title: const Text(
          'Edit GST & Tax Invoicing Info',
          style: TextStyle(
            fontFamily: TWTypography.brandFamily,
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: companyController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Registered Business Name',
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: const Color(0xFF121214),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: gstinController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'GSTIN / VAT Number',
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: const Color(0xFF121214),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Invoice Delivery Email',
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: const Color(0xFF121214),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressController,
                maxLines: 2,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Registered Address',
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: const Color(0xFF121214),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: Get.back,
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              controller.saveBillingDetails(
                company: companyController.text.trim(),
                gstin: gstinController.text.trim(),
                address: addressController.text.trim(),
                email: emailController.text.trim(),
              );
              Get.back();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.black,
            ),
            child: const Text('Save Details', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
