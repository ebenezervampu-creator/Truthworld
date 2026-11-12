import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:truthworld/core/services/channel_wallet_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/subtitles_controller.dart';
import 'package:truthworld/features/video/data/models/ai_features.dart';
import 'package:truthworld/theme/app_theme.dart';

class GenerateAiSubtitlesModal {
  static void show(
    BuildContext context,
    SubtitlesController controller, {
    required bool isDarkMode,
  }) {
    controller.refreshSpendableBalance();
    final textColor = isDarkMode ? AppColors.textPrimary : Colors.black;
    final selectedLangs = <String>{}.obs;
    final priorityMode = 'standard'.obs;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: isDarkMode ? AppColors.bgSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(24),
          child: Obx(() {
            final existingSubs = <String>{
              ...controller.availableLanguages.map((l) => l.toLowerCase()),
              ...?controller.selectedVideo.value?.mediaSubtitles.keys.map((l) => l.toLowerCase()),
            };
            final durationSecs = controller.selectedVideo.value?.durationSeconds ??
                controller.videoDuration.value.inSeconds;
            final rawCost = ChannelWalletService.calculateAIFeatureCost(
              selectedFeatures: {'subtitles'},
              targetLanguages: selectedLangs.toList(),
              durationSeconds: durationSecs > 0 ? durationSecs : 120,
              channel: controller.currentChannel.value,
            );
            final roundedCost = rawCost > 0 ? rawCost.ceilToDouble() : 0.0;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 24,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Generate Subtitles with Truthworld AI',
                        style: AppTextStyles.pageTitle.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: isDarkMode ? Colors.white : Colors.black87),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Transcribe spoken dialogue with speech recognition and automatically translate into 130+ languages.',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),

                // Priority Mode Selector
                Text(
                  'Processing Priority Mode',
                  style: AppTextStyles.labelMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Standard (Queue)'),
                        selected: priorityMode.value == 'standard',
                        onSelected: (s) {
                          if (s) priorityMode.value = 'standard';
                        },
                        selectedColor: AppColors.brand,
                        labelStyle: TextStyle(
                          color: priorityMode.value == 'standard'
                              ? Colors.black
                              : textColor,
                          fontWeight: priorityMode.value == 'standard' ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('High Priority (Express)'),
                        selected: priorityMode.value == 'high',
                        onSelected: (s) {
                          if (s) priorityMode.value = 'high';
                        },
                        selectedColor: AppColors.brand,
                        labelStyle: TextStyle(
                          color: priorityMode.value == 'high'
                              ? Colors.black
                              : textColor,
                          fontWeight: priorityMode.value == 'high' ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Quick Select / Target Languages Selection
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Target Languages (${selectedLangs.length})',
                        style: AppTextStyles.labelMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        selectedLangs.addAll(
                          ['en', 'hi', 'te', 'ta', 'es', 'fr', 'de', 'ja']
                              .where((l) => !existingSubs.contains(l)),
                        );
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(50, 32),
                      ),
                      child: Text('Popular', style: TextStyle(fontSize: 12, color: textColor)),
                    ),
                    TextButton(
                      onPressed: selectedLangs.clear,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(40, 32),
                      ),
                      child: Text('Clear', style: TextStyle(fontSize: 12, color: textColor)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Multi-select Chips
                Flexible(
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: supportedLanguages.map((lang) {
                        final isSel = selectedLangs.contains(lang.code);
                        final isExisting = existingSubs.contains(lang.code.toLowerCase());
                        return FilterChip(
                          label: Text(
                            isExisting
                                ? '${lang.name} (In Studio)'
                                : '${lang.name} (${lang.nativeName})',
                          ),
                          selected: isSel,
                          onSelected: (val) {
                            if (val) {
                              selectedLangs.add(lang.code);
                            } else {
                              selectedLangs.remove(lang.code);
                            }
                          },
                          selectedColor: AppColors.brand,
                          checkmarkColor: Colors.black,
                          labelStyle: TextStyle(
                            color: isSel
                                ? Colors.black
                                : (isExisting ? AppColors.textSecondary : textColor),
                            fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Cost summary & Action
                Builder(
                  builder: (context) {
                    final bal = controller.spendableBalance.value?.totalSpendableBalance ?? 0.0;
                    final isInsufficient = controller.spendableBalance.value != null &&
                        selectedLangs.isNotEmpty &&
                        bal < roundedCost;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDarkMode ? AppColors.bgSurfaceHover : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.payments_outlined, size: 20, color: isDarkMode ? Colors.white : Colors.black87),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Estimated Cost:',
                                    style: AppTextStyles.caption.copyWith(fontSize: 13),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '\$${roundedCost.toInt()}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isDarkMode ? Colors.white : Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Text(
                                    'Channel Revenue:',
                                    style: AppTextStyles.caption.copyWith(
                                      fontSize: 12,
                                      color: isInsufficient ? AppColors.warning : AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '\$${bal.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: isInsufficient
                                          ? AppColors.warning
                                          : (isDarkMode ? Colors.white : Colors.black),
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isInsufficient
                                          ? AppColors.info.withValues(alpha: 0.15)
                                          : AppColors.success.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isInsufficient ? 'Direct Pay Ready' : 'Deduct from Revenue',
                                      style: TextStyle(
                                        color: isInsufficient ? AppColors.info : AppColors.success,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (isInsufficient) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.info),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Channel revenue (\$${bal.toStringAsFixed(2)}) is insufficient for \$${roundedCost.toInt()}. You can pay directly to proceed.',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton.icon(
                            onPressed: selectedLangs.isEmpty
                                ? null
                                : () async {
                                    if (isInsufficient) {
                                      final chan = controller.currentChannel.value;
                                      if (chan == null) {
                                        AppSnackbar.error('Unable to verify channel. Please select a valid channel.');
                                        return;
                                      }
                                      Navigator.pop(context);
                                      final paymentOk = await ChannelWalletService().payForSubtitlesWithCashfree(
                                        channel: chan,
                                        amountUSD: roundedCost,
                                        targetLanguages: selectedLangs.toList(),
                                        videoId: controller.selectedVideo.value?.id ?? '',
                                      );
                                      if (!paymentOk) {
                                        AppSnackbar.error('Direct payment was not completed. Please try again.');
                                        return;
                                      }
                                      controller.triggerSubtitlesGeneration(
                                        targetLanguages: selectedLangs.toList(),
                                        priorityMode: priorityMode.value,
                                        isDirectlyPaid: true,
                                      );
                                      return;
                                    }
                                    Navigator.pop(context);
                                    controller.triggerSubtitlesGeneration(
                                      targetLanguages: selectedLangs.toList(),
                                      priorityMode: priorityMode.value,
                                    );
                                  },
                            icon: Icon(
                              isInsufficient ? Icons.payment_rounded : Icons.auto_awesome_rounded,
                              size: 16,
                              color: Colors.black,
                            ),
                            label: Text(
                              isInsufficient
                                  ? 'Pay Directly (\$${roundedCost.toInt()}) & Start AI'
                                  : 'Pay with Revenue & Start AI Subtitles',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.brand,
                              foregroundColor: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            );
          }),
        );
      },
    );
  }
}
