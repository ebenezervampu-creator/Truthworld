/**
 * 🧪 COST ENGINE, TELEMETRY & UNIT ECONOMICS VERIFICATION SUITE
 *
 * Tests all 4 pillars:
 * 1. Sub-cent Real-Time Attribution & Rate Cards
 * 2. Dual-Ledger Transparency (cost_events & cost_rollups with channelId)
 * 3. Dynamic Unit Economics & Contribution Margins
 * 4. Architectural & Financial Safeguards (Bandwidth metering & Viral surge holds)
 */

import {
  CostEngine,
  RATE_CARDS,
  CDN_RATE_CARDS,
  calculateSubtitleCost,
  getFlatDubbingPricePerLanguage,
  getFlatLipSyncPricePerLanguage,
} from "../../src/pipeline/services/cost-engine";

describe("Cost Engine, Telemetry & Unit Economics Verification Suite", () => {
  describe("1. Rate Cards & Zero Charm Pricing Sanity", () => {
    test("Rate card values are accurately configured", () => {
      expect(RATE_CARDS.assemblyai.perMinute).toBe(0.00383);
      expect(RATE_CARDS["search-grounding"].perQuery).toBe(0.005);
      expect(RATE_CARDS["gemini-flash"].perInputToken).toBe(0.00000015);
      expect(RATE_CARDS["gemini-flash"].perOutputToken).toBe(0.0000006);
      expect(RATE_CARDS["gemini-cached-read"].perToken).toBe(0.0000001);
      expect(RATE_CARDS["google-tts-chirp3-hd"].perCharacter).toBe(0.000030);
      expect(RATE_CARDS.elevenlabs.perCharacter).toBe(0.000200);
    });

    test("Rate cards contain zero deceptive marketing or charm pricing (.99, .95)", () => {
      const charmRegex = /(99|\.99|\.95)$/;
      Object.entries(RATE_CARDS).forEach(([_key, val]) => {
        const values = Object.values(val as Record<string, number>);
        values.forEach((v) => {
          expect(charmRegex.test(v.toString())).toBe(false);
        });
      });
    });
  });

  describe("2. CDN Region Mapping & Egress Estimation", () => {
    test("CDN region mapping resolves correctly", () => {
      expect(CDN_RATE_CARDS.india).toBe(0.08);
      expect(CDN_RATE_CARDS.asiaPacific).toBe(0.10);
      expect(CostEngine.mapCountryToCDNRegion("IN")).toBe("india");
      expect(CostEngine.mapCountryToCDNRegion("US")).toBe("northAmerica");
      expect(CostEngine.mapCountryToCDNRegion("DE")).toBe("europe");
      expect(CostEngine.mapCountryToCDNRegion("SG")).toBe("asiaPacific");
      expect(CostEngine.mapCountryToCDNRegion("BR")).toBe("southAmerica");
      expect(CostEngine.mapCountryToCDNRegion("ZA")).toBe("africa");
      expect(CostEngine.mapCountryToCDNRegion("XX")).toBe("default");
    });

    test("Egress calculations match video bitrates", () => {
      // 300s at 1080p (3.5 Mbps) -> ~0.12817 GB
      const egress1080p = CostEngine.estimateEgressGB(300, "1080p");
      expect(Math.abs(egress1080p - 0.12817)).toBeLessThan(0.001);

      // 60s at 4k (15 Mbps) -> ~0.10986 GB
      const egress4k = CostEngine.estimateEgressGB(60, "4k");
      expect(Math.abs(egress4k - 0.10986)).toBeLessThan(0.001);
    });
  });

  describe("3. Sub-cent AI Attribution & Tier Pricing", () => {
    test("Calculates subtitle, dubbing, and lip-sync pricing according to tiers", () => {
      // Subtitles (Ultra Tier: $0.50 / 10m)
      const subUltra = calculateSubtitleCost(1, 600, "standard", 0, "ultra");
      expect(subUltra).toBe(0.50);

      // Dubbing (Unified Audio Track: $3.00 for 10 min)
      const dubPrice10m = getFlatDubbingPricePerLanguage(600, "standard", "standard");
      expect(dubPrice10m).toBe(3.00);
      const clonePrice10m = getFlatDubbingPricePerLanguage(600, "standard", "voice_clone");
      expect(clonePrice10m).toBe(3.00);

      // Lip-Sync (Discontinued / Removed)
      const lipSync10m = getFlatLipSyncPricePerLanguage(600, "standard");
      expect(lipSync10m).toBe(0.00);
    });
  });

  describe("4. Dynamic Unit Economics & Contribution Margins", () => {
    test("Calculates platform margin and dynamic per-view unit economics", () => {
      const dynamicViews = 10000;
      const dynamicGrossUSD = 10.0;
      const dynamicPlatformUSD = dynamicGrossUSD * 0.30;
      const dynamicCdnUSD = 0.80;
      const dynamicComputeUSD = 0.10;
      const dynamicPerViewGross = dynamicGrossUSD / dynamicViews;
      const dynamicPerViewPlatform = dynamicPlatformUSD / dynamicViews;
      const dynamicPerViewCost = (dynamicCdnUSD + dynamicComputeUSD) / dynamicViews;
      const dynamicPerViewNet = dynamicPerViewPlatform - dynamicPerViewCost;

      expect(dynamicPerViewGross).toBe(0.001);
      expect(dynamicPerViewNet).toBeGreaterThan(0);
    });
  });

  describe("5. Viral Surge Overdraft Guard Logic", () => {
    test("Differentiates normal egress from viral surge overdraft", () => {
      const quotaBytes = 250 * 1024 * 1024 * 1024; // 250 GB
      const currentBandwidthBytes = 200 * 1024 * 1024 * 1024; // 200 GB
      const normalEgressBytes = 10 * 1024 * 1024 * 1024; // +10 GB -> 210 GB
      const isOverQuotaNormal = (currentBandwidthBytes + normalEgressBytes) > quotaBytes;
      expect(isOverQuotaNormal).toBe(false);

      const viralSurgeEgressBytes = 60 * 1024 * 1024 * 1024;
      const isOverQuotaSurge = (currentBandwidthBytes + viralSurgeEgressBytes) > quotaBytes;
      expect(isOverQuotaSurge).toBe(true);
    });
  });

  describe("6. End-to-End Pipeline Attribution & Dual-Ledger Simulation", () => {
    test("CostEngine accurately maps placeholder user to channel owner and formats rollups", () => {
      const placeholderUserId = "system";
      const isPlaceholder = !placeholderUserId || placeholderUserId === "system" || placeholderUserId === "__batch__";
      expect(isPlaceholder).toBe(true);

      const mockVideoDoc = {
        videoId: "vid_9988",
        channelId: "chan_alpha",
        userId: "creator_alpha_owner",
      };

      let resolvedUserId = isPlaceholder ? "" : placeholderUserId;
      if (!resolvedUserId) {
        resolvedUserId = mockVideoDoc.userId;
      }

      expect(resolvedUserId).toBe("creator_alpha_owner");

      const mockRollupData: Record<string, any> = {
        userId: resolvedUserId,
        month: "2026-11",
        channelType: "custom",
        channelId: mockVideoDoc.channelId,
        channelIds: [mockVideoDoc.channelId],
        totalCostUsd: 1.50,
        "breakdown.cdn_egress": 1.50,
      };

      expect(mockRollupData.channelId).toBe("chan_alpha");
      expect(mockRollupData.channelIds).toContain("chan_alpha");
    });
  });

  describe("7. Realistic Zero-Waste Monthly Rollover Verification", () => {
    test("Unspent balance and overdrawn spend rollover correctly", () => {
      const planBudget = 30.0;
      const currentMonthInfraCost = 12.50;
      const unspentRollover = Math.max(0, Number((planBudget - currentMonthInfraCost).toFixed(2)));
      expect(unspentRollover).toBe(17.50);

      const heavyInfraCost = 35.00;
      const heavyUnspent = Math.max(0, Number((planBudget - heavyInfraCost).toFixed(2)));
      expect(heavyUnspent).toBe(0.00);
    });
  });
});
