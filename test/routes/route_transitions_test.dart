import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truthworld/routes/app_pages.dart';
import 'package:truthworld/routes/app_routes.dart';
import 'package:truthworld/routes/app_transitions.dart';

void main() {
  group('Route Transitions Architecture Test Suite (All 4 Apps)', () {
    test('Every route in AppPages.routes defines an explicit transition, duration, and curve', () {
      final routes = AppPages.routes;
      expect(routes.isNotEmpty, isTrue);

      for (final page in routes) {
        expect(
          page.transition,
          isNotNull,
          reason: 'Route ${page.name} must specify an explicit transition',
        );
        expect(
          page.transitionDuration,
          isNotNull,
          reason: 'Route ${page.name} must specify an explicit transitionDuration',
        );
        expect(
          page.curve,
          isNotNull,
          reason: 'Route ${page.name} must specify an explicit animation curve',
        );
      }
    });

    test('Video playback routes use mediaZoom transition', () {
      final videoRoutes = AppPages.routes.where(
        (p) => [
          AppRoutes.videoscreen,
          AppRoutes.watch,
          AppRoutes.watchWithId,
          AppRoutes.videoShortLink,
          AppRoutes.videoAlias,
        ].contains(p.name),
      );

      expect(videoRoutes.length, equals(5));
      for (final page in videoRoutes) {
        expect(page.transition, equals(AppTransitions.mediaZoom));
        expect(page.transitionDuration, equals(AppTransitions.mediaZoomDuration));
        expect(page.curve, equals(AppTransitions.mediaZoomCurve));
      }
    });

    test('Shorts and Clips immersive feeds use verticalFeed transition', () {
      final verticalRoutes = AppPages.routes.where(
        (p) => [AppRoutes.shorts, AppRoutes.clips].contains(p.name),
      );

      expect(verticalRoutes.length, equals(2));
      for (final page in verticalRoutes) {
        expect(page.transition, equals(AppTransitions.verticalFeed));
        expect(page.transitionDuration, equals(AppTransitions.verticalFeedDuration));
        expect(page.curve, equals(AppTransitions.verticalFeedCurve));
      }
    });

    test('Creation, upload, and action modal routes use modal transition', () {
      final modalRoutes = AppPages.routes.where(
        (p) => [
          AppRoutes.upload,
          AppRoutes.uploadVideo,
          AppRoutes.uploadSubtitles,
          AppRoutes.uploadDubbing,
          AppRoutes.uploadCommunity,
          AppRoutes.createPost,
          AppRoutes.createPlaylist,
          AppRoutes.createTopic,
          AppRoutes.askAi,
          AppRoutes.aiChat,
          AppRoutes.adminLogin,
          AppRoutes.studioCreateMembershipTier,
          AppRoutes.feedback,
        ].contains(p.name),
      );

      for (final page in modalRoutes) {
        expect(
          page.transition,
          equals(AppTransitions.modal),
          reason: 'Modal route ${page.name} should use modal transition',
        );
        expect(page.transitionDuration, equals(AppTransitions.modalDuration));
        expect(page.curve, equals(AppTransitions.modalCurve));
      }
    });

    test('Primary shell and peer tabs across all 4 apps use peer fade-through transition', () {
      final peerRoutes = AppPages.routes.where(
        (p) => [
          AppRoutes.root,
          AppRoutes.home,
          AppRoutes.trending,
          AppRoutes.library,
          AppRoutes.studio,
          AppRoutes.dashboard,
          AppRoutes.adminDashboard,
          AppRoutes.advertiser,
        ].contains(p.name),
      );

      for (final page in peerRoutes) {
        expect(
          page.transition,
          equals(AppTransitions.peer),
          reason: 'Peer route ${page.name} should use peer transition',
        );
        expect(page.transitionDuration, equals(AppTransitions.peerDuration));
        expect(page.curve, equals(AppTransitions.peerCurve));
      }
    });

    test('Master-to-detail and hierarchical deep dive routes use hierarchical transition', () {
      final hierarchicalRoutes = AppPages.routes.where(
        (p) => [
          AppRoutes.channelDetails,
          AppRoutes.channelWithId,
          AppRoutes.settings,
          AppRoutes.editProfile,
          AppRoutes.playlistDetail,
          AppRoutes.history,
          AppRoutes.claimDetail,
          AppRoutes.analytics,
          AppRoutes.privacy,
          AppRoutes.terms,
        ].contains(p.name),
      );

      for (final page in hierarchicalRoutes) {
        expect(
          page.transition,
          equals(AppTransitions.hierarchical),
          reason: 'Hierarchical route ${page.name} should use hierarchical transition',
        );
        expect(page.transitionDuration, equals(AppTransitions.hierarchicalDuration));
        expect(page.curve, equals(AppTransitions.hierarchicalCurve));
      }
    });
  });
}
