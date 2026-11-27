import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/dubbing/presentation/controllers/dubbing_studio_controller.dart';
import 'package:truthworld/theme/app_colors.dart';
import 'package:truthworld/theme/tw_typography.dart';

/// Modal dialog for managing the user's Personal USD Dubbing Wallet,
/// optional TruthWorld Studio Channel Wallet, and direct Cashfree checkout.
///
/// Built with TruthWorld Dark Theme (`AppColors`, `TWTypography`).
class DubbingWalletModal extends StatelessWidget {
  const DubbingWalletModal({super.key});

  static const List<int> _usdTopupTiers = [5, 10, 25, 50, 100];

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<DubbingStudioController>();

    return Dialog(
      backgroundColor: AppColors.bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
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
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.bgInput,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet_rounded,
                            color: AppColors.textLink,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Dubbing Studio Wallet',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: TWTypography.brandFamily,
                                  fontFamilyFallback: TWTypography.fallbackFamilies,
                                  color: AppColors.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Pay-as-you-go • USD Wallet & Direct Cashfree Checkout',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: TWTypography.uiFamily,
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: Get.back,
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Scrollable Body
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Current Balances Card
                      Obx(() {
                        final wallet = controller.wallet.value;
                        final personalUsd = wallet?.balanceUsd ?? 0.0;
                        final chan = controller.userChannel.value;
                        final channelUsd = controller.studioWalletSpendableBalance;

                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF1A1B1F),
                                Color(0xFF131417),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'PERSONAL DUBBING WALLET',
                                style: TextStyle(
                                  fontFamily: TWTypography.uiFamily,
                                  color: AppColors.textTertiary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 10,
                                runSpacing: 8,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(
                                        '\$${personalUsd.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontFamily: TWTypography.brandFamily,
                                          color: AppColors.textPrimary,
                                          fontSize: 30,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: -1,
                                          fontFeatures: [FontFeature.tabularFigures()],
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Text(
                                        'USD available',
                                        style: TextStyle(
                                          fontFamily: TWTypography.uiFamily,
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (chan != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.bgSurfaceHover,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                                      ),
                                      child: Text(
                                        'Channel Wallet: \$${channelUsd.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontFamily: TWTypography.uiFamily,
                                          color: AppColors.textPrimary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              if (controller.isFreeDubbingActive) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: AppColors.successContainer,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.verified_rounded, color: AppColors.success, size: 14),
                                      SizedBox(width: 6),
                                      Text(
                                        '100% Free AI Dubbing Active',
                                        style: TextStyle(
                                          fontFamily: TWTypography.uiFamily,
                                          color: AppColors.success,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ] else if (wallet?.hasSpecialDiscount ?? false) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: AppColors.successContainer,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    wallet!.discountDisplayString,
                                    style: const TextStyle(
                                      fontFamily: TWTypography.uiFamily,
                                      color: AppColors.success,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 18),

                      // Optional Wallet Scope Selector (when user has a Creator Channel)
                      Obx(() {
                        final chan = controller.userChannel.value;
                        if (chan == null) return const SizedBox.shrink();
                        final scope = controller.selectedTopupWalletScope.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Top-Up Destination',
                                style: TextStyle(
                                  fontFamily: TWTypography.uiFamily,
                                  color: AppColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  _buildScopeChip(
                                    label: 'Personal Dubbing Wallet',
                                    isSelected: scope != 'channel',
                                    onTap: () => controller.selectedTopupWalletScope.value = 'personal',
                                  ),
                                  const SizedBox(width: 8),
                                  _buildScopeChip(
                                    label: '${chan.name} Wallet',
                                    isSelected: scope == 'channel',
                                    onTap: () => controller.selectedTopupWalletScope.value = 'channel',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),

                      // Top-Up USD Presets (Zero-Charm Round Pricing)
                      const Text(
                        r'Add USD Funds ($0.30/min standard dubbing)',
                        style: TextStyle(
                          fontFamily: TWTypography.uiFamily,
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Obx(() {
                        final cur = controller.selectedPurchaseTierUsd.value;
                        return Column(
                          children: [
                            Row(
                              children: [
                                for (var i = 0; i < 3; i++) ...[
                                  if (i > 0) const SizedBox(width: 8),
                                  _buildTopupTier(
                                    amountUsd: _usdTopupTiers[i],
                                    isPopular: _usdTopupTiers[i] == 10,
                                    isSelected: cur == _usdTopupTiers[i],
                                    onSelect: () => controller.selectedPurchaseTierUsd.value = _usdTopupTiers[i],
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _buildTopupTier(
                                  amountUsd: _usdTopupTiers[3],
                                  isSelected: cur == _usdTopupTiers[3],
                                  onSelect: () => controller.selectedPurchaseTierUsd.value = _usdTopupTiers[3],
                                ),
                                const SizedBox(width: 8),
                                _buildTopupTier(
                                  amountUsd: _usdTopupTiers[4],
                                  isSelected: cur == _usdTopupTiers[4],
                                  onSelect: () => controller.selectedPurchaseTierUsd.value = _usdTopupTiers[4],
                                ),
                              ],
                            ),
                          ],
                        );
                      }),
                      const SizedBox(height: 18),

                      // Cashfree Wallet Top-Up & Direct Order Payment Actions
                      Obx(() {
                        final signedIn = Get.isRegistered<AuthService>()
                            ? AuthService.to.isUserSignedIn
                            : (controller.wallet.value?.userId.isNotEmpty ?? false);
                        if (!signedIn) {
                          return Center(
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: controller.signInWithGoogle,
                                icon: const Icon(Icons.login, color: Colors.black, size: 16),
                                label: const Text(
                                  'Sign in with Google to Top Up Wallet',
                                  style: TextStyle(
                                    fontFamily: TWTypography.uiFamily,
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                          );
                        }

                        final selectedAmount = controller.selectedPurchaseTierUsd.value;
                        final useChannel = controller.userChannel.value != null &&
                            controller.selectedTopupWalletScope.value == 'channel';
                        final isTopupBusy = controller.isPurchasingCredits.value;
                        final isDirectBusy = controller.isProcessingDirectPayment.value;
                        final orderCost = controller.calculatedCostUsd;
                        final showDirectOrderBtn =
                            orderCost > 0 && !controller.hasSufficientBalance;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ElevatedButton.icon(
                              onPressed: (isTopupBusy || isDirectBusy)
                                  ? null
                                  : () => controller.topUpWalletWithCashfree(
                                        amountUsd: selectedAmount,
                                        useChannelWallet: useChannel,
                                      ),
                              icon: isTopupBusy
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        color: Colors.black,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.add_card_rounded, size: 17, color: Colors.black),
                              label: Text(
                                isTopupBusy
                                    ? 'Processing Cashfree Top-Up...'
                                    : 'Add \$$selectedAmount USD via Cashfree',
                                style: const TextStyle(
                                  fontFamily: TWTypography.uiFamily,
                                  color: Colors.black,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                disabledBackgroundColor: AppColors.bgSurfaceHigh,
                                disabledForegroundColor: AppColors.textTertiary,
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 0,
                              ),
                            ),
                            if (showDirectOrderBtn) ...[
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: (isTopupBusy || isDirectBusy)
                                    ? null
                                    : controller.payDirectlyAndStartDubbingJob,
                                icon: isDirectBusy
                                    ? const SizedBox(
                                        width: 15,
                                        height: 15,
                                        child: CircularProgressIndicator(
                                          color: AppColors.textPrimary,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.flash_on_rounded,
                                        size: 16,
                                        color: AppColors.textPrimary,
                                      ),
                                label: Text(
                                  isDirectBusy
                                      ? 'Starting Order Checkout...'
                                      : 'Or Pay \$${orderCost.toStringAsFixed(2)} Directly for This Order',
                                  style: const TextStyle(
                                    fontFamily: TWTypography.uiFamily,
                                    color: AppColors.textPrimary,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScopeChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : AppColors.bgInput,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: isSelected ? Colors.black : AppColors.textSecondary,
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopupTier({
    required int amountUsd,
    required VoidCallback onSelect,
    bool isPopular = false,
    bool isSelected = false,
  }) {
    final approxMins = (amountUsd / 0.30).floor();
    return Expanded(
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : AppColors.bgInput,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? Colors.white
                  : (isPopular ? AppColors.textLink.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.1)),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Text(
                '\$$amountUsd',
                style: TextStyle(
                  fontFamily: TWTypography.brandFamily,
                  color: isSelected ? Colors.black : AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '~$approxMins min dub',
                style: TextStyle(
                  fontFamily: TWTypography.uiFamily,
                  color: isSelected ? Colors.black87 : AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
