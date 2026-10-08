import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/features/admin/presentation/views/team_management_tab.dart';
import 'package:truthworld/theme/app_theme.dart';
import '../../test_helpers/mock_firebase.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(() {
    Get.reset();
    Get.testMode = true;
    if (!Get.isRegistered<AuthService>()) {
      Get.put<AuthService>(AuthService(), permanent: true);
    }
  });

  tearDown(Get.reset);

  Widget createHarness(Widget child) {
    return GetMaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    );
  }

  group('Team Management Modular Components Tests', () {
    testWidgets('TeamManagementMetricCard renders title, value, subtitle, and icon', (tester) async {
      await tester.pumpWidget(
        createHarness(
          const TeamManagementMetricCard(
            title: 'Active Accounts',
            value: '12',
            subtitle: 'Currently authorized',
            icon: Icons.verified_user_outlined,
          ),
        ),
      );

      expect(find.text('Active Accounts'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('Currently authorized'), findsOneWidget);
      expect(find.byIcon(Icons.verified_user_outlined), findsOneWidget);
    });

    testWidgets('TeamManagementStatsRow aggregates members statistics correctly', (tester) async {
      final ctrl = Get.put(AdminController());
      ctrl.adminMembers.assignAll([
        {
          'email': 'owner@truthworld.in',
          'role': 'Super Admin',
          'status': 'active',
        },
        {
          'email': 'mod1@truthworld.in',
          'role': 'Content Moderator',
          'status': 'active',
        },
        {
          'email': 'suspended@truthworld.in',
          'role': 'Community Mod',
          'status': 'suspended',
        },
      ]);

      await tester.pumpWidget(
        createHarness(TeamManagementStatsRow(controller: ctrl)),
      );

      expect(find.text('Total Administrators'), findsOneWidget);
      expect(find.text('3'), findsOneWidget); // Total
      expect(find.text('2'), findsNWidgets(2)); // Active & Moderators
      expect(find.text('1'), findsWidgets); // Super Admins
      expect(find.text('Moderators'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('TeamRoleBadges and TeamRoleBadge display role badges with semantic colors', (tester) async {
      await tester.pumpWidget(
        createHarness(
          const Column(
            children: [
              TeamRoleBadges(roles: []),
              TeamRoleBadges(roles: ['Super Admin']),
              TeamRoleBadges(roles: ['Content Moderator', 'Ad Ops']),
            ],
          ),
        ),
      );

      expect(find.text('Admin'), findsOneWidget);
      expect(find.text('Super Admin (All Tabs)'), findsOneWidget);
      expect(find.text('Content Moderator'), findsOneWidget);
      expect(find.text('Ad Ops'), findsOneWidget);
    });

    testWidgets('TeamStatusChip displays active and suspended states correctly', (tester) async {
      await tester.pumpWidget(
        createHarness(
          const Column(
            children: [
              TeamStatusChip(isSuspended: false),
              TeamStatusChip(isSuspended: true),
            ],
          ),
        ),
      );

      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Suspended'), findsOneWidget);
    });

    testWidgets('TeamRoleSelectionSection supports select all and toggle individual roles', (tester) async {
      final selectedRoles = <String>['Content Moderator'].obs;

      await tester.pumpWidget(
        createHarness(TeamRoleSelectionSection(selectedRoles: selectedRoles)),
      );

      expect(find.text('Select All Roles'), findsOneWidget);
      expect(selectedRoles.length, 1);

      // Tap Select All
      await tester.tap(find.text('Select All Roles'));
      await tester.pump();

      expect(selectedRoles.length, AdminController.availableRoles.length);
      expect(find.text('Deselect All'), findsOneWidget);

      // Tap Deselect All
      await tester.tap(find.text('Deselect All'));
      await tester.pump();

      expect(selectedRoles.isEmpty, true);
    });

    testWidgets('TeamMemberRow displays member information, credentials, and actions', (tester) async {
      final ctrl = Get.put(AdminController());
      final member = {
        'email': 'hello@truthworld.in',
        'name': 'Ebenezer',
        'role': 'Super Admin',
        'password': 'SuperSecret123',
        'status': 'active',
      };

      await tester.pumpWidget(
        createHarness(TeamMemberRow(controller: ctrl, member: member)),
      );

      expect(find.text('Ebenezer'), findsOneWidget);
      expect(find.text('hello@truthworld.in'), findsOneWidget);
      expect(find.text('OWNER'), findsOneWidget);
      expect(find.text('••••••••'), findsOneWidget);

      // Toggle show password
      await tester.tap(find.byIcon(Icons.remove_red_eye_outlined));
      await tester.pump();

      expect(find.text('SuperSecret123'), findsOneWidget);
    });

    testWidgets('TeamManagementTab full screen coordinator pumps cleanly', (tester) async {
      final ctrl = Get.put(AdminController());

      await tester.pumpWidget(
        createHarness(TeamManagementTab(controller: ctrl)),
      );

      expect(find.byType(TeamManagementTab), findsOneWidget);
      expect(find.text('Admin Team & Security'), findsOneWidget);
      expect(find.text('Change My Password'), findsOneWidget);
      expect(find.text('Add Team Member'), findsOneWidget);
      expect(find.text('Authorized Team Members'), findsOneWidget);
      expect(find.text('No team members registered yet'), findsOneWidget);
    });
  });
}
