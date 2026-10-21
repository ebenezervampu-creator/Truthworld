import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/theme/app_theme.dart';

class ChannelWizardFieldLabel extends StatelessWidget {
  final String label;
  final bool isRequired;

  const ChannelWizardFieldLabel(
    this.label, {
    required this.isRequired,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        if (isRequired) ...[
          const SizedBox(width: 4),
          const Text(
            '*',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFFEF4444),
            ),
          ),
        ],
      ],
    );
  }
}

class ChannelWizardInputField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final String? prefixText;
  final int maxLines;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;

  const ChannelWizardInputField({
    required this.controller,
    required this.hintText,
    this.prefixText,
    this.maxLines = 1,
    this.maxLength,
    this.inputFormatters,
    this.validator,
    this.suffix,
    this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveFormatters = <TextInputFormatter>[
      TruthworldTextInputFormatters.profanityFilter,
      if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
      ...?inputFormatters,
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF27272A)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: maxLines > 1
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              if (prefixText != null)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    prefixText!,
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 13,
                    ),
                  ),
                ),
              Expanded(
                child: TextFormField(
                  controller: controller,
                  maxLines: maxLines,
                  maxLength: maxLength,
                  buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                  inputFormatters: effectiveFormatters,
                  validator: validator,
                  onChanged: onChanged,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 13,
                    ),
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              if (suffix != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: suffix,
                ),
              if (maxLength != null && maxLines == 1)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller,
                    builder: (context, value, child) {
                      return Text(
                        '${value.text.length}/$maxLength',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
          if (maxLength != null && maxLines > 1)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, child) {
                    return Text(
                      '${value.text.length}/$maxLength',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
