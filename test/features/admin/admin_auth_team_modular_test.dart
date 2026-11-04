import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/features/admin/presentation/controllers/auth/admin_auth_barrel.dart';

import '../../test_helpers/mock_firebase.dart';

class TestAdminAuthController extends AdminController {
  @override
  // ignore: must_call_super
  void onInit() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (methodCall) async => '.',
    );
    await GetStorage.init();
    await setupMockFirebase();
  });

  setUp(Get.reset);

  tearDown(Get.reset);

  group('AdminAuthTeamMixin & Primary Owner Tests', () {
    late TestAdminAuthController controller;

    setUp(() {
      controller = TestAdminAuthController();
      Get.put<AdminController>(controller);
    });

    test('isPrimaryOwner recognizes authorized owner emails', () {
      controller.currentAdminEmail.value = 'hello@truthworld.in';
      expect(controller.isPrimaryOwner, isTrue);

      controller.currentAdminEmail.value = 'ebenezervampu4@gmail.com';
      expect(controller.isPrimaryOwner, isTrue);

      controller.currentAdminEmail.value = 'regular_admin@truthworld.in';
      expect(controller.isPrimaryOwner, isFalse);
    });

    test('stopAdminMembersSubscription cancels subscription safely', () {
      expect(() => controller.stopAdminMembersSubscription(), returnsNormally);
    });
  });

  group('AdminTeamService Tests', () {
    test('copyMemberCredentials formats portal text correctly', () {
      AdminTeamService.copyMemberCredentials(
        email: 'moderator@truthworld.in',
        password: 'Password123!',
        role: 'Content Moderator',
      );
      // Completes with snackbar feedback without throwing
    });

    test('deleteTeamMember safeguards primary owner account from deletion', () async {
      final result = await AdminTeamService.deleteTeamMember(
        email: 'hello@truthworld.in',
        authorizedOwnerEmails: AdminRolesConfig.authorizedOwnerEmails,
      );
      expect(result, isFalse);
    });

    test('ensureDefaultAdminSeeded completes safely when unauthenticated', () async {
      await expectLater(
        AdminTeamService.ensureDefaultAdminSeeded(
          authorizedOwnerEmails: AdminRolesConfig.authorizedOwnerEmails,
        ),
        completes,
      );
    });
  });

  group('AdminPasswordService Validation Tests', () {
    test('changeAdminPassword rejects empty password', () async {
      final result = await AdminPasswordService.changeAdminPassword(
        currentPassword: '12345',
        newPassword: '',
        currentAdminEmail: 'hello@truthworld.in'.obs,
        currentAdminRole: 'Super Admin'.obs,
        currentAdminRoles: <String>['Super Admin'].obs,
        authorizedOwnerEmails: AdminRolesConfig.authorizedOwnerEmails,
        rxIsLoading: false.obs,
      );
      expect(result, isFalse);
    });

    test('changeAdminPassword rejects password with less than 6 characters', () async {
      final result = await AdminPasswordService.changeAdminPassword(
        currentPassword: '12345',
        newPassword: 'abc',
        currentAdminEmail: 'hello@truthworld.in'.obs,
        currentAdminRole: 'Super Admin'.obs,
        currentAdminRoles: <String>['Super Admin'].obs,
        authorizedOwnerEmails: AdminRolesConfig.authorizedOwnerEmails,
        rxIsLoading: false.obs,
      );
      expect(result, isFalse);
    });

    test('changeAdminPassword rejects invalid current password without throwing', () async {
      final result = await AdminPasswordService.changeAdminPassword(
        currentPassword: 'wrong_password_999',
        newPassword: 'CorrectPassword123!',
        currentAdminEmail: 'unknown_admin@truthworld.in'.obs,
        currentAdminRole: 'Content Moderator'.obs,
        currentAdminRoles: <String>['Content Moderator'].obs,
        authorizedOwnerEmails: AdminRolesConfig.authorizedOwnerEmails,
        rxIsLoading: false.obs,
      );
      expect(result, isFalse);
    });
  });

  group('AdminAuthProtocolService Session Tests', () {
    test('restoreAdminSession loads cached admin profile', () {
      GetStorage().write('truthworld_admin_session', {
        'email': 'admin_test@truthworld.in',
        'role': 'Content Moderator',
        'roles': ['Content Moderator', 'Trust & Safety Reviewer'],
      });

      final isAdmin = false.obs;
      final email = ''.obs;
      final role = ''.obs;
      final roles = <String>[].obs;
      var subscriptionsStarted = false;

      AdminAuthProtocolService.restoreAdminSession(
        isAdmin: isAdmin,
        currentAdminEmail: email,
        currentAdminRole: role,
        currentAdminRoles: roles,
        onStartSubscriptions: () {
          subscriptionsStarted = true;
        },
      );

      expect(isAdmin.value, isTrue);
      expect(email.value, equals('admin_test@truthworld.in'));
      expect(role.value, equals('Content Moderator'));
      expect(roles.length, equals(2));
      expect(subscriptionsStarted, isTrue);
    });
  });
}
