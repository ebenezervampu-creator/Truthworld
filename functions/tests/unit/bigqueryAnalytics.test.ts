import {
  BigQueryAnalyticsService,
  BigQueryWatchEvent,
  BigQueryImpression,
  BigQueryCopyrightMatch,
  BigQueryCopyrightClaim,
  BigQueryCopyrightAppeal,
  BigQueryVerifiedClaim,
  BigQueryFactCheckEvaluation,
  BigQueryCreatorEarning,
  BigQueryPayoutTransaction,
  BigQueryMonetizationDeduction,
  BigQueryAdImpression,
  BigQueryAdClick,
  BigQueryAdFraudSignal,
  BigQuerySearchQuery,
  BigQuerySearchClickthrough,
  BigQueryModerationScan,
  BigQueryModeratorAction,
} from "../../src/analytics/bigqueryService";

describe("Unit: BigQuery Analytics & Copyright Auditing Service", () => {
  let mockTableInsert: jest.Mock;
  let mockTableExists: jest.Mock;
  let mockDatasetExists: jest.Mock;
  let mockCreateDataset: jest.Mock;
  let mockCreateTable: jest.Mock;
  let mockQuery: jest.Mock;
  let mockBqClient: any;
  let service: BigQueryAnalyticsService;

  beforeEach(() => {
    mockTableInsert = jest.fn().mockResolvedValue([{}]);
    mockTableExists = jest.fn().mockResolvedValue([true]);
    mockDatasetExists = jest.fn().mockResolvedValue([true]);
    mockCreateDataset = jest.fn().mockResolvedValue([{}]);
    mockCreateTable = jest.fn().mockResolvedValue([{}]);
    mockQuery = jest.fn().mockResolvedValue([[{ totalViews: 42 }]]);

    const mockTable = {
      insert: mockTableInsert,
      exists: mockTableExists,
    };

    const mockDataset = {
      table: jest.fn().mockReturnValue(mockTable),
      exists: mockDatasetExists,
      createTable: mockCreateTable,
    };

    mockBqClient = {
      dataset: jest.fn().mockReturnValue(mockDataset),
      createDataset: mockCreateDataset,
      query: mockQuery,
    };

    service = new BigQueryAnalyticsService(
      {
        datasetId: "test_analytics",
        location: "asia-south1",
        batchSize: 5,
        flushIntervalMs: 0, // Disable automatic background timer in test
        enabled: true,
      },
      mockBqClient as any
    );
  });

  afterEach(() => {
    service.stopFlushTimer();
  });

  describe("Schema Initialization", () => {
    it("creates dataset and all 17 partitioned tables plus 5 curated analytical views if they do not exist", async () => {
      mockDatasetExists.mockResolvedValueOnce([false]);
      mockTableExists.mockResolvedValueOnce([false]); // watch_events
      mockTableExists.mockResolvedValueOnce([false]); // impressions
      mockTableExists.mockResolvedValueOnce([false]); // copyright_matches
      mockTableExists.mockResolvedValueOnce([false]); // copyright_claims
      mockTableExists.mockResolvedValueOnce([false]); // copyright_appeals
      mockTableExists.mockResolvedValueOnce([false]); // claims_verified
      mockTableExists.mockResolvedValueOnce([false]); // fact_check_evaluations
      mockTableExists.mockResolvedValueOnce([false]); // creator_earnings
      mockTableExists.mockResolvedValueOnce([false]); // payout_transactions
      mockTableExists.mockResolvedValueOnce([false]); // monetization_deductions
      mockTableExists.mockResolvedValueOnce([false]); // ad_impressions
      mockTableExists.mockResolvedValueOnce([false]); // ad_clicks
      mockTableExists.mockResolvedValueOnce([false]); // ad_fraud_signals
      mockTableExists.mockResolvedValueOnce([false]); // search_queries
      mockTableExists.mockResolvedValueOnce([false]); // search_clickthroughs
      mockTableExists.mockResolvedValueOnce([false]); // moderation_scans
      mockTableExists.mockResolvedValueOnce([false]); // moderator_actions
      mockTableExists.mockResolvedValueOnce([false]); // v_creator_daily_pnl
      mockTableExists.mockResolvedValueOnce([false]); // v_credibility_claim_radar
      mockTableExists.mockResolvedValueOnce([false]); // v_ad_campaign_performance
      mockTableExists.mockResolvedValueOnce([false]); // v_trending_search_clusters
      mockTableExists.mockResolvedValueOnce([false]); // v_moderation_compliance_audit

      await service.ensureSchema();

      expect(mockBqClient.createDataset).toHaveBeenCalledWith("test_analytics", {
        location: "asia-south1",
      });
      expect(mockCreateTable).toHaveBeenCalledTimes(22);

      // Verify watch table partitioning & clustering
      const watchTableCall = mockCreateTable.mock.calls[0];
      expect(watchTableCall[0]).toBe("raw_watch_events");
      expect(watchTableCall[1].timePartitioning).toEqual({ field: "timestamp", type: "DAY" });
      expect(watchTableCall[1].clustering.fields).toEqual(["video_id", "channel_id", "event_type"]);

      // Verify impressions table partitioning & clustering
      const impTableCall = mockCreateTable.mock.calls[1];
      expect(impTableCall[0]).toBe("raw_impressions");
      expect(impTableCall[1].timePartitioning).toEqual({ field: "timestamp", type: "DAY" });
      expect(impTableCall[1].clustering.fields).toEqual(["video_id", "surface"]);

      // Verify copyright matches table
      const matchTableCall = mockCreateTable.mock.calls[2];
      expect(matchTableCall[0]).toBe("raw_copyright_matches");
      expect(matchTableCall[1].timePartitioning).toEqual({ field: "timestamp", type: "DAY" });
      expect(matchTableCall[1].clustering.fields).toEqual(["matched_video_id", "original_video_id", "match_type"]);

      // Verify copyright claims table
      const claimTableCall = mockCreateTable.mock.calls[3];
      expect(claimTableCall[0]).toBe("raw_copyright_claims");
      expect(claimTableCall[1].timePartitioning).toEqual({ field: "timestamp", type: "DAY" });
      expect(claimTableCall[1].clustering.fields).toEqual(["infringing_video_id", "claimant_id", "claim_status"]);

      // Verify copyright appeals table
      const appealTableCall = mockCreateTable.mock.calls[4];
      expect(appealTableCall[0]).toBe("raw_copyright_appeals");
      expect(appealTableCall[1].timePartitioning).toEqual({ field: "timestamp", type: "DAY" });
      expect(appealTableCall[1].clustering.fields).toEqual(["video_id", "appellant_id", "appeal_status"]);

      // Verify verified claims table
      const verifiedClaimsCall = mockCreateTable.mock.calls[5];
      expect(verifiedClaimsCall[0]).toBe("raw_claims_verified");
      expect(verifiedClaimsCall[1].timePartitioning).toEqual({ field: "timestamp", type: "DAY" });
      expect(verifiedClaimsCall[1].clustering.fields).toEqual(["video_id", "status", "verification_method"]);

      // Verify fact check evaluations table
      const evalCall = mockCreateTable.mock.calls[6];
      expect(evalCall[0]).toBe("raw_fact_check_evaluations");
      expect(evalCall[1].timePartitioning).toEqual({ field: "timestamp", type: "DAY" });
      expect(evalCall[1].clustering.fields).toEqual(["video_id", "channel_id", "conclusion_label"]);

      // Verify creator earnings table
      const earnCall = mockCreateTable.mock.calls[7];
      expect(earnCall[0]).toBe("raw_creator_earnings_daily");
      expect(earnCall[1].timePartitioning).toEqual({ field: "timestamp", type: "DAY" });
      expect(earnCall[1].clustering.fields).toEqual(["channel_id", "user_id", "channel_type"]);

      // Verify payout transactions table
      const payoutCall = mockCreateTable.mock.calls[8];
      expect(payoutCall[0]).toBe("raw_payout_transactions");
      expect(payoutCall[1].timePartitioning).toEqual({ field: "timestamp", type: "DAY" });
      expect(payoutCall[1].clustering.fields).toEqual(["channel_id", "user_id", "payout_status"]);

      // Verify monetization deductions table
      const deductCall = mockCreateTable.mock.calls[9];
      expect(deductCall[0]).toBe("raw_monetization_deductions_ledger");
      expect(deductCall[1].timePartitioning).toEqual({ field: "timestamp", type: "DAY" });
      expect(deductCall[1].clustering.fields).toEqual(["video_id", "source_channel_id", "beneficiary_channel_id"]);

      // Verify ad impressions table
      const adImpCall = mockCreateTable.mock.calls[10];
      expect(adImpCall[0]).toBe("raw_ad_impressions");
      expect(adImpCall[1].timePartitioning).toEqual({ field: "timestamp", type: "DAY" });
      expect(adImpCall[1].clustering.fields).toEqual(["campaign_id", "channel_id", "ad_type"]);

      // Verify ad clicks table
      const adClickCall = mockCreateTable.mock.calls[11];
      expect(adClickCall[0]).toBe("raw_ad_clicks");
      expect(adClickCall[1].timePartitioning).toEqual({ field: "timestamp", type: "DAY" });
      expect(adClickCall[1].clustering.fields).toEqual(["campaign_id", "channel_id"]);

      // Verify ad fraud signals table
      const fraudCall = mockCreateTable.mock.calls[12];
      expect(fraudCall[0]).toBe("raw_ad_fraud_signals");
      expect(fraudCall[1].timePartitioning).toEqual({ field: "timestamp", type: "DAY" });
      expect(fraudCall[1].clustering.fields).toEqual(["campaign_id", "fraud_type"]);

      // Verify search queries table
      const searchQueryCall = mockCreateTable.mock.calls[13];
      expect(searchQueryCall[0]).toBe("raw_search_queries");
      expect(searchQueryCall[1].timePartitioning).toEqual({ field: "timestamp", type: "DAY" });
      expect(searchQueryCall[1].clustering.fields).toEqual(["query_text", "search_mode", "filter"]);

      // Verify search clickthroughs table
      const searchClickCall = mockCreateTable.mock.calls[14];
      expect(searchClickCall[0]).toBe("raw_search_clickthroughs");
      expect(searchClickCall[1].timePartitioning).toEqual({ field: "timestamp", type: "DAY" });
      expect(searchClickCall[1].clustering.fields).toEqual(["query_text", "item_type", "item_id"]);

      // Verify moderation scans table
      const modScanCall = mockCreateTable.mock.calls[15];
      expect(modScanCall[0]).toBe("raw_moderation_scans");
      expect(modScanCall[1].timePartitioning).toEqual({ field: "timestamp", type: "DAY" });
      expect(modScanCall[1].clustering.fields).toEqual(["video_id", "moderation_status", "risk_level"]);

      // Verify moderator actions table
      const modActionCall = mockCreateTable.mock.calls[16];
      expect(modActionCall[0]).toBe("raw_moderator_actions");
      expect(modActionCall[1].timePartitioning).toEqual({ field: "timestamp", type: "DAY" });
      expect(modActionCall[1].clustering.fields).toEqual(["video_id", "action_type", "moderator_id"]);

      // Verify Silver Layer curated analytical views
      const creatorPnlViewCall = mockCreateTable.mock.calls[17];
      expect(creatorPnlViewCall[0]).toBe("v_creator_daily_pnl");
      expect(creatorPnlViewCall[1].view.useLegacySql).toBe(false);
      expect(creatorPnlViewCall[1].view.query).toContain("FROM `test_analytics.raw_creator_earnings_daily`");

      const claimRadarViewCall = mockCreateTable.mock.calls[18];
      expect(claimRadarViewCall[0]).toBe("v_credibility_claim_radar");
      expect(claimRadarViewCall[1].view.useLegacySql).toBe(false);
      expect(claimRadarViewCall[1].view.query).toContain("FROM `test_analytics.raw_claims_verified`");

      const adPerfViewCall = mockCreateTable.mock.calls[19];
      expect(adPerfViewCall[0]).toBe("v_ad_campaign_performance");
      expect(adPerfViewCall[1].view.useLegacySql).toBe(false);
      expect(adPerfViewCall[1].view.query).toContain("FROM `test_analytics.raw_ad_impressions`");

      const searchClustersViewCall = mockCreateTable.mock.calls[20];
      expect(searchClustersViewCall[0]).toBe("v_trending_search_clusters");
      expect(searchClustersViewCall[1].view.useLegacySql).toBe(false);
      expect(searchClustersViewCall[1].view.query).toContain("FROM `test_analytics.raw_search_queries`");

      const modAuditViewCall = mockCreateTable.mock.calls[21];
      expect(modAuditViewCall[0]).toBe("v_moderation_compliance_audit");
      expect(modAuditViewCall[1].view.useLegacySql).toBe(false);
      expect(modAuditViewCall[1].view.query).toContain("FROM `test_analytics.raw_moderation_scans`");
    });

    it("skips dataset and table creation if already present", async () => {
      mockDatasetExists.mockResolvedValueOnce([true]);
      mockTableExists.mockResolvedValue([true]);

      await service.ensureSchema();

      expect(mockBqClient.createDataset).not.toHaveBeenCalled();
      expect(mockCreateTable).not.toHaveBeenCalled();
    });
  });

  describe("Buffering and Ingestion", () => {
    it("buffers watch events until batch size threshold is reached", async () => {
      const sampleEvent: BigQueryWatchEvent = {
        event_id: "evt_101",
        timestamp: new Date().toISOString(),
        video_id: "vid_test_01",
        channel_id: "chan_test_01",
        user_id: "usr_01",
        session_id: "sess_01",
        event_type: "watch_ping",
        position_sec: 60,
        duration_sec: 300,
        watch_time_delta_sec: 60,
        country: "IN",
        state: "Telangana",
        city: "Hyderabad",
        area_type: "urban",
      };

      for (let i = 0; i < 4; i++) {
        service.enqueueWatchEvent({ ...sampleEvent, event_id: `evt_${i}` });
      }

      expect(service.getBufferSize().watchEvents).toBe(4);
      expect(mockTableInsert).not.toHaveBeenCalled();

      // 5th event triggers flush
      service.enqueueWatchEvent({ ...sampleEvent, event_id: "evt_4" });

      await new Promise((resolve) => setTimeout(resolve, 10));

      expect(mockTableInsert).toHaveBeenCalledTimes(1);
      expect(service.getBufferSize().watchEvents).toBe(0);
    });

    it("manually flushes buffered impressions, copyright matches, claims, and appeals", async () => {
      const sampleImp: BigQueryImpression = {
        impression_id: "imp_1",
        timestamp: new Date().toISOString(),
        video_id: "vid_test_02",
        surface: "home_feed",
      };

      const sampleMatch: BigQueryCopyrightMatch = {
        match_id: "match_101",
        timestamp: new Date().toISOString(),
        matched_video_id: "vid_infringing_01",
        original_video_id: "vid_original_01",
        asset_id: "asset_01",
        match_type: "transcript_similarity",
        composite_score: 0.92,
        status: "detected",
      };

      const sampleClaim: BigQueryCopyrightClaim = {
        claim_id: "claim_101",
        timestamp: new Date().toISOString(),
        match_id: "match_101",
        infringing_video_id: "vid_infringing_01",
        original_video_id: "vid_original_01",
        claim_status: "active",
        claim_policy: "monetize_shared",
        claim_impact: "Revenue Shared",
      };

      const sampleAppeal: BigQueryCopyrightAppeal = {
        appeal_id: "appeal_101",
        timestamp: new Date().toISOString(),
        claim_id: "claim_101",
        video_id: "vid_infringing_01",
        appellant_id: "user_creator_01",
        appeal_status: "pending",
        appellant_reason: "Fair use critique & commentary under Section 52",
      };

      const sampleClaimEntity: BigQueryVerifiedClaim = {
        claim_id: "claim_fact_01",
        timestamp: new Date().toISOString(),
        video_id: "vid_test_02",
        channel_id: "chan_test_01",
        user_id: "usr_01",
        claim_text: "India launched Chandrayaan-3 in 2023",
        status: "verified_true",
        verification_method: "gemini_grounded",
        verification_confidence: 0.98,
        reasoning: "Confirmed by ISRO official records",
        is_grounded: true,
      };

      const sampleEvalEntity: BigQueryFactCheckEvaluation = {
        evaluation_id: "eval_test_01",
        timestamp: new Date().toISOString(),
        video_id: "vid_test_02",
        channel_id: "chan_test_01",
        user_id: "usr_01",
        total_claims: 1,
        evaluated_claims: 1,
        correct_claims: 1,
        mostly_correct_claims: 0,
        incorrect_claims: 0,
        unverifiable_claims: 0,
        cache_hit_rate: 0.5,
        language: "en",
        conclusion_label: "Factual",
      };

      const sampleEarning: BigQueryCreatorEarning = {
        earning_id: "earn_2026-10_chan_01",
        date: "2026-10-27",
        timestamp: new Date().toISOString(),
        channel_id: "chan_test_01",
        user_id: "usr_01",
        total_views: 12000,
        gross_ads_revenue_inr: 500.0,
        gross_subs_revenue_inr: 300.0,
        gross_premium_revenue_inr: 200.0,
        platform_fee_inr: 180.0,
        net_creator_share_inr: 820.0,
        avg_rpm: 83.33,
        channel_type: "standard",
        is_finalized: false,
      };

      const samplePayout: BigQueryPayoutTransaction = {
        payout_id: "payout_req_01",
        timestamp: new Date().toISOString(),
        transfer_reference: "TW-PAYOUT-REQ01",
        channel_id: "chan_test_01",
        user_id: "usr_01",
        amount_inr: 1000.0,
        payment_method: "UPI",
        payout_status: "processing",
        tds_deducted_inr: 0,
        net_disbursed_inr: 1000.0,
      };

      const sampleDeduction: BigQueryMonetizationDeduction = {
        deduction_id: "deduct_claim_01",
        timestamp: new Date().toISOString(),
        video_id: "vid_infringing_01",
        source_channel_id: "chan_infringing_01",
        beneficiary_channel_id: "chan_original_01",
        claim_id: "claim_101",
        deduction_type: "copyright_split",
        split_ratio: 0.50,
        gross_revenue_inr: 400.0,
        diverted_amount_inr: 200.0,
        currency: "INR",
      };

      const sampleAdImp: BigQueryAdImpression = {
        ad_event_id: "ad_imp_01",
        timestamp: new Date().toISOString(),
        campaign_id: "camp_01",
        advertiser_id: "adv_01",
        channel_id: "chan_test_01",
        video_id: "vid_test_01",
        viewer_id: "usr_01",
        ad_type: "skippable",
        charge_model: "cpm",
        gross_charge_inr: 0.015,
        channel_share_inr: 0.0105,
        platform_share_inr: 0.0045,
        is_fraud_suppressed: false,
      };

      const sampleAdClick: BigQueryAdClick = {
        click_id: "ad_click_01",
        timestamp: new Date().toISOString(),
        ad_event_id: "ad_imp_01",
        campaign_id: "camp_01",
        channel_id: "chan_test_01",
        video_id: "vid_test_01",
        viewer_id: "usr_01",
        destination_url: "https://example.com/product",
        cost_per_click_inr: 2.0,
      };

      const sampleAdFraud: BigQueryAdFraudSignal = {
        signal_id: "ad_fraud_01",
        timestamp: new Date().toISOString(),
        campaign_id: "camp_01",
        viewer_id: "usr_fraud_01",
        fraud_type: "rate_limit_exceeded",
        action_taken: "rate_limited",
      };

      const sampleSearchQ: BigQuerySearchQuery = {
        query_id: "q_101",
        timestamp: new Date().toISOString(),
        query_text: "space exploration 2026",
        filter: "Videos",
        search_mode: "hybrid_semantic",
        results_count: 15,
        latency_ms: 120,
        user_id: "usr_01",
        is_zero_result: false,
      };

      const sampleSearchClick: BigQuerySearchClickthrough = {
        click_id: "clk_101",
        timestamp: new Date().toISOString(),
        query_id: "q_101",
        query_text: "space exploration 2026",
        item_id: "vid_space_01",
        item_type: "video",
        rank_position: 1,
        time_to_click_sec: 2.4,
        user_id: "usr_01",
      };

      const sampleModScan: BigQueryModerationScan = {
        scan_id: "scan_101",
        timestamp: new Date().toISOString(),
        video_id: "vid_space_01",
        channel_id: "chn_space_01",
        uploader_id: "usr_01",
        moderation_status: "approved",
        risk_level: "low",
        confidence_score: 0.98,
        policy_action: "approve",
        violation_reason: null,
        violation_categories: [],
        detected_language: "en",
        model: "gemini-2.5-flash",
        processing_time_ms: 1240,
      };

      const sampleModAction: BigQueryModeratorAction = {
        action_id: "act_101",
        timestamp: new Date().toISOString(),
        video_id: "vid_space_01",
        channel_id: "chn_space_01",
        moderator_id: "admin_super",
        action_type: "approve",
        justification: "Verified compliance with guidelines.",
        statutory_legal_basis: null,
      };

      service.enqueueImpression(sampleImp);
      service.enqueueCopyrightMatch(sampleMatch);
      service.enqueueCopyrightClaim(sampleClaim);
      service.enqueueCopyrightAppeal(sampleAppeal);
      service.enqueueVerifiedClaim(sampleClaimEntity);
      service.enqueueFactCheckEvaluation(sampleEvalEntity);
      service.enqueueCreatorEarning(sampleEarning);
      service.enqueuePayoutTransaction(samplePayout);
      service.enqueueMonetizationDeduction(sampleDeduction);
      service.enqueueAdImpression(sampleAdImp);
      service.enqueueAdClick(sampleAdClick);
      service.enqueueAdFraudSignal(sampleAdFraud);
      service.enqueueSearchQuery(sampleSearchQ);
      service.enqueueSearchClickthrough(sampleSearchClick);
      service.enqueueModerationScan(sampleModScan);
      service.enqueueModeratorAction(sampleModAction);

      const bufferSize = service.getBufferSize();
      expect(bufferSize.impressions).toBe(1);
      expect(bufferSize.copyrightMatches).toBe(1);
      expect(bufferSize.copyrightClaims).toBe(1);
      expect(bufferSize.copyrightAppeals).toBe(1);
      expect(bufferSize.verifiedClaims).toBe(1);
      expect(bufferSize.factCheckEvaluations).toBe(1);
      expect(bufferSize.creatorEarnings).toBe(1);
      expect(bufferSize.payoutTransactions).toBe(1);
      expect(bufferSize.monetizationDeductions).toBe(1);
      expect(bufferSize.adImpressions).toBe(1);
      expect(bufferSize.adClicks).toBe(1);
      expect(bufferSize.adFraudSignals).toBe(1);
      expect(bufferSize.searchQueries).toBe(1);
      expect(bufferSize.searchClickthroughs).toBe(1);
      expect(bufferSize.moderationScans).toBe(1);
      expect(bufferSize.moderatorActions).toBe(1);

      await service.flush();

      // 16 tables were inserted into
      expect(mockTableInsert).toHaveBeenCalledTimes(16);

      const emptyBuffer = service.getBufferSize();
      expect(emptyBuffer.impressions).toBe(0);
      expect(emptyBuffer.copyrightMatches).toBe(0);
      expect(emptyBuffer.copyrightClaims).toBe(0);
      expect(emptyBuffer.copyrightAppeals).toBe(0);
      expect(emptyBuffer.verifiedClaims).toBe(0);
      expect(emptyBuffer.factCheckEvaluations).toBe(0);
      expect(emptyBuffer.creatorEarnings).toBe(0);
      expect(emptyBuffer.payoutTransactions).toBe(0);
      expect(emptyBuffer.monetizationDeductions).toBe(0);
      expect(emptyBuffer.adImpressions).toBe(0);
      expect(emptyBuffer.adClicks).toBe(0);
      expect(emptyBuffer.adFraudSignals).toBe(0);
      expect(emptyBuffer.searchQueries).toBe(0);
      expect(emptyBuffer.searchClickthroughs).toBe(0);
      expect(emptyBuffer.moderationScans).toBe(0);
      expect(emptyBuffer.moderatorActions).toBe(0);
    });

    it("gracefully catches insert errors and re-enqueues failed rows without throwing", async () => {
      mockTableInsert.mockRejectedValueOnce(new Error("BigQuery streaming quota exceeded"));

      const sampleEvent: BigQueryWatchEvent = {
        event_id: "evt_err",
        timestamp: new Date().toISOString(),
        video_id: "vid_01",
        event_type: "video_start",
      };

      service.enqueueWatchEvent(sampleEvent);
      await expect(service.flush()).resolves.not.toThrow();

      // Row should be safely preserved in buffer for next flush
      expect(service.getBufferSize().watchEvents).toBe(1);
    });
  });

  describe("Analytical Query Execution", () => {
    it("runs SQL query against BigQuery and returns rows", async () => {
      const rows = await service.query("SELECT COUNT(*) as total FROM `raw_copyright_claims`");

      expect(mockQuery).toHaveBeenCalledWith({
        query: "SELECT COUNT(*) as total FROM `raw_copyright_claims`",
        params: undefined,
        location: "asia-south1",
      });
      expect(rows).toEqual([{ totalViews: 42 }]);
    });

    it("queries creator daily P&L from v_creator_daily_pnl view", async () => {
      mockQuery.mockResolvedValueOnce([
        [{ date: "2026-10-27", channel_id: "chan_01", effective_creator_net_inr: 4500 }],
      ]);

      const pnl = await service.getCreatorDailyPnl("chan_01", 14);

      expect(mockQuery).toHaveBeenCalledWith(
        expect.objectContaining({
          query: expect.stringContaining("FROM `test_analytics.v_creator_daily_pnl`"),
          params: { channelId: "chan_01", limitDays: 14 },
          location: "asia-south1",
        })
      );
      expect(pnl).toHaveLength(1);
      expect(pnl[0].effective_creator_net_inr).toBe(4500);
    });

    it("queries credibility claim radar from v_credibility_claim_radar view", async () => {
      mockQuery.mockResolvedValueOnce([
        [{ claim_hash: "hash_01", claim_text_normalized: "Earth orbits Sun", occurrence_count: 5 }],
      ]);

      const radar = await service.getCredibilityRadar(2, 20);

      expect(mockQuery).toHaveBeenCalledWith(
        expect.objectContaining({
          query: expect.stringContaining("FROM `test_analytics.v_credibility_claim_radar`"),
          params: { minOccurrences: 2, limit: 20 },
          location: "asia-south1",
        })
      );
      expect(radar[0].occurrence_count).toBe(5);
    });

    it("queries ad campaign performance from v_ad_campaign_performance view", async () => {
      mockQuery.mockResolvedValueOnce([
        [{ campaign_id: "camp_01", total_impressions: 12000, ctr_percent: 2.5 }],
      ]);

      const perf = await service.getAdCampaignPerformance("camp_01");

      expect(mockQuery).toHaveBeenCalledWith(
        expect.objectContaining({
          query: expect.stringContaining("FROM `test_analytics.v_ad_campaign_performance`"),
          params: { campaignId: "camp_01" },
          location: "asia-south1",
        })
      );
      expect(perf[0].ctr_percent).toBe(2.5);
    });

    it("queries trending search clusters from v_trending_search_clusters view", async () => {
      mockQuery.mockResolvedValueOnce([
        [{ query_text: "space exploration", search_volume: 850, clickthrough_rate_percent: 64.2 }],
      ]);

      const clusters = await service.getTrendingSearchClusters(10);

      expect(mockQuery).toHaveBeenCalledWith(
        expect.objectContaining({
          query: expect.stringContaining("FROM `test_analytics.v_trending_search_clusters`"),
          params: { limit: 10 },
          location: "asia-south1",
        })
      );
      expect(clusters[0].search_volume).toBe(850);
    });

    it("queries moderation compliance audit from v_moderation_compliance_audit view", async () => {
      mockQuery.mockResolvedValueOnce([
        [{ scan_date: "2026-10-27", total_scans: 350, auto_rejection_count: 12 }],
      ]);

      const audit = await service.getModerationComplianceAudit(7);

      expect(mockQuery).toHaveBeenCalledWith(
        expect.objectContaining({
          query: expect.stringContaining("FROM `test_analytics.v_moderation_compliance_audit`"),
          params: { days: 7 },
          location: "asia-south1",
        })
      );
      expect(audit[0].auto_rejection_count).toBe(12);
    });
  });
});
