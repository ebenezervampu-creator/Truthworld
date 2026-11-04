import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
import 'package:truthworld/features/topics/data/repositories/topic_repository.dart';
import 'package:truthworld/features/video/data/models/topic_relevance_result.dart';
import 'package:truthworld/features/video/presentation/controllers/upload_mixins/upload_controller_base.dart';

mixin UploadTopicsMixin on UploadControllerBase {
  List<Topic> get filteredTopics {
    final query = topicSearchQuery.value.trim().toLowerCase();
    if (query.isEmpty) return availableTopics;
    return availableTopics
        .where(
          (t) =>
              t.title.toLowerCase().contains(query) ||
              t.category.toLowerCase().contains(query) ||
              t.handle.toLowerCase().contains(query),
        )
        .toList();
  }

  /// Typo-tolerant global topic lookup via Typesense (with silent Firestore fallback)
  Future<void> searchTopicsRemote(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;

    try {
      final repo = TopicRepository();
      final remoteTopics = await repo.searchTopics(clean, limit: 15);
      if (remoteTopics.isNotEmpty) {
        final existingKeys =
            availableTopics.map((t) => t.canonicalKey).toSet();
        final newlyFound = <Topic>[];
        for (final t in remoteTopics) {
          if (!existingKeys.contains(t.canonicalKey) &&
              t.status != 'deleted' &&
              t.status != 'archived') {
            existingKeys.add(t.canonicalKey);
            newlyFound.add(t);
          }
        }
        if (newlyFound.isNotEmpty) {
          availableTopics.addAll(newlyFound);
        }
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'UploadTopicsMixin.searchTopicsRemote',
      );
    }
  }

  Future<void> fetchAvailableTopics() async {
    isTopicsLoading.value = true;
    topicsError.value = '';
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid ??
          AuthService.to.currentUser.value?.uid ??
          '';

      final allDocs = <QueryDocumentSnapshot>[];
      final snap = await firestore
          .collection('topics')
          .where('status', isEqualTo: 'active')
          .get();
      allDocs.addAll(snap.docs);

      if (currentUserId.isNotEmpty) {
        try {
          final userTopicsSnap = await firestore
              .collection('topics')
              .where('creatorId', isEqualTo: currentUserId)
              .get();
          for (final doc in userTopicsSnap.docs) {
            if (!allDocs.any((d) => d.id == doc.id)) {
              allDocs.add(doc);
            }
          }
        } catch (_) {}
      }

      final fetched = <Topic>[];
      final seenCanonicalKeys = <String>{};
      for (final doc in allDocs) {
        try {
          final t = Topic.fromDocumentSnapshot(doc);
          if (t.status == 'deleted' ||
              t.status == 'archived' ||
              t.status == 'empty_archived' ||
              t.status == 'deletion_pending') {
            continue;
          }
          if (seenCanonicalKeys.contains(t.canonicalKey)) {
            continue;
          }
          if (t.visibilityType == TopicVisibilityType.public ||
              (currentUserId.isNotEmpty && t.creatorId == currentUserId) ||
              (selectedChannel.value != null &&
                  t.channelId == selectedChannel.value?.id)) {
            seenCanonicalKeys.add(t.canonicalKey);
            fetched.add(t);
            // Pre-fetch channel metadata for public topics asynchronously
            if (t.channelId != null && t.channelId!.isNotEmpty) {
              fetchChannelMetadata(t.channelId!);
            }
          }
        } catch (e, stackTrace) {
          ErrorHandler.log(
            e,
            stackTrace: stackTrace,
            tag: 'UploadController.fetchAvailableTopics.parseDoc',
          );
        }
      }

      availableTopics.value = fetched;
      debugPrint(
        'Fetched ${availableTopics.length} available topics for upload screen',
      );
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'UploadController.fetchAvailableTopics',
      );
      topicsError.value = AppException.from(e, stackTrace).displayMessage;
    } finally {
      isTopicsLoading.value = false;
    }
  }

  /// Dynamically computes and ranks topic recommendations based on video details
  List<TopicRelevanceResult> getRankedTopicsForCurrentVideo({
    String? overrideTitle,
    String? overrideCategory,
    String? overrideDescription,
  }) {
    final title = (overrideTitle ?? titleController.text).trim();
    final category = (overrideCategory ?? selectedCategory.value).trim();
    final desc = (overrideDescription ?? descriptionController.text).trim();

    final results = <TopicRelevanceResult>[];

    Set<String> tokenizeText(String text) {
      if (text.isEmpty) return {};
      const stopWords = {
        'a', 'an', 'and', 'are', 'as', 'at', 'be', 'by', 'for', 'from',
        'has', 'he', 'in', 'is', 'it', 'its', 'of', 'on', 'that', 'the',
        'to', 'was', 'were', 'will', 'with', 'video', 'how', 'what'
      };
      final cleaned = text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
      return cleaned
          .split(RegExp(r'\s+'))
          .where((w) => w.length > 2 && !stopWords.contains(w))
          .toSet();
    }

    final videoTokens = tokenizeText('$title $category $desc');
    final titleTokens = tokenizeText(title);
    final catClean = category.toLowerCase();

    for (final topic in availableTopics) {
      double score = 10;
      final reasons = <String>[];

      final topicCatClean = topic.category.toLowerCase();
      if (catClean.isNotEmpty &&
          topicCatClean.isNotEmpty &&
          (catClean == topicCatClean ||
              catClean.contains(topicCatClean) ||
              topicCatClean.contains(catClean))) {
        score += 45;
        reasons.add('Category match (${topic.category})');
      }

      final topicTitleTokens = tokenizeText('${topic.name} ${topic.handle}');
      var titleMatches = 0;
      for (final token in titleTokens) {
        if (topicTitleTokens.contains(token)) {
          titleMatches++;
          score += 15;
        }
      }
      if (titleMatches > 0) {
        reasons.add('$titleMatches matching title keywords');
      }

      final topicDescTokens = tokenizeText(topic.description);
      for (final token in videoTokens) {
        if (topicDescTokens.contains(token)) {
          score += 4;
        }
      }

      final popBonus = (topic.videoCount * 0.1 + topic.followerCount * 0.05).clamp(0.0, 10.0);
      score += popBonus;

      final rawPct = ((score / 110.0) * 100).round().clamp(62, 98);
      final reason = reasons.isNotEmpty
          ? reasons.join(' • ')
          : 'Relevant topic knowledge hub';

      results.add(
        TopicRelevanceResult(
          topic: topic,
          matchPercentage: rawPct,
          recommendationReason: reason,
          score: score,
        ),
      );
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results;
  }

  /// Resolves and caches channel metadata (name, handle, avatar) for a given channelId
  Future<void> fetchChannelMetadata(String channelId) async {
    if (channelId.isEmpty || channelMetadataCache.containsKey(channelId)) {
      return;
    }

    // Check in user's own channels first
    for (final c in channels) {
      if (c.id == channelId) {
        channelMetadataCache[channelId] = {
          'name': c.channelName,
          'handle': c.handle,
          'avatarUrl': c.avatarUrl,
        };
        return;
      }
    }

    try {
      final doc = await firestore.collection('channels').doc(channelId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final name =
            (data['channelName'] ?? data['name'] ?? 'TruthWorld Channel')
                .toString();
        final handle = (data['handle'] ?? '').toString();
        final avatarUrl = (data['avatarUrl'] ?? '').toString();
        channelMetadataCache[channelId] = {
          'name': name,
          'handle': handle,
          'avatarUrl': avatarUrl,
        };
      } else {
        channelMetadataCache[channelId] = {
          'name': 'Channel',
          'handle': '',
          'avatarUrl': '',
        };
      }
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'UploadTopicsMixin.fetchChannelMetadata',
      );
    }
  }

  /// Synchronously retrieve cached channel metadata for a channelId or trigger async fetch
  Map<String, String>? getChannelMetadata(String channelId) {
    if (channelId.isEmpty) return null;
    if (channelMetadataCache.containsKey(channelId)) {
      return channelMetadataCache[channelId];
    }
    for (final c in channels) {
      if (c.id == channelId) {
        final meta = {
          'name': c.channelName,
          'handle': c.handle,
          'avatarUrl': c.avatarUrl,
        };
        channelMetadataCache[channelId] = meta;
        return meta;
      }
    }
    fetchChannelMetadata(channelId);
    return null;
  }

  void selectTopic(String id) {
    if (id.isEmpty) {
      clearAllSelectedTopics();
      return;
    }
    if (!selectedTopicIds.contains(id)) {
      if (selectedTopicIds.length >= 3) {
        selectedTopicIds.removeLast();
      }
      selectedTopicIds.add(id);
    }
    selectedTopicId.value = id;
  }

  /// Whether a specific topic belongs to the current user or active channel
  bool isOwnTopic(Topic topic) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ??
        AuthService.to.currentUser.value?.uid ??
        '';
    final currentChannelId = selectedChannel.value?.id ?? '';
    return (currentUserId.isNotEmpty && topic.creatorId == currentUserId) ||
        (currentChannelId.isNotEmpty && topic.channelId == currentChannelId) ||
        topic.visibilityType == TopicVisibilityType.channelOnly;
  }

  /// Whether an inline draft topic is active
  bool get hasDraftTopic =>
      newTopicData.isNotEmpty ||
      selectedTopicIds.contains('new_topic_draft') ||
      selectedTopicId.value == 'new_topic_draft';

  /// Total count of topics currently selected (including inline draft if active)
  int get totalSelectedTopicsCount {
    final regularCount =
        selectedTopicIds.where((id) => id != 'new_topic_draft').length;
    return hasDraftTopic ? regularCount + 1 : regularCount;
  }

  /// Count of own/channel topics selected
  int get selectedOwnTopicsCount {
    var count = 0;
    if (hasDraftTopic) count++;
    for (final id in selectedTopicIds) {
      if (id == 'new_topic_draft') continue;
      final topic = availableTopics
          .firstWhereOrNull((t) => t.slug == id || t.id == id);
      if (topic != null && isOwnTopic(topic)) {
        count++;
      }
    }
    return count;
  }

  /// Count of public topics selected
  int get selectedPublicTopicsCount {
    var count = 0;
    for (final id in selectedTopicIds) {
      if (id == 'new_topic_draft') continue;
      final topic = availableTopics
          .firstWhereOrNull((t) => t.slug == id || t.id == id);
      if (topic != null && !isOwnTopic(topic)) {
        count++;
      }
    }
    return count;
  }

  /// Checks if a topic is currently selected
  bool isTopicSelected(String idOrSlug) {
    if (idOrSlug.isEmpty) return false;
    if (idOrSlug == 'new_topic_draft') return hasDraftTopic;
    return selectedTopicIds.contains(idOrSlug) ||
        selectedTopicId.value == idOrSlug;
  }

  /// Validates whether a topic can be added under Option 1 (Max 3 total, max 1 own topic)
  bool canSelectTopic(Topic topic, {bool showToast = false}) {
    final key = topic.slug.isNotEmpty ? topic.slug : topic.id;
    if (isTopicSelected(key)) {
      return true; // Already selected, can toggle off
    }

    if (totalSelectedTopicsCount >= 3) {
      if (showToast) {
        AppSnackbar.warning('You can select up to 3 topics per video.');
      }
      return false;
    }

    final isOwn = isOwnTopic(topic);
    if (isOwn && selectedOwnTopicsCount >= 1) {
      if (showToast) {
        AppSnackbar.warning(
          'You can only link 1 own channel topic per video. You can add up to 2 public topics.',
        );
      }
      return false;
    }

    return true;
  }

  /// Toggles selection of a topic with Option 1 validation
  void toggleTopicSelection(Topic topic) {
    final key = topic.slug.isNotEmpty ? topic.slug : topic.id;
    if (isTopicSelected(key)) {
      selectedTopicIds.remove(key);
      if (selectedTopicId.value == key) {
        selectedTopicId.value =
            selectedTopicIds.isNotEmpty ? selectedTopicIds.first : '';
      }
      AppSnackbar.info('Removed topic: ${topic.name}');
    } else {
      if (!canSelectTopic(topic, showToast: true)) {
        return;
      }
      selectedTopicIds.add(key);
      selectedTopicId.value = selectedTopicIds.first;
      AppSnackbar.success(
        'Added topic: ${topic.name} ($totalSelectedTopicsCount/3)',
      );
    }
  }

  /// Removes an individual topic selection by id or slug
  void removeTopicById(String idOrSlug) {
    selectedTopicIds.remove(idOrSlug);
    if (idOrSlug == 'new_topic_draft') {
      newTopicData.clear();
    }
    if (selectedTopicId.value == idOrSlug) {
      selectedTopicId.value =
          selectedTopicIds.isNotEmpty ? selectedTopicIds.first : '';
    }
  }

  /// Clears all topic selections and draft data
  void clearAllSelectedTopics() {
    selectedTopicIds.clear();
    selectedTopicId.value = '';
    newTopicData.clear();
  }

  Future<bool> unlockPrivateTopic(String slug, String passcode) async {
    try {
      final query = await firestore
          .collection('topics')
          .where('slug', isEqualTo: slug)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        AppSnackbar.warning('Topic not found.');
        return false;
      }

      final topicDoc = query.docs.first;
      final topic = Topic.fromDocumentSnapshot(topicDoc);

      if (!topic.isValidTopic || topic.videoCount <= 0) {
        AppSnackbar.warning('This private topic is inactive or has no videos.');
        return false;
      }

      if (topic.visibilityType == TopicVisibilityType.private) {
        if (topic.accessCode != passcode) {
          AppSnackbar.warning('Incorrect passcode for private topic.');
          return false;
        }
      }

      if (!availableTopics.any((t) => t.slug == topic.slug)) {
        availableTopics.add(topic);
      }
      selectedTopicId.value = topic.slug;
      AppSnackbar.success('Successfully unlocked private topic: ${topic.name}');
      return true;
    } catch (e) {
      ErrorHandler.log(e, context: 'UploadController.unlockTopic');
      AppSnackbar.error('Unable to unlock topic. Please try again.');
      return false;
    }
  }

  Future<String?> uploadTopicCustomThumbnail(
    Uint8List bytes,
    String fileName,
  ) async {
    try {
      await ensureStorageAuthReady();
      final ref = firebaseStorage.ref().child(
        'thumbnails/topics/$fileName',
      );
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      final chId = selectedChannel.value?.id ?? '';
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploaderId': currentUid ?? '',
          'channelId': chId,
          'uploaded': DateTime.now().toString(),
        },
      );
      final uploadTask = ref.putData(bytes, metadata);
      await uploadTask.timeout(const Duration(seconds: 20));
      return await ref.getDownloadURL();
    } catch (e, stackTrace) {
      ErrorHandler.log(
        e,
        stackTrace: stackTrace,
        tag: 'UploadTopicsMixin.uploadTopicCustomThumbnail',
      );
      return null;
    }
  }
}
