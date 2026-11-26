import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/dubbing/presentation/controllers/dubbing_studio_controller.dart';
import 'package:truthworld/theme/app_colors.dart';
import 'package:truthworld/theme/tw_typography.dart';

/// Modal dialog for managing Pay-as-you-go Wallet, Free Trial Credits,
/// and purchasing credits using TruthWorld Studio Channel Wallet.
///
/// Built with TruthWorld Dark Theme (`AppColors`, `TWTypography`).
class DubbingWalletModal extends StatelessWidget {
  const DubbingWalletModal({super.key});

  int _getCreditsForAmount(int amountUsd) {
    switch (amountUsd) {
      case 5:
        return 10000;
      case 10:
        return 20000;
      case 20:
        return 45000;
      case 50:
        return 120000;
      case 100:
        return 260000;
      default:
        return amountUsd * 2000;
    }
  }

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
                  Row(
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
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dubbing Studio Wallet',
                            style: TextStyle(
                              fontFamily: TWTypography.brandFamily,
                              fontFamilyFallback: TWTypography.fallbackFamilies,
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Pay-as-you-go • Studio Wallet & Card Top-Up',
                            style: TextStyle(
                              fontFamily: TWTypography.uiFamily,
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
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
                      // Current Balance Card
                      Obx(() {
                        final wallet = controller.wallet.value;
                        final credits = wallet?.balanceCredits ?? 0;
                        final usd = wallet?.balanceUsd ?? 0.0;

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
                                'AVAILABLE DUBBING BALANCE',
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
                                        '$credits',
                                        style: const TextStyle(
                                          fontFamily: TWTypography.brandFamily,
                                          color: AppColors.textPrimary,
                                          fontSize: 30,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: -1,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Text(
                                        'characters (1 credit = 1 char)',
                                        style: TextStyle(
                                          fontFamily: TWTypography.uiFamily,
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.bgSurfaceHover,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                                    ),
                                    child: Text(
                                      '\$${usd.toStringAsFixed(2)} USD value',
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
                              if (controller.channelFreeCredits > 0) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: AppColors.warningContainer,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.bolt_rounded, color: AppColors.warning, size: 14),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          '+${controller.channelFreeCredits.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} Complimentary Characters from Channel Privileges',
                                          style: const TextStyle(
                                            fontFamily: TWTypography.uiFamily,
                                            color: AppColors.warning,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              if (controller.isFreeDubbingActive) ...[
                                const SizedBox(height: 8),
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
                              ],
                              if (wallet?.trialClaimed == true && (wallet?.totalCharactersUsed ?? 0) == 0) ...[
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
                                      Icon(Icons.check_circle_outline, color: AppColors.success, size: 14),
                                      SizedBox(width: 6),
                                      Text(
                                        '1,000 Free Characters active — test dubbing before paying',
                                        style: TextStyle(
                                          fontFamily: TWTypography.uiFamily,
                                          color: AppColors.success,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 18),

                      // Top-Up Pack Selection (Zero-Charm Round Pricing)
                      const Text(
                        'Select Character Pack (1 Credit = 1 Character)',
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
                                _buildTopupTier(
                                  amountUsd: 5,
                                  credits: 10000,
                                  isSelected: cur == 5,
                                  onSelect: () => controller.selectedPurchaseTierUsd.value = 5,
                                ),
                                const SizedBox(width: 8),
                                _buildTopupTier(
                                  amountUsd: 10,
                                  credits: 20000,
                                  isPopular: true,
                                  isSelected: cur == 10,
                                  onSelect: () => controller.selectedPurchaseTierUsd.value = 10,
                                ),
                                const SizedBox(width: 8),
                                _buildTopupTier(
                                  amountUsd: 20,
                                  credits: 45000,
                                  isSelected: cur == 20,
                                  onSelect: () => controller.selectedPurchaseTierUsd.value = 20,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _buildTopupTier(
                                  amountUsd: 50,
                                  credits: 120000,
                                  isSelected: cur == 50,
                                  onSelect: () => controller.selectedPurchaseTierUsd.value = 50,
                                ),
                                const SizedBox(width: 8),
                                _buildTopupTier(
                                  amountUsd: 100,
                                  credits: 260000,
                                  isSelected: cur == 100,
                                  onSelect: () => controller.selectedPurchaseTierUsd.value = 100,
                                ),
                              ],
                            ),
                          ],
                        );
                      }),
                      const SizedBox(height: 16),

                      // TruthWorld Studio Wallet Purchase Option
                      Obx(() {
                        final signedIn = AuthService.to.isUserSignedIn;
                        if (!signedIn) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: ElevatedButton.icon(
                                onPressed: controller.signInWithGoogle,
                                icon: const Icon(Icons.login, color: Colors.black, size: 16),
                                label: const Text(
                                  'Sign in with Google to Access Studio Wallet',
                                  style: TextStyle(
                                    fontFamily: TWTypography.uiFamily,
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                          );
                        }

                        final chan = controller.userChannel.value;
                        final studioBalance = controller.studioWalletSpendableBalance;
                        final selectedAmount = controller.selectedPurchaseTierUsd.value;
                        final selectedCredits = _getCreditsForAmount(selectedAmount);
                        final canAffordWithStudio = studioBalance >= selectedAmount;
                        final isPurchasing = controller.isPurchasingCredits.value;

                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.bgInput,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: canAffordWithStudio
                                  ? AppColors.textLink.withValues(alpha: 0.4)
                                  : Colors.white.withValues(alpha: 0.08),
                            ),
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
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: AppColors.bgSurfaceHover,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(
                                          Icons.storefront_rounded,
                                          color: AppColors.textLink,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'TruthWorld Studio Wallet',
                                        style: TextStyle(
                                          fontFamily: TWTypography.uiFamily,
                                          color: AppColors.textPrimary,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.bgSurface,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                    ),
                                    child: Text(
                                      chan != null
                                          ? '\$${studioBalance.toStringAsFixed(2)} available'
                                          : 'No Channel Linked',
                                      style: const TextStyle(
                                        fontFamily: TWTypography.uiFamily,
                                        color: AppColors.textLink,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                chan != null
                                    ? 'Channel: ${chan.name} • Purchase dubbing characters directly using your Studio Wallet balance with zero fees.'
                                    : 'Create or connect your channel in TruthWorld Studio to purchase characters with channel revenues.',
                                style: const TextStyle(
                                  fontFamily: TWTypography.uiFamily,
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (chan != null) ...[
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: (isPurchasing || !canAffordWithStudio)
                                        ? null
                                        : () => controller.purchaseCreditsWithStudioWallet(
                                              amountUsd: selectedAmount,
                                              credits: selectedCredits,
                                            ),
                                    icon: isPurchasing
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              color: Colors.black,
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.flash_on_rounded, size: 16, color: Colors.black),
                                    label: Text(
                                      isPurchasing
                                          ? 'Processing Transfer from Studio Wallet...'
                                          : 'Purchase ${selectedCredits ~/ 1000}k Characters with Studio Wallet (\$$selectedAmount)',
                                      style: const TextStyle(
                                        fontFamily: TWTypography.uiFamily,
                                        color: Colors.black,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.black,
                                      disabledBackgroundColor: AppColors.bgSurfaceHigh,
                                      disabledForegroundColor: AppColors.textTertiary,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      elevation: 0,
                                    ),
                                  ),
                                ),
                                if (!canAffordWithStudio) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.info_outline, size: 12, color: AppColors.textTertiary),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          'Need \$${(selectedAmount - studioBalance).clamp(0, 9999).toStringAsFixed(2)} more in Studio Wallet. You can also pay via Card / UPI below.',
                                          style: const TextStyle(
                                            fontFamily: TWTypography.uiFamily,
                                            color: AppColors.textTertiary,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ],
                          ),
                        );
                      }),

                      // Card / UPI Alternative
                      Obx(() {
                        final selectedAmount = controller.selectedPurchaseTierUsd.value;
                        return Container(
                          margin: const EdgeInsets.only(top: 10),
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _handleTopup(selectedAmount),
                            icon: const Icon(Icons.credit_card_rounded, size: 16, color: AppColors.textPrimary),
                            label: Text(
                              'Or Pay via Card / UPI / NetBanking (\$$selectedAmount)',
                              style: const TextStyle(
                                fontFamily: TWTypography.uiFamily,
                                color: AppColors.textPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
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

  Widget _buildTopupTier({
    required int amountUsd,
    required int credits,
    required VoidCallback onSelect,
    bool isPopular = false,
    bool isSelected = false,
  }) {
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
                '${credits ~/ 1000}k chars',
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

  void _handleTopup(int amountUsd) {
    if (!AuthService.to.isUserSignedIn) {
      Get.find<DubbingStudioController>().signInWithGoogle();
      return;
    }
    AppSnackbar.info(
      'Opening secure payment gateway for \$$amountUsd wallet top-up...',
    );
    Get.toNamed('/checkout', parameters: {
      'amount': '$amountUsd',
      'purpose': 'dubbing_wallet_topup',
    });
  }
}
