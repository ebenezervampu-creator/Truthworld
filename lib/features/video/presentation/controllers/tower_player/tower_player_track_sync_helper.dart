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
    required RxList<VideoTrack> videoTracks,
    required RxString activeVideoLang,
    required void Function(VideoTrack track) setVideoLanguage,
    required RxList<VideoChapter> chapters,
  }) {
    try {
      // 1. Sync Video Tracks (YouTube-style direct localized video track)
      if (vc.availableVideoTracks.isNotEmpty) {
        if (videoTracks.isEmpty || videoTracks.length != vc.availableVideoTracks.length) {
          videoTracks.assignAll(
            vc.availableVideoTracks
                .map(
                  (t) => VideoTrack(
                    label: t.label,
                    langCode: t.langCode,
                    type: t.type,
                    url: t.url,
                  ),
                )
                .toList(),
          );
        }

        VideoTrack? bestVideo;
        if (Get.isRegistered<UserLanguagesService>()) {
          final service = UserLanguagesService.to;
          final primary = service.primaryLanguage.value;

          // Prefer dubbed video track matching user's primary language
          bestVideo = videoTracks.firstWhereOrNull(
            (t) => t.type != 'Original' && service.isLanguageMatch(t.label, t.langCode, primary),
          );

          // If no dubbed track, check if original video matches primary language
          bestVideo ??= videoTracks.firstWhereOrNull(
            (t) => service.isLanguageMatch(t.label, t.langCode, primary),
          );

          // Secondary language fallbacks
          if (bestVideo == null) {
            for (final lang in service.secondaryLanguages) {
              bestVideo = videoTracks.firstWhereOrNull(
                (t) => service.isLanguageMatch(t.label, t.langCode, lang),
              );
              if (bestVideo != null) break;
            }
          }
        }

        if (bestVideo != null) {
          if (activeVideoLang.value != bestVideo.label) {
            setVideoLanguage(bestVideo);
          }
        } else if (videoTracks.isNotEmpty &&
            (activeVideoLang.value.isEmpty ||
                !videoTracks.any((t) => t.label == activeVideoLang.value))) {
          final active = vc.activeVideoTrack.value;
          activeVideoLang.value = active?.label ?? videoTracks.first.label;
        }
      }

      // 2. Sync Audio Tracks (YouTube-style direct localized audio track)
      if (vc.availableAudioTracks.isNotEmpty) {
        if (audioTracks.isEmpty || audioTracks.length != vc.availableAudioTracks.length) {
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
        }

        // If the active video track is already a dubbed video in the primary language,
        // it carries its own native localized audio, so separate audio overlay is bypassed.
        final isDubbedVideoInPrimary = Get.isRegistered<UserLanguagesService>() &&
            activeVideoLang.value.toLowerCase().contains('(video)') &&
            UserLanguagesService.to.isLanguageMatch(
              activeVideoLang.value,
              '',
              UserLanguagesService.to.primaryLanguage.value,
            );

        if (!isDubbedVideoInPrimary) {
          AudioTrack? bestAudio;
          if (Get.isRegistered<UserLanguagesService>()) {
            final service = UserLanguagesService.to;
            final primary = service.primaryLanguage.value;

            // 2a. Prefer alternate audio track matching user's primary language
            bestAudio = audioTracks.firstWhereOrNull(
              (t) => t.type != 'Original' && service.isLanguageMatch(t.label, t.langCode, primary),
            );

            // 2b. If no alternate audio track, check if original audio is in primary language
            bestAudio ??= audioTracks.firstWhereOrNull(
              (t) => service.isLanguageMatch(t.label, t.langCode, primary),
            );

            // 2c. Fallback to secondary languages
            if (bestAudio == null) {
              for (final lang in service.secondaryLanguages) {
                bestAudio = audioTracks.firstWhereOrNull(
                  (t) => service.isLanguageMatch(t.label, t.langCode, lang),
                );
                if (bestAudio != null) break;
              }
            }
          }

          if (bestAudio != null) {
            if (activeAudioLang.value != bestAudio.label) {
              setAudioLanguage(bestAudio);
            }
          } else if (audioTracks.isNotEmpty &&
              (activeAudioLang.value.isEmpty ||
                  !audioTracks.any((t) => t.label == activeAudioLang.value))) {
            setAudioLanguage(audioTracks.first);
          }
        }
      }

      // 3. Sync Subtitles
      if (vc.availableSubtitles.isNotEmpty) {
        if (subtitleTracks.isEmpty || subtitleTracks.length != vc.availableSubtitles.length) {
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
        }

        SubtitleTrack? bestTrack;
        if (Get.isRegistered<UserLanguagesService>()) {
          final service = UserLanguagesService.to;
          final primary = service.primaryLanguage.value;
          bestTrack = subtitleTracks.firstWhereOrNull(
            (t) => service.isLanguageMatch(t.label, t.langCode, primary),
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

        final isAudibleLanguagePrimary = Get.isRegistered<UserLanguagesService>() && (
          UserLanguagesService.to.isLanguageMatch(activeVideoLang.value, '', UserLanguagesService.to.primaryLanguage.value) ||
          UserLanguagesService.to.isLanguageMatch(activeAudioLang.value, '', UserLanguagesService.to.primaryLanguage.value)
        );

        if (bestTrack != null) {
          // Exactly like YouTube: Only force subtitles on if global subtitles are turned on,
          // or if the audible language is foreign (meaning translation subtitles are necessary).
          if (TowerPlayerPreferences.globalSubtitlesEnabled || !isAudibleLanguagePrimary) {
            setSubtitles(enabled: true, track: bestTrack);
          }
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

      // 4. Sync Display Chapters
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
