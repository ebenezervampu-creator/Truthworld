import * as fs from 'fs';
import * as path from 'path';
import { EmailService, escapeEmailHtml, sanitizeHeaderValue, isValidEmailAddress } from '../../src/services/emailService';

describe('Surface 13: Email Security Hardening, CRLF Header Injection & Pipeline Edge Sanitization', () => {
  const functionsRoot = path.resolve(__dirname, '../../src');

  describe('TW-EMAIL-01: Email HTML Injection & Stored XSS Prevention (CWE-79 / CWE-80)', () => {
    it('escapes dangerous HTML characters in welcome email template', () => {
      const maliciousName = '<script>alert("xss")</script><a href="http://evil.com">Click</a>';
      const html = EmailService.generateWelcomeEmailHtml(maliciousName);

      expect(html).not.toContain('<script>');
      expect(html).not.toContain('<a href="http://evil.com">');
      expect(html).toContain('&lt;script&gt;alert(&quot;xss&quot;)&lt;/script&gt;');
    });

    it('escapes dangerous HTML characters in channel welcome email template', () => {
      const maliciousChannel = '<img src=x onerror=alert(1)>';
      const maliciousOwner = '<script>evil()</script>';
      const maliciousHandle = '<bad>';

      const html = EmailService.generateChannelWelcomeEmailHtml(
        maliciousChannel,
        maliciousOwner,
        maliciousHandle
      );

      expect(html).not.toContain('<img src=x onerror=alert(1)>');
      expect(html).not.toContain('<script>evil()</script>');
      expect(html).not.toContain('<bad>');
      expect(html).toContain('&lt;img src=x onerror=alert(1)&gt;');
      expect(html).toContain('&lt;script&gt;evil()&lt;/script&gt;');
      expect(html).toContain('@&lt;bad&gt;');
    });

    it('escapes dangerous HTML in admin credentials email template', () => {
      const html = EmailService.generateAdminCredentialsEmailHtml({
        to: 'admin@truthworld.in',
        username: '<hacker>',
        password: 'pass<word>&"\'',
        role: '<script>director</script>',
        displayName: '<Director>',
        portalUrl: 'https://truthworld.in/admin?param="><script>alert(1)</script>',
      });

      expect(html).not.toContain('<hacker>');
      expect(html).not.toContain('<script>director</script>');
      expect(html).not.toContain('<Director>');
      expect(html).toContain('&lt;hacker&gt;');
      expect(html).toContain('&lt;script&gt;director&lt;/script&gt;');
      expect(html).toContain('&lt;Director&gt;');
      expect(html).toContain('pass&lt;word&gt;&amp;&quot;&#039;');
    });

    it('verifies escapeEmailHtml utility handles null, undefined and special characters safely', () => {
      expect(escapeEmailHtml(null)).toBe('');
      expect(escapeEmailHtml(undefined)).toBe('');
      expect(escapeEmailHtml('&<>"\'')).toBe('&amp;&lt;&gt;&quot;&#039;');
    });
  });

  describe('TW-EMAIL-02: SMTP CRLF Header Injection & Recipient Address Validation (CWE-93 / CWE-20)', () => {
    it('rejects recipient email addresses containing CRLF injection payloads', () => {
      expect(isValidEmailAddress('victim@truthworld.in\r\nBcc: evil@attacker.com')).toBe(false);
      expect(isValidEmailAddress('victim@truthworld.in\nCc: evil@attacker.com')).toBe(false);
      expect(isValidEmailAddress('victim@truthworld.in\rSubject: Injected')).toBe(false);
      expect(isValidEmailAddress('plainaddress')).toBe(false);
      expect(isValidEmailAddress('@missinguser.com')).toBe(false);
      expect(isValidEmailAddress('user@')).toBe(false);
    });

    it('accepts valid, standard email addresses', () => {
      expect(isValidEmailAddress('creator@truthworld.in')).toBe(true);
      expect(isValidEmailAddress('user.name+tag@example.co.uk')).toBe(true);
      expect(isValidEmailAddress('hello@truthworld.app')).toBe(true);
    });

    it('strips carriage returns and line feeds in sanitizeHeaderValue', () => {
      expect(sanitizeHeaderValue('Welcome\r\nBcc: attacker@evil.com')).toBe('Welcome  Bcc: attacker@evil.com');
      expect(sanitizeHeaderValue('Title\nWith\nNewlines\r')).toBe('Title With Newlines');
      expect(sanitizeHeaderValue(null)).toBe('');
      expect(sanitizeHeaderValue(undefined)).toBe('');
    });

    it('enforces isValidEmailAddress across sendWelcomeEmail, sendChannelWelcomeEmail, and sendAdminCredentialsEmail', () => {
      const code = fs.readFileSync(path.join(functionsRoot, 'services/emailService.ts'), 'utf-8');
      const matches = code.match(/isValidEmailAddress\(to\)/g);
      expect(matches).not.toBeNull();
      expect(matches!.length).toBeGreaterThanOrEqual(3);
    });
  });

  describe('TW-EDGE-01: Pipeline Edge Layer Error Sanitization (CWE-209)', () => {
    it('verifies 01-edge.ts unhandled submit error returns user-friendly message', () => {
      const code = fs.readFileSync(path.join(functionsRoot, 'pipeline/layers/01-edge.ts'), 'utf-8');
      expect(code).toContain('Unable to process video submission. Please try again.');
      expect(code).not.toContain('error instanceof Error ? error.message : "Internal error"');
    });
  });
});
