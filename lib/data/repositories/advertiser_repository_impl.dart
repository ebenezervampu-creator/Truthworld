import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:truthworld/core/base/base_repository.dart';
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
    return safeUpdate(
      _firestore.collection(FirestoreCollections.ads).doc(adId).collection('subtitles').doc('metadata'),
      subtitles,
    );
  }

  @override
  Future<Result<void>> saveAdAudioTrack(
    String adId,
    Map<String, String> audioTracks,
  ) async {
    return safeUpdate(
      _firestore.collection(FirestoreCollections.ads).doc(adId).collection('audio_tracks').doc('metadata'),
      audioTracks,
    );
  }
}
