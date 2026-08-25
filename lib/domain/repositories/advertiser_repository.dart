import 'package:truthworld/core/network/result.dart';

/// Repository interface for advertiser portal operations.
abstract class AdvertiserRepository {
  /// Fetch all ad campaigns for an advertiser.
  Future<Result<List<Map<String, dynamic>>>> getCampaigns(
    String advertiserId, {
    int page = 1,
    int limit = 20,
  });

  /// Create a new ad campaign.
  Future<Result<String>> createCampaign(Map<String, dynamic> campaignData);

  /// Update an existing campaign.
  Future<Result<void>> updateCampaign(
    String campaignId,
    Map<String, dynamic> data,
  );

  /// Delete a campaign.
  Future<Result<void>> deleteCampaign(String campaignId);

  /// Fetch performance metrics for a campaign.
  Future<Result<Map<String, dynamic>>> getCampaignMetrics(
    String campaignId, {
    required DateTime startDate,
    required DateTime endDate,
  });

  /// Fetch all saved ads for a user.
  Future<Result<List<Map<String, dynamic>>>> getSavedAds(String userId);

  /// Save/unsave an ad.
  Future<Result<void>> toggleSaveAd(String userId, String adId);

  /// Fetch channel videos for ad targeting.
  Future<Result<List<Map<String, dynamic>>>> getChannelVideosForAds(
    String channelId,
  );

  /// Save subtitle translation for an ad.
  Future<Result<void>> saveAdSubtitles(
    String adId,
    Map<String, String> subtitles,
  );

  /// Save audio dub for an ad.
  Future<Result<void>> saveAdAudioTrack(
    String adId,
    Map<String, String> audioTracks,
  );

  /// Trigger on-demand AI features (subtitles, audio dubbing) via Cloud Functions AI pipeline.
  Future<Result<void>> triggerAdAIFeatures({
    required String campaignId,
    required List<String> features,
    required List<String> targetLanguages,
    String voiceStyle = 'natural',
    String sourceLang = 'en',
  });
}

