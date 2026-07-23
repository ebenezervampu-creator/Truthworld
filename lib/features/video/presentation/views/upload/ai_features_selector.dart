import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/data/models/ai_features.dart';
import 'package:truthworld/theme/app_theme.dart';

// =============================================================================
// AI FEATURES SELECTOR — Creator-Controlled Feature Toggle
// Used in the video upload flow to select which AI features to apply
// =============================================================================

class AIFeaturesSelector extends StatelessWidget {

  const AIFeaturesSelector({
    required this.transcriptEnabled, required this.generateSubtitles, required this.generateDubbing, required this.diarizationEnabled, required this.summaryEnabled, required this.autoChaptersEnabled, required this.selectedLanguages, required this.ttsEnabled, required this.ttsVoiceType, required this.factCheckEnabled, required this.voiceSample, super.key,
    this.isPremiumUser = false,
    this.onPickVoiceSample,
  });
  // Reactive state — bound to UploadController
  final RxBool transcriptEnabled;
  final RxBool generateSubtitles;
  final RxBool generateDubbing;
  final RxBool diarizationEnabled;
  final RxBool summaryEnabled;
  final RxBool autoChaptersEnabled;
  final RxList<String> selectedLanguages;
  final RxBool ttsEnabled;
  final RxString ttsVoiceType;
  final RxBool factCheckEnabled;
  final Rx<PlatformFile?> voiceSample;
  final bool isPremiumUser;
  final VoidCallback? onPickVoiceSample;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.bgDivider,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          _buildHeader(),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Transcript (always on) ──
                _buildTranscriptSection(),
                const SizedBox(height: 16),

                // ── Multilingual Support (Translation + Dubbing) ──
                _buildMultilingualSection(),
                const SizedBox(height: 16),

                // ── Other Features ──
                _buildFeatureToggle(
                  icon: Icons.record_voice_over_rounded,
                  title: 'Speaker Diarization',
                  subtitle: 'Identify different speakers (AssemblyAI)',
                  value: diarizationEnabled,
                  gradient: [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
                ),
                const SizedBox(height: 12),

                _buildFeatureToggle(
                  icon: Icons.auto_awesome_rounded,
                  title: 'AI Summary',
                  subtitle: 'Generate key points & short summary (Gemini)',
                  value: summaryEnabled,
                  gradient: [const Color(0xFFF59E0B), const Color(0xFFEF4444)],
                ),
                const SizedBox(height: 12),

                _buildFeatureToggle(
                  icon: Icons.bookmarks_rounded,
                  title: 'Auto Chapters',
                  subtitle: 'Automatically segment video into chapters (AssemblyAI)',
                  value: autoChaptersEnabled,
                  gradient: [const Color(0xFF10B981), const Color(0xFF3B82F6)],
                ),
                const SizedBox(height: 12),

                // ── Fact-Check (premium) ──
                _buildFactCheckToggle(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────── Sections ───────────────

  Widget _buildTranscriptSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.brand.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.brand.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.brand, Color(0xFFEF4444)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.subtitles_rounded,
              color: AppColors.textPrimary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Transcription',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Powered by AssemblyAI • Always On',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.brand,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.lock_rounded, color: AppColors.brand, size: 18),
        ],
      ),
    );
  }

  Widget _buildMultilingualSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.language_rounded,
                color: AppColors.textPrimary,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Multilingual Support',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Powered by Google Cloud & ElevenLabs',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // --- Feature Toggles: Subtitles & Dubbing ---
        Row(
          children: [
            Expanded(
              child: _buildSmallToggle(
                title: 'Subtitles',
                value: generateSubtitles,
                icon: Icons.closed_caption_rounded,
                accentColor: const Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSmallToggle(
                title: 'Dubbing',
                value: generateDubbing,
                icon: Icons.record_voice_over_rounded,
                accentColor: const Color(0xFFF59E0B),
              ),
            ),
          ],
        ),
        
        Obx(() {
          if (!generateDubbing.value) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _buildDubbingOptions(),
          );
        }),

        const SizedBox(height: 16),
        Text(
          'Target Languages',
          style: AppTextStyles.labelMedium.copyWith(
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        _buildLanguageGroups(),
      ],
    );
  }

  Widget _buildSmallToggle({
    required String title,
    required RxBool value,
    required IconData icon,
    required Color accentColor,
  }) {
    return Obx(() {
      final isOn = value.value;
      return InkWell(
        onTap: () => value.value = !value.value,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isOn
                ? accentColor.withValues(alpha: 0.15)
                : AppColors.bgInput,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isOn
                  ? accentColor.withValues(alpha: 0.4)
                  : AppColors.bgDivider,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: isOn ? accentColor : AppColors.textTertiary),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isOn ? AppColors.textPrimary : AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              if (isOn) Icon(Icons.check_circle_rounded, size: 14, color: accentColor),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildDubbingOptions() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgInput,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.bgDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ElevenLabs Dubbing Mode',
            style: AppTextStyles.labelMedium.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildDubbingTypeChip('Normal', 'standard', Icons.bolt_rounded),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDubbingTypeChip('Voice Clone', 'cloned', Icons.copy_rounded),
              ),
            ],
          ),
          Obx(() {
            if (ttsVoiceType.value != 'cloned') return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _buildVoiceSamplePicker(),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDubbingTypeChip(String label, String type, IconData icon) {
    return Obx(() {
      final isSelected = ttsVoiceType.value == type;
      return InkWell(
        onTap: () => ttsVoiceType.value = type,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFF59E0B).withValues(alpha: 0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? const Color(0xFFF59E0B).withValues(alpha: 0.5) : Colors.transparent),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: isSelected ? const Color(0xFFF59E0B) : AppColors.textTertiary),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                  color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildLanguageGroups() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLanguageGroup('Widely Used', LanguageCategory.global, const Color(0xFF4285F4)),
        const SizedBox(height: 12),
        _buildLanguageGroup('Indian Languages', LanguageCategory.indian, const Color(0xFFFF6B35)),
        const SizedBox(height: 12),
        _buildLanguageGroup('All Others (100+)', LanguageCategory.other, AppColors.textTertiary),
      ],
    );
  }

  Widget _buildLanguageGroup(String title, LanguageCategory category, Color accentColor) {
    final langs = supportedLanguages.where((l) => l.category == category).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: AppTextStyles.labelSmall.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textTertiary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              height: 1,
              width: 40,
              color: AppColors.bgDivider,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: langs.map((lang) => _buildLanguageChip(lang, accentColor)).toList(),
        ),
      ],
    );
  }

  Widget _buildLanguageChip(TranslationLanguage lang, Color accent) {
    return Obx(() {
      final isSelected = selectedLanguages.contains(lang.code);
      return InkWell(
        onTap: () {
          if (isSelected) {
            selectedLanguages.remove(lang.code);
          } else {
            selectedLanguages.add(lang.code);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? accent.withValues(alpha: 0.2)
                : AppColors.bgInput,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? accent.withValues(alpha: 0.5)
                  : AppColors.bgDivider,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(Icons.check_circle_rounded, size: 14, color: accent),
                ),
              Text(
                lang.name,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                  color: isSelected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  // ─────────────── Helpers ───────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.brand.withValues(alpha: 0.15),
            Colors.transparent,
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.brand, Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.psychology_rounded, color: AppColors.textPrimary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Content Features',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'Align your content with global audiences',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureToggle({
    required IconData icon,
    required String title,
    required String subtitle,
    required RxBool value,
    required List<Color> gradient,
    bool locked = false,
    String? badge,
  }) {
    return Obx(() {
      final isOn = value.value;
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isOn
              ? gradient.first.withValues(alpha: 0.15)
              : AppColors.bgInput,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isOn
                ? gradient.first.withValues(alpha: 0.4)
                : AppColors.bgDivider,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppColors.textPrimary, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: gradient.first, borderRadius: BorderRadius.circular(6)),
                          child: Text(
                            badge,
                            style: AppTextStyles.labelSmall.copyWith(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    subtitle,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (locked)
              const Icon(Icons.lock_outline_rounded, color: AppColors.textTertiary, size: 20)
            else
              Switch(
                value: isOn,
                onChanged: (v) => value.value = v,
                activeThumbColor: gradient.first,
              ),
          ],
        ),
      );
    });
  }

  Widget _buildFactCheckToggle() {
    return _buildFeatureToggle(
      icon:     Icons.fact_check_rounded,
      title:    'Fact-Check',
      subtitle: 'Verify claims and ensure accuracy (Gemini)',
      value:    factCheckEnabled,
      gradient: [const Color(0xFF14B8A6), const Color(0xFF0D9488)],
    );
  }

  Widget _buildVoiceSamplePicker() {
    return Obx(() {
      final sample = voiceSample.value;
      return InkWell(
        onTap: onPickVoiceSample,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(sample != null ? Icons.check_circle : Icons.upload_file_rounded, color: const Color(0xFFF59E0B), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  sample != null ? '${sample.name} (${(sample.size / 1024).toStringAsFixed(0)} KB)' : 'Upload voice sample (MP3, WAV)',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontSize: 12,
                    fontWeight: sample != null ? FontWeight.w500 : FontWeight.w400,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}





