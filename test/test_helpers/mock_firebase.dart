import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_fonts/src/google_fonts_base.dart' as gfb;
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';

class MockJustAudioPlatform extends JustAudioPlatform {
  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async {
    return MockAudioPlayerPlatform(request.id);
  }

  @override
  Future<DisposePlayerResponse> disposePlayer(DisposePlayerRequest request) async {
    return DisposePlayerResponse();
  }

  @override
  Future<DisposeAllPlayersResponse> disposeAllPlayers(DisposeAllPlayersRequest request) async {
    return DisposeAllPlayersResponse();
  }
}

class MockAudioPlayerPlatform extends AudioPlayerPlatform {
  MockAudioPlayerPlatform(super.id) {
    scheduleMicrotask(() {
      if (!_playbackEventController.isClosed) {
        _playbackEventController.add(
          PlaybackEventMessage(
            processingState: ProcessingStateMessage.idle,
            updatePosition: Duration.zero,
            updateTime: DateTime.now(),
            duration: Duration.zero,
            bufferedPosition: Duration.zero,
            icyMetadata: null,
            currentIndex: null,
            androidAudioSessionId: null,
          ),
        );
      }
    });
  }

  final _playbackEventController = StreamController<PlaybackEventMessage>.broadcast();

  @override
  Stream<PlaybackEventMessage> get playbackEventMessageStream => _playbackEventController.stream;

  @override
  Future<LoadResponse> load(LoadRequest request) async {
    scheduleMicrotask(() {
      if (!_playbackEventController.isClosed) {
        _playbackEventController.add(
          PlaybackEventMessage(
            processingState: ProcessingStateMessage.ready,
            updatePosition: Duration.zero,
            updateTime: DateTime.now(),
            duration: const Duration(seconds: 15),
            bufferedPosition: const Duration(seconds: 15),
            icyMetadata: null,
            currentIndex: 0,
            androidAudioSessionId: null,
          ),
        );
      }
    });
    return LoadResponse(duration: const Duration(seconds: 15));
  }

  @override
  Future<PlayResponse> play(PlayRequest request) async => PlayResponse();

  @override
  Future<PauseResponse> pause(PauseRequest request) async => PauseResponse();

  @override
  Future<SetVolumeResponse> setVolume(SetVolumeRequest request) async => SetVolumeResponse();

  @override
  Future<SetSpeedResponse> setSpeed(SetSpeedRequest request) async => SetSpeedResponse();

  @override
  Future<SeekResponse> seek(SeekRequest request) async => SeekResponse();

  @override
  Future<SetLoopModeResponse> setLoopMode(SetLoopModeRequest request) async => SetLoopModeResponse();

  @override
  Future<SetShuffleModeResponse> setShuffleMode(SetShuffleModeRequest request) async => SetShuffleModeResponse();

  @override
  Future<DisposeResponse> dispose(DisposeRequest request) async {
    await _playbackEventController.close();
    return DisposeResponse();
  }
}

class FakeAssetManifest implements AssetManifest {
  final List<String> _assets;
  FakeAssetManifest(this._assets);

  @override
  List<String> listAssets() => _assets;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<String> _generateFontAssets() {
  final families = ['Roboto', 'Outfit', 'Oswald', 'Merriweather', 'RobotoMono', 'NotoSans'];
  final variants = [
    'Regular', 'Medium', 'Bold', 'SemiBold', 'Light', 'Thin', 'Black', 'ExtraBold', 'ExtraLight',
    'Italic', 'MediumItalic', 'BoldItalic', 'SemiBoldItalic', 'LightItalic', 'ThinItalic', 'BlackItalic',
    '100', '200', '300', '400', '500', '600', '700', '800', '900',
    '100italic', '200italic', '300italic', '400italic', '500italic', '600italic', '700italic', '800italic', '900italic',
  ];
  final list = <String>[];
  for (final f in families) {
    list.add('assets/fonts/$f.ttf');
    for (final v in variants) {
      list.add('assets/fonts/$f-$v.ttf');
      list.add('assets/fonts/${f}_$v.ttf');
      list.add('assets/fonts/$f-$v.otf');
    }
  }
  return list;
}

class MockFirebaseAppWithStorage implements TestFirebaseCoreHostApi {
  @override
  Future<CoreInitializeResponse> initializeApp(
    String appName,
    CoreFirebaseOptions initializeAppRequest,
  ) async {
    return CoreInitializeResponse(
      name: appName,
      options: CoreFirebaseOptions(
        apiKey: '123',
        projectId: '123',
        appId: '123',
        messagingSenderId: '123',
        storageBucket: 'truthworld.appspot.com',
      ),
      pluginConstants: const {
        'plugins.flutter.io/firebase_crashlytics': {
          'isCrashlyticsCollectionEnabled': false,
        },
      },
    );
  }

  @override
  Future<List<CoreInitializeResponse>> initializeCore() async {
    return [
      CoreInitializeResponse(
        name: defaultFirebaseAppName,
        options: CoreFirebaseOptions(
          apiKey: '123',
          projectId: '123',
          appId: '123',
          messagingSenderId: '123',
          storageBucket: 'truthworld.appspot.com',
        ),
        pluginConstants: const {
          'plugins.flutter.io/firebase_crashlytics': {
            'isCrashlyticsCollectionEnabled': false,
          },
        },
      ),
    ];
  }

  @override
  Future<CoreFirebaseOptions> optionsFromResource() async {
    return CoreFirebaseOptions(
      apiKey: '123',
      projectId: '123',
      appId: '123',
      messagingSenderId: '123',
      storageBucket: 'truthworld.appspot.com',
    );
  }
}

Future<void> setupMockFirebase() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  gfb.assetManifest = FakeAssetManifest(_generateFontAssets());
  final fontFile = File('assets/fonts/Roboto-Regular.ttf');
  final fontByteData = fontFile.existsSync()
      ? fontFile.readAsBytesSync().buffer.asByteData()
      : null;

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (message) async {
    if (message == null) return null;
    final key = utf8.decode(message.buffer.asUint8List(message.offsetInBytes, message.lengthInBytes));
    final file = File(key);
    if (file.existsSync()) {
      return file.readAsBytesSync().buffer.asByteData();
    }
    if (key.endsWith('.ttf') || key.endsWith('.otf') || key.endsWith('.woff') || key.endsWith('.woff2')) {
      return fontByteData;
    }
    return null;
  });
  final tempDir = Directory.systemTemp.createTempSync('tw_test_').path;
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (methodCall) async => tempDir,
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/firebase_auth'),
    (methodCall) async => null,
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler(
    'dev.flutter.pigeon.firebase_auth_platform_interface.FirebaseAuthHostApi.signOut',
    (message) async {
      return const StandardMessageCodec().encodeMessage(<Object?>[]);
    },
  );
  try {
    await GetStorage.init();
    await GetStorage().erase();
  } catch (_) {}

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('com.ryanheise.audio_session'),
    (methodCall) async => null,
  );
  TestFirebaseCoreHostApi.setUp(MockFirebaseAppWithStorage());
  JustAudioPlatform.instance = MockJustAudioPlatform();

  if (Firebase.apps.isEmpty) {
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'mock-api-key',
          appId: 'mock-app-id',
          messagingSenderId: 'mock-sender-id',
          projectId: 'mock-project-id',
          storageBucket: 'truthworld.appspot.com',
        ),
      );
    } catch (_) {}
  }
}
