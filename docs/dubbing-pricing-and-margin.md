# Dubbing pricing & margin rule (decided 2026-11-20)

## Rule
- TruthWorld keeps 1/3 of every dub's price as profit ($1 of a $3, 10-minute, one-language dub) and never spends it on models or infrastructure.
- Cost budget = price − GST (if inside the price) − payment gateway fee − profit share.

## Price (per language)
Higher of:
- $0.30 per minute of video (60-second minimum) — "$3 for 10 minutes" stays the price for most videos
- $0.30 per 1,000 characters of dubbed (target-language) speech — same unit ElevenLabs bills

Quoted from the video's transcript (every upload is transcribed) using the language AssemblyAI detected, not a client-supplied one. Estimated dubbed characters = source characters × length factor of target ÷ source (`CHAR_LENGTH_FACTOR` in `functions/src/pipeline/services/dubbing-pricing.ts`; starting estimates — calibrate from `job_pacing_telemetry`).

## Why
Cost is driven by ElevenLabs v4 voice (~$0.08 / 1K characters). A talk-heavy 10-min video (~16–18K characters) cannot keep $1 at a flat $3 when GST is inside the price. Simulated across every target language and speech density, the character rule keeps the profit share in all cases.

ElevenLabs Dubbing v2 ($2.20/min → $22 per 10-min language) is excluded from the $3 product.

## Where it lives in code
- `services/dubbing-economics.ts` — margin policy, per-language budget, retry budget (env: `DUBBING_PROFIT_SHARE`, `PRICE_INCLUDES_GST`, `GST_RATE`, `PAYMENT_GATEWAY_FEE_RATE`, `ELEVENLABS_USD_PER_1K_CHARS`)
- `services/dubbing-pricing.ts` — quote; `channelDubbingDiscountPercent`
- `services/dubbing-quote-service.ts` — loads transcript for quote and charge
- `pipelineTriggers.ts` — `getDubbingQuote` callable; `triggerVideoAIFeatures` charges character price only when `DUBBING_CHARACTER_PRICING=true` (until then: minute price charged, character price logged as `[Pricing] Dubbing price`)
- `layers/07-dubbing.ts` — budget planned before voice generation; regeneration only within budget; `video_jobs/{id}.economics.<lang>`

## Rollout
1. Deploy with the switch off; watch `[Pricing] Dubbing price` logs (minute vs character price on real orders).
2. Update the app to show `getDubbingQuote` (wallet/upload screens currently compute price client-side).
3. Turn on `DUBBING_CHARACTER_PRICING=true`.

## Fixed on the way
- TTS cost was recorded twice per voiced line (tts.ts and 07-dubbing.ts) — check custom channels' `outstandingCosts`.
- Job cost totals only summed the first 100 events → `job_costs/{jobId}` running total.
- Client could get free dubbing via `isDubbingFree` / `isSubtitlesFree` in the request body; or another channel's discount via `channelId` in the request body. Both removed.
