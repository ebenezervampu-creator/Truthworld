import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/core/exceptions/app_exceptions.dart';
import 'package:truthworld/core/network/result.dart';
import 'package:truthworld/domain/repositories/admin_repository.dart';

class FakeAdminRepository implements AdminRepository {
  final Map<String, Map<String, dynamic>> users = {
    'user1': {'id': 'user1', 'name': 'User One', 'isBanned': false},
    'user2': {'id': 'user2', 'name': 'User Two', 'isBanned': true},
  };

  @override
  Future<Result<List<Map<String, dynamic>>>> getUsers({
    int page = 1,
    int limit = 20,
    String? searchQuery,
  }) async {
    return Result.success(users.values.toList());
  }

  @override
  Future<Result<Map<String, dynamic>>> getUserById(String userId) async {
    final user = users[userId];
    if (user == null) {
      return Result.failure(const GenericAppException(message: 'User not found'));
    }
    return Result.success(user);
  }

  @override
  Future<Result<void>> banUser(String userId, {String? reason}) async {
    if (users.containsKey(userId)) {
      users[userId]!['isBanned'] = true;
      return Result.success(null);
    }
    return Result.success(null);
  }

  @override
  Future<Result<void>> unbanUser(String userId) async {
    if (users.containsKey(userId)) {
      users[userId]!['isBanned'] = false;
      return Result.success(null);
    }
    return Result.success(null);
  }

  @override
  Future<Result<void>> deleteUser(String userId) async {
    users.remove(userId);
    return Result.success(null);
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> getReportedContent({
    int page = 1,
    int limit = 20,
    String? status,
  }) async {
    return Result.success([
      {'id': 'rep1', 'reason': 'Spam', 'status': 'pending'}
    ]);
  }

  @override
  Future<Result<void>> resolveReport(
    String reportId, {
    required String action,
    String? note,
  }) async {
    return Result.success(null);
  }

  @override
  Future<Result<Map<String, dynamic>>> getPlatformAnalytics({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    return Result.success({'activeUsers': 1500, 'totalVideos': 450});
  }

  @override
  Future<Result<List<Map<String, dynamic>>>> getFeedback({
    int page = 1,
    int limit = 20,
    String? status,
  }) async {
    return Result.success([]);
  }

  @override
  Future<Result<void>> updateFeedbackStatus(String feedbackId, String status) async {
    return Result.success(null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AdminRepository Unit Tests', () {
    late FakeAdminRepository repository;

    setUp(() {
      repository = FakeAdminRepository();
    });

    test('getUsers returns user list', () async {
      final result = await repository.getUsers();
      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull?.length, equals(2));
    });

    test('banUser updates user status', () async {
      await repository.banUser('user1');
      final user = await repository.getUserById('user1');
      expect(user.dataOrNull?['isBanned'], isTrue);
    });

    test('unbanUser restores user status', () async {
      await repository.unbanUser('user2');
      final user = await repository.getUserById('user2');
      expect(user.dataOrNull?['isBanned'], isFalse);
    });

    test('deleteUser removes user from database', () async {
      await repository.deleteUser('user1');
      final list = await repository.getUsers();
      expect(list.dataOrNull?.length, equals(1));
    });
  });
}
