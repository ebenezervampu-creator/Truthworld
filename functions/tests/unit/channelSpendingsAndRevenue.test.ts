import * as admin from "firebase-admin";
import { testFirestore, Timestamp } from "../helpers/mockFirestore";
import { isCallableSuperAdmin } from "../../src/utils/auth";
import {
  computeChannelSpendingsAndRevenue,
  getChannelSpendingsAndRevenue,
} from "../../src/admin/unitEconomics";

describe("Channel Spendings and Revenue (Unit Tests)", () => {
  beforeEach(() => {
    testFirestore.clear();
    jest.clearAllMocks();
  });

  describe("isCallableSuperAdmin authorization check", () => {
    it("allows primary platform owner emails", async () => {
      const allowedOwner1 = await isCallableSuperAdmin({
        uid: "owner_uid_1",
        token: { email: "ebenezervampu4@gmail.com", email_verified: true },
      });
      const allowedOwner2 = await isCallableSuperAdmin({
        uid: "owner_uid_2",
        token: { email: "hello@truthworld.in", email_verified: true },
      });

      expect(allowedOwner1).toBe(true);
      expect(allowedOwner2).toBe(true);
    });

    it("allows user with Super Admin custom claims", async () => {
      const isSuper = await isCallableSuperAdmin({
        uid: "superadmin_uid",
        token: {
          email: "superadmin@truthworld.test",
          role: "Super Admin",
          isSuperAdmin: true,
          admin: true,
        },
      });
      expect(isSuper).toBe(true);
    });

    it("allows user whose admin_members document specifies Super Admin, Owner, or Director", async () => {
      await testFirestore
        .collection("admin_members")
        .doc("director@truthworld.test")
        .set({
          email: "director@truthworld.test",
          role: "Director",
          status: "active",
        });

      const isDirector = await isCallableSuperAdmin({
        uid: "director_uid",
        token: { email: "director@truthworld.test", admin: true },
      });
      expect(isDirector).toBe(true);
    });

    it("rejects regular users or unverified accounts", async () => {
      const rejectedUser = await isCallableSuperAdmin({
        uid: "regular_user_uid",
        token: { email: "randomuser@example.com", admin: false },
      });
      const unauth = await isCallableSuperAdmin(null);

      expect(rejectedUser).toBe(false);
      expect(unauth).toBe(false);
    });

    it("rejects regular Content Moderator without Super Admin privileges", async () => {
      await testFirestore
        .collection("admin_members")
        .doc("mod@truthworld.test")
        .set({
          email: "mod@truthworld.test",
          role: "Content Moderator",
          status: "active",
        });

      const isSuper = await isCallableSuperAdmin({
        uid: "mod_uid",
        token: { email: "mod@truthworld.test", role: "Content Moderator", admin: true },
      });
      expect(isSuper).toBe(false);
    });
  });

  describe("computeChannelSpendingsAndRevenue", () => {
    it("throws not-found when channel does not exist", async () => {
      await expect(
        computeChannelSpendingsAndRevenue("non_existent_channel_id")
      ).rejects.toThrow("Channel with ID non_existent_channel_id not found.");
    });

    it("correctly computes standard channel 70/30 split and gathers infra spendings", async () => {
      const channelId = "ch_standard_123";
      const ownerId = "usr_owner_456";

      // 1. Create standard channel
      await testFirestore.collection("channels").doc(channelId).set({
        name: "Truthworld News Official",
        ownerId,
        channelType: "standard",
        adsRevenueTotal: 8400, // 8400 INR = 100 USD
        premiumSubsRevenueTotal: 4200, // 4200 INR = 50 USD
        membershipRevenueTotal: 2100, // 2100 INR = 25 USD
        superchatRevenueTotal: 2100, // 2100 INR = 25 USD
        walletBalanceUSD: 30,
        withdrawnRevenueTotal: 5000,
        infraConfig: {
          currentMonthInfraCost: 10,
        },
      });

      // 2. Add cost rollups for the channel owner
      await testFirestore.collection("cost_rollups").doc("rollup_1").set({
        userId: ownerId,
        channelId,
        totalCostUsd: 15.0,
        breakdown: {
          extraction: 3.0,
          verification: 4.0,
          synthesis: 1.0,
          grounding: 1.0,
          cdn_egress: 3.0,
          tts: 1.0,
          transcription: 1.0,
          compute: 1.0,
        },
      });

      // 3. Add wallet transactions
      await testFirestore
        .collection("channel_wallet_transactions")
        .doc("tx_1")
        .set({
          channelId,
          amount: 5.0,
          category: "tts",
          description: "Telugu Dubbing Generation",
          timestamp: 1729000000000,
          balanceAfter: 25.0,
        });

      // 4. Add revenue statement
      await testFirestore.collection("revenue_statements").doc("stmt_2026_09").set({
        userId: ownerId,
        month: "2026-09",
        grossAdsRevenue: 5000,
        grossSubsRevenue: 2500,
        creatorShare: 5250,
        platformFee: 2250,
        infrastructureCosts: 10,
        payoutStatus: "settled",
      });

      const report = await computeChannelSpendingsAndRevenue(channelId);

      // Verify Channel Info
      expect(report.channelId).toBe(channelId);
      expect(report.channelName).toBe("Truthworld News Official");
      expect(report.channelType).toBe("standard");
      expect(report.usdInrRate).toBe(84.0);

      // Total Gross INR: 8400 + 4200 + 2100 + 2100 = 16800 INR
      expect(report.revenue.grossINR).toBe(16800);
      // Gross USD: 16800 / 84 = 200 USD
      expect(report.revenue.grossUSD).toBe(200);

      // Standard Channel: 70% Creator, 30% Platform Cut
      expect(report.revenue.creatorShareINR).toBe(11760); // 70% of 16800
      expect(report.revenue.creatorShareUSD).toBe(140); // 70% of 200
      expect(report.revenue.platformShareINR).toBe(5040); // 30% of 16800
      expect(report.revenue.platformShareUSD).toBe(60); // 30% of 200

      // Infra Spendings
      expect(report.spendings.totalInfraUSD).toBe(15.0);
      expect(report.spendings.totalInfraINR).toBe(1260); // 15 * 84
      expect(report.spendings.breakdown.geminiAI).toBe(9.0); // 3+4+1+1
      expect(report.spendings.breakdown.cdnEgress).toBe(3.0);
      expect(report.spendings.breakdown.translationDubbing).toBe(1.0);
      expect(report.spendings.breakdown.transcription).toBe(1.0);
      expect(report.spendings.breakdown.compute).toBe(1.0);

      // Net Economics: Platform Cut (60 USD) - Infra (15 USD) = 45 USD
      expect(report.economics.netPlatformContributionUSD).toBe(45);
      expect(report.economics.netPlatformContributionINR).toBe(3780); // 45 * 84
      expect(report.economics.marginPercent).toBe(75); // (45 / 60) * 100
      expect(report.economics.isProfitable).toBe(true);

      // Transactions & Statements
      expect(report.transactions.length).toBe(1);
      expect(report.transactions[0].amount).toBe(5.0);
      expect(report.transactions[0].category).toBe("tts");

      expect(report.monthlyStatements.length).toBe(1);
      expect(report.monthlyStatements[0].month).toBe("2026-09");
      expect(report.monthlyStatements[0].payoutStatus).toBe("settled");
    });

    it("correctly computes custom/pro channel with flat platform fee and detects negative net margin", async () => {
      const channelId = "ch_pro_999";
      const ownerId = "usr_pro_888";

      // Pro Channel with $15/mo SaaS plan fee, but low revenue and high infra spend
      await testFirestore.collection("channels").doc(channelId).set({
        name: "Pro Fact Check Lab",
        ownerId,
        channelType: "pro",
        adsRevenueTotal: 840, // 840 INR = 10 USD
        premiumSubsRevenueTotal: 0,
        membershipRevenueTotal: 0,
        superchatRevenueTotal: 0,
        infraConfig: {
          flatPlatformFee: 15.0, // Truthworld SaaS platform fee = $15
        },
      });

      // High infra spend: $40 total cost
      await testFirestore.collection("cost_rollups").doc("rollup_pro").set({
        userId: ownerId,
        channelId,
        totalCostUsd: 40.0,
        breakdown: {
          extraction: 15.0,
          verification: 15.0,
          cdn_egress: 10.0,
        },
      });

      const report = await computeChannelSpendingsAndRevenue(channelId);

      // Custom/Pro: Creator keeps 100% of gross
      expect(report.revenue.creatorShareINR).toBe(840);
      expect(report.revenue.creatorShareUSD).toBe(10);

      // Platform share is flat SaaS fee
      expect(report.revenue.platformShareUSD).toBe(15.0);
      expect(report.revenue.platformShareINR).toBe(1260); // 15 * 84

      // Infra spendings: 40 USD
      expect(report.spendings.totalInfraUSD).toBe(40.0);

      // Net platform contribution: 15 (fee) - 40 (infra) = -25 USD
      expect(report.economics.netPlatformContributionUSD).toBe(-25.0);
      expect(report.economics.netPlatformContributionINR).toBe(-2100);
      expect(report.economics.isProfitable).toBe(false);
      expect(report.economics.marginPercent).toBe(-166.67);
    });
  });

  describe("getChannelSpendingsAndRevenue callable endpoint", () => {
    it("rejects unauthenticated requests", async () => {
      const callable: any = getChannelSpendingsAndRevenue;
      await expect(
        callable.run({
          auth: null,
          data: { channelId: "ch_123" },
        })
      ).rejects.toThrow("Authentication required to access channel financial data.");
    });

    it("rejects non-Super Admin callers", async () => {
      const callable: any = getChannelSpendingsAndRevenue;
      await expect(
        callable.run({
          auth: {
            uid: "mod_uid_123",
            token: { email: "mod@truthworld.test", role: "Content Moderator" },
          },
          data: { channelId: "ch_123" },
        })
      ).rejects.toThrow("Access Denied: Super Admin privileges are required");
    });

    it("rejects missing channelId argument", async () => {
      const callable: any = getChannelSpendingsAndRevenue;
      await expect(
        callable.run({
          auth: {
            uid: "super_uid_123",
            token: { email: "hello@truthworld.in", role: "Super Admin" },
          },
          data: {},
        })
      ).rejects.toThrow("Missing or invalid channelId parameter.");
    });
  });
});
