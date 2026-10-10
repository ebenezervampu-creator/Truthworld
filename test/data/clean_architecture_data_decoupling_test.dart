import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/base/base_repository.dart';
import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/data/datasources/remote/channel_remote_datasource.dart';
import 'package:truthworld/data/models/channel.dart';
import 'package:truthworld/data/repositories/channel_repository_impl.dart';
import 'package:truthworld/data/repositories/video_repository_impl.dart';

class FakeBaseRepository extends BaseRepository {
  FakeBaseRepository({super.isTestMode});

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

class FakeChannelRemoteDataSource implements ChannelRemoteDataSource {
  final Map<String, Channel> channels = {};

  @override
  Future<Channel> getChannelById(String id) async {
    if (channels.containsKey(id)) return channels[id]!;
    throw Exception('Channel not found');
  }

  @override
  Future<Channel> getChannelByHandle(String handle) async {
    throw UnimplementedError();
  }

  @override
  Future<List<Channel>> getSubscriptions(
    String userId, {
    int limit = 20,
    dynamic startAfter,
  }) async =>
      [];

  @override
  Future<void> toggleSubscription(String channelId, String userId) async {}

  @override
  Future<Channel> createChannel({
    required String name,
    required String handle,
    required String description,
    required String ownerId,
  }) async {
    throw UnimplementedError();
  }
}

void main() {
  group('Clean Architecture Data & Base Layer Decoupling Test Suite', () {
    test('BaseRepository uses isTestMode flag without depending on Get.testMode', () async {
      final repoInTestMode = FakeBaseRepository(isTestMode: true);

      // In test mode, timeout is 100ms. An operation that takes 300ms should timeout.
      final result = await repoInTestMode.performFetch(() async {
        await Future.delayed(const Duration(milliseconds: 300));
        return 'success';
      });

      expect(result.isFailure, isTrue);
      expect(result.exceptionOrNull?.code, equals('timeout'));
    });

    test('ChannelRepositoryImpl supports pure constructor dependency injection', () async {
      final fakeDataSource = FakeChannelRemoteDataSource();
      fakeDataSource.channels['ch123'] = Channel.fromMap({
        'id': 'ch123',
        'name': 'Truth Channel',
        'handle': 'truth',
        'ownerId': 'user123',
        'description': 'Channel description',
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      }, 'ch123');

      var callbackNotified = false;
      final repo = ChannelRepositoryImpl(
        remoteDataSource: fakeDataSource,
        onChannelCreated: (ch) {
          callbackNotified = true;
        },
      );

      final result = await repo.getChannelById('ch123');
      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.id, equals('ch123'));
      expect(result.dataOrNull?.name, equals('Truth Channel'));
      expect(callbackNotified, isFalse);
    });

    test('VideoRepositoryImpl can be instantiated with pure DI and no GetX locator', () {
      final repo = VideoRepositoryImpl(
        isTestMode: true,
      );

      expect(repo, isNotNull);
      expect(repo.isTestMode, isTrue);
    });
  });
}
