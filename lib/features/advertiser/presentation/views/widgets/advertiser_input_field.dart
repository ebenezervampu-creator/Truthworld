import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:truthworld/core/utils/truthworld_text_input_formatters.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Reusable input field tailored for advertiser forms and checkout dialogs
class AdvertiserInputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final List<TextInputFormatter>? inputFormatters;

  const AdvertiserInputField({
    required this.label,
    required this.controller,
    required this.hint,
    this.inputFormatters,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isTechnical = label.toLowerCase().contains('card') ||
        label.toLowerCase().contains('expiry') ||
        label.toLowerCase().contains('cvc') ||
        label.toLowerCase().contains('destination') ||
        label.toLowerCase().contains('link') ||
        label.toLowerCase().contains('url');
    final effectiveFormatters = inputFormatters ??
        (isTechnical ? null : TruthworldTextInputFormatters.standard);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: const TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
        ],
        TextField(
          controller: controller,
          inputFormatters: effectiveFormatters,
          style: const TextStyle(
            fontFamily: TWTypography.uiFamily,
            color: Colors.white,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              fontFamily: TWTypography.uiFamily,
              color: AppColors.textTertiary,
              fontSize: 13,
            ),
            fillColor: const Color(0xFF121212),
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF27272A)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF27272A)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }
}
