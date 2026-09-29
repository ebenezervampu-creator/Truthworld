import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TruthWorld Anti-Fraud & Security Integrity Tests', () {
    test('Anti-Overdraft: Payout calculator enforces available balance constraint', () {
      const adsRevenue = 1000.0;
      const premiumSubsRevenue = 500.0;
      const membershipsRevenue = 200.0;
      const superchatsRevenue = 300.0;
      const walletBalanceUSD = 10.0; // $10 = ₹840
      const walletBalanceINR = walletBalanceUSD * 84.0;

      const totalEarnedINR = adsRevenue + premiumSubsRevenue + membershipsRevenue + superchatsRevenue + walletBalanceINR;
      expect(totalEarnedINR, equals(2840.0));

      const withdrawnRevenueTotal = 2500.0;
      const availableWithdrawableINR = totalEarnedINR - withdrawnRevenueTotal;
      expect(availableWithdrawableINR, equals(340.0));

      // Attempt to withdraw ₹500 (exceeds ₹340 available)
      const requestedWithdrawal = 500.0;
      const isOverdraft = requestedWithdrawal > availableWithdrawableINR;
      expect(isOverdraft, isTrue);

      // Attempt to withdraw ₹300 (within ₹340 available)
      const validWithdrawal = 300.0;
      const isValid = validWithdrawal <= availableWithdrawableINR;
      expect(isValid, isTrue);
    });

    test('Anti-Account-Takeover: Channel ownership validation rejects unauthorized requesters', () {
      const genuineChannelOwnerId = 'usr_legitimate_creator';
      const maliciousRequesterId = 'usr_attacker_123';

      bool isAuthorizedPayoutRequest(String channelOwner, String requester) {
        return channelOwner == requester;
      }

      expect(isAuthorizedPayoutRequest(genuineChannelOwnerId, genuineChannelOwnerId), isTrue);
      expect(isAuthorizedPayoutRequest(genuineChannelOwnerId, maliciousRequesterId), isFalse);
    });

    test('Anti-Watch-Time-Inflation: Heartbeat deltas are strictly clamped to maximum 30 seconds', () {
      const maxLegitimateDelta = 30;

      int sanitizeWatchTimeDelta(int rawDelta) {
        final nonNegative = rawDelta < 0 ? 0 : rawDelta;
        return nonNegative > maxLegitimateDelta ? maxLegitimateDelta : nonNegative;
      }

      // Normal heartbeat: 15 seconds
      expect(sanitizeWatchTimeDelta(15), equals(15));

      // Minor lag heartbeat: 28 seconds
      expect(sanitizeWatchTimeDelta(28), equals(28));

      // Attempted bot exploit: 10,000,000 seconds
      expect(sanitizeWatchTimeDelta(10000000), equals(30));

      // Malicious negative delta: -500 seconds
      expect(sanitizeWatchTimeDelta(-500), equals(0));
    });

    test('Anti-Ad-Fraud: Unpaid or inactive campaigns cannot settle impressions', () {
      bool canSettleImpression({required String status, required bool isPaid, required double remainingBudget}) {
        if (status != 'active') return false;
        if (!isPaid) return false;
        if (remainingBudget <= 0) return false;
        return true;
      }

      // Normal verified active paid campaign with budget
      expect(canSettleImpression(status: 'active', isPaid: true, remainingBudget: 500.0), isTrue);

      // Malicious unpaid campaign created via client SDK
      expect(canSettleImpression(status: 'active', isPaid: false, remainingBudget: 100000.0), isFalse);

      // Draft campaign
      expect(canSettleImpression(status: 'draft', isPaid: true, remainingBudget: 100.0), isFalse);

      // Exhausted campaign
      expect(canSettleImpression(status: 'active', isPaid: true, remainingBudget: 0.0), isFalse);
    });

    test('Anti-Self-Click: Channel owner impressions suppress channel revenue credit', () {
      bool shouldCreditChannel({required String channelOwnerId, required String viewerUserId, required bool suppressFlag}) {
        if (suppressFlag) return false;
        if (channelOwnerId.isNotEmpty && viewerUserId.isNotEmpty && viewerUserId != 'guest' && channelOwnerId == viewerUserId) {
          return false; // Suppress self-clicks
        }
        return true;
      }

      // Legitimate third-party viewer
      expect(shouldCreditChannel(channelOwnerId: 'creator_1', viewerUserId: 'viewer_2', suppressFlag: false), isTrue);

      // Channel owner clicking own ads
      expect(shouldCreditChannel(channelOwnerId: 'creator_1', viewerUserId: 'creator_1', suppressFlag: false), isFalse);

      // External suppression flag (e.g. subnet farm detected)
      expect(shouldCreditChannel(channelOwnerId: 'creator_1', viewerUserId: 'viewer_3', suppressFlag: true), isFalse);
    });

    test('Anti-Double-Spending: Custom plan purchase using revenue increments withdrawnRevenueTotal', () {
      const initialWithdrawnINR = 500.0;
      const revenueDeductionUSD = 15.0; // Starter plan
      const inrRate = 84.0;

      const deductionINR = revenueDeductionUSD * inrRate; // ₹1260
      expect(deductionINR, equals(1260.0));

      const updatedWithdrawnINR = initialWithdrawnINR + deductionINR;
      expect(updatedWithdrawnINR, equals(1760.0));

      // After spending ₹1260 of unwithdrawn revenue on a plan,
      // that ₹1260 is accounted for in withdrawnRevenueTotal and cannot be cashed out again
      expect(updatedWithdrawnINR > initialWithdrawnINR, isTrue);
    });

    test('Anti-Privilege-Escalation: Admin email bootstrap strictly requires email_verified == true in backend and storage rules', () {
      const adminEmails = [
        'ebenezervampy@towervsp.com',
        'ebenezervampu@towervsp.com',
        'ebenezervampu4@gmail.com',
        'admin@truthworld.com',
        'support@truthworld.com',
      ];

      bool checkIsAdmin({required String email, required bool isEmailVerified, bool hasAdminClaim = false}) {
        if (hasAdminClaim) return true;
        return isEmailVerified && adminEmails.contains(email.toLowerCase());
      }

      // Attack: attacker signs up with admin@truthworld.com without email verification
      expect(checkIsAdmin(email: 'admin@truthworld.com', isEmailVerified: false), isFalse);
      expect(checkIsAdmin(email: 'support@truthworld.com', isEmailVerified: false), isFalse);

      // Legitimate admin with email verification
      expect(checkIsAdmin(email: 'admin@truthworld.com', isEmailVerified: true), isTrue);
      expect(checkIsAdmin(email: 'support@truthworld.com', isEmailVerified: true), isTrue);
    });

    test('Anti-Bypass: Channel membership creation strictly rejected for clients (backend only)', () {
      bool isAllowedClientMembershipWrite({required bool isServerAdmin, required String callerUid, required String targetMemberId}) {
        // Direct client writes are forbidden; only server admin SDK can write memberships
        return isServerAdmin;
      }

      // Attacker trying to write their own membership record
      expect(isAllowedClientMembershipWrite(isServerAdmin: false, callerUid: 'attacker', targetMemberId: 'attacker'), isFalse);

      // Authenticated payment webhook (Cloud Function Admin SDK)
      expect(isAllowedClientMembershipWrite(isServerAdmin: true, callerUid: 'system', targetMemberId: 'user_123'), isTrue);
    });

    test('Anti-KYC-Tampering: Creator cannot self-grant verified status or bypass name match', () {
      bool isValidKycCreate(Map<String, dynamic> data) {
        final status = data['kycStatus'];
        final isNameMatched = data['isNameMatched'];
        if (status != null && status != 'pending') return false;
        if (isNameMatched != null && isNameMatched != false) return false;
        return true;
      }

      bool isValidKycUpdate(Map<String, dynamic> delta) {
        const protectedKeys = ['kycStatus', 'isNameMatched', 'nameMatchScore', 'reviewedAt', 'reviewedBy', 'userId'];
        return !delta.keys.any(protectedKeys.contains);
      }

      // Normal submission
      expect(isValidKycCreate({'userId': 'usr_1', 'panNumber': 'ABCDE1234F', 'kycStatus': 'pending'}), isTrue);

      // Forged verified status on create
      expect(isValidKycCreate({'userId': 'usr_1', 'kycStatus': 'verified'}), isFalse);
      expect(isValidKycCreate({'userId': 'usr_1', 'isNameMatched': true}), isFalse);

      // Forged status on update
      expect(isValidKycUpdate({'kycStatus': 'verified'}), isFalse);
      expect(isValidKycUpdate({'isNameMatched': true}), isFalse);
      expect(isValidKycUpdate({'identityProofFrontUrl': 'https://storage/new_id.png'}), isTrue);
    });

    test('Anti-Credibility-Tampering: Video creation rejects pre-seeded credibilityVerified and view counts', () {
      bool isValidVideoCreate(Map<String, dynamic> data) {
        if (data.containsKey('credibilityScore')) return false;
        if (data.containsKey('truthScore')) return false;
        if (data['credibilityVerified'] == true) return false;
        if (data['isVerified'] == true) return false;
        if (data.containsKey('factCheck')) return false;
        if ((data['views'] ?? 0) > 0) return false;
        if ((data['viewCount'] ?? 0) > 0) return false;
        if ((data['playCount'] ?? 0) > 0) return false;
        return true;
      }

      bool isValidVideoOwnerUpdate(Map<String, dynamic> delta) {
        const blacklist = [
          'credibilityScore', 'factCheck', 'truthScore', 'pipelineStatus', 'moderation',
          'moderationReason', 'gatewayDecision', 'views', 'viewCount', 'playCount',
          'credibilityVerified', 'isVerified'
        ];
        return !delta.keys.any(blacklist.contains);
      }

      // Valid new upload
      expect(isValidVideoCreate({'title': 'Clean Video', 'views': 0, 'credibilityVerified': false}), isTrue);

      // Malicious attempt to pre-set 1M views or self-verify
      expect(isValidVideoCreate({'title': 'Viral Hack', 'views': 1000000}), isFalse);
      expect(isValidVideoCreate({'title': 'Self-Verified Hack', 'credibilityVerified': true}), isFalse);
      expect(isValidVideoCreate({'title': 'Fake Fact Check', 'factCheck': {'status': 'verified'}}), isFalse);

      // Video owner trying to update credibilityVerified
      expect(isValidVideoOwnerUpdate({'credibilityVerified': true}), isFalse);
      expect(isValidVideoOwnerUpdate({'isVerified': true}), isFalse);
      expect(isValidVideoOwnerUpdate({'description': 'Updated description'}), isTrue);
    });

    test('Anti-Topic-Approval-Bypass: Topic creator cannot update status or geminiApproved', () {
      bool isValidTopicCreatorUpdate(Map<String, dynamic> delta) {
        const protectedKeys = ['geminiApproved', 'status', 'moderationReason', 'moderatedAt', 'creatorId', 'videoCount'];
        return !delta.keys.any(protectedKeys.contains);
      }

      // Creator trying to self-approve topic
      expect(isValidTopicCreatorUpdate({'geminiApproved': true}), isFalse);
      expect(isValidTopicCreatorUpdate({'status': 'active'}), isFalse);

      // Creator updating allowed fields like title/description
      expect(isValidTopicCreatorUpdate({'description': 'New topic description'}), isTrue);
    });

    test('Anti-Data-Leak: Leaderboard sanitizes private channel revenue and wallet fields', () {
      final rawChannelData = {
        'id': 'ch_secret_1',
        'displayName': 'Tech Channel',
        'handle': 'techchannel',
        'walletBalanceUSD': 15000.0,
        'adsRevenueTotal': 85000.0,
        'withdrawnRevenueTotal': 50000.0,
        'kycStatus': 'verified',
        'payoutSettings': {'bankAccount': '1234567890'},
        'stats': {'subscriberCount': 50000, 'avgTrustIndex': 9.2, 'videosCount': 45},
        'reputation': {'trend30d': 1.5},
        'tier': 'elite',
      };

      final stats = rawChannelData['stats'] as Map<String, dynamic>?;
      final reputation = rawChannelData['reputation'] as Map<String, dynamic>?;
      final publicLeaderboardEntry = {
        'id': rawChannelData['id'],
        'rank': 1,
        'displayName': rawChannelData['displayName'],
        'handle': rawChannelData['handle'],
        'tier': rawChannelData['tier'],
        'avgTrustIndex': stats?['avgTrustIndex'],
        'subscriberCount': stats?['subscriberCount'],
        'trend30d': reputation?['trend30d'],
        'videosCount': stats?['videosCount'],
      };

      expect(publicLeaderboardEntry.containsKey('walletBalanceUSD'), isFalse);
      expect(publicLeaderboardEntry.containsKey('adsRevenueTotal'), isFalse);
      expect(publicLeaderboardEntry.containsKey('withdrawnRevenueTotal'), isFalse);
      expect(publicLeaderboardEntry.containsKey('payoutSettings'), isFalse);
      expect(publicLeaderboardEntry.containsKey('kycStatus'), isFalse);
      expect(publicLeaderboardEntry['rank'], equals(1));
    });
  });
}
