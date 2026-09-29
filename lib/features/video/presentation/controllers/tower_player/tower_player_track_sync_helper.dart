import 'package:get/get.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/services/user_languages_service.dart';
import 'package:truthworld/features/video/data/models/video_chapter.dart';
import 'package:truthworld/features/video/presentation/controllers/tower_player/tower_player_preferences.dart';
import 'package:truthworld/features/video/presentation/controllers/video_controller.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';

/// Synchronizes audio tracks, subtitle tracks, and display chapters from VideoController with user language preferences.
class TowerPlayerTrackSyncHelper {
  /// Synchronize tracks and chapters from VideoController
  static void syncTracks({
    required VideoController vc,
    required RxList<SubtitleTrack> subtitleTracks,
    required RxString activeSubLang,
    required void Function({required bool enabled, SubtitleTrack? track}) setSubtitles,
    required RxList<AudioTrack> audioTracks,
    required RxString activeAudioLang,
    required void Function(AudioTrack track) setAudioLanguage,
    required RxList<VideoChapter> chapters,
  }) {
    try {
      // 1. Sync Subtitles
      if (vc.availableSubtitles.isNotEmpty &&
          (subtitleTracks.isEmpty ||
              subtitleTracks.length != vc.availableSubtitles.length)) {
        subtitleTracks.assignAll(
          vc.availableSubtitles
              .map(
                (t) => SubtitleTrack(
                  label: t.label,
                  langCode: t.langCode,
                  url: t.url,
                  isDefault: t.isDefault,
                ),
              )
              .toList(),
        );

        SubtitleTrack? bestTrack;
        if (Get.isRegistered<UserLanguagesService>()) {
          final service = UserLanguagesService.to;
          bestTrack = subtitleTracks.firstWhereOrNull(
            (t) => service.isLanguageMatch(
              t.label,
              t.langCode,
              service.primaryLanguage.value,
            ),
          );
          if (bestTrack == null) {
            for (final lang in service.secondaryLanguages) {
              bestTrack = subtitleTracks.firstWhereOrNull(
                (t) => service.isLanguageMatch(t.label, t.langCode, lang),
              );
              if (bestTrack != null) break;
            }
          }
          if (bestTrack == null) {
            for (final lang in service.knownLanguages) {
              bestTrack = subtitleTracks.firstWhereOrNull(
                (t) => service.isLanguageMatch(t.label, t.langCode, lang),
              );
              if (bestTrack != null) break;
            }
          }
        }

        if (bestTrack != null) {
          setSubtitles(enabled: true, track: bestTrack);
        } else if (TowerPlayerPreferences.globalSubtitlesEnabled) {
          final prefLang = TowerPlayerPreferences.globalActiveSubLang;
          final match = subtitleTracks.firstWhereOrNull(
            (t) => t.label == prefLang,
          );
          if (match != null) {
            setSubtitles(enabled: true, track: match);
          } else if (subtitleTracks.isNotEmpty && activeSubLang.value.isEmpty) {
            setSubtitles(enabled: true, track: subtitleTracks.first);
          }
        }
      }

      // 2. Sync Audio Tracks
      if (vc.availableAudioTracks.isNotEmpty &&
          (audioTracks.isEmpty ||
              audioTracks.length != vc.availableAudioTracks.length)) {
        audioTracks.assignAll(
          vc.availableAudioTracks
              .map(
                (t) => AudioTrack(
                  label: t.label,
                  langCode: t.langCode,
                  type: t.type,
                  url: t.url,
                ),
              )
              .toList(),
        );

        AudioTrack? bestAudio;
        if (Get.isRegistered<UserLanguagesService>()) {
          final service = UserLanguagesService.to;
          bestAudio = audioTracks.firstWhereOrNull(
            (t) => service.isLanguageMatch(
              t.label,
              t.langCode,
              service.primaryLanguage.value,
            ),
          );
          if (bestAudio == null) {
            for (final lang in service.secondaryLanguages) {
              bestAudio = audioTracks.firstWhereOrNull(
                (t) => service.isLanguageMatch(t.label, t.langCode, lang),
              );
              if (bestAudio != null) break;
            }
          }
          if (bestAudio == null) {
            for (final lang in service.knownLanguages) {
              bestAudio = audioTracks.firstWhereOrNull(
                (t) => service.isLanguageMatch(t.label, t.langCode, lang),
              );
              if (bestAudio != null) break;
            }
          }
        }

        if (bestAudio != null && activeAudioLang.value.isEmpty) {
          setAudioLanguage(bestAudio);
        } else if (audioTracks.isNotEmpty && (activeAudioLang.value.isEmpty || !audioTracks.any((t) => t.label == activeAudioLang.value))) {
          activeAudioLang.value = audioTracks.first.label;
        }
      }

      // 3. Sync Display Chapters
      final displayChapters = vc.getDisplayChapters();
      if (displayChapters.isNotEmpty &&
          chapters.length != displayChapters.length) {
        chapters.assignAll(displayChapters);
      }
    } catch (e, s) {
      ErrorHandler.log(
        e,
        stackTrace: s,
        tag: 'TowerPlayerTrackSyncHelper.syncTracks',
      );
    }
  }
}
