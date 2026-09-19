import 'package:flutter/material.dart';
import 'package:truthworld/theme/app_theme.dart';

/// Summary analysis narrative box.
class FactCheckNarrativeSection extends StatelessWidget {
  const FactCheckNarrativeSection({
    required this.narrative,
    super.key,
  });

  final String narrative;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SUMMARY ANALYSIS',
          style: AppTextStyles.labelSmall.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textTertiary,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.bgDivider),
          ),
          child: Text(
            narrative,
            style: AppTextStyles.bodyMedium.copyWith(
              fontSize: 15,
              color: AppColors.textPrimary,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }
}

/// Final verified conclusion section.
class FactCheckConclusionSection extends StatelessWidget {
  const FactCheckConclusionSection({
    required this.conclusion,
    super.key,
  });

  final String conclusion;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.brand.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.verified_user_outlined,
            color: Colors.white,
            size: 32,
          ),
          const SizedBox(height: 16),
          Text(
            'CONCLUSION',
            style: AppTextStyles.labelSmall.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.brand,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            conclusion,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              fontSize: 14,
              color: AppColors.textPrimary,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Diagnostic details and validation notes.
class FactCheckDiagnosticsSection extends StatelessWidget {
  const FactCheckDiagnosticsSection({
    required this.diagnostics,
    super.key,
  });

  final List<dynamic> diagnostics;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ANALYSIS DIAGNOSTICS',
          style: AppTextStyles.labelSmall.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textTertiary,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        if (diagnostics.isEmpty)
          const FactCheckEmptyBox(
            text: 'No additional diagnostic data recorded.',
          )
        else
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.bgDivider),
            ),
            child: Column(
              children: diagnostics
                  .map(
                    (d) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '• ',
                            style: TextStyle(
                              color: AppColors.brand,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              d.toString(),
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }
}

/// Generic empty box placeholder for empty sections.
class FactCheckEmptyBox extends StatelessWidget {
  const FactCheckEmptyBox({
    required this.text,
    super.key,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Text(
        text,
        style: AppTextStyles.caption.copyWith(
          color: AppColors.textTertiary,
          fontSize: 13,
          fontStyle: FontStyle.italic,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
