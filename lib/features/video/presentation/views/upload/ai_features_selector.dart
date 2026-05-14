import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:truthworld/theme/app_colors.dart';
import 'package:truthworld/features/video/data/models/ai_features.dart';

// =============================================================================
// AI FEATURES SELECTOR — Creator-Controlled Feature Toggle
// Used in the video upload flow to select which AI features to apply
// =============================================================================

class AIFeaturesSelector extends StatelessWidget {
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

  const AIFeaturesSelector({
    super.key,
    required this.transcriptEnabled,
    required this.generateSubtitles,
    required this.generateDubbing,
    required this.diarizationEnabled,
    required this.summaryEnabled,
    required this.autoChaptersEnabled,
    required this.selectedLanguages,
    required this.ttsEnabled,
    required this.ttsVoiceType,
    required this.factCheckEnabled,
    required this.voiceSample,
    this.isPremiumUser = false,
    this.onPickVoiceSample,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.bgSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? AppColors.brand.withAlpha(40)
              : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.black.withAlpha(13),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          _buildHeader(isDark),
          const Divider(height: 1),
          Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Transcript (always on) ──
                _buildTranscriptSection(isDark),
                const SizedBox(height: 16),

                // ── Multilingual Support (Translation + Dubbing) ──
                _buildMultilingualSection(isDark),
                const SizedBox(height: 16),

                // ── Other Features ──
                _buildFeatureToggle(
                  isDark: isDark,
                  icon: Icons.record_voice_over_rounded,
                  title: 'Speaker Diarization',
                  subtitle: 'Identify different speakers (AssemblyAI)',
                  value: diarizationEnabled,
                  gradient: [const Color(0xFF6366F1), const Color(0xFF8B5CF6)],
                ),
                const SizedBox(height: 12),

                _buildFeatureToggle(
                  isDark: isDark,
                  icon: Icons.auto_awesome_rounded,
                  title: 'AI Summary',
                  subtitle: 'Generate key points & short summary (Gemini)',
                  value: summaryEnabled,
                  gradient: [const Color(0xFFF59E0B), const Color(0xFFEF4444)],
                ),
                const SizedBox(height: 12),

                _buildFeatureToggle(
                  isDark: isDark,
                  icon: Icons.bookmarks_rounded,
                  title: 'Auto Chapters',
                  subtitle: 'Automatically segment video into chapters (AssemblyAI)',
                  value: autoChaptersEnabled,
                  gradient: [const Color(0xFF10B981), const Color(0xFF3B82F6)],
                ),
                const SizedBox(height: 12),

                // ── Fact-Check (premium) ──
                _buildFactCheckToggle(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────── Sections ───────────────

  Widget _buildTranscriptSection(bool isDark) {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.brand.withAlpha(isDark ? 20 : 10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.brand.withAlpha(40)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.brand, Color(0xFFEF4444)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.subtitles_rounded,
              color: Colors.white,
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
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  'Powered by AssemblyAI • Always On',
                  style: GoogleFonts.roboto(
                    fontSize: 11,
                    color: AppColors.brand,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.lock_rounded, color: AppColors.brand, size: 18),
        ],
      ),
    );
  }

  Widget _buildMultilingualSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.language_rounded,
                color: Colors.white,
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
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    'Powered by Google Cloud & ElevenLabs',
                    style: GoogleFonts.roboto(
                      fontSize: 11,
                      color: isDark ? Colors.white54 : Colors.black45,
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
                isDark: isDark,
                title: 'Subtitles',
                value: generateSubtitles,
                icon: Icons.closed_caption_rounded,
                accentColor: Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSmallToggle(
                isDark: isDark,
                title: 'Dubbing',
                value: generateDubbing,
                icon: Icons.record_voice_over_rounded,
                accentColor: Color(0xFFF59E0B),
              ),
            ),
          ],
        ),
        
        Obx(() {
          if (!generateDubbing.value) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _buildDubbingOptions(isDark),
          );
        }),

        const SizedBox(height: 16),
        Text(
          'Target Languages',
          style: GoogleFonts.roboto(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        _buildLanguageGroups(isDark),
      ],
    );
  }

  Widget _buildSmallToggle({
    required bool isDark,
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
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isOn
                ? accentColor.withAlpha(isDark ? 30 : 15)
                : (isDark ? Colors.white.withAlpha(5) : Colors.grey.shade50),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isOn
                  ? accentColor.withAlpha(60)
                  : (isDark ? Colors.white.withAlpha(10) : Colors.grey.shade200),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: isOn ? accentColor : (isDark ? Colors.white38 : Colors.black38)),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.roboto(
                  fontSize: 13,
                  fontWeight: isOn ? FontWeight.w500 : FontWeight.w500,
                  color: isOn ? (isDark ? Colors.white : accentColor) : (isDark ? Colors.white60 : Colors.black54),
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

  Widget _buildDubbingOptions(bool isDark) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.black26 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ElevenLabs Dubbing Mode',
            style: GoogleFonts.roboto(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildDubbingTypeChip(isDark, 'Normal', 'standard', Icons.bolt_rounded),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDubbingTypeChip(isDark, 'Voice Clone', 'cloned', Icons.copy_rounded),
              ),
            ],
          ),
          Obx(() {
            if (ttsVoiceType.value != 'cloned') return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _buildVoiceSamplePicker(isDark),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDubbingTypeChip(bool isDark, String label, String type, IconData icon) {
    return Obx(() {
      final isSelected = ttsVoiceType.value == type;
      return InkWell(
        onTap: () => ttsVoiceType.value = type,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFF59E0B).withAlpha(isDark ? 40 : 20) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? const Color(0xFFF59E0B).withAlpha(80) : Colors.transparent),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: isSelected ? const Color(0xFFF59E0B) : (isDark ? Colors.white38 : Colors.black38)),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.roboto(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                  color: isSelected ? (isDark ? Colors.white : const Color(0xFFD97706)) : (isDark ? Colors.white54 : Colors.black54),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildLanguageGroups(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLanguageGroup(isDark, 'Widely Used', LanguageCategory.global, const Color(0xFF4285F4)),
        const SizedBox(height: 12),
        _buildLanguageGroup(isDark, 'Indian Languages', LanguageCategory.indian, const Color(0xFFFF6B35)),
        const SizedBox(height: 12),
        _buildLanguageGroup(isDark, 'All Others (100+)', LanguageCategory.other, Colors.grey),
      ],
    );
  }

  Widget _buildLanguageGroup(bool isDark, String title, LanguageCategory category, Color accentColor) {
    final langs = supportedLanguages.where((l) => l.category == category).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: GoogleFonts.roboto(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white38 : Colors.black38,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              height: 1,
              width: 40,
              color: isDark ? Colors.white10 : Colors.black12,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: langs.map((lang) => _buildLanguageChip(isDark, lang, accentColor)).toList(),
        ),
      ],
    );
  }

  Widget _buildLanguageChip(bool isDark, TranslationLanguage lang, Color accent) {
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
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? accent.withAlpha(isDark ? 40 : 20)
                : (isDark ? Colors.white.withAlpha(5) : Colors.grey.shade100),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? accent.withAlpha(80)
                  : (isDark ? Colors.white.withAlpha(10) : Colors.grey.shade300),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected)
                Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(Icons.check_circle_rounded, size: 14, color: accent),
                ),
              Text(
                lang.name,
                style: GoogleFonts.roboto(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                  color: isSelected
                      ? (isDark ? Colors.white : accent)
                      : (isDark ? Colors.white70 : Colors.black54),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  // ─────────────── Helpers ───────────────

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.brand.withAlpha(isDark ? 30 : 15),
            Colors.transparent,
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.brand, Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Content Features',
                  style: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87),
                ),
                Text(
                  'Align your content with global audiences',
                  style: GoogleFonts.roboto(fontSize: 12, color: isDark ? Colors.white54 : Colors.black45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureToggle({
    required bool isDark,
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
        padding: EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isOn
              ? gradient.first.withAlpha(isDark ? 20 : 10)
              : (isDark ? Colors.white.withAlpha(5) : Colors.grey.shade50),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isOn
                ? gradient.first.withAlpha(60)
                : (isDark ? Colors.white.withAlpha(10) : Colors.grey.shade200),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.white, size: 18),
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
                        style: GoogleFonts.roboto(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: gradient.first, borderRadius: BorderRadius.circular(6)),
                          child: Text(
                            badge,
                            style: GoogleFonts.roboto(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.roboto(fontSize: 11, color: isDark ? Colors.white54 : Colors.black45),
                  ),
                ],
              ),
            ),
            if (locked)
              const Icon(Icons.lock_outline_rounded, color: Colors.grey, size: 20)
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

  Widget _buildFactCheckToggle(bool isDark) {
    return _buildFeatureToggle(
      isDark:   isDark,
      icon:     Icons.fact_check_rounded,
      title:    'Fact-Check',
      subtitle: 'Verify claims and ensure accuracy (Gemini)',
      value:    factCheckEnabled,
      gradient: [const Color(0xFF14B8A6), const Color(0xFF0D9488)],
      locked:   false,
    );
  }

  Widget _buildVoiceSamplePicker(bool isDark) {
    return Obx(() {
      final sample = voiceSample.value;
      return InkWell(
        onTap: onPickVoiceSample,
        child: Container(
          padding: EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFFF59E0B).withAlpha(10) : const Color(0xFFF59E0B).withAlpha(5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFF59E0B).withAlpha(30), style: BorderStyle.solid),
          ),
          child: Row(
            children: [
              Icon(sample != null ? Icons.check_circle : Icons.upload_file_rounded, color: const Color(0xFFF59E0B), size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  sample != null ? '${sample.name} (${(sample.size / 1024).toStringAsFixed(0)} KB)' : 'Upload voice sample (MP3, WAV)',
                  style: GoogleFonts.roboto(
                    fontSize: 12,
                    fontWeight: sample != null ? FontWeight.w500 : FontWeight.w400,
                    color: isDark ? Colors.white70 : Colors.black54,
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





