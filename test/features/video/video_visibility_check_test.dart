import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/services/video_visibility_policy.dart';
import 'package:truthworld/features/video/data/models/video.dart';

void main() {
  test('Check why isValidVideo might fail on Firestore documents', () {
    // Permutation 1: Video uploaded with status 'uploading' but has playable videoUrl
    final vUploadingPlayable = Video.fromMap({
      'title': 'Christian songs 2026',
      'status': 'uploading',
      'videoUrl': 'https://firebasestorage.googleapis.com/.../video.mp4',
      'thumbnailUrl': 'https://firebasestorage.googleapis.com/.../thumb.jpg',
      'ownerId': 'user_123',
      'channelId': 'chan_123',
      'visibility': 'public',
    }, 'vid_1');

    print('vUploadingPlayable status: ${vUploadingPlayable.status}');
    print('vUploadingPlayable isDraft: ${vUploadingPlayable.isDraft}');
    print('vUploadingPlayable isUploadingOrProcessing: ${vUploadingPlayable.isUploadingOrProcessing}');
    print('vUploadingPlayable isApprovedByGeminiOrManual: ${vUploadingPlayable.isApprovedByGeminiOrManual}');
    print('vUploadingPlayable hasPlayableMedia: ${VideoVisibilityPolicy.hasPlayableMedia(vUploadingPlayable)}');
    print('vUploadingPlayable isValidVideo: ${VideoVisibilityPolicy.isValidVideo(vUploadingPlayable)}');

    // Permutation 2: Video with status 'published' but hasPlayableMedia
    final vPublishedPlayable = Video.fromMap({
      'title': 'Christian songs 2026',
      'status': 'published',
      'videoUrl': 'https://firebasestorage.googleapis.com/.../video.mp4',
      'thumbnailUrl': 'https://firebasestorage.googleapis.com/.../thumb.jpg',
      'ownerId': 'user_123',
      'channelId': 'chan_123',
      'visibility': 'public',
    }, 'vid_2');
    print('vPublishedPlayable isValidVideo: ${VideoVisibilityPolicy.isValidVideo(vPublishedPlayable)}');

    // Permutation 3: Video with targetStatus 'published', pipelineStage 'published', status 'processing'
    final vProcessingPublished = Video.fromMap({
      'title': 'Christian songs 2026',
      'status': 'processing',
      'targetStatus': 'published',
      'aiFeatures': {'pipelineStage': 'published'},
      'videoUrl': 'https://firebasestorage.googleapis.com/.../video.mp4',
      'thumbnailUrl': 'https://firebasestorage.googleapis.com/.../thumb.jpg',
      'ownerId': 'user_123',
      'channelId': 'chan_123',
      'visibility': 'public',
    }, 'vid_3');
    print('vProcessingPublished status: ${vProcessingPublished.status}');
    print('vProcessingPublished isValidVideo: ${VideoVisibilityPolicy.isValidVideo(vProcessingPublished)}');

    // Permutation 4: Video with status 'ready' but NO videoUrl, only originalUrl or media map
    final vMediaMap = Video.fromMap({
      'title': 'Christian songs 2026',
      'status': 'published',
      'media': {
        'videoUrl': 'https://firebasestorage.googleapis.com/.../video.mp4',
        'thumbnailUrl': 'https://firebasestorage.googleapis.com/.../thumb.jpg',
      },
      'ownerId': 'user_123',
      'channelId': 'chan_123',
      'visibility': 'public',
    }, 'vid_4');
    print('vMediaMap videoUrl: ${vMediaMap.videoUrl}');
    print('vMediaMap hasPlayableMedia: ${VideoVisibilityPolicy.hasPlayableMedia(vMediaMap)}');
    print('vMediaMap isValidVideo: ${VideoVisibilityPolicy.isValidVideo(vMediaMap)}');

    // Permutation 5: Video with status 'published', has videoUrl, but geminiApproved = false or isApproved = false
    final vNotApproved = Video.fromMap({
      'title': 'Christian songs 2026',
      'status': 'published',
      'videoUrl': 'https://firebasestorage.googleapis.com/.../video.mp4',
      'thumbnailUrl': 'https://firebasestorage.googleapis.com/.../thumb.jpg',
      'geminiApproved': false,
    }, 'vid_5');
    print('vNotApproved isValidVideo: ${VideoVisibilityPolicy.isValidVideo(vNotApproved)}');

    // Permutation 6: Video with empty videoUrl
    final vNoMedia = Video.fromMap({
      'title': 'Christian songs 2026',
      'status': 'published',
      'videoUrl': '',
      'thumbnailUrl': 'https://firebasestorage.googleapis.com/.../thumb.jpg',
    }, 'vid_6');
    print('vNoMedia hasPlayableMedia: ${VideoVisibilityPolicy.hasPlayableMedia(vNoMedia)}');
    print('vNoMedia isValidVideo: ${VideoVisibilityPolicy.isValidVideo(vNoMedia)}');
  });
}
