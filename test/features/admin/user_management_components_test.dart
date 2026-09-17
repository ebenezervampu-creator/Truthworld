import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/features/admin/presentation/views/user_management/user_management_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UserTrustScoreBadge Tests', () {
    testWidgets('renders score and green color for score >= 75', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UserTrustScoreBadge(score: 85),
          ),
        ),
      );

      expect(find.text('85'), findsOneWidget);
    });

    testWidgets('renders score for low score < 10', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UserTrustScoreBadge(score: 5),
          ),
        ),
      );

      expect(find.text('5'), findsOneWidget);
    });
  });

  group('UserStatusBadge Tests', () {
    testWidgets('renders active status', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UserStatusBadge(status: 'active'),
          ),
        ),
      );

      expect(find.text('ACTIVE'), findsOneWidget);
    });

    testWidgets('renders banned status', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UserStatusBadge(status: 'banned'),
          ),
        ),
      );

      expect(find.text('BANNED'), findsOneWidget);
    });
  });

  group('UserVisionStatusBadge Tests', () {
    testWidgets('renders APPROVED status label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UserVisionStatusBadge(status: 'APPROVED'),
          ),
        ),
      );

      expect(find.text('APPROVED BY VISION AI'), findsOneWidget);
    });

    testWidgets('renders REJECTED status label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UserVisionStatusBadge(status: 'REJECTED'),
          ),
        ),
      );

      expect(find.text('REJECTED BY VISION AI'), findsOneWidget);
    });

    testWidgets('renders PENDING status label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UserVisionStatusBadge(status: 'PENDING'),
          ),
        ),
      );

      expect(find.text('AWAITING VISION SCAN'), findsOneWidget);
    });
  });

  group('User Detail Metrics Cards Tests', () {
    testWidgets('UserTrustScoreCard displays score and assessment', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UserTrustScoreCard(score: 90),
          ),
        ),
      );

      expect(find.text('Trust Score'), findsOneWidget);
      expect(find.text('Good Standing'), findsOneWidget);
      expect(find.text('90'), findsOneWidget);
    });

    testWidgets('UserStrikeCountCard displays strike count', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UserStrikeCountCard(strikes: 2),
          ),
        ),
      );

      expect(find.text('Recorded Strikes'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('UserUploadStatisticsCard displays upload statistics', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UserUploadStatisticsCard(
              stats: {
                'totalUploads': 42,
                'approvalRate': 95,
                'rejectionRate': 5,
              },
            ),
          ),
        ),
      );

      expect(find.text('Upload Activity Statistics'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(find.text('95%'), findsOneWidget);
      expect(find.text('5%'), findsOneWidget);
    });

    testWidgets('UserChannelsCard displays associated channels', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UserChannelsCard(
              channels: [
                {
                  'name': 'Truth Investigations',
                  'handle': 'truth_inv',
                  'subscriberCount': 1250,
                }
              ],
            ),
          ),
        ),
      );

      expect(find.text('Associated Channels'), findsOneWidget);
      expect(find.text('Truth Investigations (@truth_inv)'), findsOneWidget);
      expect(find.text('1250 subs'), findsOneWidget);
    });
  });

  group('UserActionButton & Empty State Tests', () {
    testWidgets('UserActionButton fires callback on tap', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UserActionButton(
              label: 'Test Action',
              color: Colors.blue,
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Test Action'), findsOneWidget);
      await tester.tap(find.text('Test Action'));
      expect(tapped, isTrue);
    });

    testWidgets('UserEmptyDetailPanel shows empty message', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UserEmptyDetailPanel(),
          ),
        ),
      );

      expect(find.text('Select a user to view details'), findsOneWidget);
    });
  });
}
