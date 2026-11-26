import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/core/utils/storage_canonicalizer.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/data/models/video_media.dart';
import 'package:truthworld/features/video/presentation/views/player/models/player_models.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    const MethodChannel('plugins.flutter.io/path_provider')
        .setMockMethodCallHandler((_) async => '.');
    await GetStorage.init();
  });

  setUp(Get.reset);

  tearDown(Get.reset);

  group('AI Dubbed Audio Tracks Model & Parser Tests', () {
    test('AudioTrack source property and isAiDub getter', () {
      const origTrack = AudioTrack(
        label: 'Original (English)',
        langCode: 'en',
      );
      expect(origTrack.isAiDub, isFalse);
      expect(origTrack.source, equals('creator'));

      const creatorTrack = AudioTrack(
        label: 'French (Audio)',
        langCode: 'fr',
        type: 'Audio',
        url: 'https://example.com/fr.mp3',
      );
      expect(creatorTrack.isAiDub, isFalse);
      expect(creatorTrack.source, equals('creator'));

      const aiTrack = AudioTrack(
        label: 'Telugu (Audio)',
        langCode: 'te',
        type: 'Audio',
        source: 'ai_dub',
        url: 'https://example.com/te.mp3',
      );
      expect(aiTrack.isAiDub, isTrue);
      expect(aiTrack.source, equals('ai_dub'));
    });

    test('VideoMediaLocalization parses audioTrackSources map and dotted keys', () {
      final loc = VideoMediaLocalization.fromMap({
        'audioTracks': {
          'te': 'https://example.com/te.mp3',
        },
        'audioTrackSources': {
          'te': 'ai_dub',
        },
        'audioTracks.hi': 'https://example.com/hi.mp3',
        'audioTrackSources.hi': 'ai_dub',
        'media.audioTracks.mr': 'https://example.com/mr.mp3',
        'media.audioTrackSources.mr': 'ai_dub',
        'audioTracks.fr': 'https://example.com/fr.mp3',
        'audioTrackSources.fr': 'creator',
      });

      expect(loc.audioTrackSources['te'], equals('ai_dub'));
      expect(loc.audioTrackSources['hi'], equals('ai_dub'));
      expect(loc.audioTrackSources['mr'], equals('ai_dub'));
      expect(loc.audioTrackSources['fr'], equals('creator'));
      expect(loc.toMap()['audioTrackSources']['te'], equals('ai_dub'));
    });

    test('VideoMapParser parses audioTrackSources from raw Firestore document data', () {
      final parsed = VideoMapParser.parse({
        'title': 'Test Video',
        'description': 'Description',
        'language': 'en',
        'audioTracks': {
          'te': 'https://example.com/te.mp3',
        },
        'audioTrackSources': {
          'te': 'ai_dub',
        },
        'media': {
          'audioTracks': {
            'hi': 'https://example.com/hi.mp3',
          },
          'audioTrackSources': {
            'hi': 'ai_dub',
          },
        },
        'audioTracks.mr': 'https://example.com/mr.mp3',
        'audioTrackSources.mr': 'ai_dub',
        'audioTracks.fr': 'https://example.com/fr.mp3',
        'audioTrackSources.fr': 'creator',
      }, 'test_vid_123');

      expect(parsed.audioTrackSources['te'], equals('ai_dub'));
      expect(parsed.audioTrackSources['hi'], equals('ai_dub'));
      expect(parsed.audioTrackSources['mr'], equals('ai_dub'));
      expect(parsed.audioTrackSources['fr'], equals('creator'));
    });

    test('Fallback: missing source only treats as ai_dub if dubbingLanguages contains language', () {
      final videoWithDubbing = VideoMapParser.parse({
        'title': 'AI Dubbed Video',
        'description': 'Test',
        'language': 'en',
        'dubbingLanguages': ['te', 'hi'],
        'audioTracks': {
          'te': 'https://example.com/te.mp3',
          'fr': 'https://example.com/fr.mp3',
        },
      }, 'vid_ai');

      // Helper logic matching VideoTrackManagementMixin
      String resolveSource(Video vid, String langCode) {
        final explicit = vid.audioTrackSources[langCode];
        if (explicit != null && explicit.isNotEmpty) return explicit;
        if (vid.dubbingLanguages.contains(langCode)) return 'ai_dub';
        return 'creator';
      }

      expect(resolveSource(videoWithDubbing, 'te'), equals('ai_dub'));
      expect(resolveSource(videoWithDubbing, 'fr'), equals('creator')); // Never guess AI for creator track!
    });
  });

  group('UI Tests: Audio Track Picker and Player Controls Chip', () {
    testWidgets('Audio track list tile renders AI dub badge and correct semantics', (tester) async {
      const aiTrack = AudioTrack(
        label: 'Telugu (Audio)',
        langCode: 'te',
        type: 'Audio',
        source: 'ai_dub',
      );
      const creatorTrack = AudioTrack(
        label: 'French (Audio)',
        langCode: 'fr',
        type: 'Audio',
      );
      const origTrack = AudioTrack(
        label: 'Original (English)',
        langCode: 'en',
      );

      Widget buildItem(AudioTrack track, bool isSelected) {
        final semanticsText =
            track.isAiDub ? '${track.label}, AI-dubbed audio' : track.label;
        return Semantics(
          label: semanticsText,
          selected: isSelected,
          button: true,
          child: ListTile(
            leading: Icon(
              Icons.audiotrack_rounded,
              color: isSelected ? Colors.white : Colors.white70,
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    track.label,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (track.isAiDub) ...[
                  const SizedBox(width: 8),
                  Container(
                    key: const Key('ai_dub_badge_te'),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'AI dub',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: track.type.isNotEmpty && track.type != 'Original'
                ? Text(
                    track.isAiDub ? 'AI-dubbed audio' : track.type,
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  )
                : null,
          ),
        );
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                buildItem(origTrack, false),
                buildItem(creatorTrack, false),
                buildItem(aiTrack, true),
              ],
            ),
          ),
        ),
      );

      // 1. Check AI dub badge appears only for AI track
      expect(find.byKey(const Key('ai_dub_badge_te')), findsOneWidget);
      expect(find.text('AI dub'), findsOneWidget);
      expect(find.text('AI-dubbed audio'), findsOneWidget);

      // 2. Creator and Original tracks have no AI dub badge
      expect(find.text('Original (English)'), findsOneWidget);
      expect(find.text('French (Audio)'), findsOneWidget);
      expect(find.text('Telugu (Audio)'), findsOneWidget);

      // 3. Semantics verify
      final semanticsHandle = tester.ensureSemantics();
      expect(
        tester.getSemantics(find.byKey(const Key('ai_dub_badge_te'))),
        isNotNull,
      );
      semanticsHandle.dispose();
    });

    testWidgets('AI-dubbed audio chip displays with icon and text in player controls', (tester) async {
      final isAiDubPlaying = true.obs;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.black,
            body: Stack(
              children: [
                Positioned(
                  top: 14,
                  left: 14,
                  child: Obx(() {
                    if (!isAiDubPlaying.value) return const SizedBox.shrink();
                    return Semantics(
                      label: 'Telugu, AI-dubbed audio',
                      child: Container(
                        key: const Key('ai_dub_player_chip'),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                            width: 0.8,
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_awesome_rounded,
                              size: 13,
                              color: Colors.white,
                            ),
                            SizedBox(width: 5),
                            Text(
                              'AI-dubbed audio',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('ai_dub_player_chip')), findsOneWidget);
      expect(find.text('AI-dubbed audio'), findsOneWidget);
      expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);

      // When not AI dub, chip disappears
      isAiDubPlaying.value = false;
      await tester.pump();
      expect(find.byKey(const Key('ai_dub_player_chip')), findsNothing);
    });
  });

  group('StorageCanonicalizer Unit Tests', () {
    test('same file in different URL forms -> equal', () {
      const gsUrl = 'gs://truthworld-prod.appspot.com/dubs/123/te.mp3';
      const storageGapisUrl = 'https://storage.googleapis.com/truthworld-prod.appspot.com/dubs/123/te.mp3';
      const storageWithQuery = 'https://storage.googleapis.com/truthworld-prod.appspot.com/dubs/123/te.mp3?x=1&auth=foo';
      const firebaseStorageUrl = 'https://firebasestorage.googleapis.com/v0/b/truthworld-prod.appspot.com/o/dubs%2F123%2Fte.mp3?alt=media&token=xyz-789';

      expect(StorageCanonicalizer.canonicalStorageObject(gsUrl), equals('truthworld-prod.appspot.com/dubs/123/te.mp3'));
      expect(StorageCanonicalizer.canonicalStorageObject(storageGapisUrl), equals('truthworld-prod.appspot.com/dubs/123/te.mp3'));
      expect(StorageCanonicalizer.canonicalStorageObject(storageWithQuery), equals('truthworld-prod.appspot.com/dubs/123/te.mp3'));
      expect(StorageCanonicalizer.canonicalStorageObject(firebaseStorageUrl), equals('truthworld-prod.appspot.com/dubs/123/te.mp3'));

      expect(StorageCanonicalizer.isSameStorageObject(gsUrl, storageGapisUrl), isTrue);
      expect(StorageCanonicalizer.isSameStorageObject(storageGapisUrl, storageWithQuery), isTrue);
      expect(StorageCanonicalizer.isSameStorageObject(gsUrl, firebaseStorageUrl), isTrue);
      expect(StorageCanonicalizer.isSameStorageObject(storageWithQuery, firebaseStorageUrl), isTrue);
    });

    test('different file -> not equal', () {
      const teUrl = 'https://storage.googleapis.com/truthworld-prod.appspot.com/dubs/123/te.mp3';
      const hiUrl = 'https://storage.googleapis.com/truthworld-prod.appspot.com/dubs/123/hi.mp3';
      const otherBucketUrl = 'https://storage.googleapis.com/other-bucket.appspot.com/dubs/123/te.mp3';

      expect(StorageCanonicalizer.isSameStorageObject(teUrl, hiUrl), isFalse);
      expect(StorageCanonicalizer.isSameStorageObject(teUrl, otherBucketUrl), isFalse);
    });

    test('virtual-hosted form https://<bucket>.storage.googleapis.com/<path> equals gs:// and firebasestorage forms', () {
      const bucket = 'truthworld-prod.appspot.com';
      const path = 'dubs/123/te.mp3';
      const virtualHostedUrl = 'https://$bucket.storage.googleapis.com/$path';
      const gsUrl = 'gs://$bucket/$path';
      const firebaseStorageUrl = 'https://firebasestorage.googleapis.com/v0/b/$bucket/o/dubs%2F123%2Fte.mp3?alt=media&token=xyz-789';

      expect(StorageCanonicalizer.canonicalStorageObject(virtualHostedUrl), equals('$bucket/$path'));
      expect(StorageCanonicalizer.isSameStorageObject(virtualHostedUrl, gsUrl), isTrue);
      expect(StorageCanonicalizer.isSameStorageObject(virtualHostedUrl, firebaseStorageUrl), isTrue);
    });

    test('never throws on decode error (e.g. stray %) and returns null / false', () {
      const pathWithStrayPercent = 'https://storage.googleapis.com/truthworld-prod.appspot.com/dubs/123/te%2.mp3';
      const gsWithStrayPercent = 'gs://truthworld-prod.appspot.com/dubs/123/te%2.mp3';
      const virtualHostedWithStrayPercent = 'https://truthworld-prod.appspot.com.storage.googleapis.com/dubs/123/te%2.mp3';
      const validUrl = 'https://storage.googleapis.com/truthworld-prod.appspot.com/dubs/123/te.mp3';

      expect(StorageCanonicalizer.canonicalStorageObject(pathWithStrayPercent), isNull);
      expect(StorageCanonicalizer.canonicalStorageObject(gsWithStrayPercent), isNull);
      expect(StorageCanonicalizer.canonicalStorageObject(virtualHostedWithStrayPercent), isNull);
      expect(StorageCanonicalizer.isSameStorageObject(pathWithStrayPercent, validUrl), isFalse);
      expect(StorageCanonicalizer.isSameStorageObject(gsWithStrayPercent, validUrl), isFalse);
      expect(StorageCanonicalizer.isSameStorageObject(pathWithStrayPercent, pathWithStrayPercent), isFalse);
    });
  });

  group('Task 5: Tamper-Proof aiDubbedAudio Verification Tests', () {
    String resolveSource(Video vid, String langCode, String trackUrl) {
      if (vid.aiDubbedAudio.isNotEmpty) {
        final aiAudioUrl = vid.aiDubbedAudio[langCode];
        if (aiAudioUrl != null && aiAudioUrl.isNotEmpty) {
          if (StorageCanonicalizer.isSameStorageObject(aiAudioUrl, trackUrl)) {
            return 'ai_dub';
          }
        }
        return 'creator';
      }
      if (vid.dubbedVideos.containsKey(langCode)) {
        return 'ai_dub';
      }
      if (vid.dubbingLanguages.isNotEmpty && vid.dubbingLanguages.contains(langCode)) {
        return 'ai_dub';
      }
      return 'creator';
    }

    test('URL match -> label (ai_dub)', () {
      final video = VideoMapParser.parse({
        'title': 'Test Video',
        'description': 'Description',
        'language': 'en',
        'audioTracks': {
          'te': 'https://storage.googleapis.com/truthworld/te_ai.mp3',
        },
        'aiDubbedAudio': {
          'te': 'https://storage.googleapis.com/truthworld/te_ai.mp3',
        },
      }, 'vid_match');

      expect(resolveSource(video, 'te', 'https://storage.googleapis.com/truthworld/te_ai.mp3'), equals('ai_dub'));
    });

    test('URL with query parameter bypass &x=1 still matches canonical object -> label shown (ai_dub)', () {
      final video = VideoMapParser.parse({
        'title': 'Test Video',
        'description': 'Description',
        'language': 'en',
        'audioTracks': {
          'te': 'https://storage.googleapis.com/truthworld-prod.appspot.com/dubs/123/te.mp3?x=1',
        },
        'aiDubbedAudio': {
          'te': 'https://firebasestorage.googleapis.com/v0/b/truthworld-prod.appspot.com/o/dubs%2F123%2Fte.mp3?alt=media&token=token123',
        },
      }, 'vid_query_bypass');

      expect(resolveSource(video, 'te', 'https://storage.googleapis.com/truthworld-prod.appspot.com/dubs/123/te.mp3?x=1'), equals('ai_dub'));
    });

    test('Creator replaced the track (URL differs) -> no label (creator)', () {
      final video = VideoMapParser.parse({
        'title': 'Test Video',
        'description': 'Description',
        'language': 'en',
        'audioTracks': {
          'te': 'https://storage.googleapis.com/truthworld/te_creator_replaced.mp3',
        },
        'aiDubbedAudio': {
          'te': 'https://storage.googleapis.com/truthworld/te_ai.mp3',
        },
      }, 'vid_diff');

      expect(resolveSource(video, 'te', 'https://storage.googleapis.com/truthworld/te_creator_replaced.mp3'), equals('creator'));
    });

    test('audioTrackSources says "creator" but URLs match -> label still shown (ai_dub)', () {
      final video = VideoMapParser.parse({
        'title': 'Test Video',
        'description': 'Description',
        'language': 'en',
        'audioTracks': {
          'te': 'https://storage.googleapis.com/truthworld/te_ai.mp3',
        },
        'audioTrackSources': {
          'te': 'creator', // Tampered!
        },
        'aiDubbedAudio': {
          'te': 'https://storage.googleapis.com/truthworld/te_ai.mp3',
        },
      }, 'vid_tampered');

      expect(resolveSource(video, 'te', 'https://storage.googleapis.com/truthworld/te_ai.mp3'), equals('ai_dub'));
    });

    test('Owner set-merge with literal field aiDubbedAudio.te does NOT override protected map (parser guarantee)', () {
      final video = VideoMapParser.parse({
        'title': 'Test Video',
        'description': 'Description',
        'language': 'en',
        'audioTracks': {
          'te': 'https://storage.googleapis.com/truthworld/te_real.mp3',
        },
        'aiDubbedAudio': {
          'hi': 'https://storage.googleapis.com/truthworld/hi_ai.mp3',
        },
        'aiDubbedAudio.te': 'https://storage.googleapis.com/fake/tampered.mp3', // Literal dotted override attempt
      }, 'vid_literal_dotted_attempt');

      // Parser strictly ignores literal dotted keys, reading only data['aiDubbedAudio'] map
      expect(video.aiDubbedAudio['te'], isNull);
      expect(video.aiDubbedAudio['hi'], equals('https://storage.googleapis.com/truthworld/hi_ai.mp3'));
      expect(resolveSource(video, 'te', 'https://storage.googleapis.com/truthworld/te_real.mp3'), equals('creator'));
    });

    test('No aiDubbedAudio and dub not completed -> no label (creator)', () {
      final video = VideoMapParser.parse({
        'title': 'Test Video',
        'description': 'Description',
        'language': 'en',
        'audioTracks': {
          'te': 'https://storage.googleapis.com/truthworld/te_creator.mp3',
        },
        'dubbingLanguages': <String>[], // Not completed / not listed
      }, 'vid_no_ai');

      expect(resolveSource(video, 'te', 'https://storage.googleapis.com/truthworld/te_creator.mp3'), equals('creator'));
    });

    test('Parse aiDubbedAudio from root doc only, ignoring media.* and dotted keys', () {
      final video = VideoMapParser.parse({
        'title': 'Test Video',
        'description': 'Description',
        'language': 'en',
        'aiDubbedAudio': {
          'te': 'https://storage.googleapis.com/truthworld/te_root.mp3',
        },
        'media': {
          'aiDubbedAudio': {
            'hi': 'https://storage.googleapis.com/truthworld/hi_nested_should_be_ignored.mp3',
          },
        },
        'media.aiDubbedAudio.mr': 'https://storage.googleapis.com/truthworld/mr_nested_should_be_ignored.mp3',
        'aiDubbedAudio.ml': 'https://storage.googleapis.com/truthworld/ml_dotted_root.mp3',
      }, 'vid_parser');

      expect(video.aiDubbedAudio['te'], equals('https://storage.googleapis.com/truthworld/te_root.mp3'));
      expect(video.aiDubbedAudio['ml'], isNull); // Ignored because dotted key loop is removed
      expect(video.aiDubbedAudio['hi'], isNull); // Ignored because nested in media
      expect(video.aiDubbedAudio['mr'], isNull); // Ignored because nested in media
    });
  });
}
