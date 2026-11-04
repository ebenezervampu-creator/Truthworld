import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/services/logger_service.dart';
import 'package:truthworld/features/dashboard/presentation/controllers/audio_tracks/audio_track_models.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';

/// Manages active workspace tabs, language selection layers, and community language request streams.
class AudioTracksLanguageManager {
  static const String _tag = 'AudioTracksLanguageManager';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final RxString activeTab = 'tracks'.obs; // 'tracks' or 'languages'
  final RxList<String> availableLanguages = <String>[].obs;
  final RxString selectedLanguage = ''.obs;
  final RxMap<String, String> customLanguages = <String, String>{}.obs;

  final RxList<LanguageRequest> languageRequests = <LanguageRequest>[].obs;
  final RxList<LanguageRequest> clientLanguageRequests =
      <LanguageRequest>[].obs; // backing field
  final RxBool isLoadingRequests = false.obs;
  final RxBool showRequestsPanel = false.obs;

  StreamSubscription<QuerySnapshot>? _requestsSubscription;

  void setActiveTab(String tab) {
    activeTab.value = tab;
  }

  void toggleRequestsPanel() {
    showRequestsPanel.value = !showRequestsPanel.value;
  }

  /// Listens to real-time community dubbing requests for the active video.
  void listenToLanguageRequests(String videoId) {
    _requestsSubscription?.cancel();
    isLoadingRequests.value = true;
    _requestsSubscription = _firestore
        .collection(FirestoreCollections.videos)
        .doc(videoId)
        .collection('language_requests')
        .snapshots()
        .listen(
          (snapshot) {
            final reqs =
                snapshot.docs
                    .map((doc) => LanguageRequest.fromMap(doc.data(), doc.id))
                    .toList();
            reqs.sort((a, b) {
              final countCompare = b.count.compareTo(a.count);
              if (countCompare != 0) return countCompare;
              return a.language.compareTo(b.language);
            });
            languageRequests.value = reqs;
            isLoadingRequests.value = false;
          },
          onError: (e) {
            logger.error(
              'Error listening to language requests',
              error: e,
              tag: _tag,
            );
            isLoadingRequests.value = false;
          },
        );
  }

  /// Switches active editing language track.
  void switchLanguageTrack(
    String langCode, {
    required void Function(String langCode) onLanguageSwitched,
  }) {
    if (!availableLanguages.contains(langCode)) return;
    selectedLanguage.value = langCode;
    onLanguageSwitched(langCode);
  }

  /// Adds a new language layer to the available languages catalog.
  void addLanguageLayer(
    String langCode, {
    required void Function(String langCode) onLanguageAdded,
    required void Function(String message) onShowSuccess,
  }) {
    final cleanCode = langCode.trim().toLowerCase();
    if (availableLanguages.contains(cleanCode)) {
      switchLanguageTrack(
        cleanCode,
        onLanguageSwitched: onLanguageAdded,
      );
      return;
    }
    availableLanguages.add(cleanCode);
    selectedLanguage.value = cleanCode;
    onLanguageAdded(cleanCode);
    final displayName =
        customLanguages[cleanCode] ?? getSupportedLanguageName(cleanCode);
    onShowSuccess(
      'Added new secondary audio target layer: $displayName',
    );
  }

  /// Registers a custom language and activates it as a layer.
  void addCustomLanguage(
    String langCode,
    String langName, {
    required void Function(String langCode) onLanguageAdded,
    required void Function(String message) onShowSuccess,
  }) {
    final cleanCode = langCode.trim().toLowerCase();
    final cleanName = langName.trim();
    if (cleanCode.isEmpty || cleanName.isEmpty) return;
    customLanguages[cleanCode] = cleanName;
    addLanguageLayer(
      cleanCode,
      onLanguageAdded: onLanguageAdded,
      onShowSuccess: onShowSuccess,
    );
  }

  /// Removes a language layer from available languages.
  void removeLanguageLayer(
    String langCode, {
    required String baseLang,
    required void Function(String langCode) onLanguageRemoved,
    required void Function(String message) onShowSuccess,
  }) {
    final cleanCode = langCode.trim().toLowerCase();
    if (cleanCode == baseLang.toLowerCase()) return;
    if (!availableLanguages.contains(cleanCode)) return;
    availableLanguages.remove(cleanCode);
    if (selectedLanguage.value == cleanCode) {
      selectedLanguage.value = baseLang;
    }
    onLanguageRemoved(cleanCode);
    final displayName =
        customLanguages[cleanCode] ?? getSupportedLanguageName(cleanCode);
    onShowSuccess('Removed language layer: $displayName');
  }

  /// Clears state when no video is selected.
  void clear() {
    unawaited(_requestsSubscription?.cancel());
    availableLanguages.clear();
    selectedLanguage.value = '';
    languageRequests.clear();
  }

  /// Cancels subscriptions on controller disposal.
  void dispose() {
    unawaited(_requestsSubscription?.cancel());
    _requestsSubscription = null;
  }
}
