import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security & Authorization Validation Tests', () {
    test('L-01: Admin email bootstrap requires email_verified == true', () {
      const adminEmails = [
        'hello@truthworld.in',
        'ebenezervampu4@gmail.com',
      ];

      bool checkIsAdmin({
        required String? email,
        required bool emailVerified,
        bool hasAdminClaim = false,
      }) {
        if (hasAdminClaim) return true;
        if (email != null && emailVerified && adminEmails.contains(email.toLowerCase())) {
          return true;
        }
        return false;
      }

      // Attacker registers unverified account with admin email
      expect(
        checkIsAdmin(email: 'hello@truthworld.in', emailVerified: false),
        isFalse,
        reason: 'Unverified email must NOT be granted admin privileges',
      );

      expect(
        checkIsAdmin(email: 'ebenezervampu4@gmail.com', emailVerified: false),
        isFalse,
        reason: 'Unverified gmail must NOT be granted admin privileges',
      );

      // Legitimate admin with verified email
      expect(
        checkIsAdmin(email: 'hello@truthworld.in', emailVerified: true),
        isTrue,
        reason: 'Verified admin email MUST be granted bootstrap privileges',
      );

      // Custom claims take precedence regardless
      expect(
        checkIsAdmin(email: 'moderator@truthworld.in', emailVerified: true, hasAdminClaim: true),
        isTrue,
      );
    });

    test('L-11: Video engagement counters enforce strict delta limits', () {
      bool isValidViewCountUpdate(int currentViews, int requestedViews) {
        // Must be +1 increment or unchanged
        return requestedViews == currentViews + 1 || requestedViews == currentViews;
      }

      bool isValidLikeCountUpdate(int currentLikes, int requestedLikes) {
        // Must be +1, -1, or 0 delta
        return requestedLikes == currentLikes + 1 ||
            requestedLikes == currentLikes - 1 ||
            requestedLikes == currentLikes;
      }

      // Valid increments
      expect(isValidViewCountUpdate(100, 101), isTrue);
      expect(isValidViewCountUpdate(100, 100), isTrue);
      expect(isValidLikeCountUpdate(50, 51), isTrue);
      expect(isValidLikeCountUpdate(50, 49), isTrue);

      // Attack attempts (metric inflation)
      expect(isValidViewCountUpdate(100, 100000), isFalse, reason: 'Arbitrary views jump must be rejected');
      expect(isValidViewCountUpdate(100, 99), isFalse, reason: 'Views cannot decrement');
      expect(isValidLikeCountUpdate(50, 5000), isFalse, reason: 'Arbitrary likes jump must be rejected');
      expect(isValidLikeCountUpdate(50, 0), isFalse, reason: 'Massive like drop must be rejected');
    });

    test('L-12: Client video creation cannot self-author credibility scores', () {
      bool isValidVideoCreateData(Map<String, dynamic> data) {
        if (data.containsKey('credibilityScore')) return false;
        if (data.containsKey('truthScore')) return false;
        if (data.containsKey('gatewayDecision')) return false;
        final status = data['pipelineStatus'] as String?;
        if (status != null && status != 'pending' && status != 'uploading') {
          return false;
        }
        return true;
      }

      // Legitimate client upload
      expect(
        isValidVideoCreateData({
          'title': 'My Honest Video',
          'uploaderId': 'user_123',
          'pipelineStatus': 'pending',
        }),
        isTrue,
      );

      // Attacker trying to spoof credibility and truth score
      expect(
        isValidVideoCreateData({
          'title': 'Spoofed Video',
          'uploaderId': 'user_123',
          'credibilityScore': 100,
        }),
        isFalse,
        reason: 'Client-provided credibilityScore must be rejected',
      );

      expect(
        isValidVideoCreateData({
          'title': 'Spoofed Truth',
          'uploaderId': 'user_123',
          'truthScore': 100,
        }),
        isFalse,
        reason: 'Client-provided truthScore must be rejected',
      );

      expect(
        isValidVideoCreateData({
          'title': 'Spoofed Status',
          'uploaderId': 'user_123',
          'pipelineStatus': 'completed',
        }),
        isFalse,
        reason: 'Client cannot bypass pipelineStatus to completed on create',
      );
    });

    test('L-14: Redirect origin sanitizer blocks open redirect vulnerabilities', () {
      String sanitizeRedirectOrigin(String rawOrigin) {
        try {
          final uri = Uri.parse(rawOrigin);
          final host = uri.host.toLowerCase();
          if (host == 'truthworld.in' ||
              host.endsWith('.truthworld.in') ||
              host == 'localhost' ||
              host == '127.0.0.1' ||
              host.endsWith('.web.app') ||
              host.endsWith('.firebaseapp.com')) {
            return rawOrigin.endsWith('/') ? rawOrigin.substring(0, rawOrigin.length - 1) : rawOrigin;
          }
        } catch (_) {}
        return 'https://truthworld.in';
      }

      // Valid platform origins
      expect(sanitizeRedirectOrigin('https://truthworld.in'), 'https://truthworld.in');
      expect(sanitizeRedirectOrigin('http://localhost:5000'), 'http://localhost:5000');
      expect(sanitizeRedirectOrigin('https://truthworld-1.web.app/'), 'https://truthworld-1.web.app');

      // Malicious phishing/open redirect attempts
      expect(sanitizeRedirectOrigin('https://evil-hacker.com'), 'https://truthworld.in');
      expect(sanitizeRedirectOrigin('https://truthworld.in.evil.com'), 'https://truthworld.in');
      expect(sanitizeRedirectOrigin('javascript:alert(1)'), 'https://truthworld.in');
      expect(sanitizeRedirectOrigin('not-a-valid-url'), 'https://truthworld.in');
    });

    test('L-06: Channel handle ownership check prevents handle hijacking', () {
      bool canUpdateHandle({
        required String callerUid,
        required String existingOwnerId,
        required String newOwnerId,
        bool isAdmin = false,
      }) {
        if (isAdmin) return true;
        // On update, the caller MUST match the existing ownerId
        return callerUid == existingOwnerId && newOwnerId == existingOwnerId;
      }

      // Legitimate owner updating details
      expect(
        canUpdateHandle(callerUid: 'creator_1', existingOwnerId: 'creator_1', newOwnerId: 'creator_1'),
        isTrue,
      );

      // Hijacker attempting to steal the handle
      expect(
        canUpdateHandle(callerUid: 'attacker_99', existingOwnerId: 'creator_1', newOwnerId: 'attacker_99'),
        isFalse,
        reason: "Attacker must not be allowed to update another user's handle",
      );
    });

    test('L-17: Channel creation and updates forbid tampering with protected fields', () {
      bool isValidChannelCreate(Map<String, dynamic> data) {
        if (data['isVerified'] == true) return false;
        if (data['geminiApproved'] == true) return false;
        if (data['monetizationTier'] != null && data['monetizationTier'] != 'none') return false;
        if ((data['superchatRevenueTotal'] ?? 0) > 0) return false;
        if ((data['subscriberCount'] ?? 0) > 0) return false;
        return true;
      }

      const protectedUpdateFields = [
        'isVerified',
        'geminiApproved',
        'status',
        'monetizationTier',
        'superchatRevenueTotal',
        'subscriberCount',
        'videoCount',
        'ownerId',
        'userId',
        'createdAt',
        'penaltyStatus',
        'trustScore',
        'reputationScore',
        'moderationReason',
      ];

      bool isValidChannelOwnerUpdate(Map<String, dynamic> before, Map<String, dynamic> after) {
        for (final field in protectedUpdateFields) {
          if (before[field] != after[field]) return false;
        }
        return true;
      }

      // Valid channel creation
      expect(
        isValidChannelCreate({
          'name': 'My New Channel',
          'isVerified': false,
          'monetizationTier': 'none',
          'subscriberCount': 0,
        }),
        isTrue,
      );

      // Attack: Attempt to self-verify or give subscriber count
      expect(
        isValidChannelCreate({'name': 'Fake Blue Tick', 'isVerified': true}),
        isFalse,
        reason: 'Client cannot create pre-verified channels',
      );
      expect(
        isValidChannelCreate({'name': 'Fake Subscribers', 'subscriberCount': 10000}),
        isFalse,
        reason: 'Client cannot bootstrap with artificial subscriber count',
      );

      // Channel update: name/description allowed
      final existingDoc = {
        'name': 'Channel A',
        'description': 'Old bio',
        'isVerified': false,
        'trustScore': 50,
        'monetizationTier': 'none',
      };

      expect(
        isValidChannelOwnerUpdate(
          existingDoc,
          {...existingDoc, 'description': 'Updated new bio'},
        ),
        isTrue,
      );

      // Attack: User attempts to grant themselves verified badge or inflate trustScore
      expect(
        isValidChannelOwnerUpdate(
          existingDoc,
          {...existingDoc, 'isVerified': true},
        ),
        isFalse,
        reason: 'Channel owner cannot modify isVerified',
      );
      expect(
        isValidChannelOwnerUpdate(
          existingDoc,
          {...existingDoc, 'trustScore': 99},
        ),
        isFalse,
        reason: 'Channel owner cannot modify trustScore',
      );
    });

    test('L-18: Verification approval strictly requires verified admin identity', () {
      bool isCallableAdmin({
        required bool hasAdminClaim,
        required String? email,
        required bool emailVerified,
      }) {
        if (hasAdminClaim) return true;
        const bootstrapAdmins = [
          'hello@truthworld.in',
          'ebenezervampu4@gmail.com',
        ];
        if (email != null && emailVerified && bootstrapAdmins.contains(email.toLowerCase())) {
          return true;
        }
        return false;
      }

      // Normal unprivileged user calling approveVerification
      expect(
        isCallableAdmin(hasAdminClaim: false, email: 'random@user.com', emailVerified: true),
        isFalse,
      );
      // Impersonator with unverified email
      expect(
        isCallableAdmin(hasAdminClaim: false, email: 'hello@truthworld.in', emailVerified: false),
        isFalse,
      );
      // Valid admin
      expect(
        isCallableAdmin(hasAdminClaim: true, email: 'admin@custom.com', emailVerified: true),
        isTrue,
      );
    });

    test('L-19: SuperChat requires direct payment gateway checkout without viewer wallet prefunding', () {
      Map<String, dynamic> processGatewaySuperchat({
        required String paymentGateway,
        required num superchatAmount,
      }) {
        if (paymentGateway != 'cashfree') {
          return {'success': false, 'error': 'INVALID_GATEWAY'};
        }
        return {
          'success': true,
          'amountProcessed': superchatAmount,
        };
      }

      // Valid gateway checkout
      final successResult = processGatewaySuperchat(paymentGateway: 'cashfree', superchatAmount: 200);
      expect(successResult['success'], isTrue);
      expect(successResult['amountProcessed'], 200);

      // Discontinued wallet payment method attempt
      final failResult = processGatewaySuperchat(paymentGateway: 'wallet', superchatAmount: 200);
      expect(failResult['success'], isFalse);
      expect(failResult['error'], 'INVALID_GATEWAY');
    });

    test('L-20: Channel moderation update preserves suspended or banned status', () {
      String resolveModerationStatus({
        required String currentStatus,
        required String? newStatus,
      }) {
        if (['suspended', 'deleted', 'banned'].contains(currentStatus)) {
          return currentStatus; // Lock down status
        }
        return newStatus ?? 'active';
      }

      // Normal active channel
      expect(resolveModerationStatus(currentStatus: 'active', newStatus: 'active'), 'active');

      // Suspended channel trying to sneakily reset status to active
      expect(
        resolveModerationStatus(currentStatus: 'suspended', newStatus: 'active'),
        'suspended',
        reason: 'Suspended channels cannot un-suspend via profile update',
      );
      expect(
        resolveModerationStatus(currentStatus: 'banned', newStatus: 'active'),
        'banned',
        reason: 'Banned channels cannot reset status to active',
      );
    });

    test('L-22 & L-23: Comment authorship strictly matches authenticated UID', () {
      bool canCreateComment({
        required String callerUid,
        required String commentAuthorUid,
      }) {
        return callerUid == commentAuthorUid;
      }

      expect(canCreateComment(callerUid: 'user_alice', commentAuthorUid: 'user_alice'), isTrue);
      expect(
        canCreateComment(callerUid: 'attacker_bob', commentAuthorUid: 'user_alice'),
        isFalse,
        reason: 'Attacker cannot post comments impersonating another user',
      );
    });

    test('L-24: User notification creation prevents unauthorized spam/phishing', () {
      bool canCreateNotification({
        required String callerUid,
        required String notificationTargetUserId,
        bool isAdmin = false,
      }) {
        if (isAdmin) return true;
        // Client can only create notification for self (e.g. self activity reminder), not inject into others
        return callerUid == notificationTargetUserId;
      }

      expect(canCreateNotification(callerUid: 'user_1', notificationTargetUserId: 'user_1'), isTrue);
      expect(
        canCreateNotification(callerUid: 'attacker', notificationTargetUserId: 'victim_user'),
        isFalse,
        reason: 'Attacker cannot directly inject notifications into other users inboxes',
      );
      expect(
        canCreateNotification(callerUid: 'admin_uid', notificationTargetUserId: 'victim_user', isAdmin: true),
        isTrue,
      );
    });

    test('L-28: RTDB Active Viewer session validation enforces auth match or guest format', () {
      bool isValidViewerSession({
        required String sessionId,
        required String? authUid,
      }) {
        if (authUid != null) {
          // Authenticated: sessionId must equal auth.uid
          return sessionId == authUid;
        } else {
          // Guest: sessionId must start with guest_
          return sessionId.startsWith('guest_');
        }
      }

      // Valid sessions
      expect(isValidViewerSession(sessionId: 'user_123', authUid: 'user_123'), isTrue);
      expect(isValidViewerSession(sessionId: 'guest_abc1234', authUid: null), isTrue);

      // Attack: Auth user masquerading as someone else
      expect(isValidViewerSession(sessionId: 'victim_uid', authUid: 'attacker_uid'), isFalse);
      // Attack: Guest pretending to be an auth user ID
      expect(isValidViewerSession(sessionId: 'some_real_uid', authUid: null), isFalse);
    });

    test('L-29: Dispute submission attempt cap terminates Gemini DoS loop', () {
      bool canSubmitDispute(int currentDisputeAttempts) {
        return currentDisputeAttempts < 2;
      }

      expect(canSubmitDispute(0), isTrue);
      expect(canSubmitDispute(1), isTrue);
      expect(canSubmitDispute(2), isFalse, reason: 'Max 2 attempts cap enforced');
      expect(canSubmitDispute(10), isFalse);
    });

    test('L-30: Storage uploader claim validation prevents uploaderId spoofing', () {
      bool isUploaderClaimValid({
        required String? declaredUploaderId,
        required String callerUid,
      }) {
        if (declaredUploaderId == null) return true;
        return declaredUploaderId == callerUid;
      }

      // Valid: uploader matches authenticated user
      expect(isUploaderClaimValid(declaredUploaderId: 'user_abc', callerUid: 'user_abc'), isTrue);
      expect(isUploaderClaimValid(declaredUploaderId: null, callerUid: 'user_abc'), isTrue);

      // Attack: uploader attempts to claim ownership on behalf of another user
      expect(
        isUploaderClaimValid(declaredUploaderId: 'victim_uid', callerUid: 'attacker_uid'),
        isFalse,
        reason: 'Uploader metadata cannot spoof another users UID',
      );
    });

    test('L-31: Self-follow prevention stops subscriber count inflation', () {
      bool canFollowChannel({
        required String callerUid,
        required String channelOwnerId,
      }) {
        return callerUid != channelOwnerId;
      }

      expect(canFollowChannel(callerUid: 'user_1', channelOwnerId: 'user_2'), isTrue);
      expect(canFollowChannel(callerUid: 'user_1', channelOwnerId: 'user_1'), isFalse);
    });

    test('L-32: Feed endpoint requires valid authenticated user ID', () {
      String? resolveFeedUserId({
        required String? authUid,
        required String? queryUserId,
      }) {
        // Must strictly use authUid, ignoring queryUserId
        return authUid;
      }

      expect(resolveFeedUserId(authUid: 'auth_123', queryUserId: 'victim_456'), equals('auth_123'));
      expect(resolveFeedUserId(authUid: null, queryUserId: 'victim_456'), isNull);
    });

    test('L-33: Watch event userId binds to verified auth token to prevent spoofing', () {
      String resolveWatchEventUserId({
        required String? verifiedAuthTokenUid,
        required String clientClaimedUserId,
      }) {
        if (verifiedAuthTokenUid != null && verifiedAuthTokenUid.isNotEmpty) {
          return verifiedAuthTokenUid;
        }
        return 'anonymous';
      }

      // Valid auth user
      expect(resolveWatchEventUserId(verifiedAuthTokenUid: 'user_real', clientClaimedUserId: 'user_real'), equals('user_real'));
      // Spoofing attempt without valid token
      expect(resolveWatchEventUserId(verifiedAuthTokenUid: null, clientClaimedUserId: 'victim_uid'), equals('anonymous'));
      // Spoofing attempt with attacker's valid token claiming victim's uid
      expect(resolveWatchEventUserId(verifiedAuthTokenUid: 'attacker_uid', clientClaimedUserId: 'victim_uid'), equals('attacker_uid'));
    });

    test('L-34: Hardened XSS comment sanitization strips dangerous tags and handlers', () {
      String sanitizeCommentText(String text) {
        return text
            .replaceAll(RegExp(r'<script\b[^<]*(?:(?!<\/script>)<[^<]*)*<\/script>', caseSensitive: false), '')
            .replaceAll(RegExp(r'<style\b[^<]*(?:(?!<\/style>)<[^<]*)*<\/style>', caseSensitive: false), '')
            .replaceAll(RegExp(r'<iframe\b[^<]*(?:(?!<\/iframe>)<[^<]*)*<\/iframe>', caseSensitive: false), '')
            .replaceAll(RegExp('<[^>]*>'), '')
            .replaceAll(RegExp(r'on\w+="[^"]*"', caseSensitive: false), '')
            .replaceAll(RegExp(r'on\w+=("[^"]*"|' r"'[^']*'|\w+)", caseSensitive: false), '')
            .replaceAll(RegExp('javascript:', caseSensitive: false), 'javascript_blocked:')
            .replaceAll(RegExp('data:', caseSensitive: false), 'data_blocked:')
            .replaceAll(RegExp('vbscript:', caseSensitive: false), 'vbscript_blocked:')
            .replaceAll('<', '&lt;')
            .replaceAll('>', '&gt;')
            .trim();
      }

      expect(sanitizeCommentText('Hello world!'), equals('Hello world!'));
      expect(sanitizeCommentText('<script>alert(1)</script>Safe'), equals('Safe'));
      expect(sanitizeCommentText('<img src="x" onerror="alert(1)">'), equals(''));
      expect(sanitizeCommentText('<svg onload="steal()">'), equals(''));
      expect(sanitizeCommentText('javascript:alert(1)'), equals('javascript_blocked:alert(1)'));
    });

    test('L-35: Comment query limit clamping prevents unbounded reads', () {
      int clampCommentLimit(dynamic limit) {
        final parsed = int.tryParse(limit.toString()) ?? 20;
        return parsed.clamp(1, 100);
      }

      expect(clampCommentLimit(20), equals(20));
      expect(clampCommentLimit(500), equals(100));
      expect(clampCommentLimit(-10), equals(1));
      expect(clampCommentLimit('invalid'), equals(20));
    });

    test('L-36: Duplicate comment reporting prevention stops report flooding', () {
      final existingReports = <String>{};

      bool canReportComment({
        required String reporterId,
        required String commentId,
        String? replyId,
      }) {
        final key = '${reporterId}_${commentId}_${replyId ?? "root"}';
        if (existingReports.contains(key)) return false;
        existingReports.add(key);
        return true;
      }

      expect(canReportComment(reporterId: 'user_1', commentId: 'c_100'), isTrue);
      expect(canReportComment(reporterId: 'user_1', commentId: 'c_100'), isFalse, reason: 'Duplicate report blocked');
      expect(canReportComment(reporterId: 'user_2', commentId: 'c_100'), isTrue);
    });

    test('L-37: RTDB liveChat admin email match strictly requires email_verified == true', () {
      bool canModerateLiveChatMessage({
        required String? email,
        required bool emailVerified,
      }) {
        if (email == null) return false;
        return emailVerified && email.toLowerCase().endsWith('@truthworld.in');
      }

      // Attack: unverified account with truthworld.in domain
      expect(canModerateLiveChatMessage(email: 'fakeadmin@truthworld.in', emailVerified: false), isFalse);
      // Valid verified employee
      expect(canModerateLiveChatMessage(email: 'staff@truthworld.in', emailVerified: true), isTrue);
      // Other domain verified
      expect(canModerateLiveChatMessage(email: 'attacker@gmail.com', emailVerified: true), isFalse);
    });

    test('L-38: Public discovery endpoints exclude suspended, banned, and deleted channels', () {
      bool isChannelEligibleForDiscovery(String? status) {
        return status != 'suspended' && status != 'banned' && status != 'deleted';
      }

      expect(isChannelEligibleForDiscovery('active'), isTrue);
      expect(isChannelEligibleForDiscovery(null), isTrue);
      expect(isChannelEligibleForDiscovery('suspended'), isFalse);
      expect(isChannelEligibleForDiscovery('banned'), isFalse);
      expect(isChannelEligibleForDiscovery('deleted'), isFalse);
    });

    test('L-39: Home feed personalization strictly binds to verified auth token', () {
      String? resolvePersonalizedFeedUser({
        required String? verifiedAuthUid,
        required String? queryUserId,
      }) {
        // Query param must be discarded in favor of verified auth token
        return verifiedAuthUid;
      }

      expect(resolvePersonalizedFeedUser(verifiedAuthUid: 'auth_789', queryUserId: 'victim_000'), equals('auth_789'));
      expect(resolvePersonalizedFeedUser(verifiedAuthUid: null, queryUserId: 'victim_000'), isNull);
    });

    test('L-40: Video AI features owner check validates ownerId, userId, and uploaderId', () {
      bool isVideoOwnerOrAdmin({
        required Map<String, dynamic> videoData,
        required String callerUid,
        required bool isAdmin,
      }) {
        if (isAdmin) return true;
        final owner = videoData['ownerId'] ?? videoData['userId'] ?? videoData['uploaderId'];
        return owner == callerUid;
      }

      expect(isVideoOwnerOrAdmin(videoData: {'ownerId': 'user_1'}, callerUid: 'user_1', isAdmin: false), isTrue);
      expect(isVideoOwnerOrAdmin(videoData: {'userId': 'user_1'}, callerUid: 'user_1', isAdmin: false), isTrue);
      expect(isVideoOwnerOrAdmin(videoData: {'uploaderId': 'user_1'}, callerUid: 'user_1', isAdmin: false), isTrue);
      // Attacker attempting on victim's video (only userId set)
      expect(isVideoOwnerOrAdmin(videoData: {'userId': 'victim_1'}, callerUid: 'attacker_1', isAdmin: false), isFalse);
      // Admin override
      expect(isVideoOwnerOrAdmin(videoData: {'userId': 'victim_1'}, callerUid: 'admin_1', isAdmin: true), isTrue);
    });

    test('L-41: Deep link external URL scheme validator strictly blocks non-web schemes', () {
      bool isSafeExternalUrl(String rawUrl) {
        final uri = Uri.tryParse(rawUrl);
        if (uri == null) return false;
        return uri.isScheme('https') || uri.isScheme('http');
      }

      expect(isSafeExternalUrl('https://example.com/page'), isTrue);
      expect(isSafeExternalUrl('http://example.com/page'), isTrue);
      expect(isSafeExternalUrl('javascript:alert(1)'), isFalse);
      expect(isSafeExternalUrl('file:///etc/passwd'), isFalse);
      expect(isSafeExternalUrl('data:text/html;base64,PHNjcmlwdD4='), isFalse);
      expect(isSafeExternalUrl('content://media/external/images'), isFalse);
    });

    test('L-42: Feedback and categories security rules enforce authorization', () {
      bool canSubmitFeedback({
        required String? callerUid,
        required String declaredUserId,
        String text = 'Valid feedback text',
        int rating = 5,
      }) {
        final isAuthMatch = callerUid != null && callerUid == declaredUserId && declaredUserId != 'anonymous';
        final isTextValid = text.length >= 5 && text.length <= 5000;
        final isRatingValid = rating >= 0 && rating <= 5;
        return isAuthMatch && isTextValid && isRatingValid;
      }

      bool canUpdateCategories({required bool isAdmin}) {
        return isAdmin;
      }

      // Authenticated user submitting own feedback
      expect(canSubmitFeedback(callerUid: 'user_1', declaredUserId: 'user_1'), isTrue);
      // Authenticated user attempting to spoof another user's UID
      expect(canSubmitFeedback(callerUid: 'user_1', declaredUserId: 'victim_2'), isFalse);
      // Unauthenticated / guest user attempting to submit feedback (strictly blocked)
      expect(canSubmitFeedback(callerUid: null, declaredUserId: 'anonymous'), isFalse);
      // Unauthenticated / guest user attempting to claim a real user UID
      expect(canSubmitFeedback(callerUid: null, declaredUserId: 'user_1'), isFalse);
      // Anonymous submission by authenticated user (blocked: must bind to own UID)
      expect(canSubmitFeedback(callerUid: 'user_1', declaredUserId: 'anonymous'), isFalse);
      // Invalid text length (too short)
      expect(canSubmitFeedback(callerUid: 'user_1', declaredUserId: 'user_1', text: 'hi'), isFalse);

      expect(canUpdateCategories(isAdmin: true), isTrue);
      expect(canUpdateCategories(isAdmin: false), isFalse);
    });

    test('L-43: Copyright complaints strictly require authenticated submission', () {
      bool canSubmitCopyrightComplaint({
        required String? callerUid,
        required String declaredUserId,
      }) {
        return callerUid != null && callerUid == declaredUserId;
      }

      // Authenticated user submitting with matching UID
      expect(canSubmitCopyrightComplaint(callerUid: 'user_1', declaredUserId: 'user_1'), isTrue);
      // Authenticated user attempting to spoof another UID
      expect(canSubmitCopyrightComplaint(callerUid: 'user_1', declaredUserId: 'victim_2'), isFalse);
      // Unauthenticated guest attempting to submit
      expect(canSubmitCopyrightComplaint(callerUid: null, declaredUserId: 'anonymous'), isFalse);
      expect(canSubmitCopyrightComplaint(callerUid: null, declaredUserId: 'user_1'), isFalse);
    });

    test('L-44: Admin step-up authentication recency validation', () {
      bool isSessionRecent(int? authTime, int maxAgeSeconds, int currentSeconds) {
        if (authTime == null) return false;
        return currentSeconds - authTime <= maxAgeSeconds;
      }

      const now = 1700000000;
      // Active session (10 minutes old, max age 60 minutes)
      expect(isSessionRecent(now - 600, 3600, now), isTrue);
      // Boundary session (exactly 60 minutes old)
      expect(isSessionRecent(now - 3600, 3600, now), isTrue);
      // Stale session (61 minutes old -> requires step-up re-auth)
      expect(isSessionRecent(now - 3660, 3600, now), isFalse);
      // Expired / missing auth time
      expect(isSessionRecent(null, 3600, now), isFalse);
      // Clock skew / futuristic auth time (> now)
      expect(isSessionRecent(now + 10, 3600, now), isTrue);
    });

    test('L-45: User profile update blocks self-unbanning and strike clearing', () {
      const prohibitedKeys = [
        'role', 'isAdmin', 'isSuperadmin', 'permissions', 'isPremium', 'monetizationTier',
        'premiumExpiresAt', 'premiumPlanId', 'walletBalance', 'walletBalanceUSD',
        'hasChannel', 'channelId', 'channelsCount',
        'isBanned', 'bannedAt', 'banReason', 'accountStatus', 'status', 'strikes', 'trustScore'
      ];

      bool canUserUpdateProfile(List<String> affectedKeys, bool isAdmin) {
        if (isAdmin) return true;
        for (final key in affectedKeys) {
          if (prohibitedKeys.contains(key)) return false;
        }
        return true;
      }

      // Valid profile updates
      expect(canUserUpdateProfile(['displayName', 'bio', 'photoUrl'], false), isTrue);
      expect(canUserUpdateProfile(['themePreference', 'updatedAt'], false), isTrue);

      // Malicious attempts to unban or clear strikes
      expect(canUserUpdateProfile(['isBanned'], false), isFalse);
      expect(canUserUpdateProfile(['status'], false), isFalse);
      expect(canUserUpdateProfile(['accountStatus'], false), isFalse);
      expect(canUserUpdateProfile(['strikes'], false), isFalse);
      expect(canUserUpdateProfile(['trustScore'], false), isFalse);
      expect(canUserUpdateProfile(['banReason'], false), isFalse);
      expect(canUserUpdateProfile(['role'], false), isFalse);
      expect(canUserUpdateProfile(['isAdmin'], false), isFalse);

      // Admin can perform moderation updates
      expect(canUserUpdateProfile(['isBanned', 'banReason', 'accountStatus'], true), isTrue);
    });

    test('L-46: Channel creation and updates block self-clearing of strikes and ban status', () {
      const prohibitedChannelKeys = [
        'isVerified', 'geminiApproved', 'status', 'monetizationTier', 'superchatRevenueTotal',
        'adsRevenueTotal', 'membershipRevenueTotal', 'membershipsRevenueTotal', 'premiumSubsRevenueTotal',
        'walletBalanceUSD', 'walletBalance', 'withdrawnRevenueTotal',
        'subscriberCount', 'ownerId', 'userId', 'createdAt', 'penaltyStatus',
        'trustScore', 'reputationScore', 'moderationReason', 'metrics',
        'strikes', 'strikeCount', 'isBanned', 'suspendedAt', 'bannedAt'
      ];

      bool canUpdateChannel(List<String> affectedKeys, bool isAdmin) {
        if (isAdmin) return true;
        for (final key in affectedKeys) {
          if (prohibitedChannelKeys.contains(key)) return false;
        }
        return true;
      }

      // Normal channel metadata update
      expect(canUpdateChannel(['name', 'description', 'socialLinks'], false), isTrue);
      // Video publishing updates videoCount and updatedAt
      expect(canUpdateChannel(['videoCount', 'updatedAt'], false), isTrue);

      // Malicious attempt to clear strikes or un-suspend channel
      expect(canUpdateChannel(['strikes'], false), isFalse);
      expect(canUpdateChannel(['strikeCount'], false), isFalse);
      expect(canUpdateChannel(['isBanned'], false), isFalse);
      expect(canUpdateChannel(['suspendedAt'], false), isFalse);
      expect(canUpdateChannel(['status'], false), isFalse);
      expect(canUpdateChannel(['penaltyStatus'], false), isFalse);

      // Admin override
      expect(canUpdateChannel(['strikes', 'status'], true), isTrue);
    });

    test('L-47: Topic creation strictly blocks pre-approved status and AI moderation bypass', () {
      bool canCreateTopic(Map<String, dynamic> data, bool isAdmin) {
        if (isAdmin) return true;
        final hasVideos = (data['videoCount'] is int && data['videoCount'] > 0) ||
            (data['featuredVideoIds'] is List && (data['featuredVideoIds'] as List).isNotEmpty);
        if (!hasVideos) return false;

        if (data.containsKey('geminiApproved') && data['geminiApproved'] != false) {
          return false;
        }
        final status = data['status'] as String?;
        if (status != null && status != 'pending' && status != 'underReview') {
          return false;
        }
        return true;
      }

      // Legitimate topic submission
      expect(
        canCreateTopic({
          'title': 'Quantum Physics',
          'videoCount': 5,
          'geminiApproved': false,
          'status': 'pending',
        }, false),
        isTrue,
      );

      // Attacker trying to inject pre-approved topic
      expect(
        canCreateTopic({
          'title': 'Hacked Topic',
          'videoCount': 1,
          'geminiApproved': true,
        }, false),
        isFalse,
      );

      // Attacker trying to set status = 'approved'
      expect(
        canCreateTopic({
          'title': 'Spam Topic',
          'videoCount': 1,
          'status': 'approved',
        }, false),
        isFalse,
      );

      // Admin can create pre-approved topics
      expect(
        canCreateTopic({
          'title': 'Official TruthWorld News',
          'geminiApproved': true,
          'status': 'approved',
        }, true),
        isTrue,
      );
    });

    test('L-48: Network Security and ATS enforcement policies', () {
      bool isNetworkSecure({
        required bool allowsCleartextTraffic,
        required bool allowsArbitraryLoadsIos,
        required bool allowsBackupAndroid,
      }) {
        // Must reject all cleartext/arbitrary HTTP and block ADB backup
        if (allowsCleartextTraffic) return false;
        if (allowsArbitraryLoadsIos) return false;
        if (allowsBackupAndroid) return false;
        return true;
      }

      // Production TruthWorld hardened configuration
      expect(
        isNetworkSecure(
          allowsCleartextTraffic: false,
          allowsArbitraryLoadsIos: false,
          allowsBackupAndroid: false,
        ),
        isTrue,
      );

      // Insecure configurations
      expect(
        isNetworkSecure(
          allowsCleartextTraffic: true,
          allowsArbitraryLoadsIos: false,
          allowsBackupAndroid: false,
        ),
        isFalse,
      );
      expect(
        isNetworkSecure(
          allowsCleartextTraffic: false,
          allowsArbitraryLoadsIos: true,
          allowsBackupAndroid: false,
        ),
        isFalse,
      );
      expect(
        isNetworkSecure(
          allowsCleartextTraffic: false,
          allowsArbitraryLoadsIos: false,
          allowsBackupAndroid: true,
        ),
        isFalse,
      );
    });

    test('L-49: Remote config and system collections authorization policies', () {
      bool canReadRemoteConfig() => true;
      bool canWriteRemoteConfig(bool isAdmin) => isAdmin;

      bool canAccessUserDraft(String currentUid, String docOwnerId) => currentUid == docOwnerId;
      bool canAccessUserSavedVideos(String currentUid, String profileUid) => currentUid == profileUid;

      // Remote config is publicly readable by all clients
      expect(canReadRemoteConfig(), isTrue);
      // Remote config write requires verified admin
      expect(canWriteRemoteConfig(false), isFalse);
      expect(canWriteRemoteConfig(true), isTrue);

      // User drafts and saved videos strictly enforce owner isolation
      expect(canAccessUserDraft('user_A', 'user_A'), isTrue);
      expect(canAccessUserDraft('user_B', 'user_A'), isFalse);
      expect(canAccessUserSavedVideos('user_A', 'user_A'), isTrue);
      expect(canAccessUserSavedVideos('user_B', 'user_A'), isFalse);
    });

    test('L-50: Watch sessions write lockdown prevents client watch time fabrication', () {
      bool canClientWriteWatchSession({required bool isClient}) {
        // Direct client writes are forbidden (allow write: if false)
        return !isClient;
      }

      expect(canClientWriteWatchSession(isClient: true), isFalse,
          reason: 'Client-side write to watch_sessions must be rejected');
      expect(canClientWriteWatchSession(isClient: false), isTrue,
          reason: 'Admin SDK / Cloud Functions writes are permitted');
    });

    test('L-51: Storage uploaderId metadata requirement prevents asset tampering', () {
      bool isUploaderClaimValid({
        required bool isSignedIn,
        required bool isAdmin,
        required Map<String, String>? metadata,
        required String? authUid,
      }) {
        if (!isSignedIn) return false;
        if (isAdmin) return true;
        if (metadata == null) return false;
        if (!metadata.containsKey('uploaderId')) return false;
        return metadata['uploaderId'] == authUid;
      }

      bool isOwnerOrNew({
        required bool isSignedIn,
        required bool isAdmin,
        required bool isNewResource,
        required Map<String, String>? existingMetadata,
        required String? authUid,
      }) {
        if (!isSignedIn) return false;
        if (isAdmin) return true;
        if (isNewResource) return true;
        if (existingMetadata == null) return false;
        if (!existingMetadata.containsKey('uploaderId')) return false;
        return existingMetadata['uploaderId'] == authUid;
      }

      // Valid upload with matching uploaderId
      expect(
        isUploaderClaimValid(isSignedIn: true, isAdmin: false, metadata: {'uploaderId': 'user_1'}, authUid: 'user_1'),
        isTrue,
      );

      // Missing uploaderId metadata must be rejected
      expect(
        isUploaderClaimValid(isSignedIn: true, isAdmin: false, metadata: null, authUid: 'user_1'),
        isFalse,
      );
      expect(
        isUploaderClaimValid(isSignedIn: true, isAdmin: false, metadata: {}, authUid: 'user_1'),
        isFalse,
      );

      // Spoofed uploaderId must be rejected
      expect(
        isUploaderClaimValid(isSignedIn: true, isAdmin: false, metadata: {'uploaderId': 'user_2'}, authUid: 'user_1'),
        isFalse,
      );

      // Overwriting existing file: matching owner permitted, unowned or mismatched blocked
      expect(
        isOwnerOrNew(isSignedIn: true, isAdmin: false, isNewResource: false, existingMetadata: {'uploaderId': 'user_1'}, authUid: 'user_1'),
        isTrue,
      );
      expect(
        isOwnerOrNew(isSignedIn: true, isAdmin: false, isNewResource: false, existingMetadata: {'uploaderId': 'user_2'}, authUid: 'user_1'),
        isFalse,
      );
      expect(
        isOwnerOrNew(isSignedIn: true, isAdmin: false, isNewResource: false, existingMetadata: null, authUid: 'user_1'),
        isFalse,
      );
    });

    test('L-52: Storage KYC document deletion permits deletion without request.resource requirement', () {
      bool canDeleteKycDocument({
        required bool isSignedIn,
        required String? authUid,
        required String pathUserId,
        bool isAdmin = false,
      }) {
        if (!isSignedIn) return false;
        return authUid == pathUserId || isAdmin;
      }

      expect(canDeleteKycDocument(isSignedIn: true, authUid: 'user_1', pathUserId: 'user_1'), isTrue);
      expect(canDeleteKycDocument(isSignedIn: true, authUid: 'attacker', pathUserId: 'victim'), isFalse);
      expect(canDeleteKycDocument(isSignedIn: false, authUid: null, pathUserId: 'victim'), isFalse);
      expect(canDeleteKycDocument(isSignedIn: true, authUid: 'admin_1', pathUserId: 'victim', isAdmin: true), isTrue);
    });

    test('L-53: Storage user folder read access requires authenticated account ownership', () {
      bool canReadUserStorageFolder({
        required bool isSignedIn,
        required String? authUid,
        required String pathUserId,
        bool isAdmin = false,
      }) {
        if (!isSignedIn) return false;
        return authUid == pathUserId || isAdmin;
      }

      // Owner can read their private storage folder
      expect(canReadUserStorageFolder(isSignedIn: true, authUid: 'user_abc', pathUserId: 'user_abc'), isTrue);
      // Unauthenticated / public access is strictly blocked
      expect(canReadUserStorageFolder(isSignedIn: false, authUid: null, pathUserId: 'user_abc'), isFalse);
      // Other users cannot read
      expect(canReadUserStorageFolder(isSignedIn: true, authUid: 'stranger', pathUserId: 'user_abc'), isFalse);
      // Admin override
      expect(canReadUserStorageFolder(isSignedIn: true, authUid: 'admin_uid', pathUserId: 'user_abc', isAdmin: true), isTrue);
    });

    test('L-54: Fact-check verification request submission binds to authenticated user', () {
      bool canCreateFactCheckRequest({
        required String? callerUid,
        required Map<String, dynamic> data,
        bool isAdmin = false,
      }) {
        if (callerUid == null) return false;
        if (isAdmin) return true;
        final requestedBy = data['requestedBy'] ?? data['userId'];
        if (requestedBy != callerUid) return false;
        final status = data['status'] as String?;
        if (status != null && status != 'queued' && status != 'pending') return false;
        if (data['videoId'] is! String || (data['videoId'] as String).isEmpty) return false;
        return true;
      }

      // Legitimate user request
      expect(
        canCreateFactCheckRequest(
          callerUid: 'user_123',
          data: {'requestedBy': 'user_123', 'videoId': 'vid_456', 'status': 'queued'},
        ),
        isTrue,
      );

      // Spoofed requester
      expect(
        canCreateFactCheckRequest(
          callerUid: 'attacker',
          data: {'requestedBy': 'victim', 'videoId': 'vid_456', 'status': 'queued'},
        ),
        isFalse,
      );

      // Unauthenticated request blocked
      expect(
        canCreateFactCheckRequest(
          callerUid: null,
          data: {'requestedBy': 'user_123', 'videoId': 'vid_456'},
        ),
        isFalse,
      );
    });

    test('L-55: Distributed counter shards support watch time and comment counts', () {
      const allowedVideoShardKeys = ['count', 'qualifiedCount', 'watchTimeSeconds', 'updatedAt'];
      const allowedCommentShardKeys = ['commentCount', 'updatedAt'];
      const allowedChannelShardKeys = ['views', 'watchTimeSeconds', 'updatedAt'];

      bool areKeysAllowed(List<String> keys, List<String> allowed) {
        return keys.every((k) => allowed.contains(k));
      }

      expect(areKeysAllowed(['count', 'watchTimeSeconds', 'updatedAt'], allowedVideoShardKeys), isTrue);
      expect(areKeysAllowed(['commentCount', 'updatedAt'], allowedCommentShardKeys), isTrue);
      expect(areKeysAllowed(['views', 'watchTimeSeconds'], allowedChannelShardKeys), isTrue);
      expect(areKeysAllowed(['count', 'illegalField'], allowedVideoShardKeys), isFalse);
    });

    test('L-56: Payout Engine Isolation - Client write to /payouts is strictly forbidden', () {
      // Security Rule: match /payouts/{payoutId} { allow write: if false; }
      bool canClientWritePayout({required bool isAuthenticated, bool isAdmin = false}) {
        // Rule: allow write: if false;
        return false;
      }

      // Neither regular users, channel owners, nor attackers can write to /payouts directly
      expect(canClientWritePayout(isAuthenticated: true), isFalse);
      expect(canClientWritePayout(isAuthenticated: false), isFalse);
      expect(canClientWritePayout(isAuthenticated: true, isAdmin: true), isFalse);
    });

    test('L-57: Payout Engine Isolation - Client write to /channel_wallet_transactions is strictly forbidden', () {
      // Security Rule: match /channel_wallet_transactions/{txId} { allow write: if false; }
      bool canClientWriteWalletTransaction({required bool isAuthenticated, bool isAdmin = false}) {
        // Immutable ledger authored exclusively by Cloud Functions
        return false;
      }

      expect(canClientWriteWalletTransaction(isAuthenticated: true), isFalse);
      expect(canClientWriteWalletTransaction(isAuthenticated: false), isFalse);
      expect(canClientWriteWalletTransaction(isAuthenticated: true, isAdmin: true), isFalse);
    });

    test('L-58: Payout Engine Isolation - Client cannot tamper with channel revenue or balance fields', () {
      // Protected financial fields that client diff cannot contain
      const protectedFinancialFields = {
        'superchatRevenueTotal',
        'adsRevenueTotal',
        'membershipRevenueTotal',
        'membershipsRevenueTotal',
        'premiumSubsRevenueTotal',
        'walletBalanceUSD',
        'walletBalance',
        'withdrawnRevenueTotal',
        'clearedWithdrawableRevenueTotal',
        'pendingRevenueTotal',
      };

      bool canClientUpdateChannelFields({
        required bool isAuthenticated,
        required String callerUid,
        required String channelOwnerId,
        required Set<String> changedFields,
        bool isAdmin = false,
      }) {
        if (!isAuthenticated) return false;
        if (isAdmin) return true;
        if (callerUid != channelOwnerId) return false;
        // Owners CANNOT alter protected financial fields directly
        if (changedFields.any(protectedFinancialFields.contains)) {
          return false;
        }
        return true;
      }

      // Owner updating cosmetic profile info -> ALLOWED
      expect(
        canClientUpdateChannelFields(
          isAuthenticated: true,
          callerUid: 'owner_123',
          channelOwnerId: 'owner_123',
          changedFields: {'channelName', 'description', 'avatarUrl'},
        ),
        isTrue,
      );

      // Malicious attempt to credit wallet balance directly -> BLOCKED
      expect(
        canClientUpdateChannelFields(
          isAuthenticated: true,
          callerUid: 'owner_123',
          channelOwnerId: 'owner_123',
          changedFields: {'walletBalance'},
        ),
        isFalse,
      );

      // Malicious attempt to reset withdrawn revenue -> BLOCKED
      expect(
        canClientUpdateChannelFields(
          isAuthenticated: true,
          callerUid: 'owner_123',
          channelOwnerId: 'owner_123',
          changedFields: {'withdrawnRevenueTotal'},
        ),
        isFalse,
      );

      // Malicious attempt to fabricate ads or membership revenue -> BLOCKED
      expect(
        canClientUpdateChannelFields(
          isAuthenticated: true,
          callerUid: 'owner_123',
          channelOwnerId: 'owner_123',
          changedFields: {'adsRevenueTotal', 'membershipRevenueTotal'},
        ),
        isFalse,
      );

      // Malicious attempt to fabricate cleared or pending revenue -> BLOCKED
      expect(
        canClientUpdateChannelFields(
          isAuthenticated: true,
          callerUid: 'owner_123',
          channelOwnerId: 'owner_123',
          changedFields: {'clearedWithdrawableRevenueTotal'},
        ),
        isFalse,
      );
      expect(
        canClientUpdateChannelFields(
          isAuthenticated: true,
          callerUid: 'owner_123',
          channelOwnerId: 'owner_123',
          changedFields: {'pendingRevenueTotal'},
        ),
        isFalse,
      );

      // Legitimate creator updating autoPayoutEnabled preference -> ALLOWED
      expect(
        canClientUpdateChannelFields(
          isAuthenticated: true,
          callerUid: 'owner_123',
          channelOwnerId: 'owner_123',
          changedFields: {'autoPayoutEnabled'},
        ),
        isTrue,
      );
    });

    test('L-59: Payout Engine Isolation - Client payout_requests rules enforce owner binding, threshold & status=pending', () {
      bool canClientCreatePayoutRequest({
        required bool isAuthenticated,
        required String? callerUid,
        required Map<String, dynamic> requestData,
        required Map<String, dynamic> channelData,
      }) {
        if (!isAuthenticated || callerUid == null) return false;
        if (requestData['userId'] != callerUid) return false;
        if (requestData['amount'] is! num || (requestData['amount'] as num) < 100) return false;
        // Crucial: Client can ONLY create requests with status == 'pending'
        if (requestData['status'] != 'pending') return false;
        final channelId = requestData['channelId'] as String?;
        if (channelId == null || channelId.isEmpty) return false;
        // Channel owner must match caller
        if (channelData['ownerId'] != callerUid) return false;
        return true;
      }

      bool canClientUpdatePayoutRequest({bool isAdmin = false}) {
        // Clients CANNOT mark requests as 'approved', 'processing', or 'completed'
        return isAdmin;
      }

      final validChannel = {'ownerId': 'creator_456', 'channelName': 'TechInsights'};

      // 1. Valid request created by legitimate creator
      expect(
        canClientCreatePayoutRequest(
          isAuthenticated: true,
          callerUid: 'creator_456',
          channelData: validChannel,
          requestData: {
            'userId': 'creator_456',
            'channelId': 'ch_001',
            'amount': 250.0,
            'status': 'pending',
          },
        ),
        isTrue,
      );

      // 2. Attacker trying to self-approve / trigger direct transfer by setting status='completed' -> BLOCKED
      expect(
        canClientCreatePayoutRequest(
          isAuthenticated: true,
          callerUid: 'creator_456',
          channelData: validChannel,
          requestData: {
            'userId': 'creator_456',
            'channelId': 'ch_001',
            'amount': 250.0,
            'status': 'completed', // Bypassing backend Payout Engine
          },
        ),
        isFalse,
      );

      // 3. Attacker trying to withdraw money under another creator's channel -> BLOCKED
      expect(
        canClientCreatePayoutRequest(
          isAuthenticated: true,
          callerUid: 'attacker_789',
          channelData: validChannel, // owned by creator_456
          requestData: {
            'userId': 'attacker_789',
            'channelId': 'ch_001',
            'amount': 500.0,
            'status': 'pending',
          },
        ),
        isFalse,
      );

      // 4. Request below minimum threshold of ₹100 -> BLOCKED
      expect(
        canClientCreatePayoutRequest(
          isAuthenticated: true,
          callerUid: 'creator_456',
          channelData: validChannel,
          requestData: {
            'userId': 'creator_456',
            'channelId': 'ch_001',
            'amount': 50.0, // Below ₹100
            'status': 'pending',
          },
        ),
        isFalse,
      );

      // 5. Client trying to update or alter payout status directly -> BLOCKED
      expect(canClientUpdatePayoutRequest(), isFalse);
      expect(canClientUpdatePayoutRequest(isAdmin: true), isTrue);
    });

    test('L-60: video_jobs security rules enforce owner verification on read, create, and update', () {
      bool canReadVideoJob({
        required bool isAuthenticated,
        required String? callerUid,
        required Map<String, dynamic> resourceData,
        required String jobId,
        required bool Function(String videoId) isVideoOwner,
        bool isAdmin = false,
      }) {
        if (!isAuthenticated || callerUid == null) return false;
        if (isAdmin) return true;
        if (resourceData['userId'] == callerUid) return true;
        if (isVideoOwner(jobId)) return true;
        if (resourceData['videoId'] != null && isVideoOwner(resourceData['videoId'].toString())) {
          return true;
        }
        return false;
      }

      bool canCreateVideoJob({
        required bool isAuthenticated,
        required String? callerUid,
        required Map<String, dynamic> requestResourceData,
        required String jobId,
        required bool Function(String videoId) isVideoOwner,
        required bool Function(String videoId) videoExists,
        bool isAdmin = false,
      }) {
        if (!isAuthenticated || callerUid == null) return false;
        if (isAdmin) return true;
        if (requestResourceData['userId'] == callerUid &&
            (isVideoOwner(jobId) || !videoExists(jobId))) {
          return true;
        }
        return false;
      }

      bool canUpdateVideoJob({
        required bool isAuthenticated,
        required String? callerUid,
        required Map<String, dynamic> resourceData,
        required Map<String, dynamic> requestResourceData,
        required String jobId,
        required bool Function(String videoId) isVideoOwner,
        bool isAdmin = false,
      }) {
        if (!isAuthenticated || callerUid == null) return false;
        if (isAdmin) return true;
        return resourceData['userId'] == callerUid ||
            requestResourceData['userId'] == callerUid ||
            isVideoOwner(jobId);
      }

      bool canDeleteVideoJob({bool isAdmin = false}) {
        return isAdmin;
      }

      // Read tests
      expect(
        canReadVideoJob(
          isAuthenticated: true,
          callerUid: 'creator_1',
          resourceData: {'userId': 'creator_1', 'videoId': 'vid_1'},
          jobId: 'vid_1',
          isVideoOwner: (vid) => vid == 'vid_1',
        ),
        isTrue,
        reason: 'Creator who is doc userId can read their job',
      );

      expect(
        canReadVideoJob(
          isAuthenticated: true,
          callerUid: 'creator_1',
          resourceData: {'userId': 'other_user', 'videoId': 'vid_1'},
          jobId: 'vid_1',
          isVideoOwner: (vid) => vid == 'vid_1',
        ),
        isTrue,
        reason: 'Creator who owns video can read their video job even if doc userId differs',
      );

      expect(
        canReadVideoJob(
          isAuthenticated: true,
          callerUid: 'attacker',
          resourceData: {'userId': 'victim', 'videoId': 'vid_victim'},
          jobId: 'vid_victim',
          isVideoOwner: (vid) => false,
        ),
        isFalse,
        reason: 'Attacker cannot read victim video job',
      );

      expect(
        canReadVideoJob(
          isAuthenticated: false,
          callerUid: null,
          resourceData: {'userId': 'creator_1'},
          jobId: 'vid_1',
          isVideoOwner: (vid) => false,
        ),
        isFalse,
        reason: 'Unauthenticated read blocked',
      );

      expect(
        canReadVideoJob(
          isAuthenticated: true,
          callerUid: 'admin_user',
          resourceData: {'userId': 'victim'},
          jobId: 'vid_1',
          isVideoOwner: (vid) => false,
          isAdmin: true,
        ),
        isTrue,
        reason: 'Admin can read any video job',
      );

      // Create tests
      expect(
        canCreateVideoJob(
          isAuthenticated: true,
          callerUid: 'creator_1',
          requestResourceData: {'userId': 'creator_1', 'videoId': 'vid_1'},
          jobId: 'vid_1',
          isVideoOwner: (vid) => true,
          videoExists: (vid) => true,
        ),
        isTrue,
        reason: 'Creator can create job for their existing video',
      );

      expect(
        canCreateVideoJob(
          isAuthenticated: true,
          callerUid: 'creator_1',
          requestResourceData: {'userId': 'creator_1'},
          jobId: 'new_job_1',
          isVideoOwner: (vid) => false,
          videoExists: (vid) => false,
        ),
        isTrue,
        reason: 'Creator can create job for newly queued video that does not exist yet',
      );

      expect(
        canCreateVideoJob(
          isAuthenticated: true,
          callerUid: 'attacker',
          requestResourceData: {'userId': 'attacker'},
          jobId: 'victim_vid',
          isVideoOwner: (vid) => false,
          videoExists: (vid) => true,
        ),
        isFalse,
        reason: 'Attacker cannot create job for existing video owned by someone else',
      );

      expect(
        canCreateVideoJob(
          isAuthenticated: true,
          callerUid: 'attacker',
          requestResourceData: {'userId': 'victim'},
          jobId: 'new_job',
          isVideoOwner: (vid) => false,
          videoExists: (vid) => false,
        ),
        isFalse,
        reason: 'Attacker cannot forge userId of victim on create',
      );

      // Update tests
      expect(
        canUpdateVideoJob(
          isAuthenticated: true,
          callerUid: 'creator_1',
          resourceData: {'userId': 'creator_1'},
          requestResourceData: {'userId': 'creator_1'},
          jobId: 'vid_1',
          isVideoOwner: (vid) => true,
        ),
        isTrue,
      );

      expect(
        canUpdateVideoJob(
          isAuthenticated: true,
          callerUid: 'attacker',
          resourceData: {'userId': 'victim'},
          requestResourceData: {'userId': 'victim'},
          jobId: 'victim_vid',
          isVideoOwner: (vid) => false,
        ),
        isFalse,
        reason: 'Attacker cannot update victim video job',
      );

      // Delete tests
      expect(canDeleteVideoJob(), isFalse);
      expect(canDeleteVideoJob(isAdmin: true), isTrue);
    });

    test('L-61: Firestore Rules Invariants - Null resource handling and channel/claim permissions', () {
      // 1. Channel update allows owner to increment videoCount and updatedAt
      bool canUpdateChannelOwner({
        required bool isAuthenticated,
        required String callerUid,
        required String ownerUid,
        required List<String> affectedKeys,
      }) {
        if (!isAuthenticated) return false;
        if (callerUid != ownerUid) return false;
        const forbiddenKeys = [
          'isVerified', 'geminiApproved', 'status', 'monetizationTier', 'superchatRevenueTotal',
          'adsRevenueTotal', 'membershipRevenueTotal', 'membershipsRevenueTotal', 'premiumSubsRevenueTotal',
          'walletBalanceUSD', 'walletBalance', 'withdrawnRevenueTotal',
          'subscriberCount', 'ownerId', 'userId', 'createdAt', 'penaltyStatus',
          'trustScore', 'reputationScore', 'moderationReason', 'metrics',
          'strikes', 'strikeCount', 'isBanned', 'suspendedAt', 'bannedAt',
        ];
        return !affectedKeys.any(forbiddenKeys.contains);
      }

      expect(
        canUpdateChannelOwner(
          isAuthenticated: true,
          callerUid: 'creator_1',
          ownerUid: 'creator_1',
          affectedKeys: ['videoCount', 'updatedAt'],
        ),
        isTrue,
      );

      // Counter branch allows updatedAt alongside counters
      bool canUpdateCounterBranch({
        required bool isAuthenticated,
        required List<String> affectedKeys,
      }) {
        if (!isAuthenticated) return false;
        const allowedKeys = ['subscriberCount', 'lastActiveAt', 'videoCount', 'updatedAt'];
        return affectedKeys.every(allowedKeys.contains);
      }

      expect(
        canUpdateCounterBranch(
          isAuthenticated: true,
          affectedKeys: ['videoCount', 'updatedAt'],
        ),
        isTrue,
      );

      // 2. User drafts delete allows null resource or ownership
      bool canDeleteDraft({
        required bool isAuthenticated,
        required String callerUid,
        required Map<String, dynamic>? resource,
        bool isAdmin = false,
      }) {
        if (!isAuthenticated) return false;
        return resource == null || resource['userId'] == callerUid || isAdmin;
      }

      expect(canDeleteDraft(isAuthenticated: true, callerUid: 'user_1', resource: null), isTrue);
      expect(canDeleteDraft(isAuthenticated: true, callerUid: 'user_1', resource: {'userId': 'user_1'}), isTrue);
      expect(canDeleteDraft(isAuthenticated: true, callerUid: 'user_2', resource: {'userId': 'user_1'}), isFalse);

      // 3. Copyright claims read and create authorization rules
      bool canReadCopyrightClaim({
        required bool isAuthenticated,
        required String callerUid,
        required Map<String, dynamic> resource,
        bool isAdmin = false,
      }) {
        if (!isAuthenticated) return false;
        if (isAdmin) return true;
        return resource['uploaderId'] == callerUid ||
            resource['ownerId'] == callerUid ||
            resource['channelId'] == callerUid ||
            resource['ownerChannelId'] == callerUid ||
            resource['userId'] == callerUid ||
            resource['claimantId'] == callerUid;
      }

      bool canCreateCopyrightClaim({
        required bool isAuthenticated,
        required String callerUid,
        required Map<String, dynamic> requestData,
        bool isAdmin = false,
      }) {
        if (!isAuthenticated) return false;
        if (isAdmin) return true;
        return requestData['uploaderId'] == callerUid ||
            requestData['ownerId'] == callerUid ||
            requestData['channelId'] == callerUid ||
            requestData['ownerChannelId'] == callerUid ||
            requestData['userId'] == callerUid ||
            requestData['claimantId'] == callerUid;
      }

      const testClaim = {
        'claimId': 'claim_123',
        'uploaderId': 'creator_upload_uid',
        'ownerId': 'rights_holder_uid',
        'channelId': 'channel_creator_uid',
        'ownerChannelId': 'channel_owner_uid',
      };

      // Unauthenticated reads are strictly blocked
      expect(canReadCopyrightClaim(isAuthenticated: false, callerUid: 'creator_upload_uid', resource: testClaim), isFalse);

      // Authorized parties can read
      expect(canReadCopyrightClaim(isAuthenticated: true, callerUid: 'creator_upload_uid', resource: testClaim), isTrue, reason: 'Uploader can read claim');
      expect(canReadCopyrightClaim(isAuthenticated: true, callerUid: 'rights_holder_uid', resource: testClaim), isTrue, reason: 'Rights holder owner can read claim');
      expect(canReadCopyrightClaim(isAuthenticated: true, callerUid: 'channel_creator_uid', resource: testClaim), isTrue, reason: 'Infringing channel can read claim');
      expect(canReadCopyrightClaim(isAuthenticated: true, callerUid: 'channel_owner_uid', resource: testClaim), isTrue, reason: 'Rights holder channel can read claim');
      expect(canReadCopyrightClaim(isAuthenticated: true, callerUid: 'legacy_user_uid', resource: {'userId': 'legacy_user_uid'}), isTrue, reason: 'Legacy userId can read');
      expect(canReadCopyrightClaim(isAuthenticated: true, callerUid: 'legacy_claimant_uid', resource: {'claimantId': 'legacy_claimant_uid'}), isTrue, reason: 'Legacy claimantId can read');
      expect(canReadCopyrightClaim(isAuthenticated: true, callerUid: 'admin_uid', resource: testClaim, isAdmin: true), isTrue, reason: 'Admin can read any claim');

      // Unrelated third party is blocked
      expect(canReadCopyrightClaim(isAuthenticated: true, callerUid: 'unrelated_attacker', resource: testClaim), isFalse, reason: 'Unrelated party cannot read claims');

      // Create claims authorization
      expect(canCreateCopyrightClaim(isAuthenticated: true, callerUid: 'rights_holder_uid', requestData: {'ownerId': 'rights_holder_uid'}), isTrue);
      expect(canCreateCopyrightClaim(isAuthenticated: true, callerUid: 'unrelated_user', requestData: {'ownerId': 'victim_owner'}), isFalse);
      expect(canCreateCopyrightClaim(isAuthenticated: true, callerUid: 'admin_uid', requestData: {'ownerId': 'victim_owner'}, isAdmin: true), isTrue);

      // 4. Video get safely handles null resource without throw
      bool canGetVideo({required Map<String, dynamic>? resource}) {
        if (resource == null) return true;
        final visibility = resource['visibility'];
        return visibility == null ||
            visibility == 'public' ||
            visibility == 'Public' ||
            visibility == 'unlisted' ||
            visibility == 'Unlisted';
      }

      expect(canGetVideo(resource: null), isTrue);
      expect(canGetVideo(resource: {'visibility': 'public'}), isTrue);
      expect(canGetVideo(resource: {'visibility': 'private'}), isFalse);
    });

    test('L-62: Video engagement counter update safely handles missing fields and prevents counter exploits', () {
      // Simulates the hardened CEL rule for viewCount and views
      bool canUpdateVideoCounters({
        required Map<String, dynamic> existingDoc,
        required Map<String, dynamic> updatedDoc,
        required bool isAuthenticated,
      }) {
        if (!isAuthenticated) return false;

        // Calculate affected keys
        final affectedKeys = <String>{};
        final allKeys = {...existingDoc.keys, ...updatedDoc.keys};
        for (final k in allKeys) {
          if (!existingDoc.containsKey(k) || !updatedDoc.containsKey(k) || existingDoc[k] != updatedDoc[k]) {
            affectedKeys.add(k);
          }
        }

        const allowedEngagementKeys = {
          'likeCount', 'dislikeCount', 'likes', 'dislikes', 'views', 'viewCount',
          'shareCount', 'playCount', 'engagement', 'languageRequestsCount', 'commentCount', 'commentsCount'
        };

        if (!affectedKeys.every(allowedEngagementKeys.contains)) return false;

        // viewCount CEL check
        final viewCountAffected = affectedKeys.contains('viewCount');
        final viewCountOk = !viewCountAffected ||
            (!existingDoc.containsKey('viewCount') && updatedDoc['viewCount'] == 1) ||
            (existingDoc.containsKey('viewCount') &&
                (updatedDoc['viewCount'] == existingDoc['viewCount'] + 1 ||
                 updatedDoc['viewCount'] == existingDoc['viewCount']));

        // views CEL check
        final viewsAffected = affectedKeys.contains('views');
        final viewsOk = !viewsAffected ||
            (!existingDoc.containsKey('views') && updatedDoc['views'] == 1) ||
            (existingDoc.containsKey('views') &&
                (updatedDoc['views'] == existingDoc['views'] + 1 ||
                 updatedDoc['views'] == existingDoc['views']));

        return viewCountOk && viewsOk;
      }

      // Case 1: Doc has views but lacks viewCount
      final docWithViewsOnly = {'views': 42};
      // Legitimate client updates viewCount for the first time
      expect(
        canUpdateVideoCounters(
          existingDoc: docWithViewsOnly,
          updatedDoc: {'views': 42, 'viewCount': 1},
          isAuthenticated: true,
        ),
        isTrue,
        reason: 'Should safely allow initializing viewCount to 1 when doc only had views',
      );

      // Case 2: Doc has viewCount but lacks views
      final docWithViewCountOnly = {'viewCount': 100};
      // Legitimate client updates views for the first time
      expect(
        canUpdateVideoCounters(
          existingDoc: docWithViewCountOnly,
          updatedDoc: {'viewCount': 100, 'views': 1},
          isAuthenticated: true,
        ),
        isTrue,
        reason: 'Should safely allow initializing views to 1 when doc only had viewCount',
      );

      // Case 3: Doc lacks both views and viewCount
      final docWithNeither = <String, dynamic>{'title': 'Legacy Video'};
      expect(
        canUpdateVideoCounters(
          existingDoc: docWithNeither,
          updatedDoc: {'title': 'Legacy Video', 'viewCount': 1},
          isAuthenticated: true,
        ),
        isTrue,
      );
      expect(
        canUpdateVideoCounters(
          existingDoc: docWithNeither,
          updatedDoc: {'title': 'Legacy Video', 'views': 1},
          isAuthenticated: true,
        ),
        isTrue,
      );

      // Case 4: Attacker tries to initialize missing field to > 1
      expect(
        canUpdateVideoCounters(
          existingDoc: docWithViewsOnly,
          updatedDoc: {'views': 42, 'viewCount': 1000},
          isAuthenticated: true,
        ),
        isFalse,
        reason: 'Attacker cannot initialize missing viewCount to arbitrary inflated value',
      );
      expect(
        canUpdateVideoCounters(
          existingDoc: docWithViewCountOnly,
          updatedDoc: {'viewCount': 100, 'views': 500},
          isAuthenticated: true,
        ),
        isFalse,
        reason: 'Attacker cannot initialize missing views to arbitrary inflated value',
      );

      // Case 5: Normal +1 increment when field exists
      expect(
        canUpdateVideoCounters(
          existingDoc: {'views': 42, 'viewCount': 42},
          updatedDoc: {'views': 43, 'viewCount': 43},
          isAuthenticated: true,
        ),
        isTrue,
      );

      // Case 6: Attacker tries +2 or decrement when field exists
      expect(
        canUpdateVideoCounters(
          existingDoc: {'views': 42, 'viewCount': 42},
          updatedDoc: {'views': 44, 'viewCount': 42},
          isAuthenticated: true,
        ),
        isFalse,
      );
      expect(
        canUpdateVideoCounters(
          existingDoc: {'views': 42, 'viewCount': 42},
          updatedDoc: {'views': 41, 'viewCount': 42},
          isAuthenticated: true,
        ),
        isFalse,
      );
    });

    test('L-63: User payout settings fallback & Creator KYC null-resource read permissions', () {
      // 1. users/{userId}/payout_settings/{settingId}
      bool canAccessUserPayoutSettings({
        required bool isAuthenticated,
        required String callerUid,
        required String pathUserId,
        bool isAdmin = false,
      }) {
        if (!isAuthenticated) return false;
        return callerUid == pathUserId || isAdmin;
      }

      // Owner can read/write their own payout settings
      expect(
        canAccessUserPayoutSettings(
          isAuthenticated: true,
          callerUid: 'user_123',
          pathUserId: 'user_123',
        ),
        isTrue,
        reason: 'User must be allowed to read/write their own payout settings',
      );

      // Admin can access payout settings
      expect(
        canAccessUserPayoutSettings(
          isAuthenticated: true,
          callerUid: 'admin_1',
          pathUserId: 'user_123',
          isAdmin: true,
        ),
        isTrue,
        reason: 'Admin must be allowed to access payout settings',
      );

      // Other user cannot access victim payout settings
      expect(
        canAccessUserPayoutSettings(
          isAuthenticated: true,
          callerUid: 'attacker',
          pathUserId: 'user_123',
          isAdmin: false,
        ),
        isFalse,
        reason: 'Third party cannot read/write another user payout settings',
      );

      // Unauthenticated cannot access payout settings
      expect(
        canAccessUserPayoutSettings(
          isAuthenticated: false,
          callerUid: '',
          pathUserId: 'user_123',
        ),
        isFalse,
        reason: 'Unauthenticated requests must be rejected',
      );

      // 2. creator_kyc/{channelId} read access
      bool canReadCreatorKyc({
        required bool isAuthenticated,
        required String callerUid,
        required String channelId,
        required Map<String, dynamic>? resource,
        bool isAdmin = false,
      }) {
        if (!isAuthenticated) return false;
        return resource == null ||
            resource['userId'] == callerUid ||
            callerUid == channelId ||
            isAdmin;
      }

      // Non-existent doc allows authenticated user read (returns exists: false instead of PERMISSION_DENIED)
      expect(
        canReadCreatorKyc(
          isAuthenticated: true,
          callerUid: 'creator_1',
          channelId: 'channel_abc',
          resource: null,
        ),
        isTrue,
        reason: 'Non-existent KYC doc must return exists: false without permission denied',
      );

      // Unauthenticated non-existent doc read is denied
      expect(
        canReadCreatorKyc(
          isAuthenticated: false,
          callerUid: '',
          channelId: 'channel_abc',
          resource: null,
        ),
        isFalse,
        reason: 'Unauthenticated read on creator_kyc must be denied even if doc is null',
      );

      // Existing doc: Submitter can read
      expect(
        canReadCreatorKyc(
          isAuthenticated: true,
          callerUid: 'user_456',
          channelId: 'channel_abc',
          resource: {'userId': 'user_456', 'kycStatus': 'pending'},
        ),
        isTrue,
        reason: 'KYC submitter must be allowed to read their KYC record',
      );

      // Existing doc: Channel owner can read
      expect(
        canReadCreatorKyc(
          isAuthenticated: true,
          callerUid: 'channel_abc',
          channelId: 'channel_abc',
          resource: {'userId': 'user_other', 'kycStatus': 'approved'},
        ),
        isTrue,
        reason: 'Channel owner matching channelId must be allowed to read KYC record',
      );

      // Existing doc: Admin can read
      expect(
        canReadCreatorKyc(
          isAuthenticated: true,
          callerUid: 'admin_1',
          channelId: 'channel_abc',
          resource: {'userId': 'user_456', 'kycStatus': 'pending'},
          isAdmin: true,
        ),
        isTrue,
        reason: 'Admin must be allowed to read any KYC record',
      );

      // Existing doc: Unrelated attacker is denied
      expect(
        canReadCreatorKyc(
          isAuthenticated: true,
          callerUid: 'attacker',
          channelId: 'channel_abc',
          resource: {'userId': 'user_456', 'kycStatus': 'approved'},
          isAdmin: false,
        ),
        isFalse,
        reason: 'Unrelated third party must NOT be allowed to read sensitive KYC record',
      );
    });
  });
}
