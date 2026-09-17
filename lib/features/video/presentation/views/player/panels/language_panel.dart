import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';
import 'package:truthworld/features/video/presentation/views/player/panels/language_requests.dart';
import 'package:truthworld/features/video/presentation/views/player/panels/settings_tiles.dart';
import 'package:truthworld/features/video/presentation/widgets/language_preferences_dialog.dart';

class LanguagePanel extends StatelessWidget {
  const LanguagePanel({required this.ctrl, super.key});
  final TowerPlayerController ctrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PanelHeader(
          title: 'Audio Language',
          onBack: () => ctrl.activePanel.value = '',
          onClose: null,
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Obx(() {
                  if (ctrl.audioTracks.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          'Original audio only',
                          style: TS.bodySm,
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: ctrl.audioTracks
                        .map(
                          (t) => SelectTile(
                            label: t.label,
                            sublabel: t.type,
                            badge: t.langCode.toUpperCase(),
                            selected: ctrl.activeAudioLang.value == t.label,
                            onTap: () => ctrl.setAudioLanguage(t),
                          ),
                        )
                        .toList(),
                  );
                }),
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
