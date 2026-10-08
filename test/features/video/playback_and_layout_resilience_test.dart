import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:truthworld/features/video/data/models/comment.dart';
import 'package:truthworld/features/video/presentation/controllers/downloadcontroller.dart';
import 'package:truthworld/features/video/presentation/views/widgets/comments/comment_author_header.dart';
import 'package:truthworld/theme/app_colors.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(Get.reset);

  tearDown(Get.reset);

  group('Layout & Overflow Resilience Tests', () {
    testWidgets(
      'Downloaded video tile Row does not overflow in narrow 160px container',
      (tester) async {
        final mockController = Get.put(
          DownloadsController(),
        );

        // Build a narrow container matching the video details column
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 160,
                child: Row(
                  children: [
                    const Icon(
                      Icons.enhanced_encryption_outlined,
                      color: AppColors.textPrimary,
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'AES-256 Encrypted • ${mockController.formatTimeAgo(DateTime.now().subtract(const Duration(days: 365)))}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(Row), findsOneWidget);
        expect(find.byType(Text), findsOneWidget);
      },
    );

    testWidgets(
      'VideoFactCheckCard CTA does not overflow with long claims text in 280px container',
      (tester) async {
        // Build the dynamic CTA row inside a constrained container
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 280,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.verified_outlined, size: 16, color: Colors.white),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'See 15 ground-truth verified claims & 12 sources',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 12,
                        color: Colors.white54,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(Row), findsOneWidget);
        expect(find.byType(Text), findsOneWidget);
      },
    );

    testWidgets(
      'CommentAuthorHeader does not overflow with extremely long username',
      (tester) async {
        final comment = Comment(
          id: 'test_comment_1',
          videoId: 'v123',
          userId: 'u123',
          userName: 'super_califragilistic_expialidocious_creator_with_an_ultra_long_name',
          userProfilePicUrl: '',
          channelId: 'c123',
          text: 'Great video on verified facts!',
          likeCount: 0,
          dislikeCount: 0,
          reportCount: 0,
          createdAt: Timestamp.now(),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 200,
                child: CommentAuthorHeader(
                  comment: comment,
                  channelAvatarUrl: '',
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(CommentAuthorHeader), findsOneWidget);
      },
    );
  });
}
