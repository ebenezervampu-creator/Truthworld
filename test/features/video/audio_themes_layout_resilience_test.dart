import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/features/video/data/models/video.dart';
import 'package:truthworld/features/video/presentation/views/player/overlays/components/audio_themes/audio_themes_barrel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final dummyVideo = Video(
    id: 'test_video_1',
    title: 'Test Audio Experience with a Long Title to Verify Ellipsis',
    description: 'Description',
    videoUrl: 'https://cdn.truthworld.app/video.mp4',
    thumbnailUrl: '',
    ownerId: 'owner_1',
    category: 'Music',
    tags: const ['music'],
    duration: 180,
    views: 1200,
    likes: 85,
    dislikeCount: 2,
    channelId: 'channel_1',
    channelName: 'TruthWorld Acoustic Studio',
    createdAt: DateTime.now(),
  );

  group('Audio Player Themes Layout & Infinite Constraints Resilience', () {
    testWidgets('AmbientGlowTheme renders without BoxConstraints assertion errors', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 225,
              child: AmbientGlowTheme(
                isPlaying: true,
                video: dummyVideo,
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.byType(AmbientGlowTheme), findsOneWidget);
    });

    testWidgets('All 10 Audio Themes render cleanly in bounded player viewport', (tester) async {
      final themes = <Widget>[
        AmbientGlowTheme(isPlaying: true, video: dummyVideo),
        RetroVinylTheme(isPlaying: true, video: dummyVideo),
        CyberSpectrumTheme(isPlaying: true, video: dummyVideo),
        LyricalStageTheme(isPlaying: true, currentSubtitle: '♪ Truth in sound ♪', video: dummyVideo),
        ZenAuraTheme(isPlaying: true, video: dummyVideo),
        VintageCassetteTheme(isPlaying: true, video: dummyVideo),
        AnalogVuMeterTheme(isPlaying: true, video: dummyVideo),
        CosmicNebulaTheme(isPlaying: true, video: dummyVideo),
        HolographicCdTheme(isPlaying: true, video: dummyVideo),
        FluidHorizonTheme(isPlaying: true, video: dummyVideo),
      ];

      for (final theme in themes) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 360,
                height: 202, // Standard 16:9 on compact screen
                child: theme,
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 50));

        expect(tester.takeException(), isNull, reason: '${theme.runtimeType} threw an exception');
      }
    });

    testWidgets('AnimatedSwitcher with StackFit.expand passes finite constraints to theme', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 225,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    layoutBuilder: (currentChild, previousChildren) => Stack(
                      fit: StackFit.expand,
                      children: [
                        ...previousChildren,
                        if (currentChild != null) currentChild,
                      ],
                    ),
                    child: KeyedSubtree(
                      key: const ValueKey('ambientGlow'),
                      child: AmbientGlowTheme(
                        isPlaying: true,
                        video: dummyVideo,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
      expect(find.byType(AmbientGlowTheme), findsOneWidget);
    });
  });
}
