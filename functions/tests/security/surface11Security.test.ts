import * as fs from 'fs';
import * as path from 'path';

describe('Surface 11: Ecosystem Edge Cases, Verification Queues, View Fraud, A/B Experiments & Governance Security', () => {
  const functionsRoot = path.resolve(__dirname, '../../src');

  describe('TW-DELETE-01: Permanently Delete Video Document Check & Verified Admin (CWE-285)', () => {
    it('verifies permanentlyDeleteVideo throws not-found when video document does not exist and enforces isCallableAdmin', () => {
      const code = fs.readFileSync(path.join(functionsRoot, 'publishing/videoDeletionTrigger.ts'), 'utf-8');
      expect(code).toContain('if (!videoSnap.exists) {');
      expect(code).toContain('throw new HttpsError("not-found", "Video not found.");');
      expect(code).toContain('isCallableAdmin(request.auth)');
      expect(code).not.toContain('const isAdmin = Boolean(request.auth.token.admin);');
    });
  });

  describe('TW-PHASE-01: Platform Phase Governance & Director Privilege Enforcement (CWE-284)', () => {
    it('requires verified email and recent authentication in platformPhaseAdmin.ts', () => {
      const code = fs.readFileSync(path.join(functionsRoot, 'admin/platformPhaseAdmin.ts'), 'utf-8');
      expect(code).toContain('isEmailVerified');
      expect(code).toContain('token.email_verified === true');
      expect(code).toContain('isSessionRecent(authTime, 3600)');
      expect(code).not.toContain('email === "hello@truthworld.in" ||');
    });
  });

  describe('TW-MEMBERS-01: Admin Credentials Dispatch Privilege Escalation Defense (CWE-287)', () => {
    it('requires email_verified == true for owner accounts and forbids unverified spoofing', () => {
      const code = fs.readFileSync(path.join(functionsRoot, 'admin/adminMemberEndpoints.ts'), 'utf-8');
      expect(code).toContain('isEmailVerified');
      expect(code).toContain('token.email_verified === true');
      expect(code).toContain('Super Admin or Owner privileges required.');
    });
  });

  describe('TW-FRAUD-01: View Fraud Rollback Administration Defense (CWE-285)', () => {
    it('enforces isCallableAdmin and validates videoId regex in rollbackFraudulentViews', () => {
      const code = fs.readFileSync(path.join(functionsRoot, 'fraud/viewFraudDetection.ts'), 'utf-8');
      expect(code).toContain('isCallableAdmin(request.auth)');
      expect(code).toContain('^[a-zA-Z0-9_-]{5,64}$');
    });
  });

  describe('TW-EXP-01: A/B Testing Experiment Engine Admin Verification (CWE-285)', () => {
    it('enforces isCallableAdmin on create/manage and isCallableRecentAdmin on graduate', () => {
      const code = fs.readFileSync(path.join(functionsRoot, 'experiments/engine.ts'), 'utf-8');
      expect(code).toContain('isCallableAdmin(request.auth)');
      expect(code).toContain('isCallableRecentAdmin(request.auth, 3600)');
      expect(code).not.toContain('request.auth?.token?.admin !== true');
    });
  });

  describe('TW-ECONOMY-01: Zero Raw Developer Error Policy in Financial & Governance Endpoints (CWE-209)', () => {
    it('guarantees spendWallet, settlementService, premiumRevenueDistribution, payouts, and appealsDeskEndpoints never leak raw err.message', () => {
      const spendWallet = fs.readFileSync(path.join(functionsRoot, 'economy/spendWallet.ts'), 'utf-8');
      const settlement = fs.readFileSync(path.join(functionsRoot, 'economy/settlementService.ts'), 'utf-8');
      const premium = fs.readFileSync(path.join(functionsRoot, 'economy/premiumRevenueDistribution.ts'), 'utf-8');
      const payouts = fs.readFileSync(path.join(functionsRoot, 'economy/payouts.ts'), 'utf-8');
      const appeals = fs.readFileSync(path.join(functionsRoot, 'pipeline/appealsDeskEndpoints.ts'), 'utf-8');

      expect(spendWallet).toContain('isCallableAdmin(request.auth)');
      expect(spendWallet).not.toContain('err?.message || "Failed to process wallet transaction."');

      expect(settlement).toContain('isCallableAdmin(request.auth)');
      expect(settlement).not.toContain('err?.message || "Failed to reconcile settlement."');

      expect(premium).toContain('isCallableAdmin(request.auth)');
      expect(premium).not.toContain('err?.message || "Distribution failed."');

      expect(payouts).not.toContain('err?.message || "Failed to trigger auto disbursement."');
      expect(appeals).not.toContain('err?.message || "Failed to verify governance audit log chain."');
    });
  });

  describe('TW-ADS-02: Advertising Revenue Breakdown & Audit Access Control (CWE-285)', () => {
    it('verifies getAdImpressionAudit and getAdRevenueBreakdown enforce isCallableAdmin', () => {
      const code = fs.readFileSync(path.join(functionsRoot, 'ads/adRevenueDistribution.ts'), 'utf-8');
      expect(code).toContain('isCallableAdmin(request.auth)');
      expect(code).not.toContain('userData.role === "admin"');
    });
  });

  describe('TW-UNITECO-01: Unit Economics Dashboard Access Control (CWE-285)', () => {
    it('verifies getUnitEconomicsDashboard enforces isCallableAdmin with verified email', () => {
      const code = fs.readFileSync(path.join(functionsRoot, 'admin/unitEconomics.ts'), 'utf-8');
      expect(code).toContain('isCallableAdmin(request.auth)');
      expect(code).not.toContain('const isAdmin = request.auth?.token?.admin === true;');
    });
  });

  describe('TW-CHANNELS-01: Content Moderation Prompt Injection Defense in Channel Registration (CWE-77)', () => {
    it('wraps channel registration parameters in untrusted XML tags and sanitizes input', () => {
      const code = fs.readFileSync(path.join(functionsRoot, 'channels/channels.ts'), 'utf-8');
      expect(code).toContain('sanitizeUntrustedInput');
      expect(code).toContain('<untrusted_channel_metadata>');
      expect(code).toContain('</untrusted_channel_metadata>');
    });
  });

  describe('TW-ERRORS-01: Zero Raw Developer Error & Security Headers Policy across Verification & Moderation (CWE-209)', () => {
    it('guarantees moderation and verification endpoints apply security headers and never leak details: String(err)', () => {
      const chanMod = fs.readFileSync(path.join(functionsRoot, 'channels/moderation.ts'), 'utf-8');
      const topicMod = fs.readFileSync(path.join(functionsRoot, 'topics/moderation.ts'), 'utf-8');
      const verif = fs.readFileSync(path.join(functionsRoot, 'verification/verification.ts'), 'utf-8');
      const bulkMod = fs.readFileSync(path.join(functionsRoot, 'admin/adminBulkModerate.ts'), 'utf-8');

      expect(chanMod).not.toContain('details: String(err)');
      expect(chanMod).toContain('applySecurityHeaders(res)');

      expect(topicMod).not.toContain('details: String(err)');
      expect(topicMod).toContain('applySecurityHeaders(res)');

      expect(verif).not.toContain('details: String(err)');
      expect(verif).not.toContain('res.status(500).json({ error: err.message');
      expect(verif).toContain('applySecurityHeaders(res)');

      expect(bulkMod).not.toContain('error: e.message');
      expect(bulkMod).not.toContain('error: r.reason');
      expect(bulkMod).toContain('applySecurityHeaders(res)');
    });
  });
});
