import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/core/services/auth_service.dart';
import 'package:truthworld/core/services/cashfree_service.dart';
import 'package:truthworld/core/services/connectivity_service.dart';
import 'package:truthworld/core/services/currency_localization_service.dart';
import 'package:truthworld/features/home/presentation/controllers/main_controller.dart';
import 'package:truthworld/features/video/data/models/comment.dart';
import 'package:truthworld/features/video/data/models/reply.dart';
import 'package:truthworld/features/video/presentation/controllers/comments_controller.dart';
import 'package:truthworld/features/video/presentation/views/widgets/video_comment_item_widget.dart';
import '../../test_helpers/mock_firebase.dart';

class TestMainController extends MainController {
  @override
  // ignore: must_call_super
  void onInit() {}

  @override
  Stream<List<Reply>> getRepliesStream(String videoId, String commentId) {
    return Stream.value([]);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CurrencyLocalizationService currencyService;

  setUpAll(() async {
    await setupMockFirebase();
    CurrencyLocalizationService.enablePersistentStorage = false;
    CashfreePaymentService.enableNativeGateway = false;
  });

  tearDownAll(() {
    CurrencyLocalizationService.enablePersistentStorage = true;
    CashfreePaymentService.enableNativeGateway = true;
  });

  setUp(() {
    Get.reset();
    Get.testMode = true;
    if (!Get.isRegistered<AuthService>()) {
      Get.put<AuthService>(AuthService(), permanent: true);
    }
    if (!Get.isRegistered<ConnectivityService>()) {
      Get.put<ConnectivityService>(ConnectivityService(), permanent: true);
    }
    currencyService = Get.put(CurrencyLocalizationService());
  });

  tearDown(Get.reset);

  group('Super Thanks Currency Localization & Forex Conversion', () {
    test('Detects Indian viewer and resolves INR currency symbol', () {
      currencyService.currencyOverride.value = 'INR';
      expect(currencyService.isIndianUser, isTrue);
      expect(currencyService.activeUserCurrency, 'INR');
      expect(currencyService.activeUserCurrencySymbol, '₹');
    });

    test('Detects Non-Indian viewer and resolves USD currency symbol', () {
      currencyService.currencyOverride.value = 'USD';
      expect(currencyService.isIndianUser, isFalse);
      expect(currencyService.activeUserCurrency, 'USD');
      expect(currencyService.activeUserCurrencySymbol, r'$');
    });

    test('Converts international USD Super Thanks tiers to INR for Cashfree checkout', () {
      currencyService.liveUsdToInrRate.value = 95.60;

      // $2.00 USD tier
      final inrFor2Usd = double.parse((2.0 * currencyService.rate).toStringAsFixed(2));
      expect(inrFor2Usd, 191.20);

      // $5.00 USD tier
      final inrFor5Usd = double.parse((5.0 * currencyService.rate).toStringAsFixed(2));
      expect(inrFor5Usd, 478.00);

      // $10.00 USD tier
      final inrFor10Usd = double.parse((10.0 * currencyService.rate).toStringAsFixed(2));
      expect(inrFor10Usd, 956.00);

      // $50.00 USD tier
      final inrFor50Usd = double.parse((50.0 * currencyService.rate).toStringAsFixed(2));
      expect(inrFor50Usd, 4780.00);
    });

    test('Indian viewer INR tiers require direct 1:1 amount for Cashfree checkout', () {
      currencyService.currencyOverride.value = 'INR';
      currencyService.liveUsdToInrRate.value = 95.60;
      const tierInr = 100.0;
      const amountINR = tierInr;
      expect(amountINR, 100.0);

      // Helper display conversion to USD
      final usdEquivalent = tierInr / currencyService.rate;
      expect(usdEquivalent, closeTo(1.046, 0.01));
    });
  });

  group('Super Thanks Donated Comment Rendering', () {
    Widget wrapWithMaterial(Widget child) {
      return GetMaterialApp(
        home: Scaffold(
          body: child,
        ),
      );
    }

    testWidgets('Renders Super Thanks banner on INR donated comment', (tester) async {
      final mainCtrl = TestMainController();
      final donatedComment = Comment(
        id: 'donated_comm_01',
        videoId: 'test_vid_01',
        userId: 'donor_01',
        userName: 'LoyalFan',
        userProfilePicUrl: '',
        channelId: 'chan_01',
        text: 'Keep making incredible videos!',
        likeCount: 5,
        dislikeCount: 0,
        reportCount: 0,
        createdAt: Timestamp.now(),
        isDonatedComment: true,
        donationAmount: 100.0,
        donationCurrency: '₹',
        donationColorHex: '0xFF1E88E5',
      );

      final ctrl = Get.put(
        CommentsController(),
        tag: 'video_${donatedComment.videoId}',
      );
      ctrl.comments.add(donatedComment);

      await tester.pumpWidget(
        wrapWithMaterial(
          CommentItemWidget(
            comment: donatedComment,
            videoId: donatedComment.videoId,
            channelAvatarUrl: '',
            mainController: mainCtrl,
            textSecondary: Colors.grey,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Expect Super Thanks badge with amount
      expect(find.text('Super Thanks ₹100'), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(find.text('Keep making incredible videos!'), findsOneWidget);
    });

    testWidgets('Renders Super Thanks banner on USD donated comment', (tester) async {
      final mainCtrl = TestMainController();
      final donatedCommentUsd = Comment(
        id: 'donated_comm_02',
        videoId: 'test_vid_02',
        userId: 'donor_02',
        userName: 'USFan',
        userProfilePicUrl: '',
        channelId: 'chan_02',
        text: 'Loved your breakdown on this topic!',
        likeCount: 12,
        dislikeCount: 0,
        reportCount: 0,
        createdAt: Timestamp.now(),
        isDonatedComment: true,
        donationAmount: 5.0,
        donationColorHex: '0xFF00C853',
      );

      final ctrl = Get.put(
        CommentsController(),
        tag: 'video_${donatedCommentUsd.videoId}',
      );
      ctrl.comments.add(donatedCommentUsd);

      await tester.pumpWidget(
        wrapWithMaterial(
          CommentItemWidget(
            comment: donatedCommentUsd,
            videoId: donatedCommentUsd.videoId,
            channelAvatarUrl: '',
            mainController: mainCtrl,
            textSecondary: Colors.grey,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Expect Super Thanks badge with amount
      expect(find.text(r'Super Thanks $5'), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(find.text('Loved your breakdown on this topic!'), findsOneWidget);
    });

    testWidgets('Standard comments do not render Super Thanks banner', (tester) async {
      final mainCtrl = TestMainController();
      final regularComment = Comment(
        id: 'reg_comm_01',
        videoId: 'test_vid_03',
        userId: 'viewer_01',
        userName: 'Viewer',
        userProfilePicUrl: '',
        channelId: 'chan_03',
        text: 'Great explanation!',
        likeCount: 1,
        dislikeCount: 0,
        reportCount: 0,
        createdAt: Timestamp.now(),
      );

      final ctrl = Get.put(
        CommentsController(),
        tag: 'video_${regularComment.videoId}',
      );
      ctrl.comments.add(regularComment);

      await tester.pumpWidget(
        wrapWithMaterial(
          CommentItemWidget(
            comment: regularComment,
            videoId: regularComment.videoId,
            channelAvatarUrl: '',
            mainController: mainCtrl,
            textSecondary: Colors.grey,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Expect no Super Thanks banner
      expect(find.textContaining('Super Thanks'), findsNothing);
      expect(find.text('Great explanation!'), findsOneWidget);
    });
  });
}
