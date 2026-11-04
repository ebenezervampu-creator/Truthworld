import * as fs from 'fs';
import * as path from 'path';

describe('Financial Economy, Creator Payouts & Cloud Storage Security Tests (Surface 6)', () => {
  const rootDir = path.resolve(__dirname, '../../../');
  const functionsDir = path.resolve(__dirname, '../../');
  const spendWalletPath = path.join(functionsDir, 'src/economy/spendWallet.ts');
  const kycPath = path.join(functionsDir, 'src/economy/kyc.ts');
  const payoutsPath = path.join(functionsDir, 'src/economy/payouts.ts');
  const fraudDetectionPath = path.join(functionsDir, 'src/economy/fraudDetection.ts');
  const monthlyRolloverPath = path.join(functionsDir, 'src/economy/monthlyRollover.ts');
  const storageRulesPath = path.join(rootDir, 'storage.rules');
  const databaseRulesPath = path.join(rootDir, 'database.rules.json');
  const firestoreRulesPath = path.join(rootDir, 'firestore.rules');

  let spendWalletContent: string;
  let kycContent: string;
  let payoutsContent: string;
  let fraudDetectionContent: string;
  let monthlyRolloverContent: string;
  let storageRulesContent: string;
  let databaseRulesContent: string;
  let firestoreRulesContent: string;

  beforeAll(() => {
    spendWalletContent = fs.readFileSync(spendWalletPath, 'utf8');
    kycContent = fs.readFileSync(kycPath, 'utf8');
    payoutsContent = fs.readFileSync(payoutsPath, 'utf8');
    fraudDetectionContent = fs.readFileSync(fraudDetectionPath, 'utf8');
    monthlyRolloverContent = fs.readFileSync(monthlyRolloverPath, 'utf8');
    storageRulesContent = fs.readFileSync(storageRulesPath, 'utf8');
    databaseRulesContent = fs.readFileSync(databaseRulesPath, 'utf8');
    firestoreRulesContent = fs.readFileSync(firestoreRulesPath, 'utf8');
  });

  describe('TW-ECON-01: spendWallet Quota Allocation & Plan Pricing Enforcement (CWE-840)', () => {
    it('enforces server-side unit cost calculation for storageTopup instead of trusting client metadata', () => {
      expect(spendWalletContent).toContain('STORAGE_PACK_COSTS');
      expect(spendWalletContent).toMatch(/spendAmount\s*<\s*pack\.costUSD/);
      expect(spendWalletContent).toContain('Math.floor(spendAmount / 0.10)');
    });

    it('enforces server-side unit cost calculation for bandwidthTopup instead of trusting client metadata', () => {
      expect(spendWalletContent).toContain('BANDWIDTH_PACK_COSTS');
      expect(spendWalletContent).toMatch(/spendAmount\s*<\s*pack\.costUSD/);
      expect(spendWalletContent).toContain('Math.floor(spendAmount / 0.05)');
    });

    it('strictly verifies spendAmount >= planConfig.fee for customChannelPlan upgrades', () => {
      expect(spendWalletContent).toContain('PLAN_TIER_CONFIG');
      expect(spendWalletContent).toMatch(/spendAmount\s*<\s*planConfig\.fee/);
      expect(spendWalletContent).toContain('channelUpdates["infraConfig.planStatus"] = "active"');
    });
  });

  describe('TW-ECON-02: Creator KYC Verification Gate & Anti-Self-Approval (CWE-345)', () => {
    it('guarantees onKycDocumentCreatedOrUpdated never auto-approves kycStatus to verified on client trigger', () => {
      // Must not auto-grant verified status
      expect(kycContent).not.toMatch(/batch\.update\(after\.ref,\s*\{\s*kycStatus:\s*["']verified["']/);
      expect(kycContent).not.toMatch(/batch\.set\(\s*channelRef,\s*\{\s*kycStatus:\s*["']verified["']/);
      expect(kycContent).toContain('kycStatus: "pending"');
      expect(kycContent).toContain('Queued for compliance officer');
    });
  });

  describe('TW-ECON-03: Creator Payout Schedule Gate & Anti-Takeover (CWE-285)', () => {
    it('removes client-controlled data.bypassScheduleCheck from payouts.ts', () => {
      expect(payoutsContent).not.toContain('data.bypassScheduleCheck === true');
      expect(payoutsContent).toContain('const bypassScheduleCheck = channelData.allowAnytimePayout === true;');
    });

    it('prohibits bypassScheduleCheck in firestore.rules on payout_requests create', () => {
      expect(firestoreRulesContent).toContain("(!('bypassScheduleCheck' in request.resource.data) || request.resource.data.bypassScheduleCheck == false)");
    });
  });

  describe('TW-ECON-04: Cloud Storage Stored XSS & Arbitrary Executable Upload Prevention (CWE-434 / CWE-79)', () => {
    it('restricts isValidImage to safe raster image formats and excludes SVG to eliminate Stored XSS', () => {
      expect(storageRulesContent).toContain("request.resource.contentType.matches('image/(jpeg|jpg|png|webp|gif)')");
      expect(storageRulesContent).not.toContain("request.resource.contentType.matches('image/.*')");
    });

    it('restricts isValidKycDocument to safe images or PDF and excludes SVG', () => {
      expect(storageRulesContent).toContain("request.resource.contentType.matches('image/(jpeg|jpg|png|webp)') || request.resource.contentType == 'application/pdf'");
    });

    it('removes arbitrary application/.* and text/.* uploads from video storage paths', () => {
      expect(storageRulesContent).not.toContain("request.resource.contentType.matches('application/.*|text/.*')");
      expect(storageRulesContent).toContain("request.resource.contentType.matches('text/(vtt|plain)')");
    });

    it('enforces system-only write lock on transcripts storage path', () => {
      expect(storageRulesContent).toContain('match /transcripts/{allPaths=**}');
      expect(storageRulesContent).toMatch(/match \/transcripts\/\{allPaths=\*\*\}\s*\{\s*allow read:\s*if true;\s*allow write:\s*if false;\s*allow delete:\s*if false;/);
    });

    it('enforces email_verified == true on isAdmin in storage.rules', () => {
      expect(storageRulesContent).toContain('request.auth.token.admin == true && request.auth.token.email_verified == true');
    });
  });

  describe('TW-ECON-05: Step-Up Auth & Email Verification for Sensitive Admin Financial Actions', () => {
    it('requires email_verified == true and recent authentication in reviewFraudFlag', () => {
      expect(fraudDetectionContent).toContain('token?.admin === true && token?.email_verified === true');
      expect(fraudDetectionContent).toContain('isSessionRecent(authTime, 3600)');
    });

    it('requires email_verified == true in triggerMonthlyAutoDisbursementManual', () => {
      expect(payoutsContent).toContain('request.auth?.token?.admin === true && request.auth?.token?.email_verified === true');
    });
  });

  describe('TW-ECON-06: Realtime Database LiveChat Elimination & Privilege Hardening (CWE-284)', () => {
    it('verifies @truthworld domain matching and liveChat have been eliminated from database.rules.json', () => {
      expect(databaseRulesContent).not.toContain('@truthworld');
      expect(databaseRulesContent).not.toContain('liveChat');
    });
  });

  describe('TW-ECON-07: Anti-Free-Cash Exploits in monthlyZeroWasteRollover (CWE-840)', () => {
    it('requires active paid custom plan and checks fraudReviewFlag before awarding rollover credit', () => {
      expect(monthlyRolloverContent).toContain('infra.planStatus === "active" && !data.fraudReviewFlag && !data.payoutsBlocked');
      expect(monthlyRolloverContent).toContain('const planBudget = isPlanActive ? Number(infra.flatPlatformFee || 0) : 0;');
    });
  });
});
