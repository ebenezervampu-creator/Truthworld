import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/ad/models/ad_item.dart';
import 'package:truthworld/theme/app_theme.dart';

void showReportAdDialogModal({
  required BuildContext context,
  required AdItem ad,
  Future<void> Function({required AdItem ad, required String reason, String details})? onReportAd,
}) {
    final reasons = [
      'Inappropriate or Offensive Content',
      'Misleading, False or Scam Ad',
      "Repetitive / Don't want to see this ad",
      'Copyright or Intellectual Property Violation',
      'Harmful, Dangerous or illegal',
      'Other',
    ];

    final selectedReason = reasons.first.obs;
    final detailsController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF181818),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.bgDivider),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.report_problem_rounded,
                color: Colors.white,
                size: 24,
              ),
              SizedBox(width: 10),
              Text(
                'Report Advertisement',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Why are you reporting "${ad.title}" by ${ad.advertiser}?',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                Obx(
                  () => Column(
                    children: reasons.map((r) {
                      final isSelected = selectedReason.value == r;
                      return RadioListTile<String>(
                        value: r,
                        groupValue: selectedReason.value,
                        activeColor: AppColors.warning,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(
                          r,
                          style: TextStyle(
                            color: isSelected
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        onChanged: (val) {
                          if (val != null) {
                            selectedReason.value = val;
                          }
                        },
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: detailsController,
                  inputFormatters: TruthworldTextInputFormatters.standard,
                  maxLines: 2,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Additional details (optional)...',
                    hintStyle: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 12,
                    ),
                    filled: true,
                    fillColor: const Color(0xFF0F0F0F),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.bgDivider),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.textTertiary),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                final cleanDetails = ContentValidator.cleanProfanity(detailsController.text.trim());
                if (onReportAd != null) {
                  await onReportAd(
                    ad: ad,
                    reason: selectedReason.value,
                    details: cleanDetails,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: Colors.black,
              ),
              child: const Text(
                'Submit Report',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }
