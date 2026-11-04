import * as fs from "fs";
import * as path from "path";

describe("Surface 7: Platform Manifests, Hosting & Configuration Security", () => {
  const rootDir = path.resolve(__dirname, "../../..");

  test("TW-PLAT-01: Android Manifest explicitly unexports third-party UCropActivity", () => {
    const manifestPath = path.join(rootDir, "android/app/src/main/AndroidManifest.xml");
    const content = fs.readFileSync(manifestPath, "utf8");
    
    // Assert UCropActivity has android:exported="false"
    const ucropRegex = /<activity\s+[^>]*android:name="com\.yalantis\.ucrop\.UCropActivity"[^>]*android:exported="false"/s;
    const alternateUcropRegex = /<activity\s+[^>]*android:exported="false"[^>]*android:name="com\.yalantis\.ucrop\.UCropActivity"/s;
    expect(ucropRegex.test(content) || alternateUcropRegex.test(content)).toBe(true);
  });

  test("TW-PLAT-01: Android Manifest strictly enables autoVerify on HTTPS App Links", () => {
    const manifestPath = path.join(rootDir, "android/app/src/main/AndroidManifest.xml");
    const content = fs.readFileSync(manifestPath, "utf8");
    
    expect(content).toContain('android:autoVerify="true"');
    expect(content).toContain('android:scheme="https" android:host="www.truthworld.in"');
    expect(content).toContain('android:scheme="https" android:host="truthworld.in"');
    expect(content).toContain('android:allowBackup="false"');
  });

  test("TW-PLAT-02: Web App Shell has Content Security Policy meta tag", () => {
    const webIndexPath = path.join(rootDir, "web/index.html");
    const content = fs.readFileSync(webIndexPath, "utf8");
    
    expect(content).toContain('<meta http-equiv="Content-Security-Policy"');
    expect(content).toContain("default-src 'self'");
    expect(content).toContain("object-src 'none'");
    expect(content).toContain("base-uri 'self'");
  });

  test("TW-PLAT-03: Firebase Hosting eliminates script-src https wildcard on checkout & payment-result", () => {
    const firebaseJsonPath = path.join(rootDir, "firebase.json");
    const json = JSON.parse(fs.readFileSync(firebaseJsonPath, "utf8"));
    
    const webApp = json.hosting.find((h: any) => h.target === "web-app");
    expect(webApp).toBeDefined();

    const paymentResultHeader = webApp.headers.find((h: any) => h.source === "/payment-result" || h.source === "/payment-result/**");
    expect(paymentResultHeader).toBeDefined();

    const csp = paymentResultHeader.headers.find((k: any) => k.key === "Content-Security-Policy");
    expect(csp).toBeDefined();
    // Verify script-src does not allow wildcard https:
    expect(csp.value).not.toMatch(/script-src\s+[^;]*https:\s*;/);
    expect(csp.value).toContain("https://sdk.cashfree.com");
  });

  test("TW-PLAT-04: Firebase Hosting enforces hardened CSP on Admin Portal without unsafe-inline or wasm-eval", () => {
    const firebaseJsonPath = path.join(rootDir, "firebase.json");
    const json = JSON.parse(fs.readFileSync(firebaseJsonPath, "utf8"));
    
    const adminPortal = json.hosting.find((h: any) => h.target === "admin-portal");
    expect(adminPortal).toBeDefined();

    const globalHeader = adminPortal.headers.find((h: any) => h.source === "**");
    expect(globalHeader).toBeDefined();

    const csp = globalHeader.headers.find((k: any) => k.key === "Content-Security-Policy");
    expect(csp).toBeDefined();
    expect(csp.value).not.toContain("script-src 'self' 'unsafe-inline'");
    expect(csp.value).not.toContain("wasm-unsafe-eval");
    expect(csp.value).toContain("frame-ancestors 'none'");
  });

  test("TW-PLAT-05: macOS Release and Debug entitlements grant required network and media client permissions", () => {
    const releasePath = path.join(rootDir, "macos/Runner/Release.entitlements");
    const debugPath = path.join(rootDir, "macos/Runner/DebugProfile.entitlements");
    
    const releaseContent = fs.readFileSync(releasePath, "utf8");
    const debugContent = fs.readFileSync(debugPath, "utf8");

    // Both must have client network entitlement for Firebase / Cloud Functions
    expect(releaseContent).toContain("<key>com.apple.security.network.client</key>");
    expect(releaseContent).toContain("<true/>");
    expect(releaseContent).toContain("<key>com.apple.security.device.audio-input</key>");
    expect(releaseContent).toContain("<key>com.apple.security.device.camera</key>");

    expect(debugContent).toContain("<key>com.apple.security.network.client</key>");
    expect(debugContent).toContain("<true/>");
    expect(debugContent).toContain("<key>com.apple.security.device.audio-input</key>");
    expect(debugContent).toContain("<key>com.apple.security.device.camera</key>");
  });

  test("TW-PLAT-06: Service Worker excludes payment flows, checkouts, and Cloud Function APIs from caching", () => {
    const swPath = path.join(rootDir, "web/sw.js");
    const content = fs.readFileSync(swPath, "utf8");

    expect(content).toContain("url.pathname.startsWith('/__/')");
    expect(content).toContain("url.pathname.startsWith('/checkout')");
    expect(content).toContain("url.pathname.startsWith('/payment-result')");
    expect(content).toContain("url.pathname.startsWith('/api/')");
  });

  test("TW-PLAT-07: iOS Info.plist disables arbitrary loads and locks transport security", () => {
    const plistPath = path.join(rootDir, "ios/Runner/Info.plist");
    const content = fs.readFileSync(plistPath, "utf8");

    expect(content).toContain("<key>NSAllowsArbitraryLoads</key>");
    expect(content).toContain("<false/>");
    expect(content).toContain("<key>NSAllowsLocalNetworking</key>");
    expect(content).toContain("<true/>");
  });
});
