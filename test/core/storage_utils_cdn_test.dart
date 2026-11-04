import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/config/app_config.dart';
import 'package:truthworld/core/utils/storage_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Google Cloud CDN & Media Gating Tests', () {
    setUp(() {
      StorageUtils.clearFastUrlCache();
      AppConfig.initialize(
        environment: Environment.production,
        appTitle: 'TruthWorld',
        apiBaseUrl: 'https://truthworld.app/api',
      );
      AppConfig.enableCdnThumbnails = true;
    });

    test('AppConfig cdnBaseUrl defaults to cdn.truthworld.in', () {
      expect(AppConfig.cdnBaseUrl, equals('https://cdn.truthworld.in'));
      expect(AppConfig.cdnThumbnailsUrl, equals('https://cdn.truthworld.in/thumbnails'));
      expect(AppConfig.cdnVideosUrl, equals('https://cdn.truthworld.in/videos'));
    });

    test('isPublicAsset correctly classifies open visual assets', () {
      expect(StorageUtils.isPublicAsset('thumbnails/video_123.jpg'), isTrue);
      expect(StorageUtils.isPublicAsset('gs://bucket/thumbnails/video_123.webp'), isTrue);
      expect(StorageUtils.isPublicAsset('https://firebasestorage.googleapis.com/v0/b/bucket/o/thumbnails%2Fvideo_123.jpg?alt=media'), isTrue);
      expect(StorageUtils.isPublicAsset('channels/avatars/user_456.png'), isTrue);
      expect(StorageUtils.isPublicAsset('channel_avatars/user_456.png'), isTrue);
      expect(StorageUtils.isPublicAsset('banners/channel_header.jpg'), isTrue);
      expect(StorageUtils.isPublicAsset('channel_banners/header.png'), isTrue);
      expect(StorageUtils.isPublicAsset('community_posts/image_789.png'), isTrue);
      expect(StorageUtils.isPublicAsset('community_images/image_789.png'), isTrue);
      expect(StorageUtils.isPublicAsset('topics/topic_tech_cover.jpg'), isTrue);
      expect(StorageUtils.isPublicAsset('thumbnails/topics/nature.webp'), isTrue);
      expect(StorageUtils.isPublicAsset('playlists/playlist_cover.png'), isTrue);
      expect(StorageUtils.isPublicAsset('thumbnails/playlists/mix.jpg'), isTrue);
      expect(StorageUtils.isPublicAsset('thumbnails/vid_123/chapters/intro.jpg'), isTrue);
      expect(StorageUtils.isPublicAsset('chapters/vid_123/claim_frame.jpg'), isTrue);
      expect(StorageUtils.isPublicAsset('storyboards/vid_123/sprite_0.jpg'), isTrue);

      // Videos should NOT be classified as public visual assets
      expect(StorageUtils.isPublicAsset('videos/video_123/original.mp4'), isFalse);
      expect(StorageUtils.isPublicAsset('resolutions/video_123/720p.m3u8'), isFalse);
      expect(StorageUtils.isPublicAsset('audio/dubbed_hindi.mp3'), isFalse);
    });

    test('isVideoAsset correctly classifies streaming media assets', () {
      expect(StorageUtils.isVideoAsset('videos/video_123/original.mp4'), isTrue);
      expect(StorageUtils.isVideoAsset('resolutions/video_123/720p.mp4'), isTrue);
      expect(StorageUtils.isVideoAsset('resolutions/video_123/index.m3u8'), isTrue);
      expect(StorageUtils.isVideoAsset('resolutions/video_123/segment_001.ts'), isTrue);
      expect(StorageUtils.isVideoAsset('audiotracks/video_123/telugu.aac'), isTrue);
      expect(StorageUtils.isVideoAsset('audio/original_audio.wav'), isTrue);

      // Thumbnails should NOT be classified as video assets
      expect(StorageUtils.isVideoAsset('thumbnails/cover.jpg'), isFalse);
      expect(StorageUtils.isVideoAsset('avatars/user.png'), isFalse);
    });

    test('extractCleanPath strips gs://, storage.googleapis.com, and firebasestorage URLs', () {
      expect(
        StorageUtils.extractCleanPath('gs://truthworld-1.firebasestorage.app/thumbnails/cover.jpg'),
        equals('thumbnails/cover.jpg'),
      );
      expect(
        StorageUtils.extractCleanPath('https://storage.googleapis.com/truthworld-1.firebasestorage.app/thumbnails/cover.jpg'),
        equals('thumbnails/cover.jpg'),
      );
      expect(
        StorageUtils.extractCleanPath('https://firebasestorage.googleapis.com/v0/b/truthworld-1.firebasestorage.app/o/thumbnails%2Fcover.jpg?alt=media'),
        equals('thumbnails/cover.jpg'),
      );
      expect(
        StorageUtils.extractCleanPath('/thumbnails/cover.jpg'),
        equals('thumbnails/cover.jpg'),
      );
    });

    test('getFastDownloadUrl routes public thumbnails directly to Google Cloud CDN', () {
      final thumbUrl = StorageUtils.getFastDownloadUrl('thumbnails/trending_video_1.jpg');
      expect(thumbUrl, equals('https://cdn.truthworld.in/thumbnails/trending_video_1.jpg'));

      final avatarUrl = StorageUtils.getFastDownloadUrl('gs://truthworld-1.firebasestorage.app/channels/avatars/creator_1.png');
      expect(avatarUrl, equals('https://cdn.truthworld.in/channels/avatars/creator_1.png'));

      final firebaseUrl = StorageUtils.getFastDownloadUrl('https://firebasestorage.googleapis.com/v0/b/truthworld-1.firebasestorage.app/o/thumbnails%2Fcover_art.webp?alt=media&token=12345');
      expect(firebaseUrl, equals('https://cdn.truthworld.in/thumbnails/cover_art.webp'));
    });

    test('getFastDownloadUrl preserves secure tokenized URLs for protected video media', () {
      const secureVideoUrl = 'https://firebasestorage.googleapis.com/v0/b/truthworld-1.firebasestorage.app/o/videos%2F123%2F720p.mp4?alt=media&token=secret-token-xyz';
      final resolved = StorageUtils.getFastDownloadUrl(secureVideoUrl);
      // Must preserve the authorized token for in-app video security
      expect(resolved, contains('token=secret-token-xyz'));
    });

    test('resolveGatedVideoUrl attaches session tokens and signed CDN tokens', () {
      final sessionGated = StorageUtils.resolveGatedVideoUrl(
        'videos/video_999/720p.mp4',
        sessionToken: 'sess_abc123',
      );
      expect(sessionGated, contains('tw_session=sess_abc123'));

      final signedCdnGated = StorageUtils.resolveGatedVideoUrl(
        'videos/video_999/720p.mp4',
        cdnSignature: 'Expires=1700000000&KeyName=tw-key&Signature=xyz789',
      );
      expect(signedCdnGated, startsWith('https://cdn.truthworld.in/videos/video_999/720p.mp4?'));
      expect(signedCdnGated, contains('KeyName=tw-key'));
    });

    test('getSyncMediaHeaders attaches Origin, Referer, and AppCheck token', () {
      StorageUtils.updateAppCheckToken('test-app-check-token');
      final headers = StorageUtils.getSyncMediaHeaders(
        isHlsOrCmaf: true,
        userAuthToken: 'jwt-user-token',
      );

      expect(headers['Origin'], equals('https://truthworld.in'));
      expect(headers['Referer'], equals('https://truthworld.in/'));
      expect(headers['X-Firebase-AppCheck'], equals('test-app-check-token'));
      expect(headers['Authorization'], equals('Bearer jwt-user-token'));
      expect(headers['Accept'], contains('application/x-mpegURL'));
      expect(headers['Cache-Control'], equals('no-cache'));
    });

    test('getFastDownloadUrl preserves authentic tokenized URLs when CDN is disabled', () {
      AppConfig.enableCdnThumbnails = false;
      StorageUtils.clearFastUrlCache();

      const tokenUrl = 'https://firebasestorage.googleapis.com/v0/b/truthworld-1.firebasestorage.app/o/thumbnails%2Fcover_art.webp?alt=media&token=secure-token-999';
      final resolved = StorageUtils.getFastDownloadUrl(tokenUrl);
      expect(resolved, equals(tokenUrl));
    });
  });
}
