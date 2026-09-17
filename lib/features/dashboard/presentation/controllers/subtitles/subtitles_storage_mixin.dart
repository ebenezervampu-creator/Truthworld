import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show Uint8List, kIsWeb;
import 'package:flutter/material.dart' show UniqueKey;
import 'package:http/http.dart' as http;
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/core/utils/subtitle_parser.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/subtitles/subtitle_cue_model.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/subtitles/subtitles_controller_base.dart';
import 'package:truthworld/features/video/data/models/video_media.dart';
import 'package:truthworld/features/video/data/services/video_media_service.dart';

/// Mixin handling subtitle parsing, file imports, storage uploads, and saving
mixin SubtitlesStorageMixin on SubtitlesControllerBase {
  @override
  Future<void> parseCuesForLanguage(String langCode, String? urlOrData) async {
    if (urlOrData == null || urlOrData.trim().isEmpty) {
      currentCues.clear();
      return;
    }

    var contentToParse = urlOrData;

    if (urlOrData.startsWith('gs://') ||
        urlOrData.startsWith('http://') ||
        urlOrData.startsWith('https://')) {
      try {
        setViewState(ViewState.loading);
        var downloadUrl = urlOrData;

        if (urlOrData.startsWith('gs://')) {
          downloadUrl = await FirebaseStorage.instance
              .refFromURL(urlOrData)
              .getDownloadURL();
        }

        final response = await http.get(Uri.parse(downloadUrl));
        if (response.statusCode == 200) {
          contentToParse = response.body;
        } else {
          logger.error(
            'Failed to download subtitle file from $downloadUrl, status: ${response.statusCode}',
            tag: SubtitlesControllerBase.subtitlesTag,
          );
          currentCues.clear();
          setViewState(ViewState.success);
          return;
        }
      } catch (e) {
        logger.error(
          'Error downloading/resolving remote subtitle link: $urlOrData',
          error: e,
          tag: SubtitlesControllerBase.subtitlesTag,
        );
        currentCues.clear();
        setViewState(ViewState.success);
        return;
      }
    }

    final segments = SubtitleParser.parse(contentToParse);
    if (segments.isNotEmpty) {
      currentCues.value = segments.map((seg) {
        return SubtitleCue(
          id: UniqueKey().toString(),
          startTime: SubtitlesControllerBase.formatDurationToTimecode(seg.start),
          endTime: SubtitlesControllerBase.formatDurationToTimecode(seg.end),
          text: seg.text,
        );
      }).toList();
      setViewState(ViewState.success);
      return;
    }

    currentCues.clear();
    setViewState(ViewState.success);
  }

  Future<void> saveCurrentSubtitles() async {
    final video = selectedVideo.value;
    final lang = selectedLanguage.value;
    if (video == null || lang.isEmpty) return;

    for (var i = 0; i < currentCues.length; i++) {
      final cue = currentCues[i];
      if (cue.text.trim().isNotEmpty) {
        final isEn = lang.toLowerCase() == 'en';
        final v = ContentValidator.validate(
          cue.text,
          fieldName: 'Subtitle Cue ${i + 1}',
          checkEnglishOnly: isEn,
        );
        if (!v.isValid) {
          showWarning(v.message);
          return;
        }
      }
    }

    isSaving.value = true;
    try {
      final buffer = StringBuffer();
      buffer.writeln('WEBVTT');
      buffer.writeln();
      for (final cue in currentCues) {
        buffer.writeln('${cue.startTime} --> ${cue.endTime}');
        buffer.writeln(cue.text);
        buffer.writeln();
      }
      final vttContent = buffer.toString();

      final updatedSubs = Map<String, String>.from(video.mediaSubtitles);

      final existingValue = updatedSubs[lang] ?? '';
      final isAlreadyUrl = existingValue.startsWith('http') ||
          existingValue.startsWith('gs://') ||
          existingValue.startsWith('https://');

      if (currentCues.isNotEmpty || !isAlreadyUrl) {
        final jobId = video.id;
        final storagePath = 'subtitles/$jobId/$lang.vtt';
        final storageRef = FirebaseStorage.instance.ref().child(storagePath);
        final vttBytes = vttContent.codeUnits;
        final currentUid = FirebaseAuth.instance.currentUser?.uid;
        await storageRef.putData(
          Uint8List.fromList(vttBytes),
          SettableMetadata(
            contentType: 'text/vtt',
            customMetadata: {
              'uploaderId': ?currentUid,
            },
          ),
        );

        final bucket = FirebaseStorage.instance.ref().bucket;
        final gsUrl = 'gs://$bucket/$storagePath';
        updatedSubs[lang] = gsUrl;
      }

      await firestore
          .collection(FirestoreCollections.videos)
          .doc(video.id)
          .collection('media')
          .doc('localization')
          .set({
            'subtitles': updatedSubs,
            'dubbedVideos': video.dubbedVideos,
            'audioTracks': video.audioTracks,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      await firestore
          .collection(FirestoreCollections.videos)
          .doc(video.id)
          .update({
            'subtitles': updatedSubs,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      VideoMediaService.localizationCache[video.id] = VideoMediaLocalization(
        subtitles: updatedSubs,
        dubbedVideos: video.dubbedVideos,
        audioTracks: video.audioTracks,
      );

      selectedVideo.refresh();

      hasUnsavedChanges.value = false;
      showSuccess('${getLanguageName(lang)} subtitles saved successfully!');
    } catch (e, stack) {
      logger.error(
        'Failed to save subtitles',
        error: e,
        stackTrace: stack,
        tag: SubtitlesControllerBase.subtitlesTag,
      );
      handleError('Failed to save subtitle track');
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> uploadSubtitleTrack({
    required String languageCode,
    required String title,
    required PlatformFile file,
  }) async {
    final video = selectedVideo.value;
    if (video == null) {
      showError('No video selected.');
      return;
    }

    isUploadingFile.value = true;
    try {
      final valResult = await validateContent(title, fieldName: 'Track Title');
      if (!valResult.isValid) {
        showError(valResult.message);
        return;
      }

      final Uint8List fileBytes;
      if (kIsWeb) {
        if (file.bytes == null) {
          showError('Invalid file: no bytes read.');
          return;
        }
        fileBytes = file.bytes!;
      } else {
        if (file.path == null) {
          showError('Invalid file: path is null.');
          return;
        }
        final localFile = File(file.path!);
        if (!localFile.existsSync()) {
          showError('File does not exist locally.');
          return;
        }
        fileBytes = await localFile.readAsBytes();
      }

      final sanitizedTitle = title.replaceAll(RegExp('[^a-zA-Z0-9_-]'), '_');
      final extension = file.extension ?? 'vtt';
      final storagePath =
          'videos/${video.id}/subtitles/${sanitizedTitle}_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final storageRef = FirebaseStorage.instance.ref().child(storagePath);

      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final metadata = SettableMetadata(
        contentType: 'text/vtt',
        customMetadata: {
          'uploaderId': ?currentUid,
        },
      );

      final uploadTask = storageRef.putData(fileBytes, metadata);
      await uploadTask;

      final bucket = FirebaseStorage.instance.ref().bucket;
      final gsUrl = 'gs://$bucket/$storagePath';

      final updatedSubs = Map<String, String>.from(video.mediaSubtitles);
      updatedSubs[title] = gsUrl;

      await firestore
          .collection(FirestoreCollections.videos)
          .doc(video.id)
          .collection('media')
          .doc('localization')
          .set({
            'subtitles': updatedSubs,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      VideoMediaService.localizationCache[video.id] = VideoMediaLocalization(
        subtitles: updatedSubs,
        dubbedVideos: video.dubbedVideos,
        audioTracks: video.audioTracks,
      );

      selectedVideo.refresh();

      if (!availableLanguages.contains(title)) {
        availableLanguages.add(title);
      }
      selectedLanguage.value = title;
      hasUnsavedChanges.value = false;
      if (updatedSubs.containsKey(title)) {
        parseCuesForLanguage(title, updatedSubs[title]);
      }

      showSuccess('Subtitle track "$title" uploaded successfully!');
    } catch (e, stack) {
      logger.error(
        'Failed to upload subtitle track',
        error: e,
        stackTrace: stack,
        tag: SubtitlesControllerBase.subtitlesTag,
      );
      showError('Unable to upload subtitle track. Please try again.');
    } finally {
      isUploadingFile.value = false;
    }
  }

  Future<void> deleteLanguageTrack(String langCode) async {
    final video = selectedVideo.value;
    if (video == null) return;
    try {
      final updatedSubs = Map<String, String>.from(video.mediaSubtitles);
      updatedSubs.remove(langCode);
      availableLanguages.remove(langCode);

      await firestore
          .collection(FirestoreCollections.videos)
          .doc(video.id)
          .collection('media')
          .doc('localization')
          .set({
            'subtitles': updatedSubs,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      await firestore
          .collection(FirestoreCollections.videos)
          .doc(video.id)
          .update({
            'subtitles': updatedSubs,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      VideoMediaService.localizationCache[video.id] = VideoMediaLocalization(
        subtitles: updatedSubs,
        dubbedVideos: video.dubbedVideos,
        audioTracks: video.audioTracks,
      );

      if (selectedLanguage.value == langCode) {
        if (availableLanguages.isNotEmpty) {
          selectedLanguage.value = availableLanguages.first;
          hasUnsavedChanges.value = false;
          final subs = updatedSubs;
          if (subs.containsKey(availableLanguages.first)) {
            parseCuesForLanguage(availableLanguages.first, subs[availableLanguages.first]);
          } else {
            currentCues.clear();
          }
        } else {
          selectedLanguage.value = '';
          currentCues.clear();
        }
      }
      selectedVideo.refresh();
      showSuccess('Removed ${getLanguageName(langCode)} track');
    } catch (e, stack) {
      logger.error('Failed to remove subtitle track', error: e, stackTrace: stack, tag: SubtitlesControllerBase.subtitlesTag);
      showError('Unable to remove subtitle track. Please try again.');
    }
  }

  Future<void> importSubtitleFile({
    bool replaceCurrentTrack = true,
    String? asNewLanguageCode,
  }) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['vtt', 'srt', 'txt', 'json'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      String content;
      if (kIsWeb || file.bytes != null) {
        content = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        content = await File(file.path!).readAsString();
      } else {
        showError('Unable to read subtitle file content.');
        return;
      }

      final segments = SubtitleParser.parse(content);
      if (segments.isEmpty) {
        showError('No valid subtitle cues found in selected file.');
        return;
      }

      final newCues = segments.map((seg) {
        return SubtitleCue(
          id: UniqueKey().toString(),
          startTime: SubtitlesControllerBase.formatDurationToTimecode(seg.start),
          endTime: SubtitlesControllerBase.formatDurationToTimecode(seg.end),
          text: seg.text,
        );
      }).toList();

      if (asNewLanguageCode != null && asNewLanguageCode.isNotEmpty) {
        if (!availableLanguages.contains(asNewLanguageCode)) {
          availableLanguages.add(asNewLanguageCode);
        }
        selectedLanguage.value = asNewLanguageCode;
        currentCues.value = newCues;
      } else if (replaceCurrentTrack) {
        currentCues.value = newCues;
      } else {
        currentCues.addAll(newCues);
        currentCues.sort((a, b) {
          final aMs = SubtitleParser.parseTimeDuration(a.startTime).inMilliseconds;
          final bMs = SubtitleParser.parseTimeDuration(b.startTime).inMilliseconds;
          return aMs.compareTo(bMs);
        });
        currentCues.refresh();
      }

      hasUnsavedChanges.value = true;
      showSuccess('Successfully imported ${newCues.length} subtitle cues!');
    } catch (e) {
      logger.error('Error importing subtitle file', error: e, tag: SubtitlesControllerBase.subtitlesTag);
      showError('Unable to parse subtitle file. Please verify the file format.');
    }
  }
}
