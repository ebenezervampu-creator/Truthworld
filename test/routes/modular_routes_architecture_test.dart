import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/navigation/app_navigator.dart';
import 'package:truthworld/routes/app_pages.dart';
import 'package:truthworld/routes/modules/admin_routes.dart';
import 'package:truthworld/routes/modules/advertiser_routes.dart';
import 'package:truthworld/routes/modules/channel_routes.dart';
import 'package:truthworld/routes/modules/community_routes.dart';
import 'package:truthworld/routes/modules/core_routes.dart';
import 'package:truthworld/routes/modules/economy_routes.dart';
import 'package:truthworld/routes/modules/legal_routes.dart';
import 'package:truthworld/routes/modules/studio_routes.dart';
import 'package:truthworld/routes/modules/upload_routes.dart';
import 'package:truthworld/routes/modules/user_library_routes.dart';
import 'package:truthworld/routes/modules/video_routes.dart';

class MockNavigationService implements INavigationService {
  String? lastToNamedPage;
  dynamic lastArguments;
  Map<String, String>? lastParameters;
  String? lastOffNamedPage;
  String? lastOffAllNamedPage;
  bool backCalled = false;
  dynamic backResult;

  @override
  Future<T?>? toNamed<T>(
    String page, {
    dynamic arguments,
    int? id,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
  }) {
    lastToNamedPage = page;
    lastArguments = arguments;
    lastParameters = parameters;
    return null;
  }

  @override
  Future<T?>? offNamed<T>(
    String page, {
    dynamic arguments,
    int? id,
    bool preventDuplicates = true,
    Map<String, String>? parameters,
  }) {
    lastOffNamedPage = page;
    lastArguments = arguments;
    lastParameters = parameters;
    return null;
  }

  @override
  Future<T?>? offAllNamed<T>(
    String page, {
    dynamic arguments,
    int? id,
    Map<String, String>? parameters,
  }) {
    lastOffAllNamedPage = page;
    lastArguments = arguments;
    lastParameters = parameters;
    return null;
  }

  @override
  void back<T>({T? result, bool closeOverlays = false, bool canPop = true}) {
    backCalled = true;
    backResult = result;
  }

  @override
  bool canPop() => true;
}

void main() {
  group('Clean Architecture Modular Routes Test Suite', () {
    test('AppPages aggregates routes from all 11 feature modules', () {
      final totalModuleRoutes = CoreRoutes.routes.length +
          VideoRoutes.routes.length +
          StudioRoutes.routes.length +
          UploadRoutes.routes.length +
          ChannelRoutes.routes.length +
          CommunityRoutes.routes.length +
          UserLibraryRoutes.routes.length +
          AdminRoutes.routes.length +
          AdvertiserRoutes.routes.length +
          EconomyRoutes.routes.length +
          LegalRoutes.routes.length +
          1; // ChannelRoutes.handleRoute

      expect(AppPages.routes.length, equals(totalModuleRoutes));
      expect(AppPages.initial, equals(AppRoutes.root));
    });

    test('All registered routes have unique names (no colliding duplicate routes)', () {
      final registeredNames = AppPages.routes.map((p) => p.name).toList();
      final uniqueNames = registeredNames.toSet();

      expect(
        registeredNames.length,
        equals(uniqueNames.length),
        reason: 'Duplicate route detected in aggregated route table',
      );
    });

    test('Key core and feature routes exist in the aggregated routes collection', () {
      final names = AppPages.routes.map((p) => p.name).toSet();

      expect(names.contains(AppRoutes.root), isTrue);
      expect(names.contains(AppRoutes.home), isTrue);
      expect(names.contains(AppRoutes.watch), isTrue);
      expect(names.contains(AppRoutes.studio), isTrue);
      expect(names.contains(AppRoutes.upload), isTrue);
      expect(names.contains(AppRoutes.adminDashboard), isTrue);
      expect(names.contains(AppRoutes.advertiser), isTrue);
      expect(names.contains(AppRoutes.premium), isTrue);
      expect(names.contains(AppRoutes.channelWizard), isTrue);
    });

    test('AppNavigator decouples controllers and UI from direct GetX navigation calls', () {
      final mock = MockNavigationService();
      AppNavigator.setMockService(mock);

      // Test toWatch
      AppNavigator.toWatch('test_video_123');
      expect(mock.lastToNamedPage, equals(AppRoutes.watch));
      expect(mock.lastParameters?['v'], equals('test_video_123'));
      expect(mock.lastArguments?['videoId'], equals('test_video_123'));

      // Test toStudio
      AppNavigator.toStudio();
      expect(mock.lastToNamedPage, equals(AppRoutes.studio));

      // Test toUpload
      AppNavigator.toUpload();
      expect(mock.lastToNamedPage, equals(AppRoutes.upload));

      // Test toHome
      AppNavigator.toHome();
      expect(mock.lastOffAllNamedPage, equals(AppRoutes.home));

      // Test back
      AppNavigator.back(result: 'success');
      expect(mock.backCalled, isTrue);
      expect(mock.backResult, equals('success'));

      AppNavigator.resetService();
    });
  });
}
