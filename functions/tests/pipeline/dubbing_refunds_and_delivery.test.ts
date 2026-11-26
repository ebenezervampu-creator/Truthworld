/**
 * Money fixes (audit A1, A2, A4, A6, A12):
 * - per-order, per-language refunds at the price paid, once;
 * - undelivered dubs (failed or not dubbable) are refunded and the job is not reported "completed";
 * - broken tracks never ship (blocking quality-gate violations, missing chunks, untimed fallback,
 *   unchecked delivery mix);
 * - the wallet charged is the video's own channel.
 */
import * as fs from "fs";
import * as path from "path";
import * as admin from "firebase-admin";
import { testFirestore } from "../helpers/mockFirestore";
import {
  buildOrderPrices,
  computeLanguageRefunds,
  recordDubbingOrder,
  refundDubbingFeeOnFailure,
} from "../../src/pipeline/services/refundService";
import { isBlockingViolation } from "../../src/pipeline/layers/quality-gate";

const db = () => admin.firestore();

describe("order prices", () => {
  test("charged per-language dubbing prices are kept and sum to the amount paid", () => {
    const p = buildOrderPrices({
      dubbingLanguages: ["hi", "te", "ta"],
      dubbingUSD: 45,
      dubbingPriceByLanguage: { hi: 10, te: 15, ta: 20 },
      subtitleLanguages: [],
      subtitleUSD: 0,
    });
    expect(p).toEqual({ hi: 10, te: 15, ta: 20 });
  });

  test("an even split never loses or invents a cent", () => {
    const p = buildOrderPrices({ dubbingLanguages: ["hi", "te", "ta"], dubbingUSD: 10, subtitleLanguages: [], subtitleUSD: 0 });
    const sum = Object.values(p).reduce((a, b) => a + b, 0);
    expect(Math.round(sum * 100)).toBe(1000);
    expect(Object.values(p).sort()).toEqual([3.33, 3.33, 3.34]);
  });

  test("subtitle-only languages share the subtitle amount", () => {
    const p = buildOrderPrices({ dubbingLanguages: [], dubbingUSD: 0, subtitleLanguages: ["hi", "te"], subtitleUSD: 5 });
    expect(p).toEqual({ hi: 2.5, te: 2.5 });
  });
});

describe("refund amounts", () => {
  const order = { paidUSD: 45, priceByLanguage: { hi: 10, te: 15, ta: 20 }, refundedByLanguage: {}, refundedUSD: 0 };

  test("each failed language is refunded at its own price, not by language count", () => {
    expect(computeLanguageRefunds(order, ["te"])).toEqual({ byLanguage: { te: 15 }, totalUSD: 15 });
  });

  test("languages the order did not pay for get nothing", () => {
    expect(computeLanguageRefunds(order, ["fr", "en"]).totalUSD).toBe(0);
  });

  test("a language already refunded is not refunded again", () => {
    const after = { ...order, refundedByLanguage: { te: 15 }, refundedUSD: 15 };
    expect(computeLanguageRefunds(after, ["te"]).totalUSD).toBe(0);
    expect(computeLanguageRefunds(after, ["te", "hi"])).toEqual({ byLanguage: { hi: 10 }, totalUSD: 10 });
  });

  test("refunding every language returns exactly what was paid", () => {
    const odd = { paidUSD: 10, priceByLanguage: { hi: 3.33, te: 3.33, ta: 3.34 }, refundedByLanguage: { hi: 3.33 }, refundedUSD: 3.33 };
    expect(computeLanguageRefunds(odd, ["te", "ta"]).totalUSD).toBe(6.67);
  });

  test("language codes are normalized", () => {
    expect(computeLanguageRefunds(order, ["Telugu"]).totalUSD).toBe(15);
  });
});

describe("refund transactions (in-memory Firestore)", () => {
  beforeEach(async () => {
    testFirestore.clear();
    await db().collection("channels").doc("ch1").set({ walletBalanceUSD: 100, walletBalance: 100 });
    await db().collection("video_jobs").doc("v1").set({ videoId: "v1", channelId: "ch1", currentDubbingOrderId: "tx1", linkedVideoIds: ["v1"] });
    await recordDubbingOrder({
      orderId: "tx1", jobId: "v1", videoId: "v1", userId: "u1", channelId: "ch1",
      paidUSD: 45, dubbingUSD: 45, subtitleUSD: 0, languages: ["hi", "te", "ta"],
      priceByLanguage: { hi: 10, te: 15, ta: 20 }, createdAt: 1, source: "test",
    });
  });

  const balance = async () => Number((await db().collection("channels").doc("ch1").get()).data()?.walletBalanceUSD);

  test("refunds a failed language once, even when the refund is called again", async () => {
    const first = await refundDubbingFeeOnFailure({ jobId: "v1", userId: "u1", failedLanguages: ["te"], totalLanguages: ["hi", "te", "ta"], reason: "t" });
    const again = await refundDubbingFeeOnFailure({ jobId: "v1", userId: "u1", failedLanguages: ["te"], totalLanguages: ["hi", "te", "ta"], reason: "t" });
    expect(first.refundAmountUSD).toBe(15);
    expect(again.refunded).toBe(false);
    expect(await balance()).toBe(115);
    const order = (await db().collection("dubbing_orders").doc("tx1").get()).data();
    expect(order?.refundedByLanguage).toEqual({ te: 15 });
  });

  test("a later failure on the same order refunds only the new language; the job-wide catch never refunds twice", async () => {
    await refundDubbingFeeOnFailure({ jobId: "v1", userId: "u1", failedLanguages: ["te"], totalLanguages: [], reason: "t" });
    await refundDubbingFeeOnFailure({ jobId: "v1", userId: "u1", failedLanguages: ["hi", "te", "ta"], totalLanguages: [], reason: "t" });
    expect(await balance()).toBe(145);
    const job = (await db().collection("video_jobs").doc("v1").get()).data();
    expect(job?.refundProcessed).toBe(true);
    expect(job?.refundAmountUSD).toBe(45);
  });

  test("a second order on the same video is refunded on its own (one-refund-per-video bug)", async () => {
    await refundDubbingFeeOnFailure({ jobId: "v1", userId: "u1", failedLanguages: ["hi", "te", "ta"], totalLanguages: [], reason: "t" });
    await recordDubbingOrder({
      orderId: "tx2", jobId: "v1", videoId: "v1", userId: "u1", channelId: "ch1",
      paidUSD: 10, dubbingUSD: 10, subtitleUSD: 0, languages: ["bn"], priceByLanguage: { bn: 10 }, createdAt: 2, source: "test",
    });
    await db().collection("video_jobs").doc("v1").set({ currentDubbingOrderId: "tx2", refundProcessed: false }, { merge: true });
    const r = await refundDubbingFeeOnFailure({ jobId: "v1", userId: "u1", failedLanguages: ["bn"], totalLanguages: [], reason: "t" });
    expect(r.refundAmountUSD).toBe(10);
    expect(await balance()).toBe(155);
  });

  test("an audit entry records what was refunded per language", async () => {
    const r = await refundDubbingFeeOnFailure({ jobId: "v1", userId: "u1", failedLanguages: ["hi"], totalLanguages: [], reason: "t" });
    const tx = (await db().collection("channel_wallet_transactions").doc(r.refundTxId!).get()).data();
    expect(tx?.category).toBe("aiRefund");
    expect(tx?.amount).toBe(10);
    expect(tx?.metadata?.refundByLanguage).toEqual({ hi: 10 });
    expect(tx?.originalTransactionId).toBe("tx1");
  });

  test("jobs paid before order records still refund once (legacy path)", async () => {
    await db().collection("video_jobs").doc("old").set({ channelId: "ch1", paidFromWallet: true, fundedAmountUSD: 20 });
    const a = await refundDubbingFeeOnFailure({ jobId: "old", userId: "u1", failedLanguages: ["hi"], totalLanguages: ["hi", "te"], reason: "t" });
    const b = await refundDubbingFeeOnFailure({ jobId: "old", userId: "u1", failedLanguages: ["hi"], totalLanguages: ["hi", "te"], reason: "t" });
    expect(a.refundAmountUSD).toBe(10);
    expect(b.refunded).toBe(false);
    expect(await balance()).toBe(110);
  });
});

describe("quality gate: broken tracks block every tier (A4)", () => {
  test.each([
    ["Missing speech segments: 1 of 12 segments failed to synthesize [TTS synthesis failure]", true],
    ["Audio duration mismatch: Dubbed audio is 41.0s, but video is 60.0s", true],
    ["Dialogue onset drift: Onset error 400ms exceeds 250ms (2 frames) synchronization tolerance", true],
    ["Audio file invalid: Duration is empty or near-zero (0.10s)", true],
    ["Audio file truncated: Output size (9000 bytes) is suspiciously low for 60.0s video", true],
    ["Voice cloning was requested, but fallback standard voice was used instead of creator timbre", false],
    ["Dialogue turn collision: 2 segments exceed permissible window and overlap consecutive speech turns", false],
    ["Background music preservation was requested, but discrete stem isolation or ducking failed", false],
  ])("%s → blocking=%s", (v, expected) => {
    expect(isBlockingViolation(v)).toBe(expected);
  });
});

describe("wiring (source checks)", () => {
  const read = (p: string) => fs.readFileSync(path.join(__dirname, "../../src/pipeline", p), "utf8");
  const dub = read("layers/07-dubbing.ts");
  const media = read("services/media.ts");
  const triggers = read("pipelineTriggers.ts");

  test("A1/A2: undelivered and not-dubbable languages are refunded and the job is not 'completed' without a delivered dub", () => {
    expect(dub).toContain('dubOutcome = audioUrl ? "delivered" : "failed";');
    expect(dub.match(/dubOutcome = "not_dubbable";/g)?.length).toBe(2);
    expect(dub).toContain('return outcome === "failed" || outcome === "not_dubbable" ? languagesToProcess[i] : null;');
    expect(dub).toContain('status: dubbingDelivered ? "completed" : "failed"');
  });

  test("A12: the job-wide failure refund skips languages whose dub already completed", () => {
    expect(dub).toContain('await this.refundUndeliveredLanguages(jobId, userId, executionPlan, "Dubbing could not be completed")');
    expect(dub).toMatch(/private async undeliveredLanguages\([\s\S]{0,500}loadDubbingCheckpoint[\s\S]{0,300}if \(!delivered\) undelivered\.push\(lang\);/);
  });

  test("A4: blocking violations, unchecked mixes, missing chunks and untimed concatenation all fail the language", () => {
    expect(dub).toContain("postStitchGate.violations.some(isBlockingViolation)");
    expect(dub).not.toContain("publishing the mix as built");
    expect(media).not.toMatch(/Failed to download chunk for merge:[^\n]*\n\s*return null;/);
    expect(media).toContain("untimed buffer concatenation is not allowed for a dub track");
  });

  test("A6: orders are recorded after the debit, refunded on dispatch failure, and charge the video's channel", () => {
    expect(triggers).toContain("await recordDubbingOrder({");
    expect(triggers).toContain("currentDubbingOrderId: paidOrderId,");
    expect(triggers).toMatch(/Pub\/Sub dispatch failure[\s\S]{0,1200}refundDubbingFeeOnFailure\(/);
    expect(triggers).toContain("const channelId = (isAdmin && req.body?.channelId) ? String(req.body.channelId) : (videoData.channelId || userId);");
  });
});

describe("voice-clone consent and saved voices (A5, A10 follow-up)", () => {
  const dub = fs.readFileSync(path.join(__dirname, "../../src/pipeline/layers/07-dubbing.ts"), "utf8");

  test("only an explicit consent clones; a plan without the field falls back to standard voices", () => {
    expect(dub).toContain('executionPlan.dubbingMode === "voice_clone" && executionPlan.voiceCloneConsent !== true');
    expect(dub).not.toContain("executionPlan.voiceCloneConsent === false");
  });

  test("saved voices are reused only with a consent record, and new clones only from one-speaker videos", () => {
    expect(dub).toMatch(/status === "active" && voiceProfileDoc\.data\(\)\?\.consentedAt\)/);
    expect(dub).toContain("} else if (speakerProfiles.length !== 1) {");
    expect(dub).toContain('speakerProfiles.length === 1 && executionPlan.saveAsCreatorProfile === true');
    expect(dub).toContain("consentedAt: Date.now(),");
  });

  test("a saved speaker profile never replaces this run's voice", () => {
    expect(dub).not.toMatch(/if \(persistedProfile\?\.voiceId\) \{\s*voiceId = persistedProfile\.voiceId;/);
  });
});

describe("A7 retry cap and A9 lease ownership (review fixes)", () => {
  const read = (p: string) => fs.readFileSync(path.join(__dirname, "../../src/pipeline", p), "utf8");
  const triggers = read("pipelineTriggers.ts");
  const dub = read("layers/07-dubbing.ts");

  test("attempts are counted per dubbing event, not per video, so later orders are not refunded and dropped", () => {
    expect(triggers).toContain('collection("dubbing_attempts").doc(String(parsedEvent.eventId))');
    expect(triggers).not.toContain("dubbingAttempts");
    expect(triggers).toMatch(/if \(attempts > maxAttempts\) \{[\s\S]{0,400}failAfterRetryLimit\(/);
  });

  test("past the cap, only undelivered languages are refunded and a fully delivered event is left alone", () => {
    expect(dub).toMatch(/async failAfterRetryLimit\([\s\S]{0,400}if \(undelivered\.length === 0\)/);
    expect(dub).toMatch(/async failAfterRetryLimit\([\s\S]{0,1200}refundUndeliveredLanguages\(/);
    expect(dub).toMatch(/async failAfterRetryLimit\([\s\S]{0,1600}status: "failed"/);
  });

  test("every lease renewal carries the owner's worker id", () => {
    const calls = dub.match(/this\.renewDubbingLease\([^)]*\)/g) || [];
    expect(calls.length).toBeGreaterThan(0);
    for (const c of calls) expect(c).toContain("currentWorkerId");
  });
});
