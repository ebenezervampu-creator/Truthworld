import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:truthworld/core/base/base_controller.dart';
import 'package:truthworld/core/mixins/content_validation_mixin.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/features/video/data/models/ai_features.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/models/video_media.dart';
import 'package:truthworld/features/video/data/services/video_media_service.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';

/// Internal Cue Representation for visual preview and editing
class SubtitleCue {

  SubtitleCue({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.text,
  });
  String id;
  String startTime;
  String endTime;
  String text;

  SubtitleCue copyWith({
    String? id,
    String? startTime,
    String? endTime,
    String? text,
  }) {
    return SubtitleCue(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      text: text ?? this.text,
    );
  }
}

/// Professional Subtitles Management Controller
class SubtitlesController extends BaseController with ContentValidationMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  static const String _tag = 'SubtitlesController';

  // Active channel context
  final channelId = ''.obs;

  // Video list state
  final videos = <Video>[].obs;
  final filteredVideos = <Video>[].obs;
  final searchQuery = ''.obs;
  StreamSubscription<QuerySnapshot>? _videosSubscription;

  // Selected video and subtitle preview state
  final selectedVideo = Rxn<Video>();
  final availableLanguages = <String>[].obs; // List of language codes e.g. ['en', 'es']
  final selectedLanguage = ''.obs;
  final currentCues = <SubtitleCue>[].obs;
  final isSaving = false.obs;
  final hasUnsavedChanges = false.obs;
  final isUploadingFile = false.obs;

  // Language requests states
  final languageRequests = <LanguageRequest>[].obs;
  final isLoadingRequests = false.obs;
  final showRequestsPanel = false.obs;
  StreamSubscription<QuerySnapshot>? _requestsSubscription;

  @override
  void onInit() {
    super.onInit();
    initializeContentFilters();
    _initializeContext();
  }

  @override
  void onClose() {
    _videosSubscription?.cancel();
    _requestsSubscription?.cancel();
    super.onClose();
  }

  Future<void> _initializeContext() async {
    try {
      setViewState(ViewState.loading);
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        setError('User not authenticated');
        return;
      }

      // Resolve channel ID from navigation arguments or user document
      final channelArg = Get.arguments?['channel'];
      if (channelArg != null) {
        if (channelArg is Map) {
          channelId.value = channelArg['id'] ?? '';
        } else if (channelArg is DocumentSnapshot) {
          channelId.value = channelArg.id;
        }
      }

      if (channelId.value.isEmpty) {
        final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
        if (userDoc.exists && userDoc.data() != null) {
          channelId.value = userDoc.data()!['channelId'] ?? currentUser.uid;
        } else {
          channelId.value = currentUser.uid;
        }
      }

      _listenToChannelVideos();
    } catch (e, stack) {
      logger.error('Failed to initialize subtitles context', error: e, stackTrace: stack, tag: _tag);
      setError('Initialization failed');
    }
  }

  void setChannelContext(String id) {
    if (id.isNotEmpty && channelId.value != id) {
      channelId.value = id;
      _listenToChannelVideos();
    }
  }

  void _listenToChannelVideos() {
    if (channelId.value.isEmpty) {
      setError('Channel ID is missing');
      return;
    }

    _videosSubscription?.cancel();
    _videosSubscription = _firestore
        .collection('videos')
        .where('channelId', isEqualTo: channelId.value)
        .snapshots()
        .listen((snapshot) {
      final loadedVideos = snapshot.docs.map(Video.fromDocumentSnapshot).toList();
      // Client-side sort to ensure consistent chronological ordering without composite index requirement
      loadedVideos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      videos.value = loadedVideos;
      _applySearchFilter();

      setViewState(loadedVideos.isEmpty ? ViewState.empty : ViewState.success);

      // Preserve or auto-select a video
      if (selectedVideo.value != null) {
        final updatedVideo = loadedVideos.firstWhereOrNull((v) => v.id == selectedVideo.value!.id);
        if (updatedVideo != null) {
          selectedVideo.value = updatedVideo;
          // Refresh cues if needed
        } else {
          selectVideo(loadedVideos.isNotEmpty ? loadedVideos.first : null);
        }
      } else if (loadedVideos.isNotEmpty) {
        selectVideo(loadedVideos.first);
      }
    }, onError: (e) {
      logger.error('Error streaming channel videos', error: e, tag: _tag);
      setError('Failed to fetch videos');
    });
  }

  void setSearchQuery(String query) {
    searchQuery.value = query;
    _applySearchFilter();
  }

  void _applySearchFilter() {
    if (searchQuery.value.trim().isEmpty) {
      filteredVideos.value = videos;
      return;
    }
    final q = searchQuery.value.toLowerCase().trim();
    filteredVideos.value = videos.where((v) {
      return v.title.toLowerCase().contains(q) ||
             v.description.toLowerCase().contains(q) ||
             v.tags.any((t) => t.toLowerCase().contains(q));
    }).toList();
  }

  Future<void> selectVideo(Video? video) async {
    selectedVideo.value = video;
    hasUnsavedChanges.value = false;
    _requestsSubscription?.cancel();
    if (video == null) {
      availableLanguages.clear();
      selectedLanguage.value = '';
      currentCues.clear();
      languageRequests.clear();
      return;
    }

    logger.info('Selected video for subtitles: ${video.title}', tag: _tag);

    _listenToLanguageRequests(video.id);

    // Lazy-load localization from subcollection first
    await VideoMediaService().getLocalization(video.id);

    // Parse existing mediaSubtitles map
    final subs = video.mediaSubtitles;
    final langs = subs.keys.toList();

    if (langs.isEmpty) {
      availableLanguages.value = ['en'];
      selectedLanguage.value = 'en';
      currentCues.clear();
    } else {
      availableLanguages.value = langs;
      selectedLanguage.value = langs.first;
      _parseCuesForLanguage(langs.first, subs[langs.first]);
    }
    selectedVideo.refresh();
  }

  void _listenToLanguageRequests(String videoId) {
    _requestsSubscription?.cancel();
    isLoadingRequests.value = true;
    _requestsSubscription = _firestore
        .collection('videos')
        .doc(videoId)
        .collection('language_requests')
        .snapshots()
        .listen((snapshot) {
      final reqs = snapshot.docs.map((doc) => LanguageRequest.fromMap(doc.data(), doc.id)).toList();
      reqs.sort((a, b) {
        final countCompare = b.count.compareTo(a.count);
        if (countCompare != 0) return countCompare;
        return a.language.compareTo(b.language);
      });
      languageRequests.value = reqs;
      isLoadingRequests.value = false;
    }, onError: (e) {
      logger.error('Error listening to language requests', error: e, tag: _tag);
      isLoadingRequests.value = false;
    });
  }

  void toggleRequestsPanel() {
    showRequestsPanel.value = !showRequestsPanel.value;
  }

  void switchLanguage(String langCode) {
    if (!availableLanguages.contains(langCode)) return;
    selectedLanguage.value = langCode;
    hasUnsavedChanges.value = false;
    final subs = selectedVideo.value?.mediaSubtitles ?? {};
    if (subs.containsKey(langCode)) {
      _parseCuesForLanguage(langCode, subs[langCode]);
    } else {
      currentCues.clear();
    }
  }

  Future<void> _parseCuesForLanguage(String langCode, String? urlOrData) async {
    if (urlOrData == null || urlOrData.trim().isEmpty) {
      currentCues.clear();
      return;
    }

    var contentToParse = urlOrData;

    // Check if it's a remote file link stored in Firestore instead of raw string data
    if (urlOrData.startsWith('gs://') || urlOrData.startsWith('http://') || urlOrData.startsWith('https://')) {
      try {
        setViewState(ViewState.loading);
        var downloadUrl = urlOrData;

        // Resolve gs:// storage URIs to public download URLs
        if (urlOrData.startsWith('gs://')) {
          downloadUrl = await FirebaseStorage.instance.refFromURL(urlOrData).getDownloadURL();
        }

        // Fetch actual subtitle text file payload using HTTP GET
        final response = await http.get(Uri.parse(downloadUrl));
        if (response.statusCode == 200) {
          contentToParse = response.body;
        } else {
          logger.error('Failed to download subtitle file from $downloadUrl, status: ${response.statusCode}', tag: _tag);
          currentCues.clear();
          setViewState(ViewState.success);
          return;
        }
      } catch (e) {
        logger.error('Error downloading/resolving remote subtitle link: $urlOrData', error: e, tag: _tag);
        currentCues.clear();
        setViewState(ViewState.success);
        return;
      }
    }

    // Process retrieved file buffer (either downloaded payload or embedded file buffer)
    if (contentToParse.contains('-->')) {
      final lines = contentToParse.split('\n');
      final cues = <SubtitleCue>[];
      SubtitleCue? pendingCue;
      
      for (final line in lines) {
        if (line.contains('-->')) {
          if (pendingCue != null) {
            cues.add(pendingCue);
          }
          final parts = line.split('-->');
          pendingCue = SubtitleCue(
            id: UniqueKey().toString(),
            startTime: parts[0].trim(),
            endTime: parts.length > 1 ? parts[1].trim() : '00:00:05.000',
            text: '',
          );
        } else if (line.trim().isNotEmpty && !line.startsWith('WEBVTT') && pendingCue != null) {
          pendingCue.text = pendingCue.text.isEmpty ? line.trim() : '${pendingCue.text}\n${line.trim()}';
        }
      }
      if (pendingCue != null) {
        cues.add(pendingCue);
      }
      
      if (cues.isNotEmpty) {
        currentCues.value = cues;
        setViewState(ViewState.success);
        return;
      }
    } else {
      // It's a plain text segment layout or raw strings! Let's generate clean 4-second timestamp window slices dynamically.
      final lines = contentToParse.split('\n').where((l) => l.trim().isNotEmpty).toList();
      final cues = <SubtitleCue>[];
      var startSec = 1;
      for (var i = 0; i < lines.length; i++) {
        final sStr = "00:00:${startSec.toString().padLeft(2, '0')}.000";
        final eStr = "00:00:${(startSec + 4).toString().padLeft(2, '0')}.000";
        cues.add(SubtitleCue(id: UniqueKey().toString(), startTime: sStr, endTime: eStr, text: lines[i].trim()));
        startSec += 5;
      }
      if (cues.isNotEmpty) {
        currentCues.value = cues;
        setViewState(ViewState.success);
        return;
      }
    }

    currentCues.clear();
    setViewState(ViewState.success);
  }


  void addLanguageTrack(String langCode) {
    if (availableLanguages.contains(langCode)) {
      switchLanguage(langCode);
      return;
    }
    availableLanguages.add(langCode);
    selectedLanguage.value = langCode;
    currentCues.clear();
    showSuccess('Added new track for ${getLanguageName(langCode)}');
  }

  void updateCueText(int index, String newText) {
    if (index < 0 || index >= currentCues.length) return;
    if (currentCues[index].text != newText) {
      currentCues[index].text = newText;
      hasUnsavedChanges.value = true;
      currentCues.refresh();
    }
  }

  void addNewCue() {
    final lastEndTime = currentCues.isNotEmpty ? currentCues.last.endTime : '00:00:00.000';
    currentCues.add(
      SubtitleCue(
        id: UniqueKey().toString(),
        startTime: lastEndTime,
        endTime: _shiftTimeString(lastEndTime, 4000), // automatically calculate realistic consecutive gap
        text: 'New Subtitle Segment',
      ),
    );
    hasUnsavedChanges.value = true;
  }

  void deleteCue(int index) {
    if (index < 0 || index >= currentCues.length) return;
    currentCues.removeAt(index);
    hasUnsavedChanges.value = true;
  }

  void shiftCueTiming(int index, {bool isStart = true, int shiftMilliseconds = 500}) {
    if (index < 0 || index >= currentCues.length) return;
    final cue = currentCues[index];
    final targetTimeStr = isStart ? cue.startTime : cue.endTime;
    
    final shifted = _shiftTimeString(targetTimeStr, shiftMilliseconds);
    if (isStart) {
      cue.startTime = shifted;
    } else {
      cue.endTime = shifted;
    }
    hasUnsavedChanges.value = true;
    currentCues.refresh();
  }

  String _shiftTimeString(String timeStr, int offsetMs) {
    try {
      final parts = timeStr.split(':');
      var h = 0;
      var m = 0;
      var s = 0;
      var ms = 0;
      if (parts.length >= 3) {
        h = int.parse(parts[0]);
        m = int.parse(parts[1]);
        final sParts = parts[2].split('.');
        s = int.parse(sParts[0]);
        ms = sParts.length > 1 ? int.parse(sParts[1].padRight(3, '0').substring(0, 3)) : 0;
      } else if (parts.length == 2) {
        m = int.parse(parts[0]);
        final sParts = parts[1].split('.');
        s = int.parse(sParts[0]);
        ms = sParts.length > 1 ? int.parse(sParts[1].padRight(3, '0').substring(0, 3)) : 0;
      }
      
      var totalMs = Duration(hours: h, minutes: m, seconds: s, milliseconds: ms).inMilliseconds + offsetMs;
      if (totalMs < 0) totalMs = 0;
      final updated = Duration(milliseconds: totalMs);
      
      String twoDigits(int n) => n.toString().padLeft(2, '0');
      String threeDigits(int n) => n.toString().padLeft(3, '0');
      return '${twoDigits(updated.inHours)}:${twoDigits(updated.inMinutes.remainder(60))}:${twoDigits(updated.inSeconds.remainder(60))}.${threeDigits(updated.inMilliseconds.remainder(1000))}';
    } catch (_) {
      return timeStr;
    }
  }

  void exportCurrentTrack() {
    if (currentCues.isEmpty) {
      showError('No subtitle segments available to export.');
      return;
    }
    final buffer = StringBuffer();
    buffer.writeln('WEBVTT');
    buffer.writeln();
    for (final cue in currentCues) {
      buffer.writeln('${cue.startTime} --> ${cue.endTime}');
      buffer.writeln(cue.text);
      buffer.writeln();
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    showSuccess('Exported ${getLanguageName(selectedLanguage.value)} track to Clipboard in WEBVTT format!');
  }

  Future<void> saveCurrentSubtitles() async {
    final video = selectedVideo.value;
    final lang = selectedLanguage.value;
    if (video == null || lang.isEmpty) return;

    isSaving.value = true;
    try {
      // Compile standard WebVTT layout
      final buffer = StringBuffer();
      buffer.writeln('WEBVTT');
      buffer.writeln();
      for (final cue in currentCues) {
        buffer.writeln('${cue.startTime} --> ${cue.endTime}');
        buffer.writeln(cue.text);
        buffer.writeln();
      }

      // Build updated subtitle map preserving existing tracks
      final updatedSubs = Map<String, String>.from(video.mediaSubtitles);
      // Let's store a simulated stored file URI or the raw text format
      updatedSubs[lang] = buffer.toString();

      // Save to media/localization subcollection
      await _firestore
          .collection('videos')
          .doc(video.id)
          .collection('media')
          .doc('localization')
          .set({
            'subtitles': updatedSubs,
            'dubbedVideos': video.dubbedVideos,
            'audioTracks': video.audioTracks,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      // Update static cache to reflect changes immediately
      VideoMediaService.localizationCache[video.id] = VideoMediaLocalization(
        subtitles: updatedSubs,
        dubbedVideos: video.dubbedVideos,
        audioTracks: video.audioTracks,
      );

      // Force reactive notification
      selectedVideo.refresh();

      hasUnsavedChanges.value = false;
      showSuccess('${getLanguageName(lang)} subtitles saved successfully!');
    } catch (e, stack) {
      logger.error('Failed to save subtitles', error: e, stackTrace: stack, tag: _tag);
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
      // Validate title with profanity filter
      final valResult = await validateContent(title, fieldName: 'Track Title');
      if (!valResult.isValid) {
        showError(valResult.message);
        return;
      }

      // Ensure file bytes or path is present
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

      // Upload to Firebase Storage
      final sanitizedTitle = title.replaceAll(RegExp('[^a-zA-Z0-9_-]'), '_');
      final extension = file.extension ?? 'vtt';
      final storagePath = 'videos/${video.id}/subtitles/${sanitizedTitle}_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final storageRef = FirebaseStorage.instance.ref().child(storagePath);
      
      final metadata = SettableMetadata(contentType: 'text/vtt');
      
      // Use putData for both platforms using read bytes
      final uploadTask = storageRef.putData(fileBytes, metadata);
      await uploadTask;
      
      // Construct gs:// URL
      final bucket = FirebaseStorage.instance.ref().bucket;
      final gsUrl = 'gs://$bucket/$storagePath';

      // Update Firestore map
      final updatedSubs = Map<String, String>.from(video.mediaSubtitles);
      updatedSubs[title] = gsUrl; // Use the custom Title as the key, gsUrl as value

      await _firestore
          .collection('videos')
          .doc(video.id)
          .collection('media')
          .doc('localization')
          .set({
            'subtitles': updatedSubs,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      // Update cache
      VideoMediaService.localizationCache[video.id] = VideoMediaLocalization(
        subtitles: updatedSubs,
        dubbedVideos: video.dubbedVideos,
        audioTracks: video.audioTracks,
      );

      // Refresh active video
      selectedVideo.refresh();
      
      // Refresh list of available languages & switch to it
      if (!availableLanguages.contains(title)) {
        availableLanguages.add(title);
      }
      switchLanguage(title);

      showSuccess('Subtitle track "$title" uploaded successfully!');
    } catch (e, stack) {
      logger.error('Failed to upload subtitle track', error: e, stackTrace: stack, tag: _tag);
      showError('Failed to upload subtitle track: $e');
    } finally {
      isUploadingFile.value = false;
    }
  }

  String getLanguageName(String code) {
    final found = supportedLanguages.firstWhereOrNull((l) => l.code == code);
    if (found != null) return found.name;
    return code.length <= 3 ? code.toUpperCase() : code;
  }
}




