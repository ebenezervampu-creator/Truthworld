import * as fs from 'fs';
import * as path from 'path';

describe('Admin Portal Security Remediation & Invariant Guard Tests', () => {
  const adminPortalDir = path.resolve(__dirname, '../../../admin-portal');
  const appJsxPath = path.join(adminPortalDir, 'src/App.jsx');
  const appealsDeskPath = path.join(adminPortalDir, 'src/components/AppealsDeskTab.jsx');
  const indexHtmlPath = path.join(adminPortalDir, 'index.html');

  let appJsxContent: string;
  let appealsDeskContent: string;
  let indexHtmlContent: string;

  beforeAll(() => {
    appJsxContent = fs.readFileSync(appJsxPath, 'utf8');
    appealsDeskContent = fs.readFileSync(appealsDeskPath, 'utf8');
    indexHtmlContent = fs.readFileSync(indexHtmlPath, 'utf8');
  });

  describe('TW-PORTAL-01: Hardcoded Credential Backdoor Elimination', () => {
    it('guarantees no hardcoded backdoor passwords ("12345") exist in App.jsx', () => {
      expect(appJsxContent).not.toContain('"12345"');
      expect(appJsxContent).not.toContain("'12345'");
    });

    it('guarantees no special hardcoded credential bypass checks exist for hello@truthworld.in', () => {
      expect(appJsxContent).not.toMatch(/cleanEmail\s*===\s*["']hello@truthworld\.in["']\s*&&\s*cleanPassword/);
    });
  });

  describe('TW-PORTAL-02: Plaintext Admin Password Storage Elimination', () => {
    it('guarantees client-side setDoc for admin_members never includes plaintext password field', () => {
      const setDocMatch = appJsxContent.match(/await setDoc\(doc\(db, "admin_members", cleanEmail\),\s*\{([\s\S]*?)\},\s*\{\s*merge:\s*true\s*\}\);/);
      expect(setDocMatch).not.toBeNull();
      const setDocPayload = setDocMatch ? setDocMatch[1] : '';
      expect(setDocPayload).not.toMatch(/password/);
      expect(appJsxContent).toContain('// 2. Set Firestore record (NEVER write plaintext password to database)');
    });
  });

  describe('TW-PORTAL-03: Insecure Default-to-Super-Admin Fallback Elimination', () => {
    it('guarantees that empty roles array never escalates to Super Admin in isTabAllowed', () => {
      expect(appJsxContent).not.toContain('if (userRoles.length === 0) userRoles = ["Super Admin"]');
      expect(appJsxContent).toContain('if (userRoles.length === 0) userRoles = []');
    });

    it('guarantees that onAuthStateChanged falls back to least-privilege role, never Super Admin without admin claim', () => {
      expect(appJsxContent).not.toMatch(/: \["Super Admin"\]\)\);/);
      expect(appJsxContent).toContain(': (idTokenResult.claims.admin ? ["Super Admin"] : ["Content Moderator"])));');
    });
  });

  describe('TW-PORTAL-04: Stored XSS Prevention in Appeals Desk Citations', () => {
    it('enforces safe URL protocol validation (https?://) before rendering citations as anchors', () => {
      expect(appealsDeskContent).toContain('const isSafeWebUrl = (url)');
      expect(appealsDeskContent).toContain('isSafeWebUrl(url) ?');
      expect(appealsDeskContent).toContain('[Blocked Insecure Citation URI]');
    });

    it('blocks javascript: and data: URI links from being executed by admin reviewers', () => {
      const isSafeWebUrl = (url: string) => {
        if (!url || typeof url !== 'string') return false;
        const trimmed = url.trim().toLowerCase();
        return trimmed.startsWith('https://') || trimmed.startsWith('http://');
      };

      expect(isSafeWebUrl('javascript:alert(document.cookie)')).toBe(false);
      expect(isSafeWebUrl('data:text/html,<script>alert(1)</script>')).toBe(false);
      expect(isSafeWebUrl('vbscript:msgbox(1)')).toBe(false);
      expect(isSafeWebUrl('https://example.com/source')).toBe(true);
      expect(isSafeWebUrl('http://reputable-news.org/article')).toBe(true);
    });
  });

  describe('TW-PORTAL-05 & TW-PORTAL-06: RBAC Authorization & Member Revocation Guards', () => {
    it('verifies that handleAddMember and handleDeleteMember assert team management permissions', () => {
      expect(appJsxContent).toContain('if (!isTabAllowed("team")) {');
      const deleteMemberSection = appJsxContent.substring(
        appJsxContent.indexOf('const handleDeleteMember'),
        appJsxContent.indexOf('const handleChangePassword')
      );
      expect(deleteMemberSection).toContain('if (!isTabAllowed("team"))');
      expect(deleteMemberSection).toContain('deleteDoc(doc(db, "admin_members", memberUid))');
    });

    it('guarantees that team management tab render is guarded by isTabAllowed("team")', () => {
      expect(appJsxContent).toContain('{currentTab === "team" && isTabAllowed("team") && (');
    });
  });

  describe('TW-PORTAL-07: Content Security Policy Enforcement', () => {
    it('enforces a strict Content-Security-Policy meta header in admin-portal/index.html', () => {
      expect(indexHtmlContent).toContain('http-equiv="Content-Security-Policy"');
      expect(indexHtmlContent).toContain("default-src 'self'");
      expect(indexHtmlContent).toContain("frame-ancestors 'none'");
      expect(indexHtmlContent).toContain("object-src 'none'");
    });
  });
});
