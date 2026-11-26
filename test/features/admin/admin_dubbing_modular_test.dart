import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/admin/presentation/controllers/admin_controller.dart';
import 'package:truthworld/features/admin/presentation/views/dashboard_components/admin_tab_router.dart';
import 'package:truthworld/features/admin/presentation/views/dubbing_management_tab.dart';
import 'package:truthworld/features/dubbing/data/models/dubbing_wallet.dart';

import '../../test_helpers/mock_firebase.dart';

class TestAdminController extends AdminController {
  @override
  void onInit() {
    // Avoid starting live Firestore snapshot listeners in unit test
  }

  @override
  Future<void> refreshAllData() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await setupMockFirebase();
  });

  setUp(Get.reset);
  tearDown(Get.reset);

  group('Admin Dubbing Permissions & Routing Tests', () {
    test('Super Admin has access to dubbing tab in AdminRolesConfig', () {
      final allowedTabs = AdminRolesConfig.getAllowedTabs(
        isPrimaryOwner: false,
        currentAdminEmail: 'super@truthworld.in',
        currentAdminRole: 'Super Admin',
        currentAdminRoles: ['Super Admin'],
      );

      expect(allowedTabs, contains('dubbing'));
      expect(
        AdminRolesConfig.isTabAllowed(
          tabId: 'dubbing',
          isAdmin: true,
          isPrimaryOwner: false,
          currentAdminEmail: 'super@truthworld.in',
          currentAdminRole: 'Super Admin',
          currentAdminRoles: ['Super Admin'],
        ),
        isTrue,
      );
    });

    test('Non-admin users cannot access dubbing tab', () {
      expect(
        AdminRolesConfig.isTabAllowed(
          tabId: 'dubbing',
          isAdmin: false,
          isPrimaryOwner: false,
          currentAdminEmail: 'regular@user.com',
          currentAdminRole: 'user',
          currentAdminRoles: [],
        ),
        isFalse,
      );
    });

    testWidgets('AdminTabRouter routes dubbing tab to DubbingManagementTab', (tester) async {
      final controller = Get.put(TestAdminController());
      Widget? routedWidget;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              routedWidget = AdminTabRouter.buildTabForId('dubbing', context, controller);
              return Container();
            },
          ),
        ),
      );
      expect(routedWidget, isA<DubbingManagementTab>());
    });
  });

  group('DubbingWallet Model Discounts & Credits Tests', () {
    test('Parses special discounts, waivers, and round credit allocations', () {
      final map = {
        'userId': 'usr_vip_test',
        'balanceCredits': 50000,
        'balanceUsd': 15.0,
        'specialDiscountPercent': 50.0,
        'specialDiscountType': 'percent',
        'isDubbingFree': false,
        'discountReason': 'Creator Partnership 50% Off',
        'transactions': [
          {
            'id': 'tx_1',
            'type': 'trial_credit',
            'amountCredits': 50000,
            'amountUsd': 15.0,
            'description': 'Admin Grant: Creator Partnership',
            'timestamp': 1700000000000,
          }
        ],
      };

      final wallet = DubbingWallet.fromMap(map);
      expect(wallet.userId, 'usr_vip_test');
      expect(wallet.balanceCredits, 50000);
      expect(wallet.balanceUsd, 15.0);
      expect(wallet.specialDiscountPercent, 50.0);
      expect(wallet.isDubbingFree, isFalse);
      expect(wallet.hasSpecialDiscount, isTrue);
      expect(wallet.discountDisplayString, '50% Off');
      expect(wallet.displayCreditString, '50000 characters');
      expect(wallet.displayUsdString, '\$15.00');
      expect(wallet.transactions.length, 1);
    });

    test('Correctly identifies 100% Free Waiver in DubbingWallet', () {
      final freeMap = {
        'userId': 'usr_free_test',
        'balanceCredits': 0,
        'balanceUsd': 0.0,
        'specialDiscountPercent': 100.0,
        'specialDiscountType': 'free',
        'isDubbingFree': true,
        'discountReason': 'VIP Lifetime Free Waiver',
      };

      final wallet = DubbingWallet.fromMap(freeMap);
      expect(wallet.isDubbingFree, isTrue);
      expect(wallet.hasSpecialDiscount, isTrue);
      expect(wallet.discountDisplayString, '100% Free Waiver');
    });

    test('Standard wallet has no special discount', () {
      final standardWallet = DubbingWallet(userId: 'usr_standard');
      expect(standardWallet.hasSpecialDiscount, isFalse);
      expect(standardWallet.discountDisplayString, 'Standard Pricing');
    });
  });

  group('AdminDubbingMixin Search & Filtering Tests', () {
    test('Filters users by search query and discount categories', () {
      final controller = Get.put(TestAdminController());

      controller.allDubbingUsers.assignAll([
        {
          'id': 'uid_1',
          'displayName': 'Alice Creator',
          'email': 'alice@truthworld.in',
          'balanceCredits': 25000,
          'balanceUsd': 5.0,
          'specialDiscountPercent': 50.0,
          'specialDiscountType': 'percent',
          'isDubbingFree': false,
        },
        {
          'id': 'uid_2',
          'displayName': 'Bob FreeVIP',
          'email': 'bob@truthworld.in',
          'balanceCredits': 0,
          'balanceUsd': 0.0,
          'specialDiscountPercent': 100.0,
          'specialDiscountType': 'free',
          'isDubbingFree': true,
        },
        {
          'id': 'uid_3',
          'displayName': 'Charlie Standard',
          'email': 'charlie@test.com',
          'balanceCredits': 0,
          'balanceUsd': 0.0,
          'specialDiscountPercent': 0.0,
          'specialDiscountType': 'none',
          'isDubbingFree': false,
        },
      ]);

      // 1. All users
      controller.setDubbingFilterOption('all');
      expect(controller.filteredDubbingUsers.length, 3);

      // 2. Filter: with_discount
      controller.setDubbingFilterOption('with_discount');
      expect(controller.filteredDubbingUsers.length, 2);
      expect(controller.filteredDubbingUsers.map((u) => u['id']), containsAll(['uid_1', 'uid_2']));

      // 3. Filter: free_waiver
      controller.setDubbingFilterOption('free_waiver');
      expect(controller.filteredDubbingUsers.length, 1);
      expect(controller.filteredDubbingUsers.first['id'], 'uid_2');

      // 4. Filter: with_credits
      controller.setDubbingFilterOption('with_credits');
      expect(controller.filteredDubbingUsers.length, 1);
      expect(controller.filteredDubbingUsers.first['id'], 'uid_1');

      // 5. Filter: zero_credits
      controller.setDubbingFilterOption('zero_credits');
      expect(controller.filteredDubbingUsers.length, 2);

      // 6. Search Query
      controller.setDubbingFilterOption('all');
      controller.searchDubbingUsers('Alice');
      expect(controller.filteredDubbingUsers.length, 1);
      expect(controller.filteredDubbingUsers.first['displayName'], 'Alice Creator');

      controller.searchDubbingUsers('charlie@test.com');
      expect(controller.filteredDubbingUsers.length, 1);
      expect(controller.filteredDubbingUsers.first['id'], 'uid_3');
    });
  });

  group('DubbingManagementTab Widget Rendering Tests', () {
    testWidgets('Renders Dubbing Management Tab layout without error', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = Get.put(TestAdminController());
      final sampleUser = {
        'id': 'usr_test_1',
        'displayName': 'Test Dubbing Creator',
        'email': 'creator@truthworld.in',
        'balanceCredits': 10000,
        'balanceUsd': 2.0,
        'specialDiscountPercent': 20.0,
        'specialDiscountType': 'percent',
        'isDubbingFree': false,
      };
      controller.allDubbingUsers.assignAll([sampleUser]);
      controller.filteredDubbingUsers.assignAll([sampleUser]);
      controller.selectedDubbingUser.value = sampleUser;
      controller.selectedDubbingWallet.value = DubbingWallet.fromMap(sampleUser);

      await tester.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 1400,
              height: 900,
              child: DubbingManagementTab(controller: controller),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('User Dubbing Accounts'), findsOneWidget);
      expect(find.text('Test Dubbing Creator'), findsWidgets);
      expect(find.text('Grant Free Dubbing Credits'), findsOneWidget);
      expect(find.text('Special Dubbing Discounts & Free Waiver'), findsOneWidget);
    });
  });
}
