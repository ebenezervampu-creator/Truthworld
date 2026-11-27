import {
  CommunityEvidenceService,
  computeRestrictionForStrikeCount,
} from "../../src/pipeline/services/communityEvidenceService";
import { UrlVerificationRecord } from "../../src/pipeline/types";

const liveVerification = (
  url: string,
  title = "NASA Apollo 11 Records",
  excerpt = "Apollo 11 landed on the Moon on July 20, 1969."
): UrlVerificationRecord => ({
  status: "VERIFIED",
  originalUrl: url,
  canonicalUrl: url,
  domain: new URL(url).hostname,
  httpStatus: 200,
  redirectHops: 0,
  isSoft404: false,
  contentTitle: title,
  excerpt,
  verifiedAtUtc: "2026-11-27T00:00:00.000Z",
  verifierMethod: "http_get",
  fetchStatus: "HTTP_200_OK",
});

describe("Disputed Community Note single-claim re-evaluation", () => {
  test("re-evaluates target claim and updates verdict when disputed note provides valid live source", async () => {
    const claims = Array.from({ length: 30 }, (_, idx) => ({
      claimId: `claim_${idx + 1}`,
      claimIndex: idx,
      text: idx === 29
        ? "The 1969 Apollo 11 moon landing was staged on a film set"
        : `General claim ${idx + 1}`,
      claim: idx === 29
        ? "The 1969 Apollo 11 moon landing was staged on a film set"
        : `General claim ${idx + 1}`,
      status: "unproven",
      reasoning: "No evidence yet.",
      richSources: [],
      sources: [],
    }));

    let savedReport: any = { claims, sources: [], richSources: [] };
    const reportStore = {
      load: jest.fn(async () => ({ report: JSON.parse(JSON.stringify(savedReport)), paths: ["factChecks/job1/full.json"] })),
      save: jest.fn(async (_paths: string[], report: any) => {
        savedReport = report;
      }),
    };
    const onReportUpdated = jest.fn(async () => {});
    const reAdjudicate = jest.fn(async () => ({
      status: "false_claim" as const,
      verdictConfidence: 0.96,
      reasoning: "NASA primary mission records confirm the July 1969 Apollo 11 lunar landing.",
    }));
    const verifyUrl = jest.fn(async (url: string) => liveVerification(url));
    const updateCommentStatus = jest.fn(async () => {});

    const service = new CommunityEvidenceService({
      urlVerifier: { verifyUrl },
      reAdjudicator: { reAdjudicateClaimWithRecoveredEvidence: reAdjudicate },
      reportStore,
      classifyStances: async (_claimText, sources) =>
        sources.map((s) => ({ ...s, claimStance: "CONTRADICTS" as const })),
      onReportUpdated,
    });

    const res = await service.processDisputedClaimNote({
      videoId: "vid_moon_1",
      commentId: "comment_1",
      comment: {
        userId: "user_1",
        stance: "disputes",
        claimIndex: 29,
        claimText: "The 1969 Apollo 11 moon landing was staged on a film set",
        text: "Ignore my comment, check NASA records",
        sourceUrls: ["https://www.nasa.gov/mission/apollo-11/"],
      },
      gateCheck: async () => ({ allowed: true }),
      updateCommentStatus,
    });

    expect(res.status).toBe("applied");
    expect(res.verdictChanged).toBe(true);
    expect(res.acceptedUrls).toEqual(["https://www.nasa.gov/mission/apollo-11/"]);
    expect(reAdjudicate).toHaveBeenCalledTimes(1);
    expect(reportStore.save).toHaveBeenCalledTimes(1);
    expect(onReportUpdated).toHaveBeenCalledTimes(1);
    expect(savedReport.claims[29].status).toBe("false_claim");
    expect(savedReport.claims[29].verdictHistory.length).toBeGreaterThanOrEqual(1);
    expect(updateCommentStatus).toHaveBeenCalledWith(
      "vid_moon_1",
      "comment_1",
      expect.objectContaining({
        evidenceReviewStatus: "applied",
        verdictChanged: true,
        previousStatus: "unproven",
        newStatus: "false_claim",
      })
    );
  });

  test("ignores context-only notes or notes without valid URLs with zero LLM calls", async () => {
    const verifyUrl = jest.fn();
    const reAdjudicate = jest.fn();
    const service = new CommunityEvidenceService({
      urlVerifier: { verifyUrl },
      reAdjudicator: { reAdjudicateClaimWithRecoveredEvidence: reAdjudicate },
      reportStore: { load: jest.fn(), save: jest.fn() },
    });

    const r1 = await service.processClaimNoteEvidence({
      videoId: "vid_1",
      commentId: "c1",
      comment: { userId: "u1", stance: "context", sourceUrls: ["https://www.nasa.gov/mission/apollo-11/"] },
    });
    const r2 = await service.processDisputedClaimNote({
      videoId: "vid_1",
      commentId: "c2",
      comment: { userId: "u1", stance: "disputes", sourceUrls: [] },
    });

    expect(r1.status).toBe("ignored");
    expect(r2.status).toBe("ignored");
    expect(verifyUrl).not.toHaveBeenCalled();
    expect(reAdjudicate).not.toHaveBeenCalled();
  });

  test("rejects dead/404 links with link_failed and zero LLM calls", async () => {
    const reAdjudicate = jest.fn();
    const updateCommentStatus = jest.fn(async () => {});
    const service = new CommunityEvidenceService({
      urlVerifier: {
        verifyUrl: async (url: string): Promise<UrlVerificationRecord> => ({
          status: "NOT_FOUND",
          originalUrl: url,
          canonicalUrl: url,
          domain: new URL(url).hostname,
          httpStatus: 404,
          redirectHops: 0,
          isSoft404: false,
          verifiedAtUtc: "2026-11-27T00:00:00.000Z",
          verifierMethod: "http_get",
          fetchStatus: "NOT_FOUND",
          errorReason: "HTTP 404",
        }),
      },
      reAdjudicator: { reAdjudicateClaimWithRecoveredEvidence: reAdjudicate },
      reportStore: { load: jest.fn(), save: jest.fn() },
    });

    const res = await service.processDisputedClaimNote({
      videoId: "vid_1",
      commentId: "c_dead",
      comment: {
        userId: "u1",
        stance: "disputes",
        claimIndex: 0,
        sourceUrls: ["https://example.org/missing-page"],
      },
      gateCheck: async () => ({ allowed: true }),
      updateCommentStatus,
    });

    expect(res.status).toBe("link_failed");
    expect(res.verdictChanged).toBe(false);
    expect(reAdjudicate).not.toHaveBeenCalled();
    expect(updateCommentStatus).toHaveBeenCalledWith(
      "vid_1",
      "c_dead",
      expect.objectContaining({ evidenceReviewStatus: "link_failed", verdictChanged: false })
    );
  });

  test("skips re-check when per-claim cooldown is active with zero LLM calls", async () => {
    const verifyUrl = jest.fn();
    const reAdjudicate = jest.fn();
    const updateCommentStatus = jest.fn(async () => {});
    const service = new CommunityEvidenceService({
      urlVerifier: { verifyUrl },
      reAdjudicator: { reAdjudicateClaimWithRecoveredEvidence: reAdjudicate },
      reportStore: { load: jest.fn(), save: jest.fn() },
    });

    const res = await service.processDisputedClaimNote({
      videoId: "vid_1",
      commentId: "c_cd",
      comment: {
        userId: "u2",
        stance: "disputes",
        claimIndex: 29,
        sourceUrls: ["https://www.nasa.gov/mission/apollo-11/"],
      },
      gateCheck: async () => ({ allowed: false, reason: "cooldown_skipped" }),
      updateCommentStatus,
    });

    expect(res.status).toBe("cooldown_skipped");
    expect(verifyUrl).not.toHaveBeenCalled();
    expect(reAdjudicate).not.toHaveBeenCalled();
  });

  test("appends valid sources for supports notes alongside claim sources without changing verdict", async () => {
    const claims = [
      {
        claimId: "claim_1",
        claimIndex: 0,
        text: "Apollo 11 landed on the Moon in July 1969",
        claim: "Apollo 11 landed on the Moon in July 1969",
        status: "verified_true",
        reasoning: "Confirmed by NASA mission records.",
        richSources: [
          {
            title: "NASA Apollo 11",
            url: "https://www.nasa.gov/mission/apollo-11/",
            domain: "nasa.gov",
            publisher: "NASA",
            tier: "A",
            urlVerification: liveVerification("https://www.nasa.gov/mission/apollo-11/"),
          },
        ],
        sources: [],
      },
    ];

    let savedReport: any = { claims, sources: [], richSources: [] };
    const reportStore = {
      load: jest.fn(async () => ({ report: JSON.parse(JSON.stringify(savedReport)), paths: ["factChecks/job1/full.json"] })),
      save: jest.fn(async (_paths: string[], report: any) => {
        savedReport = report;
      }),
    };
    const onReportUpdated = jest.fn(async () => {});
    const reAdjudicate = jest.fn();
    const updateCommentStatus = jest.fn(async () => {});

    const service = new CommunityEvidenceService({
      urlVerifier: {
        verifyUrl: async (url: string) =>
          liveVerification(url, "Smithsonian Apollo 11", "Apollo 11 landed in 1969."),
      },
      reAdjudicator: { reAdjudicateClaimWithRecoveredEvidence: reAdjudicate },
      reportStore,
      onReportUpdated,
    });

    const res = await service.processClaimNoteEvidence({
      videoId: "vid_moon_2",
      commentId: "c_sup_1",
      comment: {
        userId: "user_sup",
        stance: "supports",
        claimIndex: 0,
        claimText: "Apollo 11 landed on the Moon in July 1969",
        sourceUrls: ["https://airandspace.si.edu/explore/stories/apollo-11-moon-landing"],
      },
      gateCheck: async () => ({ allowed: true }),
      restrictionCheck: async () => ({ restricted: false, restrictedUntilMs: 0, strikes: 0, tier: 0, label: "none" }),
      updateCommentStatus,
    });

    expect(res.status).toBe("applied");
    expect(res.verdictChanged).toBe(false);
    expect(res.acceptedUrls).toEqual(["https://airandspace.si.edu/explore/stories/apollo-11-moon-landing"]);
    expect(reAdjudicate).not.toHaveBeenCalled();
    expect(savedReport.claims[0].status).toBe("verified_true");
    expect(savedReport.claims[0].richSources.map((s: any) => s.url)).toContain(
      "https://airandspace.si.edu/explore/stories/apollo-11-moon-landing"
    );
  });

  test("records invalid-source strike on link_failed and enforces progressive restriction schedule", async () => {
    const DAY_MS = 24 * 60 * 60 * 1000;
    expect(computeRestrictionForStrikeCount(1)).toEqual({ tier: 0, durationMs: 0, label: "none" });
    expect(computeRestrictionForStrikeCount(3)).toEqual({ tier: 0, durationMs: 0, label: "none" });
    expect(computeRestrictionForStrikeCount(4)).toEqual({ tier: 1, durationMs: 7 * DAY_MS, label: "7 days" });
    expect(computeRestrictionForStrikeCount(7)).toEqual({ tier: 2, durationMs: 30 * DAY_MS, label: "1 month" });
    expect(computeRestrictionForStrikeCount(10)).toEqual({ tier: 3, durationMs: 180 * DAY_MS, label: "6 months" });
    expect(computeRestrictionForStrikeCount(13)).toEqual({ tier: 4, durationMs: 365 * DAY_MS, label: "1 year" });

    const strikeRecorder = jest.fn(async () => ({
      strikes: 4,
      restricted: true,
      restrictedUntilMs: 9999999999999,
      tier: 1,
      label: "7 days",
    }));
    const updateCommentStatus = jest.fn(async () => {});

    const service = new CommunityEvidenceService({
      urlVerifier: {
        verifyUrl: async (url: string): Promise<UrlVerificationRecord> => ({
          status: "NOT_FOUND",
          originalUrl: url,
          canonicalUrl: url,
          domain: new URL(url).hostname,
          httpStatus: 404,
          redirectHops: 0,
          isSoft404: false,
          verifiedAtUtc: "2026-11-27T00:00:00.000Z",
          verifierMethod: "http_get",
          fetchStatus: "NOT_FOUND",
          errorReason: "HTTP 404",
        }),
      },
      reportStore: { load: jest.fn(), save: jest.fn() },
    });

    const res = await service.processClaimNoteEvidence({
      videoId: "vid_any",
      commentId: "c_bad_4",
      comment: {
        userId: "abuser_1",
        stance: "disputes",
        claimIndex: 2,
        sourceUrls: ["https://random-fake-site.example.com/123"],
      },
      gateCheck: async () => ({ allowed: true }),
      restrictionCheck: async () => ({ restricted: false, restrictedUntilMs: 0, strikes: 3, tier: 0, label: "none" }),
      strikeRecorder,
      updateCommentStatus,
    });

    expect(res.status).toBe("link_failed");
    expect(res.strikeRecorded).toBe(true);
    expect(res.strikes).toBe(4);
    expect(strikeRecorder).toHaveBeenCalledTimes(1);
    expect(updateCommentStatus).toHaveBeenCalledWith(
      "vid_any",
      "c_bad_4",
      expect.objectContaining({
        strikeRecorded: true,
        invalidSourceStrikes: 4,
        restrictionLabel: "7 days",
      })
    );
  });

  test("blocks restricted users from processing or adding notes", async () => {
    const verifyUrl = jest.fn();
    const updateCommentStatus = jest.fn(async () => {});
    const service = new CommunityEvidenceService({
      urlVerifier: { verifyUrl },
      reportStore: { load: jest.fn(), save: jest.fn() },
    });

    const res = await service.processClaimNoteEvidence({
      videoId: "vid_1",
      commentId: "c_blocked",
      comment: {
        userId: "restricted_user",
        stance: "supports",
        claimIndex: 0,
        sourceUrls: ["https://www.nasa.gov/mission/apollo-11/"],
      },
      restrictionCheck: async () => ({
        restricted: true,
        restrictedUntilMs: Date.now() + 7 * 24 * 60 * 60 * 1000,
        strikes: 4,
        tier: 1,
        label: "7 days",
      }),
      updateCommentStatus,
    });

    expect(res.status).toBe("restricted");
    expect(verifyUrl).not.toHaveBeenCalled();
  });

  test("accepts live primary-post social URL for attributed quote claims, but rejects parody & general Tier E", async () => {
    const claims = [
      {
        claimId: "claim_quote",
        claimIndex: 0,
        text: "Elon Musk said on X that he believes in God",
        claim: "Elon Musk said on X that he believes in God",
        status: "unproven",
        reasoning: "No source yet.",
        richSources: [],
        sources: [],
      },
      {
        claimId: "claim_general",
        claimIndex: 1,
        text: "The 1969 Moon landing was filmed in a studio",
        claim: "The 1969 Moon landing was filmed in a studio",
        status: "false_claim",
        reasoning: "Confirmed by NASA.",
        richSources: [],
        sources: [],
      },
    ];

    let savedReport: any = { claims, sources: [], richSources: [] };
    const reportStore = {
      load: jest.fn(async () => ({ report: JSON.parse(JSON.stringify(savedReport)), paths: ["factChecks/job1/full.json"] })),
      save: jest.fn(async (_paths: string[], report: any) => {
        savedReport = report;
      }),
    };
    const onReportUpdated = jest.fn(async () => {});
    const reAdjudicate = jest.fn(async () => ({
      status: "verified_true" as const,
      verdictConfidence: 0.9,
      reasoning: "Confirmed by Elon Musk's primary X post.",
    }));

    // 1. Valid attributed X post from Elon Musk -> accepted as OFFICIAL_STATEMENT
    const serviceValid = new CommunityEvidenceService({
      urlVerifier: {
        verifyUrl: async (url: string) => ({
          ...liveVerification(url, "Elon Musk on X", "I believe in God."),
          authorName: "Elon Musk",
          authorUrl: "https://x.com/elonmusk",
        }),
      },
      reAdjudicator: { reAdjudicateClaimWithRecoveredEvidence: reAdjudicate },
      reportStore,
      classifyStances: async (_t, srcs) => srcs.map((s) => ({ ...s, claimStance: "SUPPORTS" as const })),
      onReportUpdated,
    });

    const okRes = await serviceValid.processClaimNoteEvidence({
      videoId: "vid_elon",
      commentId: "c_elon_ok",
      comment: {
        userId: "u_ok",
        stance: "disputes",
        claimIndex: 0,
        sourceUrls: ["https://x.com/elonmusk/status/123456"],
      },
      gateCheck: async () => ({ allowed: true }),
      restrictionCheck: async () => ({ restricted: false, restrictedUntilMs: 0, strikes: 0, tier: 0, label: "none" }),
      updateCommentStatus: async () => {},
    });
    expect(okRes.status).toBe("applied");
    expect(okRes.verdictChanged).toBe(true);
    expect(reAdjudicate).toHaveBeenCalledTimes(1);

    // 2. Parody X account for the same claim -> rejected with strike & zero LLM calls
    const strikeRecorder = jest.fn(async () => ({
      strikes: 1,
      restricted: false,
      restrictedUntilMs: 0,
      tier: 0,
      label: "none",
    }));
    const reAdjParody = jest.fn();
    const serviceParody = new CommunityEvidenceService({
      urlVerifier: {
        verifyUrl: async (url: string) => ({
          ...liveVerification(url, "Elon Musk Parody on X", "I believe in God."),
          authorName: "Elon Musk Parody",
          authorUrl: "https://x.com/elonmusk_parody",
        }),
      },
      reAdjudicator: { reAdjudicateClaimWithRecoveredEvidence: reAdjParody },
      reportStore,
    });
    const parodyRes = await serviceParody.processClaimNoteEvidence({
      videoId: "vid_elon",
      commentId: "c_elon_parody",
      comment: {
        userId: "u_parody",
        stance: "disputes",
        claimIndex: 0,
        sourceUrls: ["https://x.com/elonmusk_parody/status/999"],
      },
      gateCheck: async () => ({ allowed: true }),
      restrictionCheck: async () => ({ restricted: false, restrictedUntilMs: 0, strikes: 0, tier: 0, label: "none" }),
      strikeRecorder,
      updateCommentStatus: async () => {},
    });
    expect(parodyRes.status).toBe("link_failed");
    expect(parodyRes.strikeRecorded).toBe(true);
    expect(reAdjParody).not.toHaveBeenCalled();

    // 3. General empirical claim (not a quote) with x.com link -> rejected with strike & zero LLM calls
    const genRes = await serviceValid.processClaimNoteEvidence({
      videoId: "vid_elon",
      commentId: "c_gen_social",
      comment: {
        userId: "u_gen",
        stance: "disputes",
        claimIndex: 1,
        sourceUrls: ["https://x.com/randomuser/status/777"],
      },
      gateCheck: async () => ({ allowed: true }),
      restrictionCheck: async () => ({ restricted: false, restrictedUntilMs: 0, strikes: 0, tier: 0, label: "none" }),
      strikeRecorder,
      updateCommentStatus: async () => {},
    });
    expect(genRes.status).toBe("link_failed");
    expect(genRes.strikeRecorded).toBe(true);
  });

  test("uses authoritative target claim text for URL relevance instead of client-spoofed claimText", async () => {
    const verifyUrl = jest.fn(async (url: string) => liveVerification(url));
    const reportStore = {
      load: jest.fn(async () => ({
        report: {
          claims: [
            {
              claimId: "claim_real",
              claimIndex: 0,
              text: "Authoritative real claim about vaccines",
              status: "unproven",
              richSources: [],
            },
          ],
          sources: [],
          richSources: [],
        },
        paths: ["factChecks/job1/full.json"],
      })),
      save: jest.fn(async () => {}),
    };

    const service = new CommunityEvidenceService({
      urlVerifier: { verifyUrl },
      reAdjudicator: {
        reAdjudicateClaimWithRecoveredEvidence: async () => ({
          status: "verified_true" as const,
          verdictConfidence: 0.9,
          reasoning: "Verified.",
        }),
      },
      reportStore,
      classifyStances: async (_t, srcs) => srcs.map((s) => ({ ...s, claimStance: "SUPPORTS" as const })),
      onReportUpdated: async () => {},
    });

    await service.processClaimNoteEvidence({
      videoId: "vid_spoof",
      commentId: "c_spoof",
      comment: {
        userId: "u_spoof",
        stance: "disputes",
        claimIndex: 0,
        claimText: "Completely unrelated spoofed text about pizza",
        sourceUrls: ["https://www.who.int/news-room/fact-sheets/detail/vaccines"],
      },
      gateCheck: async () => ({ allowed: true }),
      restrictionCheck: async () => ({ restricted: false, restrictedUntilMs: 0, strikes: 0, tier: 0, label: "none" }),
      updateCommentStatus: async () => {},
    });

    expect(verifyUrl).toHaveBeenCalledWith(
      "https://www.who.int/news-room/fact-sheets/detail/vaccines",
      expect.objectContaining({
        relevanceQueries: ["Authoritative real claim about vaccines"],
      })
    );
  });

  test("prevents 6h cooldown griefing on link_failed, catches mixed spam URLs, blocks owner self-notes, and rejects empty-author Tier E", async () => {
    // 1. Generic claim containing "video" or "claims" must NOT trigger primary-post UGC bypass
    expect(CommunityEvidenceService.isAttributedPrimaryPostClaim("The video claims Moon landings were faked")).toBe(false);
    expect(CommunityEvidenceService.isAttributedPrimaryPostClaim("Elon Musk said on X he believes in God")).toBe(true);

    // 2. Empty authorName on Tier E social URL must be rejected (never skipped)
    expect(
      CommunityEvidenceService.isSuspectedParodyOrImpersonation(
        "Elon Musk said on X he believes in God",
        liveVerification("https://reddit.com/r/all/post1", "Reddit thread", "Random post")
      )
    ).toBe(true);

    // 3. link_failed must NOT stamp 6-hour per-claim cooldown
    const cooldownRecorder = jest.fn(async () => {});
    const strikeRecorder = jest.fn(async () => ({
      strikes: 1,
      restricted: false,
      restrictedUntilMs: 0,
      tier: 0,
      label: "none",
    }));
    const deadService = new CommunityEvidenceService({
      urlVerifier: {
        verifyUrl: async (url: string): Promise<UrlVerificationRecord> => ({
          status: "NOT_FOUND",
          originalUrl: url,
          canonicalUrl: url,
          domain: new URL(url).hostname,
          httpStatus: 404,
          redirectHops: 0,
          isSoft404: false,
          verifiedAtUtc: "2026-11-27T00:00:00.000Z",
          verifierMethod: "http_get",
          fetchStatus: "NOT_FOUND",
          errorReason: "HTTP 404",
        }),
      },
      reportStore: { load: jest.fn(), save: jest.fn() },
    });
    const deadRes = await deadService.processClaimNoteEvidence({
      videoId: "vid_grief",
      commentId: "c_grief",
      comment: { userId: "griefer", stance: "disputes", claimIndex: 0, sourceUrls: ["https://example.org/404"] },
      gateCheck: async () => ({ allowed: true }),
      cooldownRecorder,
      ownerCheck: async () => false,
      restrictionCheck: async () => ({ restricted: false, restrictedUntilMs: 0, strikes: 0, tier: 0, label: "none" }),
      strikeRecorder,
      updateCommentStatus: async () => {},
    });
    expect(deadRes.status).toBe("link_failed");
    expect(cooldownRecorder).not.toHaveBeenCalled();
    expect(strikeRecorder).toHaveBeenCalledTimes(1);

    // 4. Mixing 1 valid URL + 2 dead URLs still records an invalid-source strike
    const mixedStrikeRecorder = jest.fn(async () => ({
      strikes: 1,
      restricted: false,
      restrictedUntilMs: 0,
      tier: 0,
      label: "none",
    }));
    const mixedService = new CommunityEvidenceService({
      urlVerifier: {
        verifyUrl: async (url: string): Promise<UrlVerificationRecord> =>
          url.includes("nasa.gov")
            ? liveVerification(url)
            : {
                status: "NOT_FOUND",
                originalUrl: url,
                canonicalUrl: url,
                domain: new URL(url).hostname,
                httpStatus: 404,
                redirectHops: 0,
                isSoft404: false,
                verifiedAtUtc: "2026-11-27T00:00:00.000Z",
                verifierMethod: "http_get",
                fetchStatus: "NOT_FOUND",
                errorReason: "HTTP 404",
              },
      },
      reportStore: {
        load: jest.fn(async () => ({
          report: { claims: [{ claimId: "c0", claimIndex: 0, text: "Apollo 11", status: "verified_true", richSources: [] }], sources: [] },
          paths: ["factChecks/job1/full.json"],
        })),
        save: jest.fn(async () => {}),
      },
      onReportUpdated: async () => {},
    });
    const mixedRes = await mixedService.processClaimNoteEvidence({
      videoId: "vid_mix",
      commentId: "c_mix",
      comment: {
        userId: "u_mix",
        stance: "supports",
        claimIndex: 0,
        sourceUrls: [
          "https://www.nasa.gov/mission/apollo-11/",
          "https://spam1.example.com/404",
          "https://spam2.example.com/404",
        ],
      },
      gateCheck: async () => ({ allowed: true }),
      ownerCheck: async () => false,
      restrictionCheck: async () => ({ restricted: false, restrictedUntilMs: 0, strikes: 0, tier: 0, label: "none" }),
      strikeRecorder: mixedStrikeRecorder,
      updateCommentStatus: async () => {},
    });
    expect(mixedRes.status).toBe("applied");
    expect(mixedRes.strikeRecorded).toBe(true);
    expect(mixedStrikeRecorder).toHaveBeenCalledTimes(1);

    // 5. Video owner submitting Community Note on their own video is directed to Appeals Desk
    const ownerRes = await mixedService.processClaimNoteEvidence({
      videoId: "vid_owner",
      commentId: "c_owner",
      comment: {
        userId: "owner_1",
        stance: "supports",
        claimIndex: 0,
        sourceUrls: ["https://www.nasa.gov/mission/apollo-11/"],
      },
      ownerCheck: async () => true,
      restrictionCheck: async () => ({ restricted: false, restrictedUntilMs: 0, strikes: 0, tier: 0, label: "none" }),
      updateCommentStatus: async () => {},
    });
    expect(ownerRes.status).toBe("owner_must_use_appeals");
  });
});
