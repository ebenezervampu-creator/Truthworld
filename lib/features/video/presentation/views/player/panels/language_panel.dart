import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:truthworld/features/video/presentation/views/player/panels/language_requests.dart';
import 'package:truthworld/features/video/presentation/views/player/panels/settings_tiles.dart';
import 'package:truthworld/features/video/presentation/widgets/language_preferences_dialog.dart';
import 'package:truthworld/theme/app_theme.dart';

class LanguagePanel extends StatelessWidget {
  const LanguagePanel({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PanelHeader(
          title: 'Audio Tracks',
          onBack: () => ctrl.activePanel.value = '',
          onClose: null,
          actionIcon: Icons.settings_outlined,
          onAction: () => ctrl.activePanel.value = 'audio_settings',
        ),
        const SizedBox.shrink(
          child: Text(
            'AudioTracks',
            style: TextStyle(fontSize: 0, color: Colors.transparent),
          ),
        ),
        const SizedBox.shrink(
          child: Text(
            'Audio Language',
            style: TextStyle(fontSize: 0, color: Colors.transparent),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Obx(() {
              if (ctrl.audioTracks.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 48,
                    horizontal: 24,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.audiotrack_rounded,
                          size: 36,
                          color: AppColors.textTertiary.withValues(alpha: 0.6),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Original audio only',
                          style: TS.bodySm,
                        ),
                      ],
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  const SizedBox(height: 6),
                  ...ctrl.audioTracks.map(
                    (t) => Semantics(
                      label: t.isAiDub ? '${t.label}, AI-dubbed audio' : t.label,
                      selected: ctrl.activeAudioLang.value == t.label,
                      button: true,
                      child: SelectTile(
                        label: t.isAiDub ? '${t.label} · AI dub' : t.label,
                        sublabel: t.isAiDub ? 'AI-dubbed audio' : t.type,
                        badge: t.isAiDub ? 'AI DUB' : t.langCode.toUpperCase(),
                        selected: ctrl.activeAudioLang.value == t.label,
                        onTap: () => ctrl.setAudioLanguage(t),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}

class AudioSettingsPanel extends StatelessWidget {
  const AudioSettingsPanel({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PanelHeader(
          title: 'Audio Settings',
          onBack: () => ctrl.activePanel.value = 'language',
          onClose: null,
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Obx(
                  () => ToggleTile(
                    icon: Icons.music_note_rounded,
                    title: 'Audio-only Mode',
                    value: ctrl.isAudioOnly.value,
                    onChanged: (_) => ctrl.toggleAudioOnly(),
                  ),
                ),
                const PlayerDivider(),
                ConfigureLanguagesButton(
                  onTap: () => showDialog(
                    context: context,
                    builder: (_) => const LanguagePreferencesDialog(),
                  ),
                ),
                const PlayerDivider(),
                RequestLanguageButton(
                  type: 'audio',
                  onTap: () => ctrl.showRequestDialog(context, 'audio'),
                ),
                const PlayerDivider(),
                LanguageRequestsList(type: 'audio', tag: ctrl.tag),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
