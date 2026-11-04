import * as fs from 'fs';
import * as path from 'path';

describe('Surface 12: SEO Server, SWR Task Queues, Pipeline Triggers & Comprehensive Security Headers', () => {
  const functionsRoot = path.resolve(__dirname, '../../src');

  describe('TW-SEO-02: SEO Server Security Headers & Embed Frame Isolation (CWE-1021 / CWE-693)', () => {
    it('verifies seoServer imports and calls applySecurityHeaders and removes X-Frame-Options on embed', () => {
      const code = fs.readFileSync(path.join(functionsRoot, 'seo/seoServer.ts'), 'utf-8');
      expect(code).toContain('import { applySecurityHeaders } from "../utils/securityHeaders";');
      expect(code).toContain('applySecurityHeaders(res);');
      expect(code).toContain('res.removeHeader("X-Frame-Options");');
      expect(code).toContain('frame-ancestors *;');
    });
  });

  describe('TW-SWR-01: SWR Task Queue Payload Validation & Resource Exhaustion Defense (CWE-400 / CWE-20)', () => {
    it('validates claimIds and cacheKeys array types and bounds maximum claims to 50', () => {
      const code = fs.readFileSync(path.join(functionsRoot, 'swr/swrQueues.ts'), 'utf-8');
      expect(code).toContain('Array.isArray(payload.claimIds)');
      expect(code).toContain('Array.isArray(payload.cacheKeys)');
      expect(code).toContain('payload.claimIds.length > 50');
      expect(code).toContain('payload.cacheKeys.length > 50');
    });
  });

  describe('TW-USERMGMT-01: User Management Security Headers & Clickjacking Defense (CWE-1021)', () => {
    it('enforces applySecurityHeaders across all userManagement HTTP endpoints', () => {
      const code = fs.readFileSync(path.join(functionsRoot, 'admin/userManagement.ts'), 'utf-8');
      expect(code).toContain('import { applySecurityHeaders } from "../utils/securityHeaders";');
      // Verify all 4 onRequest endpoints invoke applySecurityHeaders
      const matches = code.match(/applySecurityHeaders\(res\)/g);
      expect(matches).not.toBeNull();
      expect(matches!.length).toBeGreaterThanOrEqual(4);
    });
  });

  describe('TW-PIPETRIGGER-01: Video AI Features On-Demand Error Sanitization & Headers (CWE-209 / CWE-693)', () => {
    it('applies security headers and sanitizes developer errors in triggerVideoAIFeatures', () => {
      const code = fs.readFileSync(path.join(functionsRoot, 'pipeline/pipelineTriggers.ts'), 'utf-8');
      expect(code).toContain('applySecurityHeaders(res);');
      expect(code).toContain('Unable to trigger AI features. Please try again.');
      expect(code).not.toContain('error instanceof Error ? error.message :');
    });
  });

  describe('TW-PUBLISH-01: Publishing Admin Endpoints Security Headers Enforcement (CWE-693)', () => {
    it('enforces applySecurityHeaders across manual publishing endpoints', () => {
      const code = fs.readFileSync(path.join(functionsRoot, 'publishing/adminEndpoints.ts'), 'utf-8');
      expect(code).toContain('import { applySecurityHeaders } from "../utils/securityHeaders";');
      const matches = code.match(/applySecurityHeaders\(res\)/g);
      expect(matches).not.toBeNull();
      expect(matches!.length).toBeGreaterThanOrEqual(3);
    });
  });

  describe('TW-CHANNELS-02: Following Feed Security Headers & Error Sanitization (CWE-693 / CWE-209)', () => {
    it('applies security headers and returns polite standard English errors in getFollowingFeed', () => {
      const code = fs.readFileSync(path.join(functionsRoot, 'channels/social.ts'), 'utf-8');
      expect(code).toContain('applySecurityHeaders(res);');
      expect(code).toContain('Unable to load following feed. Please try again.');
      expect(code).not.toContain('res.status(500).json({ error: "Internal error" })');
    });
  });

  describe('TW-MODERATION-02: Manual Content Moderation Security Headers (CWE-693)', () => {
    it('enforces applySecurityHeaders in moderateContentManual', () => {
      const code = fs.readFileSync(path.join(functionsRoot, 'moderation/contentModeration.ts'), 'utf-8');
      expect(code).toContain('applySecurityHeaders(res);');
    });
  });

  describe('TW-AICRED-01: AI Credibility Chat Security Headers (CWE-693)', () => {
    it('enforces applySecurityHeaders in streamCredibilityAiChat', () => {
      const code = fs.readFileSync(path.join(functionsRoot, 'pipeline/aiCredibilityChat.ts'), 'utf-8');
      expect(code).toContain('applySecurityHeaders(res);');
    });
  });

  describe('TW-LIFECYCLE-01: Account Purge Endpoint Security Headers (CWE-693)', () => {
    it('enforces applySecurityHeaders in purgeUserAccount', () => {
      const code = fs.readFileSync(path.join(functionsRoot, 'users/userLifecycle.ts'), 'utf-8');
      expect(code).toContain('applySecurityHeaders(res);');
    });
  });
});
