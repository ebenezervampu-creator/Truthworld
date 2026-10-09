import { applySecurityHeaders, isSessionRecent } from '../../src/utils/securityHeaders';

describe('Unit: Security Headers & Session Utilities', () => {
  it('applies standard enterprise security headers to response', () => {
    const headers: Record<string, string> = {};
    const mockRes = {
      setHeader: (key: string, val: string) => {
        headers[key] = val;
      },
    };

    applySecurityHeaders(mockRes as any);

    expect(headers['X-Content-Type-Options']).toBe('nosniff');
    expect(headers['X-Frame-Options']).toBe('DENY');
    expect(headers['Strict-Transport-Security']).toBe('max-age=31536000; includeSubDomains; preload');
    expect(headers['Referrer-Policy']).toBe('strict-origin-when-cross-origin');
    expect(headers['Permissions-Policy']).toBe(
      'accelerometer=(), camera=(), geolocation=(), gyroscope=(), magnetometer=(), microphone=(), payment=(self "https://*.cashfree.com" "https://sdk.cashfree.com"), usb=()'
    );
    expect(headers['Cross-Origin-Opener-Policy']).toBe('same-origin-allow-popups');
    expect(headers['Cross-Origin-Resource-Policy']).toBe('cross-origin');
  });

  it('correctly assesses recent session within maxAgeSeconds', () => {
    const nowSec = Math.floor(Date.now() / 1000);
    // 5 minutes ago (300s) with 3600s threshold -> recent
    expect(isSessionRecent(nowSec - 300, 3600)).toBe(true);
    // 2 hours ago (7200s) with 3600s threshold -> expired / not recent
    expect(isSessionRecent(nowSec - 7200, 3600)).toBe(false);
  });

  it('fails closed when authTime is zero or missing', () => {
    expect(isSessionRecent(0, 3600)).toBe(false);
    expect(isSessionRecent(undefined as any, 3600)).toBe(false);
  });
});
