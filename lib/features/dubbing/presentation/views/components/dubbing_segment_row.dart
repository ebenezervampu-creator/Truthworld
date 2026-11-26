import 'package:flutter/material.dart';
import 'package:truthworld/features/dubbing/data/models/dubbing_job.dart';
import 'package:truthworld/theme/app_colors.dart';
import 'package:truthworld/theme/tw_typography.dart';

/// ElevenLabs-inspired dialogue cue row for Pre-TTS review and Post-TTS line adjustments.
///
/// Built with TruthWorld Dark Theme (`AppColors`, `TWTypography`) and strict
/// StatelessWidget architecture (Zero `setState` Policy).
class DubbingSegmentRow extends StatelessWidget {
  final DubbingSegment segment;
  final bool isPostTtsStage;
  final ValueChanged<String>? onOriginalTextChanged;
  final ValueChanged<String>? onTranslatedTextChanged;
  final VoidCallback? onRegenerate;

  const DubbingSegmentRow({
    required this.segment,
    super.key,
    this.isPostTtsStage = false,
    this.onOriginalTextChanged,
    this.onTranslatedTextChanged,
    this.onRegenerate,
  });

  static const List<Color> _speakerPalette = [
    AppColors.textLink, // Cyan-blue
    AppColors.success,  // Emerald
    AppColors.warning,  // Amber
    Color(0xFFA855F7),  // Violet
    Color(0xFFEC4899),  // Rose
  ];

  Color _speakerColor(String speakerId) {
    final idx = speakerId.hashCode.abs() % _speakerPalette.length;
    return _speakerPalette[idx];
  }

  @override
  Widget build(BuildContext context) {
    final speakerAccent = _speakerColor(segment.speakerId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cue Header: Timecode, Speaker Pill, and Regenerate Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.bgInput,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Text(
                      segment.timecodeString,
                      style: const TextStyle(
                        fontFamily: TWTypography.uiFamily,
                        color: AppColors.textLink,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: speakerAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: speakerAccent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: speakerAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          segment.speakerId.replaceAll('_', ' ').toUpperCase(),
                          style: TextStyle(
                            fontFamily: TWTypography.uiFamily,
                            color: speakerAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (isPostTtsStage)
                OutlinedButton.icon(
                  onPressed: onRegenerate,
                  icon: const Icon(Icons.refresh_rounded, size: 14, color: AppColors.textPrimary),
                  label: const Text(
                    'Regenerate',
                    style: TextStyle(
                      fontFamily: TWTypography.uiFamily,
                      color: AppColors.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppColors.bgSurfaceHover,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Dual-Column (Desktop) or Stacked (Mobile) Script Editors
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 620;
              final origField = _buildField(
                fieldKey: ValueKey('orig_${segment.id}'),
                label: 'ORIGINAL SCRIPT',
                labelColor: AppColors.textTertiary,
                initialValue: segment.originalText,
                fillColor: AppColors.bgInput,
                textColor: AppColors.textSecondary,
                fontWeight: FontWeight.w400,
                onChanged: (val) {
                  segment.originalText = val;
                  onOriginalTextChanged?.call(val);
                },
              );

              final transField = _buildField(
                fieldKey: ValueKey('trans_${segment.id}_${segment.targetLanguage}'),
                label: 'TRANSLATED SCRIPT',
                labelColor: AppColors.textLink,
                initialValue: segment.translatedText,
                fillColor: AppColors.bgSurfaceHover,
                textColor: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                onChanged: (val) {
                  segment.translatedText = val;
                  onTranslatedTextChanged?.call(val);
                },
              );

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: origField),
                    const SizedBox(width: 14),
                    Expanded(child: transField),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  origField,
                  const SizedBox(height: 12),
                  transField,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required Key fieldKey,
    required String label,
    required Color labelColor,
    required String initialValue,
    required Color fillColor,
    required Color textColor,
    required FontWeight fontWeight,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: TWTypography.uiFamily,
            color: labelColor,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          key: fieldKey,
          initialValue: initialValue,
          maxLines: null,
          style: TextStyle(
            fontFamily: TWTypography.uiFamily,
            fontFamilyFallback: TWTypography.fallbackFamilies,
            color: textColor,
            fontSize: 13,
            fontWeight: fontWeight,
            height: 1.45,
          ),
          onChanged: onChanged,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: fillColor,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.textLink, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
