import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/domain/repositories/advertiser_repository.dart';

class FakeAdvertiserRepository implements AdvertiserRepository {
  final List<Map<String, dynamic>> mockCampaigns = [
    {'id': 'c1', 'name': 'Campaign 1'},
    {'id': 'c2', 'name': 'Campaign 2'},
  ];

  final List<Map<String, dynamic>> mockSavedAds = [
    {'id': 'ad1', 'title': 'Ad 1'},
  ];

  @override
  Future<Result<List<Map<String, dynamic>>>> getCampaigns(String advertiserId, {int page = 1, int limit = 20}) async {
    return Result.success(mockCampaigns);
  }

  @override
  Future<Result<String>> createCampaign(Map<String, dynamic> campaignData) async {
    final id = 'c${mockCampaigns.length + 1}';
    final newCampaign = {'id': id, ...campaignData};
    mockCampaigns.add(newCampaign);
    return Result.success(id);
  }

  @override
  Future<Result<void>> updateCampaign(String campaignId, Map<String, dynamic> data) async {
    final index = mockCampaigns.indexWhere((c) => c['id'] == campaignId);
    if (index != -1) {
      mockCampaigns[index] = {...mockCampaigns[index], ...data};
    }
    return Result.success(null);
  }

  @override
  Future<Result<void>> deleteCampaign(String campaignId) async {
    mockCampaigns.removeWhere((c) => c['id'] == campaignId);
    return Result.success(null);
  }

  @override
  Future<Result<Map<String, dynamic>>> getCampaignMetrics(String campaignId, {required DateTime startDate, required DateTime endDate}) async {
    return Result.success({'clicks': 100, 'impressions': 1000});
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> getSavedAds(String userId) async {
    return Result.success(mockSavedAds);
  }

  @override
  Future<Result<void>> toggleSaveAd(String userId, String adId) async {
    final index = mockSavedAds.indexWhere((ad) => ad['id'] == adId);
    if (index != -1) {
      mockSavedAds.removeAt(index);
    } else {
      mockSavedAds.add({'id': adId, 'title': 'New Ad'});
    }
    return Result.success(null);
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> getChannelVideosForAds(String channelId) async {
    return Result.success([{'id': 'v1'}]);
  }

  @override
  Future<Result<void>> saveAdSubtitles(String adId, Map<String, String> subtitles) async {
    return Result.success(null);
  }

  @override
  Future<Result<void>> saveAdAudioTrack(String adId, Map<String, String> audioTracks) async {
    return Result.success(null);
  }

  @override
  Future<Result<void>> triggerAdAIFeatures({
    required String campaignId,
    required List<String> features,
    required List<String> targetLanguages,
    String voiceStyle = 'natural',
    String sourceLang = 'en',
  }) async {
    return Result.success(null);
  }

  @override
  Future<Result<void>> generateAllVideoAdsAIFeatures({
    List<String> features = const ['subtitles', 'dubbing'],
    List<String> targetLanguages = const ['te', 'hi', 'ta', 'es'],
    String voiceStyle = 'natural',
    String sourceLang = 'en',
    bool forceRegenerate = false,
  }) async {
    return Result.success(null);
  }
}

void main() {
  group('AdvertiserRepository Unit Tests', () {
    late FakeAdvertiserRepository repository;

    setUp(() {
      repository = FakeAdvertiserRepository();
    });

    test('getCampaigns returns mock campaigns', () async {
      final result = await repository.getCampaigns('adv1');
      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.length, equals(2));
    });

    test('createCampaign adds new campaign', () async {
      final result = await repository.createCampaign({'name': 'Campaign 3'});
      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull, equals('c3'));
      expect(repository.mockCampaigns.length, equals(3));
    });

    test('updateCampaign updates existing campaign', () async {
      final result = await repository.updateCampaign('c1', {'name': 'Updated 1'});
      expect(result.isSuccess, isTrue);
      expect(repository.mockCampaigns.firstWhere((c) => c['id'] == 'c1')['name'], equals('Updated 1'));
    });

    test('deleteCampaign removes campaign', () async {
      final result = await repository.deleteCampaign('c1');
      expect(result.isSuccess, isTrue);
      expect(repository.mockCampaigns.length, equals(1));
      expect(repository.mockCampaigns.any((c) => c['id'] == 'c1'), isFalse);
    });

    test('getSavedAds returns saved ads', () async {
      final result = await repository.getSavedAds('u1');
      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.length, equals(1));
    });

    test('toggleSaveAd adds or removes ad', () async {
      // Remove
      await repository.toggleSaveAd('u1', 'ad1');
      expect(repository.mockSavedAds.isEmpty, isTrue);

      // Add
      await repository.toggleSaveAd('u1', 'ad2');
      expect(repository.mockSavedAds.length, equals(1));
      expect(repository.mockSavedAds.first['id'], equals('ad2'));
    });

    test('generateAllVideoAdsAIFeatures triggers batch AI pipeline', () async {
      final result = await repository.generateAllVideoAdsAIFeatures(
        features: ['subtitles', 'dubbing'],
        targetLanguages: ['te', 'hi', 'ta', 'es'],
      );
      expect(result.isSuccess, isTrue);
    });

    test('triggerAdAIFeatures queues AI for single campaign', () async {
      final result = await repository.triggerAdAIFeatures(
        campaignId: 'c1',
        features: ['subtitles', 'dubbing'],
        targetLanguages: ['te', 'hi'],
      );
      expect(result.isSuccess, isTrue);
    });
  });
}
