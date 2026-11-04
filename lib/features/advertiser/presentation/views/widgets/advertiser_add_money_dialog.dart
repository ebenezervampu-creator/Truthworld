import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/ad_service.dart';
import 'package:truthworld/core/services/cashfree/cashfree_country_support.dart';
import 'package:truthworld/core/services/cashfree_service.dart';
import 'package:truthworld/core/services/currency_localization_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/advertiser/presentation/controllers/advertiser_portal_controller.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Modal dialog for adding funds and topping up campaign budgets.
class AdvertiserAddMoneyDialog extends StatelessWidget {
  const AdvertiserAddMoneyDialog({
    required this.controller,
    required this.campaign,
    super.key,
  });

  final AdvertiserPortalController controller;
  final AdItem campaign;

  static void show(
    BuildContext context, {
    required AdvertiserPortalController controller,
    required AdItem campaign,
  }) {
    Get.dialog(
      AdvertiserAddMoneyDialog(
        controller: controller,
        campaign: campaign,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isIndian = !Get.isRegistered<CurrencyLocalizationService>() ||
        CurrencyLocalizationService.to.isIndianUser;
    final currency = isIndian ? 'INR' : 'USD';
    final currencySymbol = isIndian ? '₹' : r'$';
    final minAmount = isIndian ? 100.0 : 5.0;

    final presetOptions = isIndian
        ? [
            {
              'amount': 500.0,
              'label': 'Basic Boost',
              'impressions': '~2,500 views',
            },
            {
              'amount': 1000.0,
              'label': 'Popular Choice',
              'impressions': '~5,000 views',
            },
            {
              'amount': 2000.0,
              'label': 'Growth Pack',
              'impressions': '~12,000 views',
            },
            {
              'amount': 5000.0,
              'label': 'Supercharge',
              'impressions': '~35,000 views',
            },
          ]
        : [
            {
              'amount': 10.0,
              'label': 'Basic Boost',
              'impressions': '~2,500 views',
            },
            {
              'amount': 25.0,
              'label': 'Popular Choice',
              'impressions': '~6,500 views',
            },
            {
              'amount': 50.0,
              'label': 'Growth Pack',
              'impressions': '~15,000 views',
            },
            {
              'amount': 100.0,
              'label': 'Supercharge',
              'impressions': '~35,000 views',
            },
          ];

    final selectedOption = (isIndian ? 1000.0 : 25.0).obs;
    final isCustom = false.obs;
    final customAmountController = TextEditingController();

    final progressStep = 0.obs;
    final isSuccess = false.obs;
    final errorMessage = ''.obs;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 480,
        constraints: const BoxConstraints(maxHeight: 680),
        decoration: BoxDecoration(
          color: AppColors.appBarSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.bgSurface),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.bgSurface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add Funds to Campaign',
                          style: TextStyle(
                            fontFamily: TWTypography.brandFamily,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Top up balance to keep your campaign running',
                          style: TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: Get.back,
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.bgSurface, height: 1),
            // Body
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Obx(() {
                  if (progressStep.value > 0) {
                    return _buildAddMoneyProcessing(
                      progressStep: progressStep.value,
                      isSuccess: isSuccess.value,
                      campaign: campaign,
                      amountAdded: isCustom.value
                          ? (double.tryParse(customAmountController.text.trim()) ?? 0.0)
                          : selectedOption.value,
                      errorMessage: errorMessage.value,
                    );
                  }

                  final activeAmount = isCustom.value
                      ? (double.tryParse(customAmountController.text.trim()) ?? 0.0)
                      : selectedOption.value;
                  final currentBudget = campaign.totalBudget;
                  final newBudget = currentBudget + activeAmount;
                  final newRemaining = campaign.remaining + activeAmount;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Campaign Summary Card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.bgSurface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.bgSurfaceHover),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              campaign.title,
                              style: const TextStyle(
                                fontFamily: TWTypography.brandFamily,
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildMiniStat(
                                  'Current Budget',
                                  '₹${currentBudget.toStringAsFixed(0)}',
                                ),
                                _buildMiniStat(
                                  'Spent',
                                  '₹${campaign.spent.toStringAsFixed(2)}',
                                ),
                                _buildMiniStat(
                                  'Remaining',
                                  '₹${campaign.remaining.toStringAsFixed(2)}',
                                  highlight: true,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Select Top-Up Amount',
                        style: TextStyle(
                          fontFamily: TWTypography.brandFamily,
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Preset Options Grid
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 2.3,
                        children: presetOptions.map((opt) {
                          final amount = (opt['amount'] as num?)?.toDouble() ?? 0.0;
                          final isSelected =
                              !isCustom.value && selectedOption.value == amount;
                          return InkWell(
                            onTap: () {
                              isCustom.value = false;
                              selectedOption.value = amount;
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.bgSurface
                                    : AppColors.bgPage,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.bgSurfaceHover,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '$currencySymbol${amount.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          fontFamily: TWTypography.brandFamily,
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (isSelected)
                                        const Icon(
                                          Icons.check_circle_rounded,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    opt['label']! as String,
                                    style: const TextStyle(
                                      fontFamily: TWTypography.uiFamily,
                                      color: AppColors.textSecondary,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 10),
                      // Custom Amount Row
                      InkWell(
                        onTap: () => isCustom.value = true,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isCustom.value
                                ? AppColors.bgSurface
                                : AppColors.bgPage,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isCustom.value
                                  ? Colors.white
                                  : AppColors.bgSurfaceHover,
                              width: isCustom.value ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.edit_note_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Custom Amount',
                                style: TextStyle(
                                  fontFamily: TWTypography.uiFamily,
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 12),
                              if (isCustom.value)
                                Expanded(
                                  child: TextField(
                                    controller: customAmountController,
                                    keyboardType: TextInputType.number,
                                    maxLength: 8,
                                    buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(8),
                                    ],
                                    style: const TextStyle(
                                      fontFamily: TWTypography.brandFamily,
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                    decoration: InputDecoration(
                                      prefixText: '$currencySymbol ',
                                      prefixStyle: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      hintText: 'Min $currencySymbol${minAmount.toStringAsFixed(0)}',
                                      hintStyle: const TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      border: const OutlineInputBorder(
                                        borderSide:
                                            BorderSide(color: AppColors.bgElevated),
                                      ),
                                      enabledBorder: const OutlineInputBorder(
                                        borderSide:
                                            BorderSide(color: AppColors.bgElevated),
                                      ),
                                      focusedBorder: const OutlineInputBorder(
                                        borderSide:
                                            BorderSide(color: Colors.white),
                                      ),
                                    ),
                                    onChanged: (_) => isCustom.refresh(),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      // Calculation Preview
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.bgPage,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.bgSurface),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Top-Up Amount',
                                  style: TextStyle(
                                    fontFamily: TWTypography.uiFamily,
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  '+$currencySymbol${activeAmount.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontFamily: TWTypography.brandFamily,
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'New Total Budget',
                                  style: TextStyle(
                                    fontFamily: TWTypography.uiFamily,
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  '$currencySymbol${newBudget.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontFamily: TWTypography.brandFamily,
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'New Remaining Balance',
                                  style: TextStyle(
                                    fontFamily: TWTypography.uiFamily,
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  '$currencySymbol${newRemaining.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontFamily: TWTypography.brandFamily,
                                    color: AppColors.success,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      // Cashfree Gateway Summary Box
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.bgSurface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.bgSurfaceHover),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.bgSurface,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.verified_user_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isIndian
                                        ? 'Cashfree Payment Gateway'
                                        : 'Cashfree Global Gateway',
                                    style: const TextStyle(
                                      fontFamily: TWTypography.brandFamily,
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${CashfreeCountrySupport.getPaymentMethodsSummary(currency == 'INR' ? 'IN' : 'US')} • 100% Encrypted',
                                    style: const TextStyle(
                                      fontFamily: TWTypography.uiFamily,
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
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: activeAmount < minAmount
                            ? null
                            : () async {
                                progressStep.value = 1;
                                final paymentResult = await CashfreePaymentService.to.startPayment(
                                  amount: activeAmount,
                                  currency: currency,
                                  purpose: 'advertiser_campaign',
                                  orderNote: 'Top-up for Campaign: ${campaign.title}',
                                  metadata: {
                                    'campaignId': campaign.id,
                                    'campaignTitle': campaign.title,
                                    'isTopup': true,
                                  },
                                );

                                if (paymentResult.success) {
                                  final success = await AdService.to
                                      .addFundsToCampaign(
                                        campaign.id,
                                        activeAmount,
                                        syncRemoteBudget: false,
                                      );
                                  if (success) {
                                    isSuccess.value = true;
                                    progressStep.value = 4;
                                    AppSnackbar.success(
                                      '$currencySymbol${activeAmount.toStringAsFixed(0)} added to "${campaign.title}". New budget: $currencySymbol${newBudget.toStringAsFixed(0)}',
                                      title: 'Funds Added',
                                    );
                                  } else {
                                    errorMessage.value =
                                        'Payment confirmed, but failed to update budget.';
                                    progressStep.value = 0;
                                    AppSnackbar.error(errorMessage.value);
                                  }
                                } else {
                                  errorMessage.value = paymentResult.errorMessage ??
                                      'Failed to complete payment transaction.';
                                  progressStep.value = 0;
                                  if (paymentResult.errorMessage != null &&
                                      !paymentResult.errorMessage!
                                          .toLowerCase()
                                          .contains('cancel')) {
                                    AppSnackbar.error(errorMessage.value);
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          minimumSize: const Size(double.infinity, 46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          activeAmount < minAmount
                              ? 'Enter Valid Amount (Min $currencySymbol${minAmount.toStringAsFixed(0)})'
                              : 'Pay $currencySymbol${activeAmount.toStringAsFixed(0)} with Cashfree',
                          style: const TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, {bool highlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: TWTypography.uiFamily,
            color: AppColors.textSecondary,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontFamily: TWTypography.brandFamily,
            color: highlight ? AppColors.success : Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildAddMoneyProcessing({
    required int progressStep,
    required bool isSuccess,
    required AdItem campaign,
    required double amountAdded,
    required String errorMessage,
  }) {
    if (isSuccess) {
      final newBudget = campaign.totalBudget + amountAdded;
      final newRemaining = campaign.remaining + amountAdded;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 20),
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.success,
            ),
            child: const Center(
              child: Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Funds Added Successfully!',
            style: TextStyle(
              fontFamily: TWTypography.brandFamily,
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '₹${amountAdded.toStringAsFixed(0)} has been credited to "${campaign.title}".',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.bgPage,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.bgSurface),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'New Total Budget',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '₹${newBudget.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontFamily: TWTypography.brandFamily,
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'New Remaining Balance',
                      style: TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '₹${newRemaining.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontFamily: TWTypography.brandFamily,
                        color: AppColors.success,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: Get.back,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Done',
              style: TextStyle(
                fontFamily: TWTypography.uiFamily,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      );
    }

    final stepText = progressStep == 4
        ? 'Funds credited successfully!'
        : 'Connecting to Cashfree Payment Gateway...';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 30),
        const CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
        const SizedBox(height: 24),
        Text(
          stepText,
          style: const TextStyle(
            fontFamily: TWTypography.uiFamily,
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Please do not close this window',
          style: TextStyle(
            fontFamily: TWTypography.uiFamily,
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }
}
