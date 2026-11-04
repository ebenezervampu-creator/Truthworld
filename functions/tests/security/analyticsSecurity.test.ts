import * as fs from "fs";
import * as path from "path";
import * as crypto from "crypto";
import { isSafeImageUrl } from "../../src/seo/render/safeImageFetcher";

describe("Surface 9 Security Verification: Watch Time, Analytics, Search & Discovery Defenses", () => {
  const rootDir = path.resolve(__dirname, "../../..");

  // ─── 1. SSRF Safe Image Fetcher (TW-SEO-01) ───────────────────────────────
  describe("TW-SEO-01: SSRF Safe Image URL Validation & Fetcher", () => {
    test("allows valid public HTTPS and HTTP image URLs", () => {
      expect(isSafeImageUrl("https://truthworld.in/images/thumb.jpg")).toBe(true);
      expect(isSafeImageUrl("https://cdn.example.com/avatar.png")).toBe(true);
      expect(isSafeImageUrl("https://images.unsplash.com/photo-12345")).toBe(true);
      expect(isSafeImageUrl("http://example.com/banner.jpg")).toBe(true);
    });

    test("rejects non-HTTP protocols (file, ftp, javascript, data)", () => {
      expect(isSafeImageUrl("file:///etc/passwd")).toBe(false);
      expect(isSafeImageUrl("ftp://ftp.example.com/file.png")).toBe(false);
      expect(isSafeImageUrl("javascript:alert(1)")).toBe(false);
      expect(isSafeImageUrl("data:image/png;base64,iVBORw0KGgoAAAANSUhEUg==")).toBe(false);
    });

    test("rejects loopback and localhost addresses", () => {
      expect(isSafeImageUrl("http://localhost/admin")).toBe(false);
      expect(isSafeImageUrl("http://sub.localhost:8080/image.png")).toBe(false);
      expect(isSafeImageUrl("http://127.0.0.1/secret")).toBe(false);
      expect(isSafeImageUrl("http://127.0.0.2:3000/avatar.jpg")).toBe(false);
      expect(isSafeImageUrl("http://0.0.0.0:80/")).toBe(false);
      expect(isSafeImageUrl("http://[::1]/image.png")).toBe(false);
    });

    test("rejects cloud metadata endpoints (169.254.169.254 & metadata.google.internal)", () => {
      expect(isSafeImageUrl("http://169.254.169.254/computeMetadata/v1/")).toBe(false);
      expect(isSafeImageUrl("http://169.254.169.254/latest/meta-data/")).toBe(false);
      expect(isSafeImageUrl("http://metadata.google.internal/computeMetadata/v1/")).toBe(false);
      expect(isSafeImageUrl("http://metadata.google/computeMetadata/v1/")).toBe(false);
      expect(isSafeImageUrl("http://instance-data.internal/")).toBe(false);
    });

    test("rejects private RFC 1918 IPv4 ranges (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16)", () => {
      expect(isSafeImageUrl("http://10.0.0.1/private.png")).toBe(false);
      expect(isSafeImageUrl("http://10.254.1.5:8080/pic.jpg")).toBe(false);
      expect(isSafeImageUrl("http://172.16.0.1/dashboard.png")).toBe(false);
      expect(isSafeImageUrl("http://172.31.255.255/avatar.png")).toBe(false);
      expect(isSafeImageUrl("http://192.168.1.1/router.jpg")).toBe(false);
      expect(isSafeImageUrl("http://192.168.0.100:9000/card.png")).toBe(false);
    });

    test("rejects empty, null, and malformed URLs", () => {
      expect(isSafeImageUrl("")).toBe(false);
      expect(isSafeImageUrl("   ")).toBe(false);
      expect(isSafeImageUrl(null as any)).toBe(false);
      expect(isSafeImageUrl(undefined as any)).toBe(false);
      expect(isSafeImageUrl("not_a_valid_url")).toBe(false);
    });

    test("verifies SEO renderers import safeFetchImageBuffer instead of direct axios calls", () => {
      const channelRenderer = fs.readFileSync(path.join(rootDir, "functions/src/seo/render/channelCardImageRenderer.ts"), "utf8");
      const videoRenderer = fs.readFileSync(path.join(rootDir, "functions/src/seo/render/videoCardImageRenderer.ts"), "utf8");
      const topicRenderer = fs.readFileSync(path.join(rootDir, "functions/src/seo/render/topicCardImageRenderer.ts"), "utf8");

      expect(channelRenderer).toContain('import { safeFetchImageBuffer } from "./safeImageFetcher";');
      expect(channelRenderer).toContain("safeFetchImageBuffer");
      expect(channelRenderer).not.toContain('axios.get(data.bannerUrl');
      expect(channelRenderer).not.toContain('axios.get(data.avatarUrl');

      expect(videoRenderer).toContain('import { safeFetchImageBuffer } from "./safeImageFetcher";');
      expect(videoRenderer).toContain("safeFetchImageBuffer");
      expect(videoRenderer).not.toContain('axios.get(data.thumbnailUrl');

      expect(topicRenderer).toContain('import { safeFetchImageBuffer } from "./safeImageFetcher";');
      expect(topicRenderer).toContain("safeFetchImageBuffer");
      expect(topicRenderer).not.toContain('axios.get(data.thumbnailUrl');
    });
  });

  // ─── 2. Creator Stats Authentication & Authorization (TW-ANALYTICS-01) ────
  describe("TW-ANALYTICS-01: Creator Analytics Authorization & Origin Lockdown", () => {
    test("verifies getCreatorStats enforces Bearer token authentication and owner authorization", () => {
      const wtContent = fs.readFileSync(path.join(rootDir, "functions/src/watchtime/watchtime.ts"), "utf8");
      const creatorStatsBlock = wtContent.slice(wtContent.indexOf("export const getCreatorStats"));

      expect(creatorStatsBlock).toContain("export const getCreatorStats = onRequest");
      expect(creatorStatsBlock).toContain("TW-ANALYTICS-01: Authentication & Authorization Guard");
      expect(creatorStatsBlock).toContain("Authentication required to access creator statistics.");
      expect(creatorStatsBlock).toContain("callerUid !== creatorId && !isAdminUser");
      expect(creatorStatsBlock).toContain("Access denied. You can only view analytics for your own channel.");
      expect(creatorStatsBlock).not.toContain('res.set("Access-Control-Allow-Origin", "*");');
      expect(creatorStatsBlock).toContain("https://studio.truthworld.in");
    });
  });

  // ─── 3. Watch Time Clamping & Anti-Overflow (TW-ANALYTICS-02) ─────────────
  describe("TW-ANALYTICS-02: Watch Time Clamping & Duration Bounds", () => {
    test("verifies trackWatchEvent caps duration to 24h and clamps positions", () => {
      const wtContent = fs.readFileSync(path.join(rootDir, "functions/src/watchtime/watchtime.ts"), "utf8");

      expect(wtContent).toContain("TW-ANALYTICS-02: Bound video duration to max 24 hours (86,400s)");
      expect(wtContent).toContain("const duration = Math.min(86400, Math.max(1, rawDuration));");
      expect(wtContent).toContain("const position = Math.max(0, Math.min(rawPosition, duration));");
      expect(wtContent).toContain("const prevPosition = rawPrevPosition !== undefined ? Math.max(0, Math.min(rawPrevPosition, duration)) : undefined;");
    });
  });

  // ─── 4. Search Backend Hardening (TW-SEARCH-01 & TW-SEARCH-02) ────────────
  describe("TW-SEARCH-01 & TW-SEARCH-02: Search Sanitization & Discovery Filters", () => {
    test("verifies searchTruthWorld clamps query length to 200 characters and uses SHA-256 caching", () => {
      const searchContent = fs.readFileSync(path.join(rootDir, "functions/src/search/searchBackend.ts"), "utf8");

      expect(searchContent).toContain('import * as crypto from "crypto";');
      expect(searchContent).toContain('crypto.createHash("sha256").update(key).digest("hex");');
      expect(searchContent).toContain('.slice(0, 200)');
    });

    test("verifies searchTruthWorld implements isVideoDiscoverable and excludes suspended channels/topics", () => {
      const searchContent = fs.readFileSync(path.join(rootDir, "functions/src/search/searchBackend.ts"), "utf8");

      expect(searchContent).toContain("function isVideoDiscoverable(vData: admin.firestore.DocumentData): boolean");
      expect(searchContent).toContain('status === "draft"');
      expect(searchContent).toContain('status === "uploading"');
      expect(searchContent).toContain('status === "suspended"');
      expect(searchContent).toContain('status === "blocked"');
      expect(searchContent).toContain('vData.isDeleted === true');
      expect(searchContent).toContain('vData.moderationStatus === "rejected"');
      expect(searchContent).toContain('vData.copyrightStrike === true');

      expect(searchContent).toContain('cData.isSuspended === true');
      expect(searchContent).toContain('cData.isBanned === true');
      expect(searchContent).toContain('cData.isActive === false');
      expect(searchContent).toContain('cData.isPublic === false');

      expect(searchContent).toContain('tData.isActive === false');
      expect(searchContent).toContain('tData.isSuspended === true');
    });

    test("verifies SHA-256 doc ID properties", () => {
      const key = "all:::truth in modern artificial intelligence";
      const docId = crypto.createHash("sha256").update(key).digest("hex");
      expect(docId).toHaveLength(64);
      expect(/^[0-9a-f]{64}$/.test(docId)).toBe(true);
    });
  });

  // ─── 5. AI Search Prompt Injection Defense (TW-SEARCH-03) ─────────────────
  describe("TW-SEARCH-03: AI Search Prompt Injection Defenses", () => {
    test("verifies aiSearchAssistant sanitizes query and encapsulates in <untrusted_user_query> tags", () => {
      const aiSearchContent = fs.readFileSync(path.join(rootDir, "functions/src/search/aiSearch.ts"), "utf8");

      expect(aiSearchContent).toContain('import { sanitizeUntrustedInput } from "../pipeline/services/videoGatewayService";');
      expect(aiSearchContent).toContain("const sanitizedQuery = sanitizeUntrustedInput(query).slice(0, 250);");
      expect(aiSearchContent).toContain("<untrusted_user_query>");
      expect(aiSearchContent).toContain("</untrusted_user_query>");
      expect(aiSearchContent).toContain("CRITICAL SECURITY DIRECTIVE:");
    });
  });

  // ─── 6. Discovery Pagination Bounds (TW-DISCO-01) ─────────────────────────
  describe("TW-DISCO-01: Discovery Pagination Limits", () => {
    test("verifies getLeaderboard and getRisingCreators bound limit to safe integer ranges", () => {
      const discoContent = fs.readFileSync(path.join(rootDir, "functions/src/channels/discovery.ts"), "utf8");

      expect(discoContent).toContain("Math.max(1, Math.min(Math.floor(Number(req.query.limit) || 20), 100))");
      expect(discoContent).toContain("Math.max(1, Math.min(Math.floor(Number(req.query.limit) || 10), 50))");
    });
  });
});
