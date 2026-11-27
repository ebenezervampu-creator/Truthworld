import { BigQuery, Table } from "@google-cloud/bigquery";
import { resolveBigQueryAnalyticsEnabled } from "../config/env";
import { logger } from "../pipeline/utils/logger";

// ─── Playback & View Telemetry ────────────────────────────────────────────────
export interface BigQueryWatchEvent {
  event_id: string;
  timestamp: string; // ISO 8601 string
  client_timestamp?: string | null;
  video_id: string;
  channel_id?: string | null;
  user_id?: string | null;
  session_id?: string | null;
  event_type: string;
  position_sec?: number | null;
  duration_sec?: number | null;
  watch_time_delta_sec?: number | null;
  is_subscriber?: boolean | null;
  is_premium?: boolean | null;
  country?: string | null;
  state?: string | null;
  city?: string | null;
  area_type?: string | null;
  playback_quality?: string | null;
  playback_rate?: number | null;
  platform?: string | null;
  traffic_source?: string | null;
  ip_hash?: string | null;
}

export interface BigQueryImpression {
  impression_id: string;
  timestamp: string; // ISO 8601 string
  video_id: string;
  channel_id?: string | null;
  user_id?: string | null;
  surface?: string | null;
  position_index?: number | null;
}

// ─── Copyright & DRM Telemetry ────────────────────────────────────────────────
export interface BigQueryCopyrightMatch {
  match_id: string;
  timestamp: string; // ISO 8601 string
  matched_video_id: string;
  original_video_id: string;
  asset_id: string;
  claimant_channel_id?: string | null;
  infringing_channel_id?: string | null;
  match_type: string;
  composite_score?: number | null;
  md5_score?: number | null;
  embedding_score?: number | null;
  transcript_score?: number | null;
  semantic_score?: number | null;
  segments_count?: number | null;
  status: string;
}

export interface BigQueryCopyrightClaim {
  claim_id: string;
  timestamp: string; // ISO 8601 string
  match_id?: string | null;
  asset_id?: string | null;
  original_video_id?: string | null;
  infringing_video_id: string;
  claimant_id?: string | null;
  infringing_creator_id?: string | null;
  claim_status: string;
  claim_policy?: string | null;
  claim_impact?: string | null;
  fair_use_score?: number | null;
  fair_use_category?: string | null;
  resolved_at?: string | null;
  resolution_reason?: string | null;
}

export interface BigQueryCopyrightAppeal {
  appeal_id: string;
  timestamp: string; // ISO 8601 string
  claim_id: string;
  video_id: string;
  appellant_id: string;
  claimant_id?: string | null;
  appeal_status: string;
  appellant_reason?: string | null;
  ai_fair_use_score?: number | null;
  resolved_at?: string | null;
}

// ─── Fact-Checking & Credibility Intelligence ────────────────────────────────
export interface BigQueryVerifiedClaim {
  claim_id: string;
  timestamp: string; // ISO 8601 string
  video_id: string;
  channel_id?: string | null;
  user_id?: string | null;
  claim_text: string;
  normalized_claim_hash?: string | null;
  english_claim_hash?: string | null;
  semantic_hash?: string | null;
  evidence_schema_version?: string | number | null;
  rich_sources_json?: string | null;
  speaker?: string | null;
  start_sec?: number | null;
  end_sec?: number | null;
  status: string;
  verification_method?: string | null;
  verification_confidence?: number | null;
  evidence_confidence?: number | null;
  reasoning?: string | null;
  sources_count?: number | null;
  primary_source_url?: string | null;
  primary_source_domain?: string | null;
  primary_source_tier?: string | null;
  is_grounded?: boolean | null;
  nature?: string | null;
  importance?: number | null;
  gemini_model?: string | null;
  language?: string | null;
}

export interface BigQueryFactCheckEvaluation {
  evaluation_id: string;
  timestamp: string; // ISO 8601 string
  video_id: string;
  channel_id?: string | null;
  user_id?: string | null;
  total_claims: number;
  evaluated_claims: number;
  correct_claims: number;
  mostly_correct_claims: number;
  incorrect_claims: number;
  unverifiable_claims: number;
  cache_hit_rate?: number | null;
  extraction_latency_ms?: number | null;
  verification_latency_ms?: number | null;
  total_latency_ms?: number | null;
  language?: string | null;
  conclusion_label?: string | null;
  is_degraded?: boolean | null;
}

export interface BigQueryCreatorEarning {
  earning_id: string;
  date: string; // YYYY-MM-DD
  timestamp: string; // ISO 8601
  channel_id: string;
  user_id: string;
  total_views: number;
  gross_ads_revenue_inr: number;
  gross_subs_revenue_inr: number;
  gross_premium_revenue_inr: number;
  platform_fee_inr: number;
  net_creator_share_inr: number;
  avg_rpm: number;
  channel_type: string; // standard | custom
  is_finalized: boolean;
}

export interface BigQueryPayoutTransaction {
  payout_id: string;
  timestamp: string; // ISO 8601
  transfer_reference: string;
  channel_id: string;
  user_id: string;
  amount_inr: number;
  payment_method?: string | null;
  payout_status: string; // processing | completed | failed | held | rejected
  tds_deducted_inr?: number | null;
  net_disbursed_inr?: number | null;
  reconciled_withdrawable_before_inr?: number | null;
  hold_or_reject_reason?: string | null;
}

export interface BigQueryMonetizationDeduction {
  deduction_id: string;
  timestamp: string; // ISO 8601
  video_id: string;
  source_channel_id: string;
  beneficiary_channel_id: string;
  claim_id?: string | null;
  deduction_type: string; // copyright_split | dispute_escrow | tax_withholding | platform_admin
  split_ratio: number;
  gross_revenue_inr: number;
  diverted_amount_inr: number;
  currency?: string | null;
}

export interface BigQueryAdImpression {
  ad_event_id: string;
  timestamp: string; // ISO 8601
  campaign_id: string;
  advertiser_id?: string | null;
  channel_id?: string | null;
  video_id?: string | null;
  viewer_id?: string | null;
  ad_type: string; // homepage | scroll | skippable | comment
  charge_model: string; // cpm | cpv | cpc
  gross_charge_inr?: number | null;
  channel_share_inr?: number | null;
  platform_share_inr?: number | null;
  is_fraud_suppressed?: boolean | null;
  fraud_reason?: string | null;
}

export interface BigQueryAdClick {
  click_id: string;
  timestamp: string; // ISO 8601
  ad_event_id?: string | null;
  campaign_id: string;
  channel_id?: string | null;
  video_id?: string | null;
  viewer_id?: string | null;
  destination_url?: string | null;
  cost_per_click_inr?: number | null;
}

export interface BigQueryAdFraudSignal {
  signal_id: string;
  timestamp: string; // ISO 8601
  campaign_id: string;
  viewer_id?: string | null;
  ip_hash?: string | null;
  fraud_type: string; // self_view | rate_limit_exceeded | channel_mismatch | velocity_spike
  action_taken: string; // suppressed_credit | rate_limited | campaign_paused
}

export interface BigQuerySearchQuery {
  query_id: string;
  timestamp: string; // ISO 8601
  query_text: string;
  filter?: string | null;
  search_mode: string; // hybrid_semantic | channel_handle | cache_l1 | cache_l2
  results_count: number;
  latency_ms: number;
  user_id?: string | null;
  is_zero_result: boolean;
}

export interface BigQuerySearchClickthrough {
  click_id: string;
  timestamp: string; // ISO 8601
  query_id: string;
  query_text: string;
  item_id: string;
  item_type: string; // video | channel | topic | playlist
  rank_position: number;
  time_to_click_sec?: number | null;
  user_id?: string | null;
}

export interface BigQueryModerationScan {
  scan_id: string;
  timestamp: string; // ISO 8601
  video_id: string;
  channel_id?: string | null;
  uploader_id?: string | null;
  moderation_status: string; // approved | rejected | flagged_for_review | manual_review | error
  risk_level?: string | null;
  confidence_score?: number | null;
  policy_action?: string | null;
  violation_reason?: string | null;
  violation_categories?: string[] | null;
  detected_language?: string | null;
  model?: string | null;
  processing_time_ms?: number | null;
}

export interface BigQueryModeratorAction {
  action_id: string;
  timestamp: string; // ISO 8601
  video_id: string;
  channel_id?: string | null;
  moderator_id: string;
  action_type: string; // approve | reject | hold | quarantine | strike | clear
  justification?: string | null;
  statutory_legal_basis?: string | null;
}

// ─── Silver Layer: Curated Analytical View Record Types ───────────────────────

export interface CreatorDailyPnlRow {
  date: string;
  channel_id: string;
  user_id: string;
  channel_type?: string;
  total_views?: number;
  gross_ads_revenue_inr?: number;
  gross_subs_revenue_inr?: number;
  gross_premium_revenue_inr?: number;
  total_gross_revenue_inr: number;
  platform_fee_inr?: number;
  total_copyright_deductions_inr: number;
  effective_creator_net_inr: number;
  avg_rpm?: number;
  is_finalized?: boolean;
  total_payout_disbursed_inr: number;
  total_tds_withheld_inr: number;
}

export interface CredibilityClaimRadarRow {
  claim_hash: string;
  claim_text_normalized: string;
  status: string;
  occurrence_count: number;
  distinct_videos_count: number;
  avg_confidence: number;
  primary_verification_method?: string;
  highest_source_tier?: string;
  is_grounded_anywhere?: boolean;
  first_detected_at: string;
  last_detected_at: string;
  sample_video_ids?: string[];
}

export interface AdCampaignPerformanceRow {
  campaign_id: string;
  advertiser_id?: string;
  event_date: string;
  ad_type: string;
  total_impressions: number;
  valid_impressions: number;
  fraud_suppressed_impressions: number;
  unique_viewers: number;
  distinct_channels_reached: number;
  total_gross_spend_inr: number;
  total_creator_payout_inr: number;
  total_platform_margin_inr: number;
  clicks_count: number;
  ctr_percent: number;
  fraud_rate_percent: number;
}

export interface TrendingSearchClusterRow {
  query_text: string;
  search_date: string;
  search_mode: string;
  search_volume: number;
  zero_result_count: number;
  zero_result_percent: number;
  avg_results_count: number;
  avg_latency_ms: number;
  click_count: number;
  clickthrough_rate_percent: number;
  avg_rank_selected?: number;
  avg_time_to_click_sec?: number;
}

export interface ModerationComplianceAuditRow {
  scan_date: string;
  moderation_status: string;
  risk_level?: string;
  model?: string;
  total_scans: number;
  avg_confidence?: number;
  avg_processing_time_ms?: number;
  auto_rejection_count: number;
  auto_flagged_count: number;
  human_action_count: number;
  human_override_count: number;
}

export interface BigQueryConfig {
  datasetId?: string;
  location?: string;
  projectId?: string;
  batchSize?: number;
  flushIntervalMs?: number;
  enabled?: boolean;
}

/**
 * 📊 BigQuery Analytics & Auditing Service
 *
 * Enterprise analytical warehouse for high-velocity telemetry, DRM & intelligence:
 * - Playback watch events & impressions.
 * - Copyright detection matches, claims, and appeals.
 * - Fact-checking claims warehouse & credibility evaluations.
 * - Non-blocking streaming buffer with micro-batching.
 * - Partitioned by timestamp (DAY) and clustered by query keys.
 */
export class BigQueryAnalyticsService {
  private bigquery: BigQuery;
  private readonly datasetId: string;
  private readonly location: string;
  private readonly batchSize: number;
  private readonly flushIntervalMs: number;
  private readonly enabled: boolean;

  private watchEventBuffer: BigQueryWatchEvent[] = [];
  private impressionBuffer: BigQueryImpression[] = [];
  private copyrightMatchBuffer: BigQueryCopyrightMatch[] = [];
  private copyrightClaimBuffer: BigQueryCopyrightClaim[] = [];
  private copyrightAppealBuffer: BigQueryCopyrightAppeal[] = [];
  private verifiedClaimBuffer: BigQueryVerifiedClaim[] = [];
  private factCheckEvaluationBuffer: BigQueryFactCheckEvaluation[] = [];
  private creatorEarningsBuffer: BigQueryCreatorEarning[] = [];
  private payoutTransactionsBuffer: BigQueryPayoutTransaction[] = [];
  private monetizationDeductionsBuffer: BigQueryMonetizationDeduction[] = [];
  private adImpressionBuffer: BigQueryAdImpression[] = [];
  private adClickBuffer: BigQueryAdClick[] = [];
  private adFraudSignalBuffer: BigQueryAdFraudSignal[] = [];
  private searchQueryBuffer: BigQuerySearchQuery[] = [];
  private searchClickthroughBuffer: BigQuerySearchClickthrough[] = [];
  private moderationScanBuffer: BigQueryModerationScan[] = [];
  private moderatorActionBuffer: BigQueryModeratorAction[] = [];

  private flushTimer: NodeJS.Timeout | null = null;
  private isFlushing = false;
  private schemaInitialized = false;
  private verifiedClaimsColumnsEnsured = false;

  public static readonly WATCH_EVENTS_TABLE = "raw_watch_events";
  public static readonly IMPRESSIONS_TABLE = "raw_impressions";
  public static readonly COPYRIGHT_MATCHES_TABLE = "raw_copyright_matches";
  public static readonly COPYRIGHT_CLAIMS_TABLE = "raw_copyright_claims";
  public static readonly COPYRIGHT_APPEALS_TABLE = "raw_copyright_appeals";
  public static readonly VERIFIED_CLAIMS_TABLE = "raw_claims_verified";
  public static readonly FACT_CHECK_EVALUATIONS_TABLE = "raw_fact_check_evaluations";
  public static readonly CREATOR_EARNINGS_TABLE = "raw_creator_earnings_daily";
  public static readonly PAYOUT_TRANSACTIONS_TABLE = "raw_payout_transactions";
  public static readonly MONETIZATION_DEDUCTIONS_TABLE = "raw_monetization_deductions_ledger";
  public static readonly AD_IMPRESSIONS_TABLE = "raw_ad_impressions";
  public static readonly AD_CLICKS_TABLE = "raw_ad_clicks";
  public static readonly AD_FRAUD_SIGNALS_TABLE = "raw_ad_fraud_signals";
  public static readonly SEARCH_QUERIES_TABLE = "raw_search_queries";
  public static readonly SEARCH_CLICKTHROUGHS_TABLE = "raw_search_clickthroughs";
  public static readonly MODERATION_SCANS_TABLE = "raw_moderation_scans";
  public static readonly MODERATOR_ACTIONS_TABLE = "raw_moderator_actions";

  // Silver Layer Curated Analytical Views
  public static readonly CREATOR_DAILY_PNL_VIEW = "v_creator_daily_pnl";
  public static readonly CREDIBILITY_CLAIM_RADAR_VIEW = "v_credibility_claim_radar";
  public static readonly AD_CAMPAIGN_PERFORMANCE_VIEW = "v_ad_campaign_performance";
  public static readonly TRENDING_SEARCH_CLUSTERS_VIEW = "v_trending_search_clusters";
  public static readonly MODERATION_COMPLIANCE_AUDIT_VIEW = "v_moderation_compliance_audit";

  constructor(config?: BigQueryConfig, bqClient?: BigQuery) {
    this.datasetId = config?.datasetId || process.env.BIGQUERY_DATASET || "truthworld_analytics";
    this.location = config?.location || process.env.BIGQUERY_LOCATION || "asia-south1";
    this.batchSize = config?.batchSize || 100;
    this.flushIntervalMs = config?.flushIntervalMs || 2000;
    const explicitEnabled =
      typeof config?.enabled === "boolean"
        ? config.enabled
        : bqClient
          ? process.env.ENABLE_BIGQUERY_ANALYTICS !== "false"
          : undefined;
    this.enabled = resolveBigQueryAnalyticsEnabled(explicitEnabled);

    this.bigquery = bqClient || new BigQuery({
      projectId: config?.projectId || process.env.GCP_PROJECT || process.env.GCLOUD_PROJECT,
    });

    if (this.enabled && this.flushIntervalMs > 0) {
      this.startFlushTimer();
    }
  }

  public isEnabled(): boolean {
    return this.enabled;
  }

  private startFlushTimer(): void {
    if (this.flushTimer) return;
    this.flushTimer = setInterval(() => {
      this.flush().catch((err) => {
        logger.error("[BigQueryAnalytics] Periodic buffer flush failed", { err: String(err) });
      });
    }, this.flushIntervalMs);

    // Unref timer so node process can exit cleanly during shutdown/tests
    if (this.flushTimer && typeof this.flushTimer.unref === "function") {
      this.flushTimer.unref();
    }
  }

  public stopFlushTimer(): void {
    if (this.flushTimer) {
      clearInterval(this.flushTimer);
      this.flushTimer = null;
    }
  }

  /**
   * Initializes the BigQuery dataset and analytical tables if they do not exist.
   * Uses daily partitioning and column clustering for optimal query performance.
   */
  async ensureSchema(): Promise<void> {
    if (!this.enabled || this.schemaInitialized) return;

    try {
      const dataset = this.bigquery.dataset(this.datasetId);
      const [datasetExists] = await dataset.exists();
      if (!datasetExists) {
        await this.bigquery.createDataset(this.datasetId, {
          location: this.location,
        });
        logger.info(`[BigQueryAnalytics] Created dataset '${this.datasetId}' in location '${this.location}'`);
      }

      // 1. Ensure raw_watch_events table
      const watchTable = dataset.table(BigQueryAnalyticsService.WATCH_EVENTS_TABLE);
      const [watchExists] = await watchTable.exists();
      if (!watchExists) {
        const watchSchema = [
          { name: "event_id", type: "STRING", mode: "REQUIRED" },
          { name: "timestamp", type: "TIMESTAMP", mode: "REQUIRED" },
          { name: "client_timestamp", type: "TIMESTAMP", mode: "NULLABLE" },
          { name: "video_id", type: "STRING", mode: "REQUIRED" },
          { name: "channel_id", type: "STRING", mode: "NULLABLE" },
          { name: "user_id", type: "STRING", mode: "NULLABLE" },
          { name: "session_id", type: "STRING", mode: "NULLABLE" },
          { name: "event_type", type: "STRING", mode: "REQUIRED" },
          { name: "position_sec", type: "FLOAT64", mode: "NULLABLE" },
          { name: "duration_sec", type: "FLOAT64", mode: "NULLABLE" },
          { name: "watch_time_delta_sec", type: "FLOAT64", mode: "NULLABLE" },
          { name: "is_subscriber", type: "BOOL", mode: "NULLABLE" },
          { name: "is_premium", type: "BOOL", mode: "NULLABLE" },
          { name: "country", type: "STRING", mode: "NULLABLE" },
          { name: "state", type: "STRING", mode: "NULLABLE" },
          { name: "city", type: "STRING", mode: "NULLABLE" },
          { name: "area_type", type: "STRING", mode: "NULLABLE" },
          { name: "playback_quality", type: "STRING", mode: "NULLABLE" },
          { name: "playback_rate", type: "FLOAT64", mode: "NULLABLE" },
          { name: "platform", type: "STRING", mode: "NULLABLE" },
          { name: "traffic_source", type: "STRING", mode: "NULLABLE" },
          { name: "ip_hash", type: "STRING", mode: "NULLABLE" },
        ];

        await dataset.createTable(BigQueryAnalyticsService.WATCH_EVENTS_TABLE, {
          schema: watchSchema,
          timePartitioning: { field: "timestamp", type: "DAY" },
          clustering: { fields: ["video_id", "channel_id", "event_type"] },
        });
        logger.info(`[BigQueryAnalytics] Created table '${BigQueryAnalyticsService.WATCH_EVENTS_TABLE}'`);
      }

      // 2. Ensure raw_impressions table
      const impTable = dataset.table(BigQueryAnalyticsService.IMPRESSIONS_TABLE);
      const [impExists] = await impTable.exists();
      if (!impExists) {
        const impSchema = [
          { name: "impression_id", type: "STRING", mode: "REQUIRED" },
          { name: "timestamp", type: "TIMESTAMP", mode: "REQUIRED" },
          { name: "video_id", type: "STRING", mode: "REQUIRED" },
          { name: "channel_id", type: "STRING", mode: "NULLABLE" },
          { name: "user_id", type: "STRING", mode: "NULLABLE" },
          { name: "surface", type: "STRING", mode: "NULLABLE" },
          { name: "position_index", type: "INT64", mode: "NULLABLE" },
        ];

        await dataset.createTable(BigQueryAnalyticsService.IMPRESSIONS_TABLE, {
          schema: impSchema,
          timePartitioning: { field: "timestamp", type: "DAY" },
          clustering: { fields: ["video_id", "surface"] },
        });
        logger.info(`[BigQueryAnalytics] Created table '${BigQueryAnalyticsService.IMPRESSIONS_TABLE}'`);
      }

      // 3. Ensure raw_copyright_matches table
      const matchTable = dataset.table(BigQueryAnalyticsService.COPYRIGHT_MATCHES_TABLE);
      const [matchExists] = await matchTable.exists();
      if (!matchExists) {
        const matchSchema = [
          { name: "match_id", type: "STRING", mode: "REQUIRED" },
          { name: "timestamp", type: "TIMESTAMP", mode: "REQUIRED" },
          { name: "matched_video_id", type: "STRING", mode: "REQUIRED" },
          { name: "original_video_id", type: "STRING", mode: "REQUIRED" },
          { name: "asset_id", type: "STRING", mode: "REQUIRED" },
          { name: "claimant_channel_id", type: "STRING", mode: "NULLABLE" },
          { name: "infringing_channel_id", type: "STRING", mode: "NULLABLE" },
          { name: "match_type", type: "STRING", mode: "REQUIRED" },
          { name: "composite_score", type: "FLOAT64", mode: "NULLABLE" },
          { name: "md5_score", type: "FLOAT64", mode: "NULLABLE" },
          { name: "embedding_score", type: "FLOAT64", mode: "NULLABLE" },
          { name: "transcript_score", type: "FLOAT64", mode: "NULLABLE" },
          { name: "semantic_score", type: "FLOAT64", mode: "NULLABLE" },
          { name: "segments_count", type: "INT64", mode: "NULLABLE" },
          { name: "status", type: "STRING", mode: "REQUIRED" },
        ];

        await dataset.createTable(BigQueryAnalyticsService.COPYRIGHT_MATCHES_TABLE, {
          schema: matchSchema,
          timePartitioning: { field: "timestamp", type: "DAY" },
          clustering: { fields: ["matched_video_id", "original_video_id", "match_type"] },
        });
        logger.info(`[BigQueryAnalytics] Created table '${BigQueryAnalyticsService.COPYRIGHT_MATCHES_TABLE}'`);
      }

      // 4. Ensure raw_copyright_claims table
      const claimTable = dataset.table(BigQueryAnalyticsService.COPYRIGHT_CLAIMS_TABLE);
      const [claimExists] = await claimTable.exists();
      if (!claimExists) {
        const claimSchema = [
          { name: "claim_id", type: "STRING", mode: "REQUIRED" },
          { name: "timestamp", type: "TIMESTAMP", mode: "REQUIRED" },
          { name: "match_id", type: "STRING", mode: "NULLABLE" },
          { name: "asset_id", type: "STRING", mode: "NULLABLE" },
          { name: "original_video_id", type: "STRING", mode: "NULLABLE" },
          { name: "infringing_video_id", type: "STRING", mode: "REQUIRED" },
          { name: "claimant_id", type: "STRING", mode: "NULLABLE" },
          { name: "infringing_creator_id", type: "STRING", mode: "NULLABLE" },
          { name: "claim_status", type: "STRING", mode: "REQUIRED" },
          { name: "claim_policy", type: "STRING", mode: "NULLABLE" },
          { name: "claim_impact", type: "STRING", mode: "NULLABLE" },
          { name: "fair_use_score", type: "FLOAT64", mode: "NULLABLE" },
          { name: "fair_use_category", type: "STRING", mode: "NULLABLE" },
          { name: "resolved_at", type: "TIMESTAMP", mode: "NULLABLE" },
          { name: "resolution_reason", type: "STRING", mode: "NULLABLE" },
        ];

        await dataset.createTable(BigQueryAnalyticsService.COPYRIGHT_CLAIMS_TABLE, {
          schema: claimSchema,
          timePartitioning: { field: "timestamp", type: "DAY" },
          clustering: { fields: ["infringing_video_id", "claimant_id", "claim_status"] },
        });
        logger.info(`[BigQueryAnalytics] Created table '${BigQueryAnalyticsService.COPYRIGHT_CLAIMS_TABLE}'`);
      }

      // 5. Ensure raw_copyright_appeals table
      const appealTable = dataset.table(BigQueryAnalyticsService.COPYRIGHT_APPEALS_TABLE);
      const [appealExists] = await appealTable.exists();
      if (!appealExists) {
        const appealSchema = [
          { name: "appeal_id", type: "STRING", mode: "REQUIRED" },
          { name: "timestamp", type: "TIMESTAMP", mode: "REQUIRED" },
          { name: "claim_id", type: "STRING", mode: "REQUIRED" },
          { name: "video_id", type: "STRING", mode: "REQUIRED" },
          { name: "appellant_id", type: "STRING", mode: "REQUIRED" },
          { name: "claimant_id", type: "STRING", mode: "NULLABLE" },
          { name: "appeal_status", type: "STRING", mode: "REQUIRED" },
          { name: "appellant_reason", type: "STRING", mode: "NULLABLE" },
          { name: "ai_fair_use_score", type: "FLOAT64", mode: "NULLABLE" },
          { name: "resolved_at", type: "TIMESTAMP", mode: "NULLABLE" },
        ];

        await dataset.createTable(BigQueryAnalyticsService.COPYRIGHT_APPEALS_TABLE, {
          schema: appealSchema,
          timePartitioning: { field: "timestamp", type: "DAY" },
          clustering: { fields: ["video_id", "appellant_id", "appeal_status"] },
        });
        logger.info(`[BigQueryAnalytics] Created table '${BigQueryAnalyticsService.COPYRIGHT_APPEALS_TABLE}'`);
      }

      // 6. Ensure raw_claims_verified table
      const verifiedClaimsTable = dataset.table(BigQueryAnalyticsService.VERIFIED_CLAIMS_TABLE);
      const [claimsExists] = await verifiedClaimsTable.exists();
      if (!claimsExists) {
        const verifiedClaimsSchema = [
          { name: "claim_id", type: "STRING", mode: "REQUIRED" },
          { name: "timestamp", type: "TIMESTAMP", mode: "REQUIRED" },
          { name: "video_id", type: "STRING", mode: "REQUIRED" },
          { name: "channel_id", type: "STRING", mode: "NULLABLE" },
          { name: "user_id", type: "STRING", mode: "NULLABLE" },
          { name: "claim_text", type: "STRING", mode: "REQUIRED" },
          { name: "normalized_claim_hash", type: "STRING", mode: "NULLABLE" },
          { name: "english_claim_hash", type: "STRING", mode: "NULLABLE" },
          { name: "semantic_hash", type: "STRING", mode: "NULLABLE" },
          { name: "evidence_schema_version", type: "STRING", mode: "NULLABLE" },
          { name: "rich_sources_json", type: "STRING", mode: "NULLABLE" },
          { name: "speaker", type: "STRING", mode: "NULLABLE" },
          { name: "start_sec", type: "FLOAT64", mode: "NULLABLE" },
          { name: "end_sec", type: "FLOAT64", mode: "NULLABLE" },
          { name: "status", type: "STRING", mode: "REQUIRED" },
          { name: "verification_method", type: "STRING", mode: "NULLABLE" },
          { name: "verification_confidence", type: "FLOAT64", mode: "NULLABLE" },
          { name: "evidence_confidence", type: "FLOAT64", mode: "NULLABLE" },
          { name: "reasoning", type: "STRING", mode: "NULLABLE" },
          { name: "sources_count", type: "INT64", mode: "NULLABLE" },
          { name: "primary_source_url", type: "STRING", mode: "NULLABLE" },
          { name: "primary_source_domain", type: "STRING", mode: "NULLABLE" },
          { name: "primary_source_tier", type: "STRING", mode: "NULLABLE" },
          { name: "is_grounded", type: "BOOL", mode: "NULLABLE" },
          { name: "nature", type: "STRING", mode: "NULLABLE" },
          { name: "importance", type: "FLOAT64", mode: "NULLABLE" },
          { name: "gemini_model", type: "STRING", mode: "NULLABLE" },
          { name: "language", type: "STRING", mode: "NULLABLE" },
        ];

        await dataset.createTable(BigQueryAnalyticsService.VERIFIED_CLAIMS_TABLE, {
          schema: verifiedClaimsSchema,
          timePartitioning: { field: "timestamp", type: "DAY" },
          clustering: { fields: ["video_id", "status", "verification_method"] },
        });
        this.verifiedClaimsColumnsEnsured = true;
        logger.info(`[BigQueryAnalytics] Created table '${BigQueryAnalyticsService.VERIFIED_CLAIMS_TABLE}'`);
      } else {
        await this.ensureVerifiedClaimsColumns(verifiedClaimsTable);
      }

      // 7. Ensure raw_fact_check_evaluations table
      const evalTable = dataset.table(BigQueryAnalyticsService.FACT_CHECK_EVALUATIONS_TABLE);
      const [evalExists] = await evalTable.exists();
      if (!evalExists) {
        const evalSchema = [
          { name: "evaluation_id", type: "STRING", mode: "REQUIRED" },
          { name: "timestamp", type: "TIMESTAMP", mode: "REQUIRED" },
          { name: "video_id", type: "STRING", mode: "REQUIRED" },
          { name: "channel_id", type: "STRING", mode: "NULLABLE" },
          { name: "user_id", type: "STRING", mode: "NULLABLE" },
          { name: "total_claims", type: "INT64", mode: "REQUIRED" },
          { name: "evaluated_claims", type: "INT64", mode: "REQUIRED" },
          { name: "correct_claims", type: "INT64", mode: "REQUIRED" },
          { name: "mostly_correct_claims", type: "INT64", mode: "NULLABLE" },
          { name: "incorrect_claims", type: "INT64", mode: "REQUIRED" },
          { name: "unverifiable_claims", type: "INT64", mode: "REQUIRED" },
          { name: "cache_hit_rate", type: "FLOAT64", mode: "NULLABLE" },
          { name: "extraction_latency_ms", type: "INT64", mode: "NULLABLE" },
          { name: "verification_latency_ms", type: "INT64", mode: "NULLABLE" },
          { name: "total_latency_ms", type: "INT64", mode: "NULLABLE" },
          { name: "language", type: "STRING", mode: "NULLABLE" },
          { name: "conclusion_label", type: "STRING", mode: "NULLABLE" },
          { name: "is_degraded", type: "BOOL", mode: "NULLABLE" },
        ];

        await dataset.createTable(BigQueryAnalyticsService.FACT_CHECK_EVALUATIONS_TABLE, {
          schema: evalSchema,
          timePartitioning: { field: "timestamp", type: "DAY" },
          clustering: { fields: ["video_id", "channel_id", "conclusion_label"] },
        });
        logger.info(`[BigQueryAnalytics] Created table '${BigQueryAnalyticsService.FACT_CHECK_EVALUATIONS_TABLE}'`);
      }

      // 8. Ensure raw_creator_earnings_daily table
      const earningsTable = dataset.table(BigQueryAnalyticsService.CREATOR_EARNINGS_TABLE);
      const [earningsExists] = await earningsTable.exists();
      if (!earningsExists) {
        const earningsSchema = [
          { name: "earning_id", type: "STRING", mode: "REQUIRED" },
          { name: "date", type: "STRING", mode: "REQUIRED" },
          { name: "timestamp", type: "TIMESTAMP", mode: "REQUIRED" },
          { name: "channel_id", type: "STRING", mode: "REQUIRED" },
          { name: "user_id", type: "STRING", mode: "REQUIRED" },
          { name: "total_views", type: "INT64", mode: "NULLABLE" },
          { name: "gross_ads_revenue_inr", type: "FLOAT64", mode: "NULLABLE" },
          { name: "gross_subs_revenue_inr", type: "FLOAT64", mode: "NULLABLE" },
          { name: "gross_premium_revenue_inr", type: "FLOAT64", mode: "NULLABLE" },
          { name: "platform_fee_inr", type: "FLOAT64", mode: "NULLABLE" },
          { name: "net_creator_share_inr", type: "FLOAT64", mode: "NULLABLE" },
          { name: "avg_rpm", type: "FLOAT64", mode: "NULLABLE" },
          { name: "channel_type", type: "STRING", mode: "NULLABLE" },
          { name: "is_finalized", type: "BOOL", mode: "NULLABLE" },
        ];

        await dataset.createTable(BigQueryAnalyticsService.CREATOR_EARNINGS_TABLE, {
          schema: earningsSchema,
          timePartitioning: { field: "timestamp", type: "DAY" },
          clustering: { fields: ["channel_id", "user_id", "channel_type"] },
        });
        logger.info(`[BigQueryAnalytics] Created table '${BigQueryAnalyticsService.CREATOR_EARNINGS_TABLE}'`);
      }

      // 9. Ensure raw_payout_transactions table
      const payoutTable = dataset.table(BigQueryAnalyticsService.PAYOUT_TRANSACTIONS_TABLE);
      const [payoutExists] = await payoutTable.exists();
      if (!payoutExists) {
        const payoutSchema = [
          { name: "payout_id", type: "STRING", mode: "REQUIRED" },
          { name: "timestamp", type: "TIMESTAMP", mode: "REQUIRED" },
          { name: "transfer_reference", type: "STRING", mode: "REQUIRED" },
          { name: "channel_id", type: "STRING", mode: "REQUIRED" },
          { name: "user_id", type: "STRING", mode: "REQUIRED" },
          { name: "amount_inr", type: "FLOAT64", mode: "REQUIRED" },
          { name: "payment_method", type: "STRING", mode: "NULLABLE" },
          { name: "payout_status", type: "STRING", mode: "REQUIRED" },
          { name: "tds_deducted_inr", type: "FLOAT64", mode: "NULLABLE" },
          { name: "net_disbursed_inr", type: "FLOAT64", mode: "NULLABLE" },
          { name: "reconciled_withdrawable_before_inr", type: "FLOAT64", mode: "NULLABLE" },
          { name: "hold_or_reject_reason", type: "STRING", mode: "NULLABLE" },
        ];

        await dataset.createTable(BigQueryAnalyticsService.PAYOUT_TRANSACTIONS_TABLE, {
          schema: payoutSchema,
          timePartitioning: { field: "timestamp", type: "DAY" },
          clustering: { fields: ["channel_id", "user_id", "payout_status"] },
        });
        logger.info(`[BigQueryAnalytics] Created table '${BigQueryAnalyticsService.PAYOUT_TRANSACTIONS_TABLE}'`);
      }

      // 10. Ensure raw_monetization_deductions_ledger table
      const deductionsTable = dataset.table(BigQueryAnalyticsService.MONETIZATION_DEDUCTIONS_TABLE);
      const [deductionsExists] = await deductionsTable.exists();
      if (!deductionsExists) {
        const deductionsSchema = [
          { name: "deduction_id", type: "STRING", mode: "REQUIRED" },
          { name: "timestamp", type: "TIMESTAMP", mode: "REQUIRED" },
          { name: "video_id", type: "STRING", mode: "REQUIRED" },
          { name: "source_channel_id", type: "STRING", mode: "REQUIRED" },
          { name: "beneficiary_channel_id", type: "STRING", mode: "REQUIRED" },
          { name: "claim_id", type: "STRING", mode: "NULLABLE" },
          { name: "deduction_type", type: "STRING", mode: "REQUIRED" },
          { name: "split_ratio", type: "FLOAT64", mode: "NULLABLE" },
          { name: "gross_revenue_inr", type: "FLOAT64", mode: "NULLABLE" },
          { name: "diverted_amount_inr", type: "FLOAT64", mode: "NULLABLE" },
          { name: "currency", type: "STRING", mode: "NULLABLE" },
        ];

        await dataset.createTable(BigQueryAnalyticsService.MONETIZATION_DEDUCTIONS_TABLE, {
          schema: deductionsSchema,
          timePartitioning: { field: "timestamp", type: "DAY" },
          clustering: { fields: ["video_id", "source_channel_id", "beneficiary_channel_id"] },
        });
        logger.info(`[BigQueryAnalytics] Created table '${BigQueryAnalyticsService.MONETIZATION_DEDUCTIONS_TABLE}'`);
      }

      // 11. Ensure raw_ad_impressions table
      const adImpTable = dataset.table(BigQueryAnalyticsService.AD_IMPRESSIONS_TABLE);
      const [adImpExists] = await adImpTable.exists();
      if (!adImpExists) {
        const adImpSchema = [
          { name: "ad_event_id", type: "STRING", mode: "REQUIRED" },
          { name: "timestamp", type: "TIMESTAMP", mode: "REQUIRED" },
          { name: "campaign_id", type: "STRING", mode: "REQUIRED" },
          { name: "advertiser_id", type: "STRING", mode: "NULLABLE" },
          { name: "channel_id", type: "STRING", mode: "NULLABLE" },
          { name: "video_id", type: "STRING", mode: "NULLABLE" },
          { name: "viewer_id", type: "STRING", mode: "NULLABLE" },
          { name: "ad_type", type: "STRING", mode: "REQUIRED" },
          { name: "charge_model", type: "STRING", mode: "REQUIRED" },
          { name: "gross_charge_inr", type: "FLOAT64", mode: "NULLABLE" },
          { name: "channel_share_inr", type: "FLOAT64", mode: "NULLABLE" },
          { name: "platform_share_inr", type: "FLOAT64", mode: "NULLABLE" },
          { name: "is_fraud_suppressed", type: "BOOL", mode: "NULLABLE" },
          { name: "fraud_reason", type: "STRING", mode: "NULLABLE" },
        ];

        await dataset.createTable(BigQueryAnalyticsService.AD_IMPRESSIONS_TABLE, {
          schema: adImpSchema,
          timePartitioning: { field: "timestamp", type: "DAY" },
          clustering: { fields: ["campaign_id", "channel_id", "ad_type"] },
        });
        logger.info(`[BigQueryAnalytics] Created table '${BigQueryAnalyticsService.AD_IMPRESSIONS_TABLE}'`);
      }

      // 12. Ensure raw_ad_clicks table
      const adClickTable = dataset.table(BigQueryAnalyticsService.AD_CLICKS_TABLE);
      const [adClickExists] = await adClickTable.exists();
      if (!adClickExists) {
        const adClickSchema = [
          { name: "click_id", type: "STRING", mode: "REQUIRED" },
          { name: "timestamp", type: "TIMESTAMP", mode: "REQUIRED" },
          { name: "ad_event_id", type: "STRING", mode: "NULLABLE" },
          { name: "campaign_id", type: "STRING", mode: "REQUIRED" },
          { name: "channel_id", type: "STRING", mode: "NULLABLE" },
          { name: "video_id", type: "STRING", mode: "NULLABLE" },
          { name: "viewer_id", type: "STRING", mode: "NULLABLE" },
          { name: "destination_url", type: "STRING", mode: "NULLABLE" },
          { name: "cost_per_click_inr", type: "FLOAT64", mode: "NULLABLE" },
        ];

        await dataset.createTable(BigQueryAnalyticsService.AD_CLICKS_TABLE, {
          schema: adClickSchema,
          timePartitioning: { field: "timestamp", type: "DAY" },
          clustering: { fields: ["campaign_id", "channel_id"] },
        });
        logger.info(`[BigQueryAnalytics] Created table '${BigQueryAnalyticsService.AD_CLICKS_TABLE}'`);
      }

      // 13. Ensure raw_ad_fraud_signals table
      const fraudTable = dataset.table(BigQueryAnalyticsService.AD_FRAUD_SIGNALS_TABLE);
      const [fraudExists] = await fraudTable.exists();
      if (!fraudExists) {
        const fraudSchema = [
          { name: "signal_id", type: "STRING", mode: "REQUIRED" },
          { name: "timestamp", type: "TIMESTAMP", mode: "REQUIRED" },
          { name: "campaign_id", type: "STRING", mode: "REQUIRED" },
          { name: "viewer_id", type: "STRING", mode: "NULLABLE" },
          { name: "ip_hash", type: "STRING", mode: "NULLABLE" },
          { name: "fraud_type", type: "STRING", mode: "REQUIRED" },
          { name: "action_taken", type: "STRING", mode: "REQUIRED" },
        ];

        await dataset.createTable(BigQueryAnalyticsService.AD_FRAUD_SIGNALS_TABLE, {
          schema: fraudSchema,
          timePartitioning: { field: "timestamp", type: "DAY" },
          clustering: { fields: ["campaign_id", "fraud_type"] },
        });
        logger.info(`[BigQueryAnalytics] Created table '${BigQueryAnalyticsService.AD_FRAUD_SIGNALS_TABLE}'`);
      }

      // 14. Ensure raw_search_queries table
      const searchTable = dataset.table(BigQueryAnalyticsService.SEARCH_QUERIES_TABLE);
      const [searchExists] = await searchTable.exists();
      if (!searchExists) {
        const searchSchema = [
          { name: "query_id", type: "STRING", mode: "REQUIRED" },
          { name: "timestamp", type: "TIMESTAMP", mode: "REQUIRED" },
          { name: "query_text", type: "STRING", mode: "REQUIRED" },
          { name: "filter", type: "STRING", mode: "NULLABLE" },
          { name: "search_mode", type: "STRING", mode: "REQUIRED" },
          { name: "results_count", type: "INT64", mode: "REQUIRED" },
          { name: "latency_ms", type: "INT64", mode: "REQUIRED" },
          { name: "user_id", type: "STRING", mode: "NULLABLE" },
          { name: "is_zero_result", type: "BOOL", mode: "REQUIRED" },
        ];

        await dataset.createTable(BigQueryAnalyticsService.SEARCH_QUERIES_TABLE, {
          schema: searchSchema,
          timePartitioning: { field: "timestamp", type: "DAY" },
          clustering: { fields: ["query_text", "search_mode", "filter"] },
        });
        logger.info(`[BigQueryAnalytics] Created table '${BigQueryAnalyticsService.SEARCH_QUERIES_TABLE}'`);
      }

      // 15. Ensure raw_search_clickthroughs table
      const clickthroughTable = dataset.table(BigQueryAnalyticsService.SEARCH_CLICKTHROUGHS_TABLE);
      const [clickthroughExists] = await clickthroughTable.exists();
      if (!clickthroughExists) {
        const clickthroughSchema = [
          { name: "click_id", type: "STRING", mode: "REQUIRED" },
          { name: "timestamp", type: "TIMESTAMP", mode: "REQUIRED" },
          { name: "query_id", type: "STRING", mode: "REQUIRED" },
          { name: "query_text", type: "STRING", mode: "REQUIRED" },
          { name: "item_id", type: "STRING", mode: "REQUIRED" },
          { name: "item_type", type: "STRING", mode: "REQUIRED" },
          { name: "rank_position", type: "INT64", mode: "REQUIRED" },
          { name: "time_to_click_sec", type: "FLOAT64", mode: "NULLABLE" },
          { name: "user_id", type: "STRING", mode: "NULLABLE" },
        ];

        await dataset.createTable(BigQueryAnalyticsService.SEARCH_CLICKTHROUGHS_TABLE, {
          schema: clickthroughSchema,
          timePartitioning: { field: "timestamp", type: "DAY" },
          clustering: { fields: ["query_text", "item_type", "item_id"] },
        });
        logger.info(`[BigQueryAnalytics] Created table '${BigQueryAnalyticsService.SEARCH_CLICKTHROUGHS_TABLE}'`);
      }

      // 16. Ensure raw_moderation_scans table
      const modScanTable = dataset.table(BigQueryAnalyticsService.MODERATION_SCANS_TABLE);
      const [modScanExists] = await modScanTable.exists();
      if (!modScanExists) {
        const modScanSchema = [
          { name: "scan_id", type: "STRING", mode: "REQUIRED" },
          { name: "timestamp", type: "TIMESTAMP", mode: "REQUIRED" },
          { name: "video_id", type: "STRING", mode: "REQUIRED" },
          { name: "channel_id", type: "STRING", mode: "NULLABLE" },
          { name: "uploader_id", type: "STRING", mode: "NULLABLE" },
          { name: "moderation_status", type: "STRING", mode: "REQUIRED" },
          { name: "risk_level", type: "STRING", mode: "NULLABLE" },
          { name: "confidence_score", type: "FLOAT64", mode: "NULLABLE" },
          { name: "policy_action", type: "STRING", mode: "NULLABLE" },
          { name: "violation_reason", type: "STRING", mode: "NULLABLE" },
          { name: "violation_categories", type: "STRING", mode: "REPEATED" },
          { name: "detected_language", type: "STRING", mode: "NULLABLE" },
          { name: "model", type: "STRING", mode: "NULLABLE" },
          { name: "processing_time_ms", type: "INT64", mode: "NULLABLE" },
        ];

        await dataset.createTable(BigQueryAnalyticsService.MODERATION_SCANS_TABLE, {
          schema: modScanSchema,
          timePartitioning: { field: "timestamp", type: "DAY" },
          clustering: { fields: ["video_id", "moderation_status", "risk_level"] },
        });
        logger.info(`[BigQueryAnalytics] Created table '${BigQueryAnalyticsService.MODERATION_SCANS_TABLE}'`);
      }

      // 17. Ensure raw_moderator_actions table
      const modActionTable = dataset.table(BigQueryAnalyticsService.MODERATOR_ACTIONS_TABLE);
      const [modActionExists] = await modActionTable.exists();
      if (!modActionExists) {
        const modActionSchema = [
          { name: "action_id", type: "STRING", mode: "REQUIRED" },
          { name: "timestamp", type: "TIMESTAMP", mode: "REQUIRED" },
          { name: "video_id", type: "STRING", mode: "REQUIRED" },
          { name: "channel_id", type: "STRING", mode: "NULLABLE" },
          { name: "moderator_id", type: "STRING", mode: "REQUIRED" },
          { name: "action_type", type: "STRING", mode: "REQUIRED" },
          { name: "justification", type: "STRING", mode: "NULLABLE" },
          { name: "statutory_legal_basis", type: "STRING", mode: "NULLABLE" },
        ];

        await dataset.createTable(BigQueryAnalyticsService.MODERATOR_ACTIONS_TABLE, {
          schema: modActionSchema,
          timePartitioning: { field: "timestamp", type: "DAY" },
          clustering: { fields: ["video_id", "action_type", "moderator_id"] },
        });
        logger.info(`[BigQueryAnalytics] Created table '${BigQueryAnalyticsService.MODERATOR_ACTIONS_TABLE}'`);
      }

      // ─── Silver Layer: Curated Analytical Views ────────────────────────────────

      // 18. Ensure v_creator_daily_pnl view
      const creatorPnlView = dataset.table(BigQueryAnalyticsService.CREATOR_DAILY_PNL_VIEW);
      const [creatorPnlExists] = await creatorPnlView.exists();
      if (!creatorPnlExists) {
        const creatorPnlSql = `
SELECT
  e.date,
  e.channel_id,
  e.user_id,
  e.channel_type,
  e.total_views,
  e.gross_ads_revenue_inr,
  e.gross_subs_revenue_inr,
  e.gross_premium_revenue_inr,
  (COALESCE(e.gross_ads_revenue_inr, 0) + COALESCE(e.gross_subs_revenue_inr, 0) + COALESCE(e.gross_premium_revenue_inr, 0)) AS total_gross_revenue_inr,
  e.platform_fee_inr,
  COALESCE(d.total_deductions_inr, 0) AS total_copyright_deductions_inr,
  (COALESCE(e.net_creator_share_inr, 0) - COALESCE(d.total_deductions_inr, 0)) AS effective_creator_net_inr,
  e.avg_rpm,
  e.is_finalized,
  COALESCE(p.total_disbursed_inr, 0) AS total_payout_disbursed_inr,
  COALESCE(p.total_tds_inr, 0) AS total_tds_withheld_inr
FROM \`${this.datasetId}.${BigQueryAnalyticsService.CREATOR_EARNINGS_TABLE}\` e
LEFT JOIN (
  SELECT
    source_channel_id,
    CAST(DATE(timestamp) AS STRING) AS deduction_date,
    SUM(diverted_amount_inr) AS total_deductions_inr
  FROM \`${this.datasetId}.${BigQueryAnalyticsService.MONETIZATION_DEDUCTIONS_TABLE}\`
  GROUP BY source_channel_id, deduction_date
) d ON e.channel_id = d.source_channel_id AND e.date = d.deduction_date
LEFT JOIN (
  SELECT
    channel_id,
    CAST(DATE(timestamp) AS STRING) AS payout_date,
    SUM(CASE WHEN payout_status = 'SUCCESS' THEN net_disbursed_inr ELSE 0 END) AS total_disbursed_inr,
    SUM(CASE WHEN payout_status = 'SUCCESS' THEN tds_deducted_inr ELSE 0 END) AS total_tds_inr
  FROM \`${this.datasetId}.${BigQueryAnalyticsService.PAYOUT_TRANSACTIONS_TABLE}\`
  GROUP BY channel_id, payout_date
) p ON e.channel_id = p.channel_id AND e.date = p.payout_date`.trim();

        await dataset.createTable(BigQueryAnalyticsService.CREATOR_DAILY_PNL_VIEW, {
          view: { query: creatorPnlSql, useLegacySql: false },
        });
        logger.info(`[BigQueryAnalytics] Created view '${BigQueryAnalyticsService.CREATOR_DAILY_PNL_VIEW}'`);
      }

      // 19. Ensure v_credibility_claim_radar view
      const claimRadarView = dataset.table(BigQueryAnalyticsService.CREDIBILITY_CLAIM_RADAR_VIEW);
      const [claimRadarExists] = await claimRadarView.exists();
      if (!claimRadarExists) {
        const claimRadarSql = `
SELECT
  normalized_claim_hash AS claim_hash,
  claim_text AS claim_text_normalized,
  status,
  COUNT(1) AS occurrence_count,
  COUNT(DISTINCT video_id) AS distinct_videos_count,
  ROUND(AVG(verification_confidence), 4) AS avg_confidence,
  MAX(verification_method) AS primary_verification_method,
  MAX(primary_source_tier) AS highest_source_tier,
  LOGICAL_OR(COALESCE(is_grounded, false)) AS is_grounded_anywhere,
  MIN(timestamp) AS first_detected_at,
  MAX(timestamp) AS last_detected_at,
  ARRAY_AGG(DISTINCT video_id LIMIT 10) AS sample_video_ids
FROM \`${this.datasetId}.${BigQueryAnalyticsService.VERIFIED_CLAIMS_TABLE}\`
GROUP BY normalized_claim_hash, claim_text, status`.trim();

        await dataset.createTable(BigQueryAnalyticsService.CREDIBILITY_CLAIM_RADAR_VIEW, {
          view: { query: claimRadarSql, useLegacySql: false },
        });
        logger.info(`[BigQueryAnalytics] Created view '${BigQueryAnalyticsService.CREDIBILITY_CLAIM_RADAR_VIEW}'`);
      }

      // 20. Ensure v_ad_campaign_performance view
      const adPerfView = dataset.table(BigQueryAnalyticsService.AD_CAMPAIGN_PERFORMANCE_VIEW);
      const [adPerfExists] = await adPerfView.exists();
      if (!adPerfExists) {
        const adPerfSql = `
SELECT
  i.campaign_id,
  MAX(i.advertiser_id) AS advertiser_id,
  DATE(i.timestamp) AS event_date,
  i.ad_type,
  COUNT(1) AS total_impressions,
  COUNTIF(COALESCE(i.is_fraud_suppressed, false) = false) AS valid_impressions,
  COUNTIF(COALESCE(i.is_fraud_suppressed, false) = true) AS fraud_suppressed_impressions,
  COUNT(DISTINCT i.viewer_id) AS unique_viewers,
  COUNT(DISTINCT i.channel_id) AS distinct_channels_reached,
  ROUND(SUM(CASE WHEN COALESCE(i.is_fraud_suppressed, false) = false THEN COALESCE(i.gross_charge_inr, 0) ELSE 0 END), 2) AS total_gross_spend_inr,
  ROUND(SUM(CASE WHEN COALESCE(i.is_fraud_suppressed, false) = false THEN COALESCE(i.channel_share_inr, 0) ELSE 0 END), 2) AS total_creator_payout_inr,
  ROUND(SUM(CASE WHEN COALESCE(i.is_fraud_suppressed, false) = false THEN COALESCE(i.platform_share_inr, 0) ELSE 0 END), 2) AS total_platform_margin_inr,
  COALESCE(c.clicks_count, 0) AS clicks_count,
  ROUND(SAFE_DIVIDE(COALESCE(c.clicks_count, 0) * 100.0, COUNTIF(COALESCE(i.is_fraud_suppressed, false) = false)), 2) AS ctr_percent,
  ROUND(SAFE_DIVIDE(COUNTIF(COALESCE(i.is_fraud_suppressed, false) = true) * 100.0, COUNT(1)), 2) AS fraud_rate_percent
FROM \`${this.datasetId}.${BigQueryAnalyticsService.AD_IMPRESSIONS_TABLE}\` i
LEFT JOIN (
  SELECT
    campaign_id,
    DATE(timestamp) AS click_date,
    COUNT(1) AS clicks_count
  FROM \`${this.datasetId}.${BigQueryAnalyticsService.AD_CLICKS_TABLE}\`
  GROUP BY campaign_id, click_date
) c ON i.campaign_id = c.campaign_id AND DATE(i.timestamp) = c.click_date
GROUP BY i.campaign_id, event_date, i.ad_type, c.clicks_count`.trim();

        await dataset.createTable(BigQueryAnalyticsService.AD_CAMPAIGN_PERFORMANCE_VIEW, {
          view: { query: adPerfSql, useLegacySql: false },
        });
        logger.info(`[BigQueryAnalytics] Created view '${BigQueryAnalyticsService.AD_CAMPAIGN_PERFORMANCE_VIEW}'`);
      }

      // 21. Ensure v_trending_search_clusters view
      const searchClustersView = dataset.table(BigQueryAnalyticsService.TRENDING_SEARCH_CLUSTERS_VIEW);
      const [searchClustersExists] = await searchClustersView.exists();
      if (!searchClustersExists) {
        const searchClustersSql = `
SELECT
  q.query_text,
  DATE(q.timestamp) AS search_date,
  q.search_mode,
  COUNT(1) AS search_volume,
  COUNTIF(q.is_zero_result = true) AS zero_result_count,
  ROUND(SAFE_DIVIDE(COUNTIF(q.is_zero_result = true) * 100.0, COUNT(1)), 2) AS zero_result_percent,
  ROUND(AVG(q.results_count), 1) AS avg_results_count,
  ROUND(AVG(q.latency_ms), 1) AS avg_latency_ms,
  COALESCE(c.click_count, 0) AS click_count,
  ROUND(SAFE_DIVIDE(COALESCE(c.click_count, 0) * 100.0, COUNT(1)), 2) AS clickthrough_rate_percent,
  c.avg_rank_selected,
  c.avg_time_to_click_sec
FROM \`${this.datasetId}.${BigQueryAnalyticsService.SEARCH_QUERIES_TABLE}\` q
LEFT JOIN (
  SELECT
    query_id,
    COUNT(1) AS click_count,
    ROUND(AVG(rank_position), 2) AS avg_rank_selected,
    ROUND(AVG(time_to_click_sec), 2) AS avg_time_to_click_sec
  FROM \`${this.datasetId}.${BigQueryAnalyticsService.SEARCH_CLICKTHROUGHS_TABLE}\`
  GROUP BY query_id
) c ON q.query_id = c.query_id
GROUP BY q.query_text, search_date, q.search_mode, c.click_count, c.avg_rank_selected, c.avg_time_to_click_sec`.trim();

        await dataset.createTable(BigQueryAnalyticsService.TRENDING_SEARCH_CLUSTERS_VIEW, {
          view: { query: searchClustersSql, useLegacySql: false },
        });
        logger.info(`[BigQueryAnalytics] Created view '${BigQueryAnalyticsService.TRENDING_SEARCH_CLUSTERS_VIEW}'`);
      }

      // 22. Ensure v_moderation_compliance_audit view
      const modAuditView = dataset.table(BigQueryAnalyticsService.MODERATION_COMPLIANCE_AUDIT_VIEW);
      const [modAuditExists] = await modAuditView.exists();
      if (!modAuditExists) {
        const modAuditSql = `
SELECT
  DATE(s.timestamp) AS scan_date,
  s.moderation_status,
  s.risk_level,
  s.model,
  COUNT(1) AS total_scans,
  ROUND(AVG(s.confidence_score), 4) AS avg_confidence,
  ROUND(AVG(s.processing_time_ms), 1) AS avg_processing_time_ms,
  COUNTIF(s.policy_action = 'reject') AS auto_rejection_count,
  COUNTIF(s.policy_action = 'flag') AS auto_flagged_count,
  COALESCE(a.human_action_count, 0) AS human_action_count,
  COALESCE(a.human_override_count, 0) AS human_override_count
FROM \`${this.datasetId}.${BigQueryAnalyticsService.MODERATION_SCANS_TABLE}\` s
LEFT JOIN (
  SELECT
    video_id,
    COUNT(1) AS human_action_count,
    COUNTIF(action_type = 'approve') AS human_override_count
  FROM \`${this.datasetId}.${BigQueryAnalyticsService.MODERATOR_ACTIONS_TABLE}\`
  GROUP BY video_id
) a ON s.video_id = a.video_id
GROUP BY scan_date, s.moderation_status, s.risk_level, s.model, a.human_action_count, a.human_override_count`.trim();

        await dataset.createTable(BigQueryAnalyticsService.MODERATION_COMPLIANCE_AUDIT_VIEW, {
          view: { query: modAuditSql, useLegacySql: false },
        });
        logger.info(`[BigQueryAnalytics] Created view '${BigQueryAnalyticsService.MODERATION_COMPLIANCE_AUDIT_VIEW}'`);
      }

      this.schemaInitialized = true;
    } catch (err: any) {
      logger.error("[BigQueryAnalytics] Schema initialization warning", { err: String(err?.message || err) });
    }
  }

  // ─── Enqueue Methods (In-Memory Micro-Batching) ─────────────────────────────

  enqueueWatchEvent(event: BigQueryWatchEvent): void {
    if (!this.enabled) return;
    this.watchEventBuffer.push(event);
    if (this.watchEventBuffer.length >= this.batchSize) {
      this.flush().catch((err) => {
        logger.error("[BigQueryAnalytics] Flush on watch batch limit failed", { err: String(err) });
      });
    }
  }

  enqueueImpression(impression: BigQueryImpression): void {
    if (!this.enabled) return;
    this.impressionBuffer.push(impression);
    if (this.impressionBuffer.length >= this.batchSize) {
      this.flush().catch((err) => {
        logger.error("[BigQueryAnalytics] Flush on impression batch limit failed", { err: String(err) });
      });
    }
  }

  enqueueCopyrightMatch(match: BigQueryCopyrightMatch): void {
    if (!this.enabled) return;
    this.copyrightMatchBuffer.push(match);
    if (this.copyrightMatchBuffer.length >= this.batchSize) {
      this.flush().catch((err) => {
        logger.error("[BigQueryAnalytics] Flush on match batch limit failed", { err: String(err) });
      });
    }
  }

  enqueueCopyrightClaim(claim: BigQueryCopyrightClaim): void {
    if (!this.enabled) return;
    this.copyrightClaimBuffer.push(claim);
    if (this.copyrightClaimBuffer.length >= this.batchSize) {
      this.flush().catch((err) => {
        logger.error("[BigQueryAnalytics] Flush on claim batch limit failed", { err: String(err) });
      });
    }
  }

  enqueueCopyrightAppeal(appeal: BigQueryCopyrightAppeal): void {
    if (!this.enabled) return;
    this.copyrightAppealBuffer.push(appeal);
    if (this.copyrightAppealBuffer.length >= this.batchSize) {
      this.flush().catch((err) => {
        logger.error("[BigQueryAnalytics] Flush on appeal batch limit failed", { err: String(err) });
      });
    }
  }

  enqueueVerifiedClaim(claim: BigQueryVerifiedClaim): void {
    if (!this.enabled) return;
    this.verifiedClaimBuffer.push(claim);
    if (this.verifiedClaimBuffer.length >= this.batchSize) {
      this.flush().catch((err) => {
        logger.error("[BigQueryAnalytics] Flush on verified claim batch limit failed", { err: String(err) });
      });
    }
  }

  enqueueFactCheckEvaluation(evaluation: BigQueryFactCheckEvaluation): void {
    if (!this.enabled) return;
    this.factCheckEvaluationBuffer.push(evaluation);
    if (this.factCheckEvaluationBuffer.length >= this.batchSize) {
      this.flush().catch((err) => {
        logger.error("[BigQueryAnalytics] Flush on fact check evaluation batch limit failed", { err: String(err) });
      });
    }
  }

  enqueueCreatorEarning(earning: BigQueryCreatorEarning): void {
    if (!this.enabled) return;
    this.creatorEarningsBuffer.push(earning);
    if (this.creatorEarningsBuffer.length >= this.batchSize) {
      this.flush().catch((err) => {
        logger.error("[BigQueryAnalytics] Flush on creator earning batch limit failed", { err: String(err) });
      });
    }
  }

  enqueuePayoutTransaction(tx: BigQueryPayoutTransaction): void {
    if (!this.enabled) return;
    this.payoutTransactionsBuffer.push(tx);
    if (this.payoutTransactionsBuffer.length >= this.batchSize) {
      this.flush().catch((err) => {
        logger.error("[BigQueryAnalytics] Flush on payout transaction batch limit failed", { err: String(err) });
      });
    }
  }

  enqueueMonetizationDeduction(deduction: BigQueryMonetizationDeduction): void {
    if (!this.enabled) return;
    this.monetizationDeductionsBuffer.push(deduction);
    if (this.monetizationDeductionsBuffer.length >= this.batchSize) {
      this.flush().catch((err) => {
        logger.error("[BigQueryAnalytics] Flush on monetization deduction batch limit failed", { err: String(err) });
      });
    }
  }

  enqueueAdImpression(impression: BigQueryAdImpression): void {
    if (!this.enabled) return;
    this.adImpressionBuffer.push(impression);
    if (this.adImpressionBuffer.length >= this.batchSize) {
      this.flush().catch((err) => {
        logger.error("[BigQueryAnalytics] Flush on ad impression batch limit failed", { err: String(err) });
      });
    }
  }

  enqueueAdClick(click: BigQueryAdClick): void {
    if (!this.enabled) return;
    this.adClickBuffer.push(click);
    if (this.adClickBuffer.length >= this.batchSize) {
      this.flush().catch((err) => {
        logger.error("[BigQueryAnalytics] Flush on ad click batch limit failed", { err: String(err) });
      });
    }
  }

  enqueueAdFraudSignal(signal: BigQueryAdFraudSignal): void {
    if (!this.enabled) return;
    this.adFraudSignalBuffer.push(signal);
    if (this.adFraudSignalBuffer.length >= this.batchSize) {
      this.flush().catch((err) => {
        logger.error("[BigQueryAnalytics] Flush on ad fraud signal batch limit failed", { err: String(err) });
      });
    }
  }

  enqueueSearchQuery(query: BigQuerySearchQuery): void {
    if (!this.enabled) return;
    this.searchQueryBuffer.push(query);
    if (this.searchQueryBuffer.length >= this.batchSize) {
      this.flush().catch((err) => {
        logger.error("[BigQueryAnalytics] Flush on search query batch limit failed", { err: String(err) });
      });
    }
  }

  enqueueSearchClickthrough(click: BigQuerySearchClickthrough): void {
    if (!this.enabled) return;
    this.searchClickthroughBuffer.push(click);
    if (this.searchClickthroughBuffer.length >= this.batchSize) {
      this.flush().catch((err) => {
        logger.error("[BigQueryAnalytics] Flush on search clickthrough batch limit failed", { err: String(err) });
      });
    }
  }

  enqueueModerationScan(scan: BigQueryModerationScan): void {
    if (!this.enabled) return;
    this.moderationScanBuffer.push(scan);
    if (this.moderationScanBuffer.length >= this.batchSize) {
      this.flush().catch((err) => {
        logger.error("[BigQueryAnalytics] Flush on moderation scan batch limit failed", { err: String(err) });
      });
    }
  }

  enqueueModeratorAction(action: BigQueryModeratorAction): void {
    if (!this.enabled) return;
    this.moderatorActionBuffer.push(action);
    if (this.moderatorActionBuffer.length >= this.batchSize) {
      this.flush().catch((err) => {
        logger.error("[BigQueryAnalytics] Flush on moderator action batch limit failed", { err: String(err) });
      });
    }
  }

  // ─── Flush Buffer ───────────────────────────────────────────────────────────

  async flush(): Promise<void> {
    if (!this.enabled || this.isFlushing) return;
    if (
      this.watchEventBuffer.length === 0 &&
      this.impressionBuffer.length === 0 &&
      this.copyrightMatchBuffer.length === 0 &&
      this.copyrightClaimBuffer.length === 0 &&
      this.copyrightAppealBuffer.length === 0 &&
      this.verifiedClaimBuffer.length === 0 &&
      this.factCheckEvaluationBuffer.length === 0 &&
      this.creatorEarningsBuffer.length === 0 &&
      this.payoutTransactionsBuffer.length === 0 &&
      this.monetizationDeductionsBuffer.length === 0 &&
      this.adImpressionBuffer.length === 0 &&
      this.adClickBuffer.length === 0 &&
      this.adFraudSignalBuffer.length === 0 &&
      this.searchQueryBuffer.length === 0 &&
      this.searchClickthroughBuffer.length === 0 &&
      this.moderationScanBuffer.length === 0 &&
      this.moderatorActionBuffer.length === 0
    ) {
      return;
    }

    this.isFlushing = true;
    const watchBatch = [...this.watchEventBuffer];
    const impBatch = [...this.impressionBuffer];
    const matchBatch = [...this.copyrightMatchBuffer];
    const claimBatch = [...this.copyrightClaimBuffer];
    const appealBatch = [...this.copyrightAppealBuffer];
    const claimItemBatch = [...this.verifiedClaimBuffer];
    const evalBatch = [...this.factCheckEvaluationBuffer];
    const earningsBatch = [...this.creatorEarningsBuffer];
    const payoutBatch = [...this.payoutTransactionsBuffer];
    const deductionBatch = [...this.monetizationDeductionsBuffer];
    const adImpBatch = [...this.adImpressionBuffer];
    const adClickBatch = [...this.adClickBuffer];
    const adFraudBatch = [...this.adFraudSignalBuffer];
    const searchQueryBatch = [...this.searchQueryBuffer];
    const searchClickBatch = [...this.searchClickthroughBuffer];
    const moderationScanBatch = [...this.moderationScanBuffer];
    const moderatorActionBatch = [...this.moderatorActionBuffer];

    this.watchEventBuffer = [];
    this.impressionBuffer = [];
    this.copyrightMatchBuffer = [];
    this.copyrightClaimBuffer = [];
    this.copyrightAppealBuffer = [];
    this.verifiedClaimBuffer = [];
    this.factCheckEvaluationBuffer = [];
    this.creatorEarningsBuffer = [];
    this.payoutTransactionsBuffer = [];
    this.monetizationDeductionsBuffer = [];
    this.adImpressionBuffer = [];
    this.adClickBuffer = [];
    this.adFraudSignalBuffer = [];
    this.searchQueryBuffer = [];
    this.searchClickthroughBuffer = [];
    this.moderationScanBuffer = [];
    this.moderatorActionBuffer = [];

    try {
      const promises: Promise<any>[] = [];

      if (watchBatch.length > 0) promises.push(this.insertWatchEvents(watchBatch));
      if (impBatch.length > 0) promises.push(this.insertImpressions(impBatch));
      if (matchBatch.length > 0) promises.push(this.insertCopyrightMatches(matchBatch));
      if (claimBatch.length > 0) promises.push(this.insertCopyrightClaims(claimBatch));
      if (appealBatch.length > 0) promises.push(this.insertCopyrightAppeals(appealBatch));
      if (claimItemBatch.length > 0) promises.push(this.insertVerifiedClaims(claimItemBatch));
      if (evalBatch.length > 0) promises.push(this.insertFactCheckEvaluations(evalBatch));
      if (earningsBatch.length > 0) promises.push(this.insertCreatorEarnings(earningsBatch));
      if (payoutBatch.length > 0) promises.push(this.insertPayoutTransactions(payoutBatch));
      if (deductionBatch.length > 0) promises.push(this.insertMonetizationDeductions(deductionBatch));
      if (adImpBatch.length > 0) promises.push(this.insertAdImpressions(adImpBatch));
      if (adClickBatch.length > 0) promises.push(this.insertAdClicks(adClickBatch));
      if (adFraudBatch.length > 0) promises.push(this.insertAdFraudSignals(adFraudBatch));
      if (searchQueryBatch.length > 0) promises.push(this.insertSearchQueries(searchQueryBatch));
      if (searchClickBatch.length > 0) promises.push(this.insertSearchClickthroughs(searchClickBatch));
      if (moderationScanBatch.length > 0) promises.push(this.insertModerationScans(moderationScanBatch));
      if (moderatorActionBatch.length > 0) promises.push(this.insertModeratorActions(moderatorActionBatch));

      await Promise.all(promises);
    } catch (err: any) {
      logger.error("[BigQueryAnalytics] Buffer flush error", {
        watchCount: watchBatch.length,
        impCount: impBatch.length,
        matchCount: matchBatch.length,
        claimCount: claimBatch.length,
        appealCount: appealBatch.length,
        verifiedClaimsCount: claimItemBatch.length,
        evalCount: evalBatch.length,
        earningsCount: earningsBatch.length,
        payoutCount: payoutBatch.length,
        deductionCount: deductionBatch.length,
        adImpCount: adImpBatch.length,
        adClickCount: adClickBatch.length,
        adFraudCount: adFraudBatch.length,
        searchQueryCount: searchQueryBatch.length,
        searchClickCount: searchClickBatch.length,
        moderationScanCount: moderationScanBatch.length,
        moderatorActionCount: moderatorActionBatch.length,
        error: String(err?.message || err),
      });

      // Re-enqueue items to prevent data loss (bounded to prevent memory bloat)
      if (this.watchEventBuffer.length + watchBatch.length < 5000) this.watchEventBuffer.unshift(...watchBatch);
      if (this.impressionBuffer.length + impBatch.length < 5000) this.impressionBuffer.unshift(...impBatch);
      if (this.copyrightMatchBuffer.length + matchBatch.length < 5000) this.copyrightMatchBuffer.unshift(...matchBatch);
      if (this.copyrightClaimBuffer.length + claimBatch.length < 5000) this.copyrightClaimBuffer.unshift(...claimBatch);
      if (this.copyrightAppealBuffer.length + appealBatch.length < 5000) this.copyrightAppealBuffer.unshift(...appealBatch);
      if (this.verifiedClaimBuffer.length + claimItemBatch.length < 5000) this.verifiedClaimBuffer.unshift(...claimItemBatch);
      if (this.factCheckEvaluationBuffer.length + evalBatch.length < 5000) this.factCheckEvaluationBuffer.unshift(...evalBatch);
      if (this.creatorEarningsBuffer.length + earningsBatch.length < 5000) this.creatorEarningsBuffer.unshift(...earningsBatch);
      if (this.payoutTransactionsBuffer.length + payoutBatch.length < 5000) this.payoutTransactionsBuffer.unshift(...payoutBatch);
      if (this.monetizationDeductionsBuffer.length + deductionBatch.length < 5000) this.monetizationDeductionsBuffer.unshift(...deductionBatch);
      if (this.adImpressionBuffer.length + adImpBatch.length < 5000) this.adImpressionBuffer.unshift(...adImpBatch);
      if (this.adClickBuffer.length + adClickBatch.length < 5000) this.adClickBuffer.unshift(...adClickBatch);
      if (this.adFraudSignalBuffer.length + adFraudBatch.length < 5000) this.adFraudSignalBuffer.unshift(...adFraudBatch);
      if (this.searchQueryBuffer.length + searchQueryBatch.length < 5000) this.searchQueryBuffer.unshift(...searchQueryBatch);
      if (this.searchClickthroughBuffer.length + searchClickBatch.length < 5000) this.searchClickthroughBuffer.unshift(...searchClickBatch);
      if (this.moderationScanBuffer.length + moderationScanBatch.length < 5000) this.moderationScanBuffer.unshift(...moderationScanBatch);
      if (this.moderatorActionBuffer.length + moderatorActionBatch.length < 5000) this.moderatorActionBuffer.unshift(...moderatorActionBatch);
    } finally {
      this.isFlushing = false;
    }
  }

  // ─── Direct Streaming Inserts ───────────────────────────────────────────────

  async insertWatchEvents(events: BigQueryWatchEvent[]): Promise<void> {
    if (!this.enabled || events.length === 0) return;
    try {
      const table: Table = this.bigquery.dataset(this.datasetId).table(BigQueryAnalyticsService.WATCH_EVENTS_TABLE);
      await table.insert(events, { skipInvalidRows: true, ignoreUnknownValues: true });
      logger.info(`[BigQueryAnalytics] Streamed ${events.length} watch events to BigQuery`);
    } catch (err: any) {
      const insertErrors = err?.errors || err?.response?.insertErrors;
      logger.error("[BigQueryAnalytics] Failed streaming watch events", {
        count: events.length,
        message: err?.message,
        insertErrors: insertErrors ? JSON.stringify(insertErrors).substring(0, 500) : undefined,
      });
      throw err;
    }
  }

  async insertImpressions(impressions: BigQueryImpression[]): Promise<void> {
    if (!this.enabled || impressions.length === 0) return;
    try {
      const table: Table = this.bigquery.dataset(this.datasetId).table(BigQueryAnalyticsService.IMPRESSIONS_TABLE);
      await table.insert(impressions, { skipInvalidRows: true, ignoreUnknownValues: true });
      logger.info(`[BigQueryAnalytics] Streamed ${impressions.length} impressions to BigQuery`);
    } catch (err: any) {
      const insertErrors = err?.errors || err?.response?.insertErrors;
      logger.error("[BigQueryAnalytics] Failed streaming impressions", {
        count: impressions.length,
        message: err?.message,
        insertErrors: insertErrors ? JSON.stringify(insertErrors).substring(0, 500) : undefined,
      });
      throw err;
    }
  }

  async insertCopyrightMatches(matches: BigQueryCopyrightMatch[]): Promise<void> {
    if (!this.enabled || matches.length === 0) return;
    try {
      const table: Table = this.bigquery.dataset(this.datasetId).table(BigQueryAnalyticsService.COPYRIGHT_MATCHES_TABLE);
      await table.insert(matches, { skipInvalidRows: true, ignoreUnknownValues: true });
      logger.info(`[BigQueryAnalytics] Streamed ${matches.length} copyright matches to BigQuery`);
    } catch (err: any) {
      const insertErrors = err?.errors || err?.response?.insertErrors;
      logger.error("[BigQueryAnalytics] Failed streaming copyright matches", {
        count: matches.length,
        message: err?.message,
        insertErrors: insertErrors ? JSON.stringify(insertErrors).substring(0, 500) : undefined,
      });
      throw err;
    }
  }

  async insertCopyrightClaims(claims: BigQueryCopyrightClaim[]): Promise<void> {
    if (!this.enabled || claims.length === 0) return;
    try {
      const table: Table = this.bigquery.dataset(this.datasetId).table(BigQueryAnalyticsService.COPYRIGHT_CLAIMS_TABLE);
      await table.insert(claims, { skipInvalidRows: true, ignoreUnknownValues: true });
      logger.info(`[BigQueryAnalytics] Streamed ${claims.length} copyright claims to BigQuery`);
    } catch (err: any) {
      const insertErrors = err?.errors || err?.response?.insertErrors;
      logger.error("[BigQueryAnalytics] Failed streaming copyright claims", {
        count: claims.length,
        message: err?.message,
        insertErrors: insertErrors ? JSON.stringify(insertErrors).substring(0, 500) : undefined,
      });
      throw err;
    }
  }

  async insertCopyrightAppeals(appeals: BigQueryCopyrightAppeal[]): Promise<void> {
    if (!this.enabled || appeals.length === 0) return;
    try {
      const table: Table = this.bigquery.dataset(this.datasetId).table(BigQueryAnalyticsService.COPYRIGHT_APPEALS_TABLE);
      await table.insert(appeals, { skipInvalidRows: true, ignoreUnknownValues: true });
      logger.info(`[BigQueryAnalytics] Streamed ${appeals.length} copyright appeals to BigQuery`);
    } catch (err: any) {
      const insertErrors = err?.errors || err?.response?.insertErrors;
      logger.error("[BigQueryAnalytics] Failed streaming copyright appeals", {
        count: appeals.length,
        message: err?.message,
        insertErrors: insertErrors ? JSON.stringify(insertErrors).substring(0, 500) : undefined,
      });
      throw err;
    }
  }

  private async ensureVerifiedClaimsColumns(table: Table): Promise<void> {
    if (!this.enabled || this.verifiedClaimsColumnsEnsured) return;
    if (typeof (table as any)?.getMetadata !== "function") {
      this.verifiedClaimsColumnsEnsured = true;
      return;
    }

    const requiredColumns: Array<{ name: string; type: string; mode: string }> = [
      { name: "english_claim_hash", type: "STRING", mode: "NULLABLE" },
      { name: "semantic_hash", type: "STRING", mode: "NULLABLE" },
      { name: "evidence_schema_version", type: "STRING", mode: "NULLABLE" },
      { name: "rich_sources_json", type: "STRING", mode: "NULLABLE" },
    ];

    try {
      const [metadata] = await table.getMetadata();
      const existingFields: Array<{ name: string; [key: string]: any }> = Array.isArray(metadata?.schema?.fields)
        ? metadata.schema.fields
        : [];
      const existingNames = new Set(existingFields.map((f) => f?.name).filter(Boolean));
      const missingFields = requiredColumns.filter((col) => !existingNames.has(col.name));

      if (missingFields.length === 0) {
        this.verifiedClaimsColumnsEnsured = true;
        return;
      }

      if (typeof (table as any)?.setMetadata === "function") {
        await table.setMetadata({
          schema: {
            fields: [...existingFields, ...missingFields],
          },
        });
      } else if (typeof (this.bigquery as any)?.query === "function") {
        for (const col of missingFields) {
          await this.bigquery.query({
            query: `ALTER TABLE \`${this.datasetId}.${BigQueryAnalyticsService.VERIFIED_CLAIMS_TABLE}\` ADD COLUMN IF NOT EXISTS ${col.name} ${col.type}`,
            location: this.location,
          });
        }
      }

      this.verifiedClaimsColumnsEnsured = true;
      logger.info("[BigQueryAnalytics] Upgraded raw_claims_verified schema columns", {
        added: missingFields.map((f) => f.name),
      });
    } catch (err: any) {
      logger.warn("[BigQueryAnalytics] Non-fatal schema upgrade check on raw_claims_verified", {
        err: String(err?.message || err),
      });
    }
  }

  async insertVerifiedClaims(claims: BigQueryVerifiedClaim[]): Promise<void> {
    if (!this.enabled || claims.length === 0) return;
    try {
      const table: Table = this.bigquery.dataset(this.datasetId).table(BigQueryAnalyticsService.VERIFIED_CLAIMS_TABLE);
      if (!this.verifiedClaimsColumnsEnsured) {
        await this.ensureVerifiedClaimsColumns(table);
      }
      const normalizedRows = claims.map((c) => ({
        ...c,
        ...(c.evidence_schema_version !== undefined && c.evidence_schema_version !== null
          ? { evidence_schema_version: String(c.evidence_schema_version) }
          : {}),
      }));
      await table.insert(normalizedRows, { skipInvalidRows: true, ignoreUnknownValues: true });
      logger.info(`[BigQueryAnalytics] Streamed ${claims.length} verified claims to BigQuery`);
    } catch (err: any) {
      const insertErrors = err?.errors || err?.response?.insertErrors;
      logger.error("[BigQueryAnalytics] Failed streaming verified claims", {
        count: claims.length,
        message: err?.message,
        insertErrors: insertErrors ? JSON.stringify(insertErrors).substring(0, 500) : undefined,
      });
      throw err;
    }
  }

  async insertFactCheckEvaluations(evaluations: BigQueryFactCheckEvaluation[]): Promise<void> {
    if (!this.enabled || evaluations.length === 0) return;
    try {
      const table: Table = this.bigquery.dataset(this.datasetId).table(BigQueryAnalyticsService.FACT_CHECK_EVALUATIONS_TABLE);
      await table.insert(evaluations, { skipInvalidRows: true, ignoreUnknownValues: true });
      logger.info(`[BigQueryAnalytics] Streamed ${evaluations.length} fact-check evaluations to BigQuery`);
    } catch (err: any) {
      const insertErrors = err?.errors || err?.response?.insertErrors;
      logger.error("[BigQueryAnalytics] Failed streaming fact-check evaluations", {
        count: evaluations.length,
        message: err?.message,
        insertErrors: insertErrors ? JSON.stringify(insertErrors).substring(0, 500) : undefined,
      });
      throw err;
    }
  }

  async insertCreatorEarnings(earnings: BigQueryCreatorEarning[]): Promise<void> {
    if (!this.enabled || earnings.length === 0) return;
    try {
      const table: Table = this.bigquery.dataset(this.datasetId).table(BigQueryAnalyticsService.CREATOR_EARNINGS_TABLE);
      await table.insert(earnings, { skipInvalidRows: true, ignoreUnknownValues: true });
      logger.info(`[BigQueryAnalytics] Streamed ${earnings.length} creator earnings records to BigQuery`);
    } catch (err: any) {
      const insertErrors = err?.errors || err?.response?.insertErrors;
      logger.error("[BigQueryAnalytics] Failed streaming creator earnings", {
        count: earnings.length,
        message: err?.message,
        insertErrors: insertErrors ? JSON.stringify(insertErrors).substring(0, 500) : undefined,
      });
      throw err;
    }
  }

  async insertPayoutTransactions(transactions: BigQueryPayoutTransaction[]): Promise<void> {
    if (!this.enabled || transactions.length === 0) return;
    try {
      const table: Table = this.bigquery.dataset(this.datasetId).table(BigQueryAnalyticsService.PAYOUT_TRANSACTIONS_TABLE);
      await table.insert(transactions, { skipInvalidRows: true, ignoreUnknownValues: true });
      logger.info(`[BigQueryAnalytics] Streamed ${transactions.length} payout transactions to BigQuery`);
    } catch (err: any) {
      const insertErrors = err?.errors || err?.response?.insertErrors;
      logger.error("[BigQueryAnalytics] Failed streaming payout transactions", {
        count: transactions.length,
        message: err?.message,
        insertErrors: insertErrors ? JSON.stringify(insertErrors).substring(0, 500) : undefined,
      });
      throw err;
    }
  }

  async insertMonetizationDeductions(deductions: BigQueryMonetizationDeduction[]): Promise<void> {
    if (!this.enabled || deductions.length === 0) return;
    try {
      const table: Table = this.bigquery.dataset(this.datasetId).table(BigQueryAnalyticsService.MONETIZATION_DEDUCTIONS_TABLE);
      await table.insert(deductions, { skipInvalidRows: true, ignoreUnknownValues: true });
      logger.info(`[BigQueryAnalytics] Streamed ${deductions.length} monetization deductions to BigQuery`);
    } catch (err: any) {
      const insertErrors = err?.errors || err?.response?.insertErrors;
      logger.error("[BigQueryAnalytics] Failed streaming monetization deductions", {
        count: deductions.length,
        message: err?.message,
        insertErrors: insertErrors ? JSON.stringify(insertErrors).substring(0, 500) : undefined,
      });
      throw err;
    }
  }

  async insertAdImpressions(impressions: BigQueryAdImpression[]): Promise<void> {
    if (!this.enabled || impressions.length === 0) return;
    try {
      const table: Table = this.bigquery.dataset(this.datasetId).table(BigQueryAnalyticsService.AD_IMPRESSIONS_TABLE);
      await table.insert(impressions, { skipInvalidRows: true, ignoreUnknownValues: true });
      logger.info(`[BigQueryAnalytics] Streamed ${impressions.length} ad impressions to BigQuery`);
    } catch (err: any) {
      const insertErrors = err?.errors || err?.response?.insertErrors;
      logger.error("[BigQueryAnalytics] Failed streaming ad impressions", {
        count: impressions.length,
        message: err?.message,
        insertErrors: insertErrors ? JSON.stringify(insertErrors).substring(0, 500) : undefined,
      });
      throw err;
    }
  }

  async insertAdClicks(clicks: BigQueryAdClick[]): Promise<void> {
    if (!this.enabled || clicks.length === 0) return;
    try {
      const table: Table = this.bigquery.dataset(this.datasetId).table(BigQueryAnalyticsService.AD_CLICKS_TABLE);
      await table.insert(clicks, { skipInvalidRows: true, ignoreUnknownValues: true });
      logger.info(`[BigQueryAnalytics] Streamed ${clicks.length} ad clicks to BigQuery`);
    } catch (err: any) {
      const insertErrors = err?.errors || err?.response?.insertErrors;
      logger.error("[BigQueryAnalytics] Failed streaming ad clicks", {
        count: clicks.length,
        message: err?.message,
        insertErrors: insertErrors ? JSON.stringify(insertErrors).substring(0, 500) : undefined,
      });
      throw err;
    }
  }

  async insertAdFraudSignals(signals: BigQueryAdFraudSignal[]): Promise<void> {
    if (!this.enabled || signals.length === 0) return;
    try {
      const table: Table = this.bigquery.dataset(this.datasetId).table(BigQueryAnalyticsService.AD_FRAUD_SIGNALS_TABLE);
      await table.insert(signals, { skipInvalidRows: true, ignoreUnknownValues: true });
      logger.info(`[BigQueryAnalytics] Streamed ${signals.length} ad fraud signals to BigQuery`);
    } catch (err: any) {
      const insertErrors = err?.errors || err?.response?.insertErrors;
      logger.error("[BigQueryAnalytics] Failed streaming ad fraud signals", {
        count: signals.length,
        message: err?.message,
        insertErrors: insertErrors ? JSON.stringify(insertErrors).substring(0, 500) : undefined,
      });
      throw err;
    }
  }

  async insertSearchQueries(queries: BigQuerySearchQuery[]): Promise<void> {
    if (!this.enabled || queries.length === 0) return;
    try {
      const table: Table = this.bigquery.dataset(this.datasetId).table(BigQueryAnalyticsService.SEARCH_QUERIES_TABLE);
      await table.insert(queries, { skipInvalidRows: true, ignoreUnknownValues: true });
      logger.info(`[BigQueryAnalytics] Streamed ${queries.length} search queries to BigQuery`);
    } catch (err: any) {
      const insertErrors = err?.errors || err?.response?.insertErrors;
      logger.error("[BigQueryAnalytics] Failed streaming search queries", {
        count: queries.length,
        message: err?.message,
        insertErrors: insertErrors ? JSON.stringify(insertErrors).substring(0, 500) : undefined,
      });
      throw err;
    }
  }

  async insertSearchClickthroughs(clicks: BigQuerySearchClickthrough[]): Promise<void> {
    if (!this.enabled || clicks.length === 0) return;
    try {
      const table: Table = this.bigquery.dataset(this.datasetId).table(BigQueryAnalyticsService.SEARCH_CLICKTHROUGHS_TABLE);
      await table.insert(clicks, { skipInvalidRows: true, ignoreUnknownValues: true });
      logger.info(`[BigQueryAnalytics] Streamed ${clicks.length} search clickthroughs to BigQuery`);
    } catch (err: any) {
      const insertErrors = err?.errors || err?.response?.insertErrors;
      logger.error("[BigQueryAnalytics] Failed streaming search clickthroughs", {
        count: clicks.length,
        message: err?.message,
        insertErrors: insertErrors ? JSON.stringify(insertErrors).substring(0, 500) : undefined,
      });
      throw err;
    }
  }

  async insertModerationScans(scans: BigQueryModerationScan[]): Promise<void> {
    if (!this.enabled || scans.length === 0) return;
    try {
      const table: Table = this.bigquery.dataset(this.datasetId).table(BigQueryAnalyticsService.MODERATION_SCANS_TABLE);
      await table.insert(scans, { skipInvalidRows: true, ignoreUnknownValues: true });
      logger.info(`[BigQueryAnalytics] Streamed ${scans.length} moderation scans to BigQuery`);
    } catch (err: any) {
      const insertErrors = err?.errors || err?.response?.insertErrors;
      logger.error("[BigQueryAnalytics] Failed streaming moderation scans", {
        count: scans.length,
        message: err?.message,
        insertErrors: insertErrors ? JSON.stringify(insertErrors).substring(0, 500) : undefined,
      });
      throw err;
    }
  }

  async insertModeratorActions(actions: BigQueryModeratorAction[]): Promise<void> {
    if (!this.enabled || actions.length === 0) return;
    try {
      const table: Table = this.bigquery.dataset(this.datasetId).table(BigQueryAnalyticsService.MODERATOR_ACTIONS_TABLE);
      await table.insert(actions, { skipInvalidRows: true, ignoreUnknownValues: true });
      logger.info(`[BigQueryAnalytics] Streamed ${actions.length} moderator actions to BigQuery`);
    } catch (err: any) {
      const insertErrors = err?.errors || err?.response?.insertErrors;
      logger.error("[BigQueryAnalytics] Failed streaming moderator actions", {
        count: actions.length,
        message: err?.message,
        insertErrors: insertErrors ? JSON.stringify(insertErrors).substring(0, 500) : undefined,
      });
      throw err;
    }
  }

  /**
   * Executes an analytical query against BigQuery.
   */
  async query<T = any>(queryText: string, params?: Record<string, any>): Promise<T[]> {
    if (!this.enabled) return [];
    try {
      const [rows] = await this.bigquery.query({
        query: queryText,
        params,
        location: this.location,
      });
      return rows as T[];
    } catch (err: any) {
      logger.error("[BigQueryAnalytics] Query execution failed", {
        query: queryText.substring(0, 200),
        error: String(err?.message || err),
      });
      throw err;
    }
  }

  /**
   * Tier 1C single-query batched lookup against `raw_claims_verified`.
   * Fails open cleanly on error or timeout so verification is never blocked.
   */
  async lookupVerifiedClaimsBatch(params: {
    exactHashes: string[];
    semanticHashes: string[];
    schemaVersion: string | number;
    timeoutMs?: number;
  }): Promise<BigQueryVerifiedClaim[]> {
    if (!this.enabled) return [];

    const exactHashes = Array.from(new Set((params.exactHashes || []).map((h) => String(h || "").trim()).filter(Boolean)));
    const semanticHashes = Array.from(new Set((params.semanticHashes || []).map((h) => String(h || "").trim()).filter(Boolean)));
    if (exactHashes.length === 0 && semanticHashes.length === 0) {
      return [];
    }

    const timeoutMs = params.timeoutMs ?? 2500;
    const schemaVersion = String(params.schemaVersion);
    const sql = `
SELECT *
FROM \`${this.datasetId}.${BigQueryAnalyticsService.VERIFIED_CLAIMS_TABLE}\`
WHERE is_grounded = TRUE
  AND evidence_schema_version = @schemaVersion
  AND (
    normalized_claim_hash IN UNNEST(@hashes)
    OR english_claim_hash IN UNNEST(@hashes)
    OR semantic_hash IN UNNEST(@semHashes)
  )
QUALIFY ROW_NUMBER() OVER (
  PARTITION BY COALESCE(normalized_claim_hash, english_claim_hash, semantic_hash, claim_id)
  ORDER BY timestamp DESC
) = 1`;

    let timeoutHandle: NodeJS.Timeout | undefined;
    try {
      const queryOpts: any = {
        query: sql.trim(),
        params: {
          hashes: exactHashes,
          semHashes: semanticHashes,
          schemaVersion,
        },
        location: this.location,
        jobTimeoutMs: timeoutMs,
      };
      if (exactHashes.length === 0 || semanticHashes.length === 0) {
        queryOpts.types = {
          hashes: ["STRING"],
          semHashes: ["STRING"],
          schemaVersion: "STRING",
        };
      }

      const queryPromise = this.bigquery.query(queryOpts).then(([rows]) => (Array.isArray(rows) ? rows : []));
      const timeoutPromise = new Promise<never>((_, reject) => {
        timeoutHandle = setTimeout(() => reject(new Error(`BIGQUERY_LOOKUP_TIMEOUT_${timeoutMs}ms`)), timeoutMs);
        if (typeof timeoutHandle.unref === "function") {
          timeoutHandle.unref();
        }
      });

      const rows = await Promise.race([queryPromise, timeoutPromise]);
      return rows as BigQueryVerifiedClaim[];
    } catch (err: any) {
      logger.warn("[BigQueryAnalytics] Tier 1C lookupVerifiedClaimsBatch failed open", {
        exactCount: exactHashes.length,
        semanticCount: semanticHashes.length,
        error: String(err?.message || err),
      });
      return [];
    } finally {
      if (timeoutHandle) {
        clearTimeout(timeoutHandle);
      }
    }
  }

  // ─── Silver Layer Curated View Query Helpers ─────────────────────────────────

  /**
   * Queries daily P&L statements for a creator's channel from v_creator_daily_pnl.
   */
  async getCreatorDailyPnl(channelId: string, limitDays = 30): Promise<CreatorDailyPnlRow[]> {
    const sql = `
SELECT *
FROM \`${this.datasetId}.${BigQueryAnalyticsService.CREATOR_DAILY_PNL_VIEW}\`
WHERE channel_id = @channelId
ORDER BY date DESC
LIMIT @limitDays`;
    return this.query<CreatorDailyPnlRow>(sql, { channelId, limitDays });
  }

  /**
   * Queries deduplicated verified claims across all videos from v_credibility_claim_radar.
   */
  async getCredibilityRadar(minOccurrences = 1, limit = 50): Promise<CredibilityClaimRadarRow[]> {
    const sql = `
SELECT *
FROM \`${this.datasetId}.${BigQueryAnalyticsService.CREDIBILITY_CLAIM_RADAR_VIEW}\`
WHERE occurrence_count >= @minOccurrences
ORDER BY occurrence_count DESC, distinct_videos_count DESC
LIMIT @limit`;
    return this.query<CredibilityClaimRadarRow>(sql, { minOccurrences, limit });
  }

  /**
   * Queries campaign attribution and anti-fraud telemetry from v_ad_campaign_performance.
   */
  async getAdCampaignPerformance(campaignId: string): Promise<AdCampaignPerformanceRow[]> {
    const sql = `
SELECT *
FROM \`${this.datasetId}.${BigQueryAnalyticsService.AD_CAMPAIGN_PERFORMANCE_VIEW}\`
WHERE campaign_id = @campaignId
ORDER BY event_date DESC`;
    return this.query<AdCampaignPerformanceRow>(sql, { campaignId });
  }

  /**
   * Queries top rising search queries, intent clusters, and CTR from v_trending_search_clusters.
   */
  async getTrendingSearchClusters(limit = 25): Promise<TrendingSearchClusterRow[]> {
    const sql = `
SELECT *
FROM \`${this.datasetId}.${BigQueryAnalyticsService.TRENDING_SEARCH_CLUSTERS_VIEW}\`
ORDER BY search_volume DESC
LIMIT @limit`;
    return this.query<TrendingSearchClusterRow>(sql, { limit });
  }

  /**
   * Queries content moderation audits, overturn rates, and statutory actions from v_moderation_compliance_audit.
   */
  async getModerationComplianceAudit(days = 14): Promise<ModerationComplianceAuditRow[]> {
    const sql = `
SELECT *
FROM \`${this.datasetId}.${BigQueryAnalyticsService.MODERATION_COMPLIANCE_AUDIT_VIEW}\`
WHERE scan_date >= DATE_SUB(CURRENT_DATE(), INTERVAL @days DAY)
ORDER BY scan_date DESC, total_scans DESC`;
    return this.query<ModerationComplianceAuditRow>(sql, { days });
  }

  // Diagnostic helpers
  public getBufferSize(): {
    watchEvents: number;
    impressions: number;
    copyrightMatches: number;
    copyrightClaims: number;
    copyrightAppeals: number;
    verifiedClaims: number;
    factCheckEvaluations: number;
    creatorEarnings: number;
    payoutTransactions: number;
    monetizationDeductions: number;
    adImpressions: number;
    adClicks: number;
    adFraudSignals: number;
    searchQueries: number;
    searchClickthroughs: number;
    moderationScans: number;
    moderatorActions: number;
  } {
    return {
      watchEvents: this.watchEventBuffer.length,
      impressions: this.impressionBuffer.length,
      copyrightMatches: this.copyrightMatchBuffer.length,
      copyrightClaims: this.copyrightClaimBuffer.length,
      copyrightAppeals: this.copyrightAppealBuffer.length,
      verifiedClaims: this.verifiedClaimBuffer.length,
      factCheckEvaluations: this.factCheckEvaluationBuffer.length,
      creatorEarnings: this.creatorEarningsBuffer.length,
      payoutTransactions: this.payoutTransactionsBuffer.length,
      monetizationDeductions: this.monetizationDeductionsBuffer.length,
      adImpressions: this.adImpressionBuffer.length,
      adClicks: this.adClickBuffer.length,
      adFraudSignals: this.adFraudSignalBuffer.length,
      searchQueries: this.searchQueryBuffer.length,
      searchClickthroughs: this.searchClickthroughBuffer.length,
      moderationScans: this.moderationScanBuffer.length,
      moderatorActions: this.moderatorActionBuffer.length,
    };
  }
}

// Global Singleton Instance
let defaultService: BigQueryAnalyticsService | null = null;

export function getBigQueryAnalyticsService(): BigQueryAnalyticsService {
  if (!defaultService) {
    defaultService = new BigQueryAnalyticsService();
  }
  return defaultService;
}

export function setBigQueryAnalyticsService(service: BigQueryAnalyticsService): void {
  if (defaultService) {
    defaultService.stopFlushTimer();
  }
  defaultService = service;
}
