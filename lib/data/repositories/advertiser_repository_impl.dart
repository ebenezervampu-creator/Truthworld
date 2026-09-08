import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:truthworld/core/base/base_repository.dart';
import 'package:truthworld/core/config/app_config.dart';
import 'package:truthworld/core/constants/firestore_collections.dart';
import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/domain/repositories/advertiser_repository.dart';

class AdvertiserRepositoryImpl extends BaseRepository implements AdvertiserRepository {
  final FirebaseFirestore _firestore;
  
  DocumentSnapshot? _lastCampaignDoc;

  AdvertiserRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<Result<List<Map<String, dynamic>>>> getCampaigns(
    String advertiserId, {
    int page = 1,
    int limit = 20,
  }) async {
    return safeFetch(() async {
      if (page == 1) _lastCampaignDoc = null;
      
      var query = _firestore.collection('campaigns')
          .where('advertiserId', isEqualTo: advertiserId)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (page > 1 && _lastCampaignDoc != null) {
        query = query.startAfterDocument(_lastCampaignDoc!);
      }

      final snapshot = await query.get();
      if (snapshot.docs.isNotEmpty) {
        _lastCampaignDoc = snapshot.docs.last;
      }

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  @override
  Future<Result<String>> createCampaign(Map<String, dynamic> campaignData) async {
    return safeFetch(() async {
      campaignData['createdAt'] = FieldValue.serverTimestamp();
      final docRef = await _firestore.collection('campaigns').add(campaignData);
      return docRef.id;
    });
  }

  @override
  Future<Result<void>> updateCampaign(
    String campaignId,
    Map<String, dynamic> data,
  ) async {
    return safeUpdate(
      _firestore.collection('campaigns').doc(campaignId),
      {...data, 'updatedAt': FieldValue.serverTimestamp()},
    );
  }

  @override
  Future<Result<void>> deleteCampaign(String campaignId) async {
    return safeDelete(
      _firestore.collection('campaigns').doc(campaignId),
    );
  }

  @override
  Future<Result<Map<String, dynamic>>> getCampaignMetrics(
    String campaignId, {
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    return safeFetch(() async {
      final doc = await _firestore.collection('campaigns').doc(campaignId).collection('metrics').doc('summary').get();
      if (!doc.exists) return {};
      return doc.data()!;
    });
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> getSavedAds(String userId) async {
    return safeFetch(() async {
      final snapshot = await _firestore.collection('users').doc(userId).collection('saved_ads').get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  @override
  Future<Result<void>> toggleSaveAd(String userId, String adId) async {
    return safeFetch(() async {
      final docRef = _firestore.collection('users').doc(userId).collection('saved_ads').doc(adId);
      final doc = await docRef.get();
      if (doc.exists) {
        await docRef.delete();
      } else {
        await docRef.set({'savedAt': FieldValue.serverTimestamp()});
      }
    });
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> getChannelVideosForAds(
    String channelId,
  ) async {
    return safeFetch(() async {
      final snapshot = await _firestore.collection(FirestoreCollections.videos)
          .where('channelId', isEqualTo: channelId)
          .where('isMonetized', isEqualTo: true)
          .get();
          
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  @override
  Future<Result<void>> saveAdSubtitles(
    String adId,
    Map<String, String> subtitles,
  ) async {
    return safeSet(
      _firestore.collection('ad_campaigns').doc(adId),
      {
        'subtitles': subtitles,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  @override
  Future<Result<void>> saveAdAudioTrack(
    String adId,
    Map<String, String> audioTracks,
  ) async {
    return safeSet(
      _firestore.collection('ad_campaigns').doc(adId),
      {
        'audioTracks': audioTracks,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  @override
  Future<Result<void>> triggerAdAIFeatures({
    required String campaignId,
    required List<String> features,
    required List<String> targetLanguages,
    String voiceStyle = 'natural',
    String sourceLang = 'en',
  }) async {
    return safeFetch(() async {
      final currentUser = FirebaseAuth.instance.currentUser;
      final token = currentUser != null ? await currentUser.getIdToken() : null;

      final url = Uri.parse(
        '${AppConfig.cloudFunctionsBaseUrl}/triggerAdAIFeatures',
      );

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'campaignId': campaignId,
          'features': features,
          'targetLanguages': targetLanguages,
          'voiceStyle': voiceStyle,
          'sourceLang': sourceLang,
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      }

      // If HTTP call encounters issue (or offline/local), update Firestore directly so trigger picks it up
      await _firestore.collection('ad_campaigns').doc(campaignId).set({
        'stages': {
          'ai': {
            'status': 'running',
            'progress': 10,
            'currentStage': 'Triggering AI features...',
            'features': features,
            'targetLanguages': targetLanguages,
            'voiceStyle': voiceStyle,
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
          },
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  @override
  Future<Result<void>> generateAllVideoAdsAIFeatures({
    List<String> features = const ['subtitles', 'dubbing'],
    List<String> targetLanguages = const ['te', 'hi', 'ta', 'es'],
    String voiceStyle = 'natural',
    String sourceLang = 'en',
    bool forceRegenerate = false,
  }) async {
    return safeFetch(() async {
      final currentUser = FirebaseAuth.instance.currentUser;
      final token = currentUser != null ? await currentUser.getIdToken() : null;

      final url = Uri.parse(
        '${AppConfig.cloudFunctionsBaseUrl}/generateAllVideoAdsAIFeatures',
      );

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'features': features,
          'targetLanguages': targetLanguages,
          'voiceStyle': voiceStyle,
          'sourceLang': sourceLang,
          'forceRegenerate': forceRegenerate,
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      }

      // If HTTP call fails, query video ads in Firestore directly and mark stages.ai
      final snapshot = await _firestore.collection('ad_campaigns').get();
      final batch = _firestore.batch();
      var count = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final hasVideo = data['videoUrl'] != null ||
            data['midrollVideoUrl'] != null ||
            (data['resolutions'] is List && (data['resolutions'] as List).isNotEmpty);
        if (hasVideo) {
          batch.set(
            doc.reference,
            {
              'stages': {
                'ai': {
                  'status': 'running',
                  'progress': 10,
                  'currentStage': 'Batch queued for AI generation...',
                  'features': features,
                  'targetLanguages': targetLanguages,
                  'voiceStyle': voiceStyle,
                  'updatedAt': DateTime.now().millisecondsSinceEpoch,
                },
              },
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
          count++;
          if (count >= 400) break; // Firestore batch limit safety
        }
      }

      if (count > 0) {
        await batch.commit();
      }
    });
  }
}

