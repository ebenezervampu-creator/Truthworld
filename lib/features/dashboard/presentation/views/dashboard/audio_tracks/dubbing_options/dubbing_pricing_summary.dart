import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/channel_wallet_service.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/audio_tracks/dubbing_options/dubbing_options_state.dart';
import 'package:truthworld/features/dashboard/presentation/views/dashboard/monetization/channel_wallet_topup_sheet.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Minimal monochrome CTA footer for AI Audio Track & Dubbing generation.
/// Supports single-track and multi-language batch generation with high-contrast styling.
class DubbingPricingSummary extends StatelessWidget {
  const DubbingPricingSummary({
    required this.state,
    required this.durationSeconds,
    required this.onGenerate,
    super.key,
  });

  final DubbingOptionsState state;
  final int durationSeconds;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.twTypography;

    return Obx(() {
      final loading = state.isGenerating.value;
      final selectedCount = state.selectedLangCodes.length;
      final billableCount = state.billableLanguageCount;
      final effectiveCount = billableCount > 0 ? billableCount : selectedCount;
      final tierId = state.selectedDubbingTier.value;
      final chan = state.currentChannel.value;

      final activeRate = effectiveCount > 0
          ? ChannelWalletService.calculateProductionTierCost(
              tierId: tierId,
              languageCount: effectiveCount,
              durationSeconds: durationSeconds,
              channel: chan,
            )
          : 0.0;

      final bal = state.spendableBalance.value?.totalSpendableBalance ?? 0.0;
      final isInsufficient = state.spendableBalance.value != null &&
          activeRate > 0 &&
          bal < activeRate;

      final canSubmit = !loading && selectedCount > 0;

      final String buttonLabel;
      if (loading) {
        buttonLabel = selectedCount > 1
            ? 'Generating $selectedCount Audio Tracks...'
            : 'Generating...';
      } else if (selectedCount == 0) {
        buttonLabel = 'Select Target Language';
      } else if (isInsufficient) {
        buttonLabel = selectedCount > 1
            ? 'Pay \$${activeRate.toStringAsFixed(2)} & Generate $selectedCount Tracks'
            : 'Pay \$${activeRate.toStringAsFixed(2)} & Generate Track';
      } else if (selectedCount > 1) {
        buttonLabel = 'Generate $selectedCount Audio Tracks';
      } else {
        buttonLabel = 'Generate Audio Track';
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (activeRate > 0) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 4,
                children: [
                  Text(
                    selectedCount > 1
                        ? 'Estimated total: \$${activeRate.toStringAsFixed(2)} for $selectedCount languages'
                        : 'Estimated total: \$${activeRate.toStringAsFixed(2)}',
                    textAlign: TextAlign.center,
                    style: typography.caption.copyWith(
                      color: colors.textSecondary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (chan != null) ...[
                    Text(
                      '•',
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        ChannelWalletTopupSheet.show(
                          context,
                          channel: chan,
                          onTopupSuccess: state.loadChannelBalance,
                        );
                      },
                      child: Text(
                        'Top Up Wallet',
                        style: typography.caption.copyWith(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: canSubmit ? onGenerate : null,
              icon: loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                      ),
                    )
                  : const Icon(
                      Icons.auto_awesome,
                      size: 18,
                      color: Colors.black,
                    ),
              label: Text(
                buttonLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: typography.button.copyWith(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  letterSpacing: 0.1,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.45),
                disabledForegroundColor: Colors.black87,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}
