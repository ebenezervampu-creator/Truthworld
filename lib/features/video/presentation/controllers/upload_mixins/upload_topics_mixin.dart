import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/ux/app_snackbar.dart';
import 'package:truthworld/features/topics/data/models/topic.dart';
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

  Future<void> fetchAvailableTopics() async {
    isTopicsLoading.value = true;
    topicsError.value = '';
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid ??
          AuthService.to.currentUser.value?.uid ??
          '';

      final snap = await firestore
          .collection('topics')
          .where('status', isEqualTo: 'active')
          .get();

      final fetched = <Topic>[];
      for (final doc in snap.docs) {
        try {
          final t = Topic.fromDocumentSnapshot(doc);
          if (!t.isValidTopic || t.videoCount <= 0) continue;
          if (t.visibilityType == TopicVisibilityType.public ||
              (currentUserId.isNotEmpty && t.creatorId == currentUserId) ||
              (selectedChannel.value != null &&
                  t.channelId == selectedChannel.value!.id)) {
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

      final topicTitleTokens = tokenizeText('${topic.title} ${topic.handle}');
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
    selectedTopicId.value = id;
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
      AppSnackbar.success('Successfully unlocked private topic: ${topic.title}');
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
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploaderId': ?currentUid,
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
