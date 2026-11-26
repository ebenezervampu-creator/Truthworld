import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/ai_languages.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_controller.dart';
import 'package:truthworld/features/video/presentation/views/upload/components/dubbing/dubbing_multi_language_picker_sheet.dart';
import 'package:truthworld/theme/app_colors.dart';

/// Full-page screen for configuring Audio Track & Dubbing during video upload.
/// Matches Image 5 specification and the Audio Tracks page layout:
/// - Minimal back arrow
/// - "Audio Track & Dubbing" title & description
/// - Segmented mode switcher ("AI Dubbing" | "Direct Audio Track")
/// - Original Video Language card with Change action
/// - Target Language selector card
/// - Voice Cloning toggle card
/// - Speaker Diarization toggle card
/// - Voice Gender selector card
/// - Direct Audio Track file picker & role selection
/// - Solid white action button ("Generate Audio Track" / "Attach Audio Track")
class UploadAudioTrackDubbingPage extends StatelessWidget {
  const UploadAudioTrackDubbingPage({
    this.initialLangCode,
    this.initialTab = 0,
    super.key,
  });

  final String? initialLangCode;
  final int initialTab;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<UploadController>();

    // Local reactive state for this configuration page (Zero setState policy)
    final selectedTab = initialTab.obs; // 0: AI Dubbing, 1: Direct Audio Track
    final selectedLangCode = (initialLangCode ?? '').obs;
    final isVoiceCloning = (controller.aiTTSVoiceType.value == 'cloned').obs;
    final isDiarization = controller.aiDiarizationEnabled.value.obs;
    final selectedVoiceGender = 'auto'.obs;

    // Direct Track State
    final selectedRole = 'Dubbed Audio'.obs;
    final directFile = Rx<PlatformFile?>(null);

    // If an initial language was passed, pre-select it
    if (initialLangCode != null && initialLangCode!.isNotEmpty) {
      selectedLangCode.value = initialLangCode!;
    }

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Back Arrow
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Get.back<void>(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                      tooltip: 'Back',
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Display Heading & Subtitle
                  const Text(
                    'Audio Track & Dubbing',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Create a new audio track or dub your video into another language.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13.5,
                      height: 1.35,
                    ),
                  ),

                  const SizedBox(height: 22),

                  // 1. Mode Switcher (AI Dubbing | Direct Audio Track)
                  Obx(() {
                    final tab = selectedTab.value;
                    return Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131419),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildModeTab(
                              label: 'AI Dubbing',
                              icon: Icons.mic_none_rounded,
                              isSelected: tab == 0,
                              onTap: () => selectedTab.value = 0,
                            ),
                          ),
                          Expanded(
                            child: _buildModeTab(
                              label: 'Direct Audio Track',
                              icon: Icons.graphic_eq_rounded,
                              isSelected: tab == 1,
                              onTap: () => selectedTab.value = 1,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 20),

                  // 2. Original Video Language Card
                  Obx(() {
                    final baseCode = controller.effectiveVideoLanguage;
                    final baseName = controller.getLanguageName(baseCode);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131419),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Row(
                        children: [
                          buildLanguageFlag(baseName),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Original Video Language',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$baseName (Base)',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.edit_outlined, size: 13, color: Colors.white),
                            label: const Text(
                              'Change',
                              style: TextStyle(color: Colors.white, fontSize: 12),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () {
                              showSpokenLanguagePicker(
                                context: context,
                                controller: controller,
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 12),

                  // 3. Target Language Selector Card
                  Obx(() {
                    final currentCode = selectedLangCode.value;
                    final hasLang = currentCode.isNotEmpty;
                    final displayName = hasLang ? controller.getLanguageName(currentCode) : 'Select a language';

                    return InkWell(
                      onTap: () {
                        _showTargetLanguagePicker(
                          context: context,
                          controller: controller,
                          onSelected: (code) => selectedLangCode.value = code,
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF131419),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: hasLang ? Colors.white.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Row(
                          children: [
                            if (hasLang) ...[
                              buildLanguageFlag(displayName),
                              const SizedBox(width: 8),
                            ] else ...[
                              const Icon(Icons.language, color: Colors.white70, size: 20),
                              const SizedBox(width: 8),
                            ],
                            const Text(
                              'Target Language',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                displayName,
                                textAlign: TextAlign.end,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: hasLang ? Colors.white : AppColors.textSecondary,
                                  fontSize: 13.5,
                                  fontWeight: hasLang ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 20),
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 12),

                  // Content depends on Tab (0: AI Dubbing, 1: Direct Audio Track)
                  Obx(() {
                    if (selectedTab.value == 0) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Voice Cloning Toggle Card
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF131419),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.mic_none_rounded, color: Colors.white70, size: 22),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Voice Cloning',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        "Use the original speaker's voice.",
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch.adaptive(
                                  value: isVoiceCloning.value,
                                  activeColor: Colors.white,
                                  activeTrackColor: Colors.white38,
                                  onChanged: (val) {
                                    isVoiceCloning.value = val;
                                    controller.aiTTSVoiceType.value = val ? 'cloned' : 'default';
                                  },
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Speaker Diarization Toggle Card
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF131419),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.groups_rounded, color: Colors.white70, size: 22),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Speaker Diarization',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Detect and separate multiple speakers.',
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch.adaptive(
                                  value: isDiarization.value,
                                  activeColor: Colors.white,
                                  activeTrackColor: Colors.white38,
                                  onChanged: (val) {
                                    isDiarization.value = val;
                                    controller.aiDiarizationEnabled.value = val;
                                  },
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Voice Gender Card
                          InkWell(
                            onTap: () {
                              _showVoiceGenderPicker(
                                context: context,
                                selected: selectedVoiceGender.value,
                                onSelect: (val) {
                                  selectedVoiceGender.value = val;
                                },
                              );
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF131419),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.graphic_eq_rounded, color: Colors.white70, size: 22),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Voice Gender',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    _formatGender(selectedVoiceGender.value),
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.chevron_right, color: Colors.white54, size: 18),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 28),

                          // Generate Audio Track Button (Solid White)
                          SizedBox(
                            height: 50,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.auto_awesome, color: Colors.black87, size: 18),
                              label: const Text(
                                'Generate Audio Track',
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black87,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              onPressed: () {
                                final code = selectedLangCode.value.trim().toLowerCase();
                                if (code.isEmpty) {
                                  AppSnackbar.warning('Please select a target language.');
                                  return;
                                }
                                if (code == controller.effectiveVideoLanguage.trim().toLowerCase()) {
                                  AppSnackbar.warning('Target language cannot be the original spoken language.');
                                  return;
                                }
                                controller.toggleDubbingLanguage(code);
                                Get.back<void>();
                              },
                            ),
                          ),
                        ],
                      );
                    } else {
                      // Direct Audio Track Tab
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Role Selector
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF131419),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.category_outlined, color: Colors.white70, size: 20),
                                const SizedBox(width: 12),
                                const Text(
                                  'Audio Role',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: selectedRole.value,
                                    dropdownColor: const Color(0xFF1E2028),
                                    style: const TextStyle(color: Colors.white, fontSize: 13.5),
                                    icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                                    items: const [
                                      DropdownMenuItem(value: 'Dubbed Audio', child: Text('Dubbed Audio')),
                                      DropdownMenuItem(value: 'Commentary', child: Text('Commentary')),
                                      DropdownMenuItem(value: 'Descriptive Audio', child: Text('Descriptive Audio')),
                                      DropdownMenuItem(value: 'Original Spoken', child: Text('Original Spoken')),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) selectedRole.value = val;
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // File Picker Dropzone Card
                          InkWell(
                            onTap: () async {
                              final result = await FilePicker.pickFiles(
                                type: FileType.custom,
                                allowedExtensions: const ['mp3', 'wav', 'm4a', 'mp4', 'mov'],
                              );
                              if (result != null && result.files.isNotEmpty) {
                                directFile.value = result.files.first;
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF131419),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: directFile.value != null ? Colors.white : Colors.white24,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    directFile.value != null ? Icons.check_circle_rounded : Icons.upload_file_rounded,
                                    color: directFile.value != null ? Colors.white : Colors.white70,
                                    size: 32,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    directFile.value?.name ?? 'Tap to select audio or video file',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Supports .mp3, .wav, .m4a, .mp4, .mov',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 28),

                          // Attach Audio Track Button (Solid White)
                          SizedBox(
                            height: 50,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.upload_file_rounded, color: Colors.black87, size: 18),
                              label: const Text(
                                'Attach Audio Track',
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black87,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                              onPressed: () {
                                final code = selectedLangCode.value.trim().toLowerCase();
                                final file = directFile.value;
                                if (code.isEmpty) {
                                  AppSnackbar.warning('Please select a target language.');
                                  return;
                                }
                                if (file == null) {
                                  AppSnackbar.warning('Please select an audio or video file.');
                                  return;
                                }
                                controller.attachDeviceAudioTrack(code, file, selectedRole.value);
                                Get.back<void>();
                              },
                            ),
                          ),
                        ],
                      );
                    }
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buildModeTab({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.black87 : Colors.white70,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? Colors.black87 : Colors.white70,
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatGender(String val) {
    switch (val.toLowerCase()) {
      case 'male':
        return 'Male';
      case 'female':
        return 'Female';
      default:
        return 'Auto';
    }
  }

  static void _showVoiceGenderPicker({
    required BuildContext context,
    required String selected,
    required ValueChanged<String> onSelect,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          decoration: const BoxDecoration(
            color: Color(0xFF16171E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Voice Gender',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              _buildGenderTile('Auto', 'Automatically match original speaker', selected == 'auto', () {
                onSelect('auto');
                Navigator.pop(ctx);
              }),
              const SizedBox(height: 8),
              _buildGenderTile('Male', 'Synthesize natural male voice profile', selected == 'male', () {
                onSelect('male');
                Navigator.pop(ctx);
              }),
              const SizedBox(height: 8),
              _buildGenderTile('Female', 'Synthesize natural female voice profile', selected == 'female', () {
                onSelect('female');
                Navigator.pop(ctx);
              }),
            ],
          ),
        );
      },
    );
  }

  static Widget _buildGenderTile(String title, String subtitle, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? Colors.white : Colors.white12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
                ],
              ),
            ),
            if (isSelected) const Icon(Icons.check, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }

  static void _showTargetLanguagePicker({
    required BuildContext context,
    required UploadController controller,
    required ValueChanged<String> onSelected,
  }) {
    final search = ''.obs;
    final baseLang = controller.effectiveVideoLanguage.toLowerCase();
    final languages = controller.supportedLanguagesList
        .where((l) => l.code.toLowerCase() != baseLang)
        .toList();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.75,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          decoration: const BoxDecoration(
            color: Color(0xFF16171E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Select Target Language',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                onChanged: (val) => search.value = val.trim().toLowerCase(),
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search languages...',
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
                  prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),
                  filled: true,
                  fillColor: const Color(0xFF222430),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Obx(() {
                  final q = search.value;
                  final filtered = languages.where((l) {
                    if (q.isEmpty) return true;
                    return l.name.toLowerCase().contains(q) ||
                        l.nativeName.toLowerCase().contains(q) ||
                        l.code.toLowerCase().contains(q);
                  }).toList();

                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text('No languages match search', style: TextStyle(color: Colors.white38)),
                    );
                  }

                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (ctx, idx) => const Divider(color: Color(0xFF222430), height: 1),
                    itemBuilder: (_, index) {
                      final item = filtered[index];
                      final isClickable = kDubbingLaunchTargetCodes.contains(item.code.toLowerCase());
                      final isNotPlanned = kDubbingNotPlannedTargetCodes.contains(item.code.toLowerCase());
                      final semanticLabel = isClickable
                          ? '${item.name}, active'
                          : (isNotPlanned
                              ? '${item.name}, not yet supported'
                              : '${item.name}, available soon');

                      return Semantics(
                        enabled: isClickable,
                        label: semanticLabel,
                        child: ListTile(
                          leading: buildLanguageFlag(item.name),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  item.name,
                                  style: TextStyle(
                                    color: isClickable ? Colors.white : const Color(0xFFA1A1AA),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (isClickable)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF27272A),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.white24, width: 0.8),
                                  ),
                                  child: const Text(
                                    'Active',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              else if (isNotPlanned)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF27272A),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFF3F3F46), width: 0.8),
                                  ),
                                  child: const Text(
                                    'Not yet supported',
                                    style: TextStyle(
                                      color: Color(0xFFA1A1AA),
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF27272A),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFF3F3F46), width: 0.8),
                                  ),
                                  child: const Text(
                                    'Available soon',
                                    style: TextStyle(
                                      color: Color(0xFFA1A1AA),
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: item.nativeName.isNotEmpty && item.nativeName != item.name
                              ? Text(item.nativeName, style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12))
                              : null,
                          trailing: isClickable
                              ? Text(
                                  item.code.toUpperCase(),
                                  style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                                )
                              : const Icon(Icons.schedule_rounded, color: Color(0xFF52525B), size: 18),
                          onTap: isClickable
                              ? () {
                                  onSelected(item.code);
                                  Navigator.pop(ctx);
                                }
                              : () {
                                  if (isNotPlanned) {
                                    AppSnackbar.info("${item.name} isn't supported yet.");
                                  } else {
                                    AppSnackbar.info(
                                      '${item.name} is available soon! Active production dubbing languages: Telugu, Hindi, Marathi, Tamil, and Malayalam.',
                                    );
                                  }
                                },
                        ),
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }
}
