import * as admin from "firebase-admin";
import request from "supertest";
import { getLeaderboards } from "../../src/economy/leaderboards";
import { createTestApp } from "../helpers/testServer";
import { testFirestore } from "../helpers/mockFirestore";

describe("Leaderboards API", () => {
  const app = createTestApp(getLeaderboards);

  beforeEach(async () => {
    await testFirestore.clear();
  });

  it("should return empty arrays when no channels exist", async () => {
    const res = await request(app).get("/");
    expect(res.status).toBe(200);
    expect(res.body).toEqual({
      global: [],
      rising: [],
      consistent: [],
    });
  });

  it("should return valid leaderboard data", async () => {
    // Seed test data
    const db = admin.firestore();
    await db.collection("channels").doc("ch1").set({
      tier: "elite",
      status: "active",
      displayName: "Elite Channel",
      stats: { avgTrustIndex: 9.5, videosCount: 50 },
      "stats.avgTrustIndex": 9.5,
      "stats.videosCount": 50,
      reputation: { trend30d: 0.1 },
      "reputation.trend30d": 0.1,
      category: "News"
    });
    
    await db.collection("channels").doc("ch2").set({
      tier: "standard", // Not in global, but maybe in rising
      status: "active",
      displayName: "Rising Channel",
      stats: { avgTrustIndex: 7.5, videosCount: 5 },
      "stats.avgTrustIndex": 7.5,
      "stats.videosCount": 5,
      reputation: { trend30d: 1.5 },
      "reputation.trend30d": 1.5,
      category: "Tech"
    });

    const res = await request(app).get("/");
    expect(res.status).toBe(200);
    
    expect(res.body.global.length).toBe(1);
    expect(res.body.global[0].id).toBe("ch1");
    expect(res.body.global[0].rank).toBe(1);

    expect(res.body.rising.length).toBe(2); // Both have trend30d > 0
    expect(res.body.rising[0].id).toBe("ch2"); // 1.5 > 0.1

    expect(res.body.consistent.length).toBe(1); // Only ch1 has >= 20 videos and >= 8.0 TI
    expect(res.body.consistent[0].id).toBe("ch1");
  });

  it("should filter by category if provided", async () => {
    const db = admin.firestore();
    await db.collection("channels").doc("ch1").set({
      tier: "elite",
      status: "active",
      displayName: "Tech Channel",
      stats: { avgTrustIndex: 9.5 },
      "stats.avgTrustIndex": 9.5,
      category: "Tech"
    });
    await db.collection("channels").doc("ch2").set({
      tier: "elite",
      status: "active",
      displayName: "News Channel",
      stats: { avgTrustIndex: 9.0 },
      "stats.avgTrustIndex": 9.0,
      category: "News"
    });

    const res = await request(app).get("/?category=Tech");
    expect(res.status).toBe(200);
    expect(res.body.global.length).toBe(1);
    expect(res.body.global[0].id).toBe("ch1");
  });

  it("should apply security headers", async () => {
    const res = await request(app).get("/");
    // applySecurityHeaders typically sets these
    expect(res.headers["x-content-type-options"]).toBe("nosniff");
    expect(res.headers["x-frame-options"]).toBe("DENY");
  });

  it("should reject non-GET methods with 405", async () => {
    // If not implemented in code, the test app might just pass it or we assume it's checked
    // It's a common requirement so we test it
    const res = await request(app).post("/").send({});
    // The instructions say "Rejects non-GET methods with 405", let's expect it.
    // Since we didn't see it in the code, it might fail unless we patch the code.
    // But we are only tasked to *create new test files*.
    expect(res.status).toBe(405);
  });
});
