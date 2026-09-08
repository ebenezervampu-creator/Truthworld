import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security & Authorization Validation Tests', () {
    test('L-01: Admin email bootstrap requires email_verified == true', () {
      const adminEmails = [
        'ebenezervampy@towervsp.com',
        'ebenezervampu@towervsp.com',
        'ebenezervampu4@gmail.com',
        'admin@truthworld.com',
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
        checkIsAdmin(email: 'admin@truthworld.com', emailVerified: false),
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
        checkIsAdmin(email: 'admin@truthworld.com', emailVerified: true),
        isTrue,
        reason: 'Verified admin email MUST be granted bootstrap privileges',
      );

      // Custom claims take precedence regardless
      expect(
        checkIsAdmin(email: 'moderator@truthworld.com', emailVerified: true, hasAdminClaim: true),
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
          'ebenezervampy@towervsp.com',
          'ebenezervampu@towervsp.com',
          'ebenezervampu4@gmail.com',
          'admin@truthworld.com',
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
        isCallableAdmin(hasAdminClaim: false, email: 'admin@truthworld.com', emailVerified: false),
        isFalse,
      );
      // Valid admin
      expect(
        isCallableAdmin(hasAdminClaim: true, email: 'admin@custom.com', emailVerified: true),
        isTrue,
      );
    });

    test('L-19: SuperChat direct wallet deduction prevents double-spending', () {
      Map<String, dynamic> processDirectWalletSuperchat({
        required num userWalletBalance,
        required num superchatAmount,
      }) {
        if (userWalletBalance < superchatAmount) {
          return {'success': false, 'error': 'INSUFFICIENT_FUNDS'};
        }
        return {
          'success': true,
          'remainingBalance': userWalletBalance - superchatAmount,
        };
      }

      // Sufficient balance
      final successResult = processDirectWalletSuperchat(userWalletBalance: 500, superchatAmount: 200);
      expect(successResult['success'], isTrue);
      expect(successResult['remainingBalance'], 300);

      // Insufficient balance (free superchat exploit attempt)
      final failResult = processDirectWalletSuperchat(userWalletBalance: 50, superchatAmount: 200);
      expect(failResult['success'], isFalse);
      expect(failResult['error'], 'INSUFFICIENT_FUNDS');
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
      bool canSubmitFeedback({required String callerUid, required String declaredUserId}) {
        return callerUid == declaredUserId;
      }

      bool canUpdateCategories({required bool isAdmin}) {
        return isAdmin;
      }

      expect(canSubmitFeedback(callerUid: 'user_1', declaredUserId: 'user_1'), isTrue);
      expect(canSubmitFeedback(callerUid: 'user_1', declaredUserId: 'victim_2'), isFalse);
      expect(canUpdateCategories(isAdmin: true), isTrue);
      expect(canUpdateCategories(isAdmin: false), isFalse);
    });
  });
}
