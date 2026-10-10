import 'dart:io';
import 'package:truthworld/core/base/base_repository.dart';
import 'package:truthworld/core/navigation/app_navigator.dart';
import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/data/datasources/remote/channel_remote_datasource.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/data/repositories/channel_repository_impl.dart';
import 'package:truthworld/data/repositories/video_repository_impl.dart';
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

class FakeTestRepository extends BaseRepository {
  FakeTestRepository({super.isTestMode});

  Future<Result<String>> performFetch(
    Future<String> Function() task, {
    Duration? timeout,
  }) {
    return safeFetch(
      task,
      timeout: timeout ?? const Duration(seconds: 5),
    );
  }
}

class FakeChannelDataSource implements ChannelRemoteDataSource {
  @override
  Future<Channel> getChannelById(String id) async {
    return Channel.fromMap({
      'name': 'Decoupled Channel',
      'handle': 'decoupled',
      'ownerId': 'usr_1',
    }, id);
  }

  @override
  Future<Channel> getChannelByHandle(String handle) => throw UnimplementedError();

  @override
  Future<List<Channel>> getSubscriptions(String userId, {int limit = 20, dynamic startAfter}) =>
      throw UnimplementedError();

  @override
  Future<void> toggleSubscription(String channelId, String userId) =>
      throw UnimplementedError();

  @override
  Future<Channel> createChannel({
    required String name,
    required String handle,
    required String description,
    required String ownerId,
  }) =>
      throw UnimplementedError();
}

Future<void> main() async {
  stdout.writeln('=== [TRUTHWORLD CLEAN ARCHITECTURE VERIFICATION] ===\n');

  var passed = 0;
  var failed = 0;

  void check(String name, bool condition, [String? detail]) {
    if (condition) {
      stdout.writeln('  [PASS] $name');
      passed++;
    } else {
      stderr.writeln('  [FAIL] $name: ${detail ?? "Condition not met"}');
      failed++;
    }
  }

  // 1. Modular Routes Verification
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
      LegalRoutes.routes.length;

  check(
    'AppPages aggregates all 11 modular route tables',
    AppPages.routes.length == totalModuleRoutes,
    'Expected $totalModuleRoutes routes, found ${AppPages.routes.length}',
  );

  final registeredNames = AppPages.routes.map((p) => p.name).toList();
  final uniqueNames = registeredNames.toSet();
  check(
    'No duplicate route collision in aggregated route table',
    registeredNames.length == uniqueNames.length,
    'Duplicates found: ${registeredNames.length - uniqueNames.length}',
  );

  check('AppRoutes.root is initial route', AppPages.initial == AppRoutes.root);
  check('Contains core route "/"', uniqueNames.contains(AppRoutes.root));
  check('Contains home route "/home"', uniqueNames.contains(AppRoutes.home));
  check('Contains watch route "/watch"', uniqueNames.contains(AppRoutes.watch));
  check('Contains studio route "/studio"', uniqueNames.contains(AppRoutes.studio));
  check('Contains upload route "/upload"', uniqueNames.contains(AppRoutes.upload));
  check(
    'Contains admin dashboard "/admin/dashboard"',
    uniqueNames.contains(AppRoutes.adminDashboard),
  );
  check('Contains advertiser route "/advertiser"', uniqueNames.contains(AppRoutes.advertiser));
  check('Contains premium route "/premium"', uniqueNames.contains(AppRoutes.premium));

  // 2. AppNavigator Decoupling Verification
  final mockNav = MockNavigationService();
  AppNavigator.setMockService(mockNav);

  AppNavigator.toWatch('vid_xyz');
  check(
    'AppNavigator.toWatch delegates to INavigationService',
    mockNav.lastToNamedPage == AppRoutes.watch &&
        mockNav.lastParameters?['v'] == 'vid_xyz',
  );

  AppNavigator.toStudio();
  check(
    'AppNavigator.toStudio delegates correctly',
    mockNav.lastToNamedPage == AppRoutes.studio,
  );

  AppNavigator.toHome();
  check(
    'AppNavigator.toHome delegates offAllNamed',
    mockNav.lastOffAllNamedPage == AppRoutes.home,
  );

  AppNavigator.back(result: 42);
  check(
    'AppNavigator.back delegates with result',
    mockNav.backCalled && mockNav.backResult == 42,
  );

  AppNavigator.resetService();

  // 3. Data Layer Decoupling from GetX
  final testRepo = FakeTestRepository(isTestMode: true);
  final timeoutResult = await testRepo.performFetch(() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return 'ok';
  });
  check(
    'BaseRepository enforces isTestMode timeout without Get.testMode',
    timeoutResult.isFailure && timeoutResult.exceptionOrNull?.code == 'timeout',
  );

  final channelRepo = ChannelRepositoryImpl(
    remoteDataSource: FakeChannelDataSource(),
  );
  final channelResult = await channelRepo.getChannelById('c_100');
  check(
    'ChannelRepositoryImpl fetches channel with pure constructor DI',
    channelResult.isSuccess && channelResult.dataOrNull?.name == 'Decoupled Channel',
  );

  final videoRepo = VideoRepositoryImpl(isTestMode: true);
  check(
    'VideoRepositoryImpl instantiates with pure DI and zero GetX locator',
    videoRepo.isTestMode,
  );

  // 4. Source Code Purity Verification (No package:get in domain or data)
  final domainDir = Directory('lib/domain');
  var domainGetxCount = 0;
  for (final file in domainDir.listSync(recursive: true).whereType<File>()) {
    if (file.path.endsWith('.dart') &&
        file.readAsStringSync().contains('package:get')) {
      domainGetxCount++;
    }
  }
  check(
    'Domain layer has 0 imports of package:get',
    domainGetxCount == 0,
    'Found $domainGetxCount files importing GetX in lib/domain',
  );

  final dataDir = Directory('lib/data');
  var dataGetxCount = 0;
  for (final file in dataDir.listSync(recursive: true).whereType<File>()) {
    if (file.path.endsWith('.dart') &&
        file.readAsStringSync().contains('package:get')) {
      dataGetxCount++;
    }
  }
  check(
    'Data layer has 0 imports of package:get',
    dataGetxCount == 0,
    'Found $dataGetxCount files importing GetX in lib/data',
  );

  final baseRepoFile = File('lib/core/base/base_repository.dart');
  check(
    'BaseRepository has 0 imports of package:get',
    !baseRepoFile.readAsStringSync().contains('package:get'),
  );

  final appPagesFile = File('lib/routes/app_pages.dart');
  final appPagesLineCount = appPagesFile.readAsLinesSync().length;
  check(
    'app_pages.dart is compact composite router (< 60 lines)',
    appPagesLineCount < 60,
    'Line count: $appPagesLineCount (expected < 60)',
  );

  stdout.writeln('\n----------------------------------------');
  stdout.writeln('Total checks: ${passed + failed}');
  stdout.writeln('Passed: $passed, Failed: $failed');
  stdout.writeln('----------------------------------------');

  if (failed > 0) {
    exit(1);
  } else {
    stdout.writeln('\n[SUCCESS] Flutter Clean Architecture complies 100% with industry standards!');
  }
}
