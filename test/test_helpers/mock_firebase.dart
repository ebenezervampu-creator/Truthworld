import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_fonts/src/google_fonts_base.dart' as gfb;

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
      pluginConstants: const {},
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
        pluginConstants: const {},
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

  TestFirebaseCoreHostApi.setUp(MockFirebaseAppWithStorage());

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
