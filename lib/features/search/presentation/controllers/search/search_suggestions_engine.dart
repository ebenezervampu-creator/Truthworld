import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/errors/error_handler.dart';
import 'package:truthworld/features/home/presentation/controllers/home_controller.dart';
import 'package:truthworld/features/search/data/models/search_result.dart';
import 'package:truthworld/features/search/presentation/controllers/search/search_models.dart';
import 'package:truthworld/features/video/data/models/video.dart';

/// Aggregates multi-source rich suggestions across recent history, local home videos,
/// and remote Firestore videos, channels, and topics.
class SearchSuggestionsEngine {
  /// Fetch suggestions combining local cache and remote database queries
  Future<List<SearchSuggestion>> fetchRichSuggestions({
    required String query,
    required List<String> recentSearches,
    required int currentToken,
    required bool Function(int token) isTokenActive,
  }) async {
    final normalized = query.toLowerCase().trim();
    if (normalized.isEmpty) return [];

    final newSuggestions = <SearchSuggestion>[];
    final seenIds = <String>{};
    final seenTexts = <String>{};

    // 1. Add matching recent searches first
    final recentMatches = recentSearches
        .where((q) => q.toLowerCase().contains(normalized))
        .take(3);
    for (final text in recentMatches) {
      final key = text.toLowerCase();
      if (!seenTexts.contains(key)) {
        seenTexts.add(key);
        newSuggestions.add(
          SearchSuggestion(
            text: text,
            icon: Icons.history,
          ),
        );
      }
    }

    // 2. Local fallback/addition from HomeController (0 database reads, instant suggestions)
    try {
      if (Get.isRegistered<HomeController>()) {
        final homeCtrl = Get.find<HomeController>();
        final localVideos = homeCtrl.videos;
        final localMatches = localVideos
            .whereType<Video>()
            .where((v) => v.title.toLowerCase().contains(normalized))
            .take(3);
        for (final v in localMatches) {
          final key = v.title.toLowerCase();
          if (!seenIds.contains(v.id) && !seenTexts.contains(key)) {
            seenIds.add(v.id);
            seenTexts.add(key);
            newSuggestions.add(
              SearchSuggestion(
                text: v.title,
                imageUrl: v.thumbnailUrl,
                matchedResult: SearchResult(
                  id: v.id,
                  title: v.title,
                  thumbnail: v.thumbnailUrl,
                  views: v.viewCount,
                  channelName: v.channelName,
                  channelImage: v.channelAvatarUrl,
                  createdAt: v.createdAt,
                  durationMs: v.durationValue.inMilliseconds,
                ),
              ),
            );
          }
        }
      }
    } catch (e, s) {
      ErrorHandler.log(e, stackTrace: s, tag: 'SearchSuggestionsEngine.localSuggestions');
    }

    // 3. Remote Firestore queries across content types (videos, channels, topics)
    if (normalized.isNotEmpty) {
      try {
        final results = await Future.wait([
          FirebaseFirestore.instance
              .collection(FirestoreCollections.videos)
              .where('titleLowercase', isGreaterThanOrEqualTo: normalized)
              .where('titleLowercase', isLessThanOrEqualTo: '$normalized\uf8ff')
              .limit(5)
              .get()
              .catchError(
                (_) => FirebaseFirestore.instance
                    .collection(FirestoreCollections.videos)
                    .where('title', isGreaterThanOrEqualTo: normalized)
                    .where('title', isLessThanOrEqualTo: '$normalized\uf8ff')
                    .limit(5)
                    .get()
                    .catchError(
                      (_) => FirebaseFirestore.instance
                          .collection(FirestoreCollections.videos)
                          .limit(0)
                          .get(),
                    ),
              ),
          FirebaseFirestore.instance
              .collection('channels')
              .where('nameLowercase', isGreaterThanOrEqualTo: normalized)
              .where('nameLowercase', isLessThanOrEqualTo: '$normalized\uf8ff')
              .limit(3)
              .get()
              .catchError(
                (_) => FirebaseFirestore.instance
                    .collection('channels')
                    .limit(0)
                    .get(),
              ),
          FirebaseFirestore.instance
              .collection('topics')
              .where('slug', isGreaterThanOrEqualTo: normalized)
              .where('slug', isLessThanOrEqualTo: '$normalized\uf8ff')
              .limit(3)
              .get()
              .catchError(
                (_) => FirebaseFirestore.instance
                    .collection('topics')
                    .limit(0)
                    .get(),
              ),
        ]);

        // Stale query check
        if (!isTokenActive(currentToken)) {
          debugPrint('⏰ [Search] Stale suggestion query ignored');
          return [];
        }

        // Add matching channels
        for (final doc in results[1].docs) {
          final data = doc.data();
          final name = data['name'] as String? ??
              data['channelName'] as String? ??
              '';
          final key = name.toLowerCase();
          if (name.isNotEmpty &&
              !seenIds.contains(doc.id) &&
              !seenTexts.contains(key)) {
            seenIds.add(doc.id);
            seenTexts.add(key);
            newSuggestions.add(
              SearchSuggestion(
                text: name,
                subtitle: 'Channel',
                imageUrl: data['avatarUrl'] as String? ??
                    data['channelAvatarUrl'] as String? ??
                    '',
                isRoundImage: true,
                icon: Icons.account_circle,
                matchedResult: SearchResult.fromFirestore(
                  doc,
                  type: ResultType.channel,
                ),
              ),
            );
          }
        }

        // Add matching topics
        for (final doc in results[2].docs) {
          final data = doc.data();
          final status = (data['status'] as String?)?.toLowerCase();
          if (status != null && status != 'active') continue;
          final count = (data['videoCount'] as num?)?.toInt() ??
              (data['featuredVideoIds'] as List?)?.length ??
              0;
          if (count <= 0) continue;

          final title = data['title'] as String? ??
              data['slug'] as String? ??
              '';
          final key = title.toLowerCase();
          if (title.isNotEmpty &&
              !seenIds.contains(doc.id) &&
              !seenTexts.contains(key)) {
            seenIds.add(doc.id);
            seenTexts.add(key);
            newSuggestions.add(
              SearchSuggestion(
                text: title,
                subtitle: 'Topic',
                imageUrl: data['thumbnailUrl'] as String? ??
                    data['coverImage'] as String? ??
                    '',
                icon: Icons.topic,
                matchedResult: SearchResult.fromFirestore(
                  doc,
                  type: ResultType.topic,
                ),
              ),
            );
          }
        }

        // Add matching videos
        for (final doc in results[0].docs) {
          final data = doc.data();
          final status = (data['status'] as String?)?.toLowerCase();
          if (status != null &&
              status != 'processed' &&
              status != 'published' &&
              status != 'completed') {
            continue;
          }
          final title = data['title'] as String? ?? '';
          final key = title.toLowerCase();
          if (!seenIds.contains(doc.id) && !seenTexts.contains(key)) {
            seenIds.add(doc.id);
            seenTexts.add(key);
            newSuggestions.add(
              SearchSuggestion(
                text: title,
                imageUrl: data['thumbnailUrl'] as String? ?? '',
                matchedResult: SearchResult.fromFirestore(doc),
              ),
            );
          }
        }
      } catch (e, s) {
        ErrorHandler.log(e, stackTrace: s, tag: 'SearchSuggestionsEngine.remoteSuggestions');
      }
    }

    if (!isTokenActive(currentToken)) return [];
    return newSuggestions.take(12).toList();
  }
}
