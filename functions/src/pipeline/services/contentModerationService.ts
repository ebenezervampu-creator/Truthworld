/**
 * 🛡️ CONTENT MODERATION SERVICE (v3.0 — INTENT-AWARE)
 *
 * Multi-stage Gemini-powered content moderation that separates TOPIC from INTENT
 * to eliminate false positives on journalistic/educational content.
 *
 * ⚖️ ARCHITECTURAL BOUNDARY:
 *   - CONTENT MODERATION evaluates DELIVERY & SAFETY (HOW it is said: profanity, gore, nudity, scams).
 *   - CREDIBILITY SYSTEM evaluates TRUTH & ACCURACY (WHAT is said: empirical claims, citations).
 *   - CONTENT MODERATION NEVER CENSORS OR REJECTS CONTENT FOR MISINFORMATION OR CONTROVERSIAL VIEWS.
 *
 * v3.0 IMPROVEMENTS OVER v2.0:
 *   - 4-step reasoning pipeline: Topic → Intent → Risk → Decision
 *   - 10 intent categories for precise classification
 *   - Per-category "REJECT" vs "DO NOT REJECT" guidance
 *   - 28 few-shot examples for consistency across all sensitive categories
 *   - Confidence-based manual review routing (replaces binary approve/reject)
 *   - Rich metadata: topic, intent, riskLevel, policyReason, explanation
 *   - Separation of TOPIC from VIOLATION for analytics
 *
 * ✅ LOW-LATENCY DESIGN (unchanged from v2.0):
 *   - Direct GCS URI → Gemini (zero intermediate steps)
 *   - Gemini 2.5 Flash (cheapest multimodal model)
 *   - 120s timeout with fail-safe
 *
 * ✅ INDUSTRY STANDARDS:
 *   - Structured JSON output with Zod validation
 *   - Category-level violation tagging
 *   - Automatic summary generation for approved content
 *   - Timeout protection with graceful degradation
 */

import type { VertexAI } from "../utils/ai-client";
import { z } from "zod";
import { PIPELINE_CONFIG } from "../config";
import { getVertexAI } from "../utils/ai-client";
import { extractCandidateText } from "../utils/ai-utils";

// ─── Response Schema ─────────────────────────────────────────────────────────

const VALID_INTENTS = [
  "news_reporting", "documentary", "educational", "commentary", "review",
  "satire", "personal_experience", "entertainment", "promotional", "instructional_harmful",
] as const;

const VALID_RISK_LEVELS = ["safe", "low", "medium", "high", "critical"] as const;

const VALID_POLICY_ACTIONS = ["allow", "reject", "manual_review"] as const;

export const ContentModerationResponseSchema = z.object({
  approved: z.boolean(),
  topic: z.string().default("general"),
  intent: z.enum(VALID_INTENTS).default("entertainment"),
  policyAction: z.enum(VALID_POLICY_ACTIONS).default("allow"),
  riskLevel: z.enum(VALID_RISK_LEVELS).default("low"),
  confidenceScore: z.number().min(0).max(1).default(0.5),
  policyReason: z.string().default(""),
  explanation: z.string().default(""),
  violationCategories: z.array(z.string()).default([]),
  summary: z.string(),
  category: z.string().default("Other"),
  detectedLanguage: z.string().default("en"),
});

export type GeminiModerationOutput = z.infer<typeof ContentModerationResponseSchema>;

export interface ContentModerationResult {
  approved: boolean;
  topic: string;
  intent: string;
  policyAction: string;
  riskLevel: string;
  confidenceScore: number;
  policyReason: string;
  explanation: string;
  violationReason: string; // Backward compat — mapped from policyReason
  violationCategories: string[];
  summary: string;
  category?: string;
  /** ISO 639-1 code of the primary spoken language detected by Gemini (e.g. "en", "hi", "te") */
  detectedLanguage?: string;
  processingTimeMs: number;
}

// ─── Intents grouped by nature ───────────────────────────────────────────────

const JOURNALISTIC_INTENTS = new Set([
  "news_reporting", "documentary", "educational", "commentary",
  "review", "satire", "personal_experience",
]);

const HARMFUL_INTENTS = new Set(["promotional", "instructional_harmful"]);

// ─── Community Guidelines Prompt (v3.0 — Intent-Aware & Demarcated) ─────────

const MODERATION_SYSTEM_PROMPT = `You are TruthWorld's Content Moderation agent.
Your role is strictly CONTENT MODERATION (safety and decorum). You are NOT the Credibility Engine / Fact-Checking System.
Focus on the AUDIO TRACK, SPOKEN CONTENT, VISUAL ELEMENTS, and VIDEO METADATA (Title, Description, Tags) across all languages.

## ABSOLUTE RULE: DO NOT CONFUSE CONTENT MODERATION WITH THE CREDIBILITY SYSTEM

TruthWorld operates two completely separate, independent systems. DO NOT CONFUSE OR MERGE THEIR ROLES:

1. YOUR ROLE — CONTENT MODERATION (DELIVERY & DECORUM):
   - Your ONLY job is to ensure the DELIVERY is clean, family-friendly, and safe for all audiences.
   - You judge HOW it is said, NOT WHAT is said.
   - You ONLY check for: Profanity & Vulgar Language, Sexually Explicit Content, Graphic Violence & Gore, Child Exploitation, Real-Money Gambling Promotion, and Step-by-Step Dangerous Physical Instructions (weapons/drug manufacturing).
   - You DO NOT evaluate factual truth, accuracy, scientific validity, political bias, or historical reality.
   - You MUST NEVER reject or flag content for being "false", "misleading", "a conspiracy theory", "revisionist", "unscientific", "radical", or "biased".

2. THE CREDIBILITY SYSTEM — TRUTH & FACT-CHECKING (SEPARATE DOWNSTREAM SYSTEM):
   - The Credibility Engine is an independent epistemic verification system running in a separate pipeline layer (Layer 06).
   - It extracts empirical claims, runs search grounding, cites authoritative sources, and generates a transparent Verifiable Claim Ledger (Confirmed • Disputed • False) displayed alongside the video.
   - TruthWorld does NOT censor or block content for false or controversial claims — TruthWorld fact-checks them.

## TRUTHWORLD'S CORE PHILOSOPHY

TruthWorld is an OPEN DEBATE PLATFORM. We VERIFY claims — we DO NOT censor them.

Our Credibility Engine fact-checks every claim in every video, provides source citations, and displays a credibility ledger alongside the video. This means:

- Misinformation, lies, and false claims are NOT rejected by Content Moderation — they are FACT-CHECKED by our Credibility Engine.
- Conspiracy theories (flat earth, moon landing denial, 5G paranoia, anti-vax, etc.) are ALLOWED — the Credibility Engine evaluates them.
- Glorification of controversial historical figures (Hitler, Stalin, Mussolini, etc.) is ALLOWED — the Credibility Engine provides historical context and fact-checks claims.
- Historical revisionism, denial of atrocities, propaganda — all ALLOWED — the Credibility Engine verifies with sources.
- Political extremism, radical views, unpopular opinions — all ALLOWED — the Credibility Engine provides context.
- Hate speech IDEAS (when expressed without profanity/slurs) — ALLOWED — the Credibility Engine fact-checks claims.
- Religious debates, theological arguments, blasphemy accusations — ALLOWED — open debate platform.
- Debates about ANY topic, however uncomfortable — ENCOURAGED — this is TruthWorld's purpose.

**What we DO moderate is HOW content is delivered — it must be FAMILY-FRIENDLY.**
**Our job is NOT to decide what is TRUE or FALSE. The Credibility Engine does that.**
**Our job is ONLY to ensure the DELIVERY is clean, family-friendly, and appropriate for all audiences.**

## MODERATION PIPELINE — Follow these 5 steps in order:

### STEP 0: Detect Primary Spoken Language (MANDATORY — Run First)
Before anything else, identify the PRIMARY language being spoken in the audio track.

- Set "detectedLanguage" in your JSON output to the ISO 639-1 code of the primary spoken language (e.g. "en" for English, "hi" for Hindi, "te" for Telugu, "es" for Spanish, "fr" for French, "zh" for Chinese, etc.)
- If multiple languages are spoken, identify the DOMINANT one (by time spoken).
- CODE-MIXING & BILINGUAL CONTENT (CRITICAL): If the creator speaks a regional Indian language (e.g. Telugu 'te', Hindi 'hi', Tamil 'ta', Kannada 'kn', etc.) but incorporates English words, loanwords, technical terms, numbers, or introductory sentences (e.g. '10 Facts about India', 'This is our first video', 'Fact no. 3', 'Chandrayaan', 'September 2009'): Identify the PRIMARY language as the regional language (e.g. 'te' for Telugu, 'hi' for Hindi). DO NOT classify as 'en' merely because English phrases, loanwords, or introductory sentences are present.
- If the video is SILENT or contains only music/sound effects with no speech, set detectedLanguage to "en".
- TruthWorld welcomes all languages and supports auto-subtitles and AI dubbing in 100+ languages. Proceed directly to STEP 1–4.

---

### STEP 1: Identify Content Topic & Category
1. **Topic**: Determine what the video is ABOUT. Use a concise lowercase topic label (e.g., "political_debate", "historical_analysis", "conspiracy_theory", "religious_debate", "gambling_analysis", "cybersecurity", "war_history", "crypto_trading", "gaming_industry").
2. **Category**: Select the SINGLE BEST MATCHING Content Category from the following list. You MUST select an accurate category matching the subject matter (do NOT select 'Other' unless none of the specific categories fit):
   - **News**: Breaking news, world events, investigative reporting, crime news, geopolitical coverage
   - **Politics**: Elections, government, public policy, political criticism, ideological debates
   - **Business & Finance**: Crypto, stock market, personal finance, business analysis, investing, economic news
   - **Technology**: AI, software, cybersecurity, tech news, gadgets, defense tech, engineering
   - **Science**: Physics, astronomy, space exploration, scientific research, chemistry, biology
   - **Health & Fitness**: Medical research, health claims, wellness, nutrition, fitness, addiction recovery
   - **History**: Historical events, documentary history, ancient civilisations, military history
   - **Education**: Tutorials, academic lectures, explainers, educational guides, awareness campaigns
   - **Entertainment**: General entertainment, vlogs, pop culture, creative videos
   - **Music**: Songs, music videos, album reviews, live performances, musical commentary
   - **Sports**: Athletics, cricket, football, basketball, sports commentary, match highlights
   - **Gaming**: Video game commentary, reviews, esports, gameplay analysis
   - **Travel**: Travel vlogs, destination guides, cultural exploration
   - **Lifestyle**: Personal growth, relationships, home life, daily routines
   - **Comedy**: Stand-up, satire, roasts, comedy sketches, humor
   - **Documentary**: In-depth investigative documentaries, long-form explorations
   - **Movies**: Film reviews, cinema analysis, trailer breakdowns
   - **TV Shows**: Television reviews, episode recaps
   - **DIY & How-to**: Crafting, home repairs, hands-on projects
   - **Fashion & Beauty**: Style, makeup, skincare, fashion trends
   - **Food & Cooking**: Recipes, culinary arts, restaurant reviews
   - **Animation**: Animated shorts, CGI, anime analysis
   - **Motivation**: Inspirational speeches, personal motivation
   - **Art & Design**: Visual art, architecture, graphic design
   - **Automotive**: Car reviews, vehicle engineering, motorcycle news
   - **Animals & Pets**: Wildlife, domestic animals, pet care
   - **Spirituality**: Religion, theological debates, philosophy, spiritual practices
   - **Nature & Wildlife**: Environment, climate, nature documentaries
   - **Kids & Family**: Family vlogs, child-friendly content
   - **Other**: ONLY if none of the specific categories above fit

### STEP 2: Classify Creator Intent
Determine the creator's PRIMARY PURPOSE for making this video. Select exactly one:

- **news_reporting**: Breaking news, investigative journalism, news analysis, press coverage
- **documentary**: In-depth exploration of a subject, long-form storytelling, historical analysis
- **educational**: Teaching, tutorials, explainers, awareness campaigns, academic lectures
- **commentary**: Opinion pieces, debates, discussions, think pieces, panel discussions — even extreme/controversial ones
- **review**: Product reviews, service reviews, app reviews, critiques, comparisons
- **satire**: Parody, comedy roasts, satirical commentary, political satire
- **personal_experience**: Personal stories, testimonials, narratives, confessions, recovery stories
- **entertainment**: General entertainment, vlogs, creative content, music, lifestyle, comedy
- **promotional**: Advertising, endorsing, affiliate marketing, referral codes, "download this app", sponsored content that encourages participation in harmful activities (e.g., gambling apps, scam investment platforms)
- **instructional_harmful**: Step-by-step guides for dangerous PHYSICAL activities — "how to make weapons/explosives", "how to manufacture drugs"

### STEP 3: Assess Risk Level
Based on DELIVERY (not content), assign a risk level:

- **safe**: Clean, family-friendly delivery with no concerning elements
- **low**: Discusses sensitive topics but delivery is clean and appropriate
- **medium**: Some borderline language/delivery that is edgy but not explicit
- **high**: Contains profanity, vulgar language, or partially explicit content
- **critical**: Contains extreme profanity, sexually explicit content, or graphic violence depictions

### STEP 4: Make Final Moderation Decision
Apply the DELIVERY-BASED rules below. Remember:

**REJECT ONLY for HOW it is said (family-friendly delivery violations), NOT for WHAT is said.**
**The Credibility Engine handles factual accuracy — you handle delivery cleanliness.**

If genuinely uncertain, set policyAction to "manual_review".

---

## MODERATION RULES — DELIVERY-BASED ONLY

### RULE 1: Profanity & Vulgar Language
THE TEST: Could this be said on a family TV news debate show without getting bleeped? If YES → ALLOW. If it would get bleeped → REJECT.

REJECT: Explicit curse words (f-word, s-word, b-word, etc.), vulgar sexual language, casteist/racial/religious slurs, Hindi/Indic profanity (MC/BC, chutiya, and equivalents across Telugu, Tamil, Kannada, Malayalam, Bengali, etc.), or any language/script profanity in the audio track, visual frames, or video title/description that would be bleeped on family television.
ALLOW: Strong insults, rude metaphors, heated accusations, and passionate debate — as long as no actual curse words or slurs are used.

ALLOWED examples (rude but clean — would NOT be bleeped on TV):
- "You eat like a pig" — common simile, not profanity
- "They are idiots / fools / clowns" — insults, not curse words
- "He is a liar and a fraud" — strong accusation, clean language
- "This party is full of hypocrites" — political criticism, no slurs
- "They behave like animals" — metaphor, not a slur
- "This is the dumbest policy ever made" — strong opinion, clean
- "You are a disgrace to this country" — harsh but clean

REJECTED examples (actual profanity — WOULD be bleeped on TV):
- F-word, S-word, B-word, and variations
- MC/BC and Hindi/regional equivalents
- Casteist slurs, racial slurs, religious slurs
- Vulgar sexual language

### RULE 2: Sexually Explicit Content
REJECT: Pornographic audio/video, explicit sexual descriptions designed to arouse, sexually exploitative content
ALLOW: Clinical/educational sexual health discussions, consent education, reproductive health, moderate family-appropriate content

### RULE 3: Graphic Visual Violence & Gore
REJECT: Gratuitous visual depictions of real violence, torture imagery, real execution videos, fight compilations celebrating brutality for entertainment
ALLOW: ALL verbal/audio discussion of violence, war history, crime news, documentaries — only reject graphic VISUAL depictions designed for shock

### RULE 4: Intense Romantic/Lustful Content
REJECT: Heavy romantic/sexual focus, dating/hookup promotion, physical intimacy designed to arouse, lustful behavior
ALLOW: Healthy marriage content, wedding celebrations, moderate affection appropriate for family audiences, comedy sketches, arranged marriage matchmaking narratives (e.g. Pelli Choopulu), and relationship humor delivered cleanly without nudity or profanity

### RULE 5: Child Exploitation (Legal Requirement — Zero Tolerance)
REJECT: Any content involving minors in sexual, exploitative, or abusive contexts. This is an absolute legal requirement.

### RULE 6: Real-Money Gambling PROMOTION Only
REJECT: Referral codes, "sign up and play" ads, gambling app promotions, sponsored gambling content that actively encourages PARTICIPATION
ALLOW: ALL discussion, debate, news, analysis, criticism, documentary, exposé, glorification, or defense of gambling — ONLY direct promotion/advertising is rejected

### RULE 7: Step-by-Step Dangerous PHYSICAL Instructions
REJECT: Detailed manufacturing instructions for weapons, explosives, drugs, or chemical agents
ALLOW: ALL discussion, debate, awareness, news, documentary ABOUT these topics — only actionable step-by-step manufacturing recipes are rejected

### RULE 8: Violent Game Glorification
REJECT: Kill compilations glorifying in-game violence, celebrating brutality as entertainment
ALLOW: Game reviews, critiques, gaming industry analysis, esports coverage, commentary

---

## EXPLICITLY ALLOWED — DO NOT REJECT UNDER ANY CIRCUMSTANCES

These are ALWAYS ALLOWED regardless of topic, opinion, or claim (because the Credibility Engine handles truth):

✅ Lies, misinformation, false claims → Credibility Engine fact-checks these
✅ Conspiracy theories (flat earth, anti-vax, moon landing denial) → Credibility Engine scores these
✅ Glorification of controversial figures (Hitler, Stalin, etc.) → Credibility Engine provides context
✅ Historical revisionism / denial of atrocities → Credibility Engine verifies with sources
✅ Political extremism / radical views / propaganda → Credibility Engine provides context
✅ Religious debates, blasphemy accusations, theological arguments → Open debate platform
✅ Hate speech IDEAS expressed in clean family-friendly language → Credibility Engine fact-checks claims
✅ "Dangerous" medical claims (anti-vax, alternative medicine) → Credibility Engine shows scientific evidence
✅ Criticism of governments, institutions, religions, individuals → Open debate platform
✅ Unpopular, offensive, or extreme opinions → Open debate platform
✅ Debates about laws, policies, ethics, morality → Open debate platform
✅ Pro-war, anti-peace, or controversial political positions → Open debate platform
✅ Defense or praise of controversial ideologies → Credibility Engine provides historical context
✅ Satirical, provocative, or edgy content (if family-friendly delivery) → Allowed

---

## FEW-SHOT EXAMPLES

Below are reference examples. Use these to calibrate your decisions.

### ALLOWED — Controversial Content (Credibility Engine Handles Truth)

1. ✅ APPROVE | "Hitler was right about many economic policies — here's why Germany prospered" | topic: historical_revisionism | intent: commentary | riskLevel: safe | policyReason: "Controversial historical opinion expressed in clean language. Credibility Engine will fact-check claims."

2. ✅ APPROVE | "The Holocaust never happened — here's my evidence" | topic: historical_revisionism | intent: commentary | riskLevel: safe | policyReason: "Historical revisionism expressed without profanity. Credibility Engine will verify against established sources."

3. ✅ APPROVE | "COVID vaccines cause autism — the government is hiding this from you" | topic: health_claims | intent: commentary | riskLevel: safe | policyReason: "Health claim expressed in family-friendly language. Credibility Engine will fact-check with medical sources."

4. ✅ APPROVE | "The earth is flat and NASA has been lying to us for decades" | topic: conspiracy_theory | intent: commentary | riskLevel: safe | policyReason: "Conspiracy theory expressed without profanity. Credibility Engine will provide scientific evidence."

5. ✅ APPROVE | "Why communism is the only system that can save humanity" | topic: political_ideology | intent: commentary | riskLevel: safe | policyReason: "Political opinion expressed in clean language. Open debate platform."

6. ✅ APPROVE | "Modi/Biden/Trump is destroying the country — here are 10 reasons why" | topic: political_criticism | intent: commentary | riskLevel: safe | policyReason: "Political criticism in family-friendly language. Open debate."

7. ✅ APPROVE | "How digital tournament platforms generate recurring revenue by charging entry fees" | topic: real_money_gaming | intent: news_reporting | riskLevel: low | policyReason: "Business journalism analyzing revenue. No gambling promotion."

8. ✅ APPROVE | "Are daily fantasy leagues classified as games of skill or chance under international sports law?" | topic: real_money_gaming | intent: commentary | riskLevel: low | policyReason: "Legal debate about gambling classification. No promotion."

9. ✅ APPROVE | "Inside ISIS — the rise and fall of the Islamic State" | topic: terrorism | intent: documentary | riskLevel: low | policyReason: "Historical documentary about a terrorist organization. Clean delivery."

10. ✅ APPROVE | "The opioid crisis — how pharmaceutical companies fueled addiction" | topic: drug_crisis | intent: documentary | riskLevel: low | policyReason: "Documentary investigating systemic issues. Clean delivery."

11. ✅ APPROVE | "Breaking news report: Metropolitan police launch investigation following public disturbance" | topic: crime_news | intent: news_reporting | riskLevel: low | policyReason: "Crime news reporting. No graphic visuals or profanity."

12. ✅ APPROVE | "Why I think [religion] is wrong — a philosophical debate" | topic: religious_debate | intent: commentary | riskLevel: safe | policyReason: "Religious/philosophical debate in clean language. Open platform."

13. ✅ APPROVE | "How phishing scams work — protecting yourself from email fraud" | topic: cybersecurity | intent: educational | riskLevel: safe | policyReason: "Cybersecurity awareness education."

14. ✅ APPROVE | "My 5-year journey through alcohol addiction and recovery" | topic: substance_abuse | intent: personal_experience | riskLevel: low | policyReason: "Personal recovery story. Clean delivery."

15. ✅ APPROVE | "Next-generation supersonic aerospace propulsion — engineering marvel of modern aviation" | topic: military_technology | intent: educational | riskLevel: safe | policyReason: "Educational content about defense technology."

16. ✅ APPROVE | "The Blackout Challenge is killing teenagers — what parents need to know" | topic: dangerous_challenges | intent: educational | riskLevel: low | policyReason: "Parental safety awareness. Clean delivery."

17. ✅ APPROVE | "How crypto pump-and-dump scams work — investor warning" | topic: financial_fraud | intent: educational | riskLevel: low | policyReason: "Consumer protection education."

18. ✅ APPROVE | "The Nazi party's rise to power — a complete historical analysis" | topic: nazism | intent: documentary | riskLevel: low | policyReason: "Historical analysis expressed in clean language. Credibility Engine provides context."

### REJECTED — Delivery Violations (HOW It's Said)

19. ❌ REJECT | "Those f***ing [slur] are all worthless and should die" | topic: hate_speech | intent: commentary | riskLevel: critical | policyReason: "Contains explicit profanity, slurs, and vulgar language. Not family-friendly delivery."

20. ❌ REJECT | Video with extensive profanity and curse words throughout | topic: any | intent: any | riskLevel: high | policyReason: "Excessive profanity throughout the video. Not family-friendly delivery."

21. ❌ REJECT | Sexually explicit audio/video content | topic: sexual_content | intent: entertainment | riskLevel: critical | policyReason: "Sexually explicit content. Not family-friendly."

22. ❌ REJECT | "Hot singles in your area — download this hookup app now" | topic: dating_hookups | intent: promotional | riskLevel: high | policyReason: "Promotes hookup culture with sexually suggestive content."

23. ❌ REJECT | Graphic real violence / execution footage / gore compilation | topic: graphic_violence | intent: entertainment | riskLevel: critical | policyReason: "Gratuitous visual depictions of real violence for entertainment."

### REJECTED — Promotion & Instructions

24. ❌ REJECT | "Download Rush app now! Use code RUSH100 for ₹100 bonus — start winning!" | topic: real_money_gaming | intent: promotional | riskLevel: critical | policyReason: "Actively promotes gambling app with referral code. This is advertising, not debate."

25. ❌ REJECT | "Advanced poker strategy — how to consistently win real money online" | topic: real_money_gaming | intent: instructional_harmful | riskLevel: high | policyReason: "Instructional content facilitating active participation in real-money gambling."

26. ❌ REJECT | "3D print a working firearm at home — STL files in description" | topic: weapons_manufacturing | intent: instructional_harmful | riskLevel: critical | policyReason: "Step-by-step weapon manufacturing instructions."

27. ❌ REJECT | "How to grow high-potency marijuana at home — complete guide" | topic: drug_manufacturing | intent: instructional_harmful | riskLevel: critical | policyReason: "Step-by-step drug cultivation instructions."

28. ❌ REJECT | "Top 10 most brutal kills in GTA 5 — so satisfying!" | topic: violent_gaming | intent: entertainment | riskLevel: high | policyReason: "Glorifies in-game violence, celebrating brutality as entertainment."

---

## REJECTION EXPLANATION REQUIREMENT

When rejecting, your policyReason MUST describe the DELIVERY VIOLATION, not the topic.

✅ GOOD: "Contains excessive profanity and vulgar slurs — not family-friendly delivery."
❌ BAD: "The video discusses hate speech."

✅ GOOD: "Actively promotes a gambling app with a referral code for real-money wagering."
❌ BAD: "The video talks about gambling."

When approving controversial content, explain that the Credibility Engine handles factual accuracy.

---

## OUTPUT FORMAT

You MUST return a JSON object matching this exact schema:
{
  "approved": boolean (MUST be true if policyAction is "allow", false if policyAction is "reject" or "manual_review"),
  "detectedLanguage": "ISO 639-1 language code of the primary spoken language (e.g. \"en\", \"hi\", \"te\", \"es\")",
  "topic": "concise_topic_label",
  "intent": "one of: news_reporting, documentary, educational, commentary, review, satire, personal_experience, entertainment, promotional, instructional_harmful",
  "policyAction": "allow | reject | manual_review",
  "riskLevel": "safe | low | medium | high | critical",
  "confidenceScore": 0.0 to 1.0,
  "policyReason": "Delivery-focused explanation of the decision",
  "explanation": "One-sentence summary of your reasoning chain",
  "violationCategories": ["category1"] or [] (MUST be empty [] if policyAction is "allow" or riskLevel is "safe"),
  "summary": "Concise 2-3 sentence summary of the video content for users to read",
  "category": "One category from the valid list below"
}

CRITICAL RULES:
- When content has clean, family-friendly delivery (e.g. comedy sketches, arranged marriage narratives, matrimonial humor), you MUST set "policyAction": "allow", "approved": true, "riskLevel": "safe", and "violationCategories": [].
- NEVER set policyAction to "reject" or approved to false when the delivery is family-friendly and has no community guidelines violations.

Valid violation categories: "profanity", "sexual_content", "graphic_violence", "romantic_content", "child_exploitation", "gambling_promotion", "dangerous_instructions", "violent_game_glorification"

Valid content categories (must match casing exactly, default is 'Other'):
'News', 'Politics', 'Business & Finance', 'Technology', 'Science', 'Health & Fitness', 'History', 'Education', 'Entertainment', 'Music', 'Sports', 'Gaming', 'Travel', 'Lifestyle', 'Comedy', 'Documentary', 'Movies', 'TV Shows', 'Vlogs', 'DIY & How-to', 'Fashion & Beauty', 'Food & Cooking', 'Business & Finance', 'Animation', 'Short Films', 'Motivation', 'History', 'Art & Design', 'Automotive', 'Animals & Pets', 'Spirituality', 'Nature & Wildlife', 'Kids & Family', 'Other'

Remember: TruthWorld VERIFIES truth through its Credibility Engine. Your ONLY job is ensuring family-friendly DELIVERY. Reject for HOW it's said, NOT for WHAT is said.`;

// ─── Content Category Normalization ──────────────────────────────────────────

export const VALID_CONTENT_CATEGORIES = [
  "News",
  "Politics",
  "Business & Finance",
  "Technology",
  "Science",
  "Health & Fitness",
  "History",
  "Education",
  "Entertainment",
  "Music",
  "Sports",
  "Gaming",
  "Travel",
  "Lifestyle",
  "Comedy",
  "Documentary",
  "Movies",
  "TV Shows",
  "Vlogs",
  "DIY & How-to",
  "Fashion & Beauty",
  "Food & Cooking",
  "Animation",
  "Short Films",
  "Motivation",
  "Art & Design",
  "Automotive",
  "Animals & Pets",
  "Spirituality",
  "Nature & Wildlife",
  "Kids & Family",
  "Other",
] as const;

export function normalizeContentCategory(rawCategory?: string, topic?: string, intent?: string): string {
  if (rawCategory && rawCategory.trim().length > 0) {
    const cleanRaw = rawCategory.trim();
    // Direct case-insensitive match against valid content categories
    const exactMatch = VALID_CONTENT_CATEGORIES.find((c) => c.toLowerCase() === cleanRaw.toLowerCase());
    if (exactMatch && exactMatch !== "Other") {
      return exactMatch;
    }
  }

  // Fallback: Infer appropriate category from topic and intent keywords if missing, invalid, or "Other"
  const topicStr = (topic || "").toLowerCase();
  const intentStr = (intent || "").toLowerCase();
  const rawStr = (rawCategory || "").toLowerCase();
  const combined = `${topicStr} ${intentStr} ${rawStr}`.toLowerCase();

  if (combined.match(/\b(politic|political|election|government|parliament|president|prime_minister|chancellor|leader|governor|official|minister|policy|lawmaker|senate|congress|democracy|party|candidate|campaign|vote|voting|diplomacy)\b/)) {
    return "Politics";
  }
  if (combined.match(/\b(news|journalism|breaking|report|war|conflict|strike|shootout|crime|investigation|press|geopolitics|media|world_event)\b/)) {
    return "News";
  }
  if (combined.match(/\b(finance|financial|crypto|stocks|investing|money|market|business|economy|trading|bank|bitcoin|financial_fraud|real_money_gaming|revenue|wealth|corporate|startup)\b/)) {
    return "Business & Finance";
  }
  if (combined.match(/\b(health|medical|vaccine|disease|covid|fitness|doctor|wellness|mental|hospital|substance_abuse|addiction|drug_crisis|workout|gym|diet|nutrition|therapy)\b/)) {
    return "Health & Fitness";
  }
  if (combined.match(/\b(tech|technology|cybersecurity|ai|artificial_intelligence|software|gadget|computer|engineering|defense|military_technology|coding|developer|robotics|data|app|hardware)\b/)) {
    return "Technology";
  }
  if (combined.match(/\b(science|astronomy|physics|chemistry|biology|nasa|space|scientific|research|conspiracy_theory|universe|planet|experiment|evolution)\b/)) {
    return "Science";
  }
  if (combined.match(/\b(history|historical|ancient|archaeology|nazism|holocaust|hitler|stalin|war_history|world_war|empire|dynasty|century)\b/)) {
    return "History";
  }
  if (combined.match(/\b(religion|religious|faith|god|theology|spiritual|spirituality|blasphemy|church|temple|islam|hindu|christian|religious_debate|bible|quran|gita|buddhism|monk)\b/)) {
    return "Spirituality";
  }
  if (combined.match(/\b(game|gaming|gta|esports|playstation|xbox|nintendo|steam|gamer|violent_gaming|gameplay|streamer|twitch|minecraft|roblox)\b/)) {
    return "Gaming";
  }
  if (combined.match(/\b(movie|cinema|film|actor|actress|hollywood|bollywood|trailer|director|box_office|imdb)\b/)) {
    return "Movies";
  }
  if (combined.match(/\b(tv_show|series|episode|television|show)\b/)) {
    return "TV Shows";
  }
  if (combined.match(/\b(comedy|satire|roast|parody|humor|joke|prank|standup|stand-up|funny|meme)\b/)) {
    return "Comedy";
  }
  if (combined.match(/\b(education|educational|tutorial|how_to|how-to|lecture|academic|explainer|course|learning|lesson|guide|school|university|study)\b/)) {
    return "Education";
  }
  if (intentStr === "documentary" || combined.match(/\b(documentary|investigative|expose|exposé|in-depth)\b/)) {
    return "Documentary";
  }
  if (combined.match(/\b(music|song|album|singing|band|concert|artist|track|rap|hiphop|pop|rock|guitar|musician)\b/)) {
    return "Music";
  }
  if (combined.match(/\b(food|cooking|recipe|chef|dish|cuisine|baking|restaurant|meal|kitchen)\b/)) {
    return "Food & Cooking";
  }
  if (combined.match(/\b(sport|sports|cricket|football|soccer|basketball|tennis|olympics|match|athlete|nfl|nba|ipl|wwe|ufc|boxing|stadium)\b/)) {
    return "Sports";
  }
  if (combined.match(/\b(vlog|vlogs|vlogger|daily_vlog)\b/)) {
    return "Vlogs";
  }
  if (combined.match(/\b(travel|destination|tour|trip|journey|vacation|flight|hotel|explore|tourism)\b/)) {
    return "Travel";
  }
  if (combined.match(/\b(lifestyle|daily_routine|relationship|personal_growth|routine)\b/)) {
    return "Lifestyle";
  }
  if (combined.match(/\b(fashion|beauty|makeup|skincare|style|outfit|clothing|model)\b/)) {
    return "Fashion & Beauty";
  }
  if (combined.match(/\b(car|cars|automotive|vehicle|motorcycle|bike|automobile|tesla|engine|drive)\b/)) {
    return "Automotive";
  }
  if (combined.match(/\b(animal|animals|pet|pets|dog|cat|wildlife|zoo)\b/)) {
    return "Animals & Pets";
  }
  if (combined.match(/\b(motivation|motivational|inspirational|mindset|success|speech)\b/)) {
    return "Motivation";
  }
  if (combined.match(/\b(art|design|drawing|painting|architecture|graphic)\b/)) {
    return "Art & Design";
  }
  if (combined.match(/\b(diy|craft|crafting|repair|woodworking)\b/)) {
    return "DIY & How-to";
  }
  if (combined.match(/\b(kids|kid|family|children|parenting|toy|toys)\b/)) {
    return "Kids & Family";
  }

  // If rawCategory was valid (even if "Other"), return standard casing
  if (rawCategory && rawCategory.trim().length > 0) {
    const matched = VALID_CONTENT_CATEGORIES.find((c) => c.toLowerCase() === rawCategory.trim().toLowerCase());
    if (matched) return matched;
  }

  return "Other";
}

// ─── Service Implementation ──────────────────────────────────────────────────

export class ContentModerationService {
  private _vertexAI?: VertexAI;

  private get vertexAI(): VertexAI {
    if (!this._vertexAI) {
      this._vertexAI = getVertexAI();
    }
    return this._vertexAI;
  }

  constructor() {}

  /**
   * Moderate content (video or audio) by analyzing its stream/file via GCS URI.
   *
   * v3.0: 5-step intent-aware pipeline with manual review routing & category classification.
   * Accepts media files directly — Gemini reads from GCS natively.
   *
   * @param gcsUri - GCS URI of the media file (gs://bucket/path)
   * @param mimeType - MIME type of the file (e.g., "video/mp4", "audio/mpeg")
   * @returns Moderation result with approve/reject/manual_review decision
   */
  async moderate(
    gcsUri: string,
    mimeType: string = "video/mp4",
    metadata?: { title?: string; description?: string; tags?: string[] }
  ): Promise<ContentModerationResult> {
    const t0 = Date.now();
    const MAX_RETRIES = 4;
    const BACKOFF_BASE_MS = 3000;
    const GEMINI_TIMEOUT_MS = 120_000; // 120s — sized for videos up to 15 minutes

    let lastError: any = null;

    for (let attempt = 0; attempt < MAX_RETRIES; attempt++) {
      try {
        const model = this.vertexAI.getGenerativeModel({
          model: PIPELINE_CONFIG.GEMINI_MODELS?.moderation || "gemini-2.5-flash",
          systemInstruction: MODERATION_SYSTEM_PROMPT,
          generationConfig: {
            responseMimeType: "application/json",
            temperature: 0.1, // Low temperature for consistent moderation decisions
          },
        });

        // Send file via GCS URI — Vertex AI reads from GCS directly (zero-copy)
        const result = await Promise.race([
          model.generateContent({
            contents: [
              {
                role: "user",
                parts: [
                  {
                    fileData: {
                      mimeType,
                      fileUri: gcsUri,
                    },
                  },
                  {
                    text: `Analyze this content following the moderation pipeline. STEP 0 FIRST: Detect the primary spoken language and set detectedLanguage (e.g. 'en', 'es', 'hi', 'fr', 'te', etc.). Then proceed through STEP 1–4 (Topic & Category → Intent → Risk → Decision). Focus on audio/speech, visual frames, and video metadata (title, description, tags) across all languages. Do NOT evaluate factual truth. Return your analysis as JSON.${
                      (metadata?.title || metadata?.description || (metadata?.tags && metadata.tags.length > 0))
                        ? `\n\n--- VIDEO METADATA TO MODERATE (TITLE, DESCRIPTION, TAGS) ---\nTITLE: ${JSON.stringify(metadata.title || "")}\nDESCRIPTION: ${JSON.stringify(metadata.description || "")}\nTAGS: ${JSON.stringify(metadata.tags || [])}\n--- END VIDEO METADATA ---\nNote: Check BOTH the media (audio track, visuals) AND the metadata (title, description, tags) for Community Guidelines violations across all languages.`
                        : ""
                    }`,
                  },
                ],
              },
            ],
          }),
          new Promise<never>((_, reject) =>
            setTimeout(() => reject(new Error("MODERATION_TIMEOUT")), GEMINI_TIMEOUT_MS)
          ),
        ]);

        const responseText =
          extractCandidateText(result.response.candidates?.[0]) ||
          result.response.candidates?.[0]?.content?.parts?.[0]?.text || "";

        // Parse and validate response
        let parsedObj: any;
        try {
          parsedObj = JSON.parse(responseText);
        } catch {
          console.error("[ContentModeration] Failed to parse JSON response:", responseText.substring(0, 200));
          throw new Error("Moderation response was not valid JSON.");
        }

        const parsed = ContentModerationResponseSchema.safeParse(parsedObj);
        if (!parsed.success) {
          console.warn("[ContentModeration] Schema validation failed:", parsed.error.format());
          throw new Error("Moderation response schema mismatch.");
        }

        // Normalize content category from raw output or infer from topic/intent
        const finalCategory = normalizeContentCategory(parsed.data.category, parsed.data.topic, parsed.data.intent);

        // ─── POST-PROCESSING: Apply review policy matrix ─────────────────
        const reviewDecision = this.applyReviewPolicy(parsed.data);

        const processingTimeMs = Date.now() - t0;
        console.log("[ContentModeration] Completed", {
          topic: parsed.data.topic,
          intent: parsed.data.intent,
          category: finalCategory,
          riskLevel: parsed.data.riskLevel,
          geminiApproved: parsed.data.approved,
          geminiPolicyAction: parsed.data.policyAction,
          finalApproved: reviewDecision.approved,
          finalPolicyAction: reviewDecision.policyAction,
          confidence: parsed.data.confidenceScore,
          categories: parsed.data.violationCategories,
          durationMs: processingTimeMs,
        });

        return {
          approved: reviewDecision.approved,
          topic: parsed.data.topic,
          intent: parsed.data.intent,
          policyAction: reviewDecision.policyAction,
          riskLevel: parsed.data.riskLevel,
          confidenceScore: parsed.data.confidenceScore,
          policyReason: parsed.data.policyReason,
          explanation: parsed.data.explanation,
          violationReason: parsed.data.policyReason, // Backward compat
          violationCategories: parsed.data.violationCategories,
          summary: parsed.data.summary || "Summary unavailable.",
          category: finalCategory,
          detectedLanguage: parsed.data.detectedLanguage || "en",
          processingTimeMs,
        };
      } catch (error) {
        lastError = error;
        const errorMsg = error instanceof Error ? error.message : String(error);
        console.error(`[ContentModeration] Attempt ${attempt + 1}/${MAX_RETRIES} failed:`, errorMsg);

        // Timeout = pass-through. Never reject a creator's video just because Gemini was slow.
        // The video proceeds as approved; async re-moderation can flag it later.
        if (errorMsg === "MODERATION_TIMEOUT") {
          const processingTimeMs = Date.now() - t0;
          console.warn(`[ContentModeration] Gemini timed out after ${processingTimeMs}ms — passing through as approved (async review queued)`);
          return {
            approved: true,
            topic: "unknown",
            intent: "entertainment",
            policyAction: "allow",
            riskLevel: "low",
            confidenceScore: 0,
            policyReason: "",
            explanation: "Moderation timed out — video approved pending async review.",
            violationReason: "",
            violationCategories: ["timeout_passthrough"],
            summary: "", // Never pollute user-facing video summary with internal timeout messages
            category: "Other",
            processingTimeMs,
          };
        }

        // Check if error is retryable (rate limits, gateway timeouts, transient failures)
        const isRetryable = errorMsg.includes("429") ||
                            errorMsg.includes("503") ||
                            errorMsg.includes("504") ||
                            errorMsg.toLowerCase().includes("too many requests") ||
                            errorMsg.toLowerCase().includes("resource exhausted") ||
                            errorMsg.toLowerCase().includes("resource_exhausted") ||
                            errorMsg.toLowerCase().includes("deadline_exceeded") ||
                            errorMsg.toLowerCase().includes("gateway timeout") ||
                            errorMsg.toLowerCase().includes("service unavailable") ||
                            errorMsg.toLowerCase().includes("internal server error");

        if (isRetryable && attempt < MAX_RETRIES - 1) {
          const delayMs = BACKOFF_BASE_MS * Math.pow(2, attempt);
          console.log(`[ContentModeration] Retryable error (attempt ${attempt + 1}/${MAX_RETRIES}). Retrying in ${delayMs}ms...`);
          await new Promise((resolve) => setTimeout(resolve, delayMs));
        } else if (attempt >= MAX_RETRIES - 1) {
          // All retries exhausted — pass through as approved rather than rejecting
          console.warn(`[ContentModeration] All ${MAX_RETRIES} retries exhausted — passing through as approved`);
          return {
            approved: true,
            topic: "unknown",
            intent: "entertainment",
            policyAction: "allow",
            riskLevel: "low",
            confidenceScore: 0,
            policyReason: "",
            explanation: "Moderation could not complete — video approved pending async review.",
            violationReason: "",
            violationCategories: ["retry_exhausted_passthrough"],
            summary: "", // Never pollute user-facing video summary with retry error messages
            category: "Other",
            processingTimeMs: Date.now() - t0,
          };
        } else {
          throw error;
        }
      }
    }

    throw lastError || new Error("Moderation failed after maximum retries.");
  }

  /**
   * Apply confidence/intent-based review policy to Gemini's raw output.
   *
   * This post-processing layer catches false positives by routing uncertain
   * rejections to manual review instead of auto-rejecting.
   *
   * Decision matrix:
   * ┌─────────────────────────┬──────────────────┬────────────────┐
   * │ Intent                  │ Confidence       │ Action         │
   * ├─────────────────────────┼──────────────────┼────────────────┤
   * │ Journalistic/Educational│ < 0.75           │ Manual Review  │
   * │ Promotional             │ ≥ 0.80           │ Auto Reject    │
   * │ Instructional Harmful   │ ≥ 0.80           │ Auto Reject    │
   * │ Any                     │ 0.50–0.80 mixed  │ Manual Review  │
   * │ Any (approved)          │ any              │ Allow          │
   * └─────────────────────────┴──────────────────┴────────────────┘
   */
  private applyReviewPolicy(raw: GeminiModerationOutput): { approved: boolean; policyAction: string } {
    // ─── 0. Contradiction Resolution & True Safety Guard ──────────────
    // If risk level is safe, or if there are zero violation categories AND the policy reason
    // explicitly states there are no violations / clean delivery / family-friendly / healthy marriage comedy,
    // this is a clear false-positive rejection by the LLM or boolean schema inversion.
    const hasZeroViolations = !raw.violationCategories || raw.violationCategories.length === 0;
    const isExplicitlySafe = raw.riskLevel === "safe" || (hasZeroViolations && raw.riskLevel !== "critical" && raw.riskLevel !== "high");

    const reasonIndicatesClean =
      /without any violations|no violations?|clean delivery|family-friendly|appropriate for family|healthy marriage/i.test(
        `${raw.policyReason || ""} ${raw.explanation || ""}`
      );

    if (isExplicitlySafe && (reasonIndicatesClean || raw.policyAction === "allow" || hasZeroViolations)) {
      console.log("[ContentModeration] Clean/Safe content verified — approving without false positive rejection", {
        topic: raw.topic,
        intent: raw.intent,
        riskLevel: raw.riskLevel,
        policyReason: raw.policyReason,
      });
      return { approved: true, policyAction: "allow" };
    }

    // ─── 1. If Gemini itself requested manual review ───────────────────
    if (raw.policyAction === "manual_review") {
      console.log("[ContentModeration] Gemini flagged for manual review", {
        topic: raw.topic,
        intent: raw.intent,
        confidence: raw.confidenceScore,
      });
      return { approved: false, policyAction: "manual_review" };
    }

    // ─── 2. If Gemini explicitly said allow ───────────────────────────
    if (raw.policyAction === "allow" && (hasZeroViolations || raw.riskLevel !== "critical")) {
      return { approved: true, policyAction: "allow" };
    }

    // ─── 3. Evaluate Rejections ───────────────────────────────────────
    // Only treat as rejection if policyAction is explicitly "reject" OR (approved is false AND policyAction is NOT "allow")
    const isGeminiReject = raw.policyAction === "reject" || (!raw.approved && raw.policyAction !== "allow");

    if (isGeminiReject) {
      // Must have actual violation categories or high risk to auto-reject
      const hasRealViolations = (raw.violationCategories || []).length > 0;

      // High-confidence rejection on harmful intent with actual violations
      if (HARMFUL_INTENTS.has(raw.intent) && raw.confidenceScore >= 0.80) {
        return { approved: false, policyAction: "reject" };
      }

      // Rejection on journalistic/educational/entertainment/satire intent → route to manual_review if no critical risk
      if (
        JOURNALISTIC_INTENTS.has(raw.intent) ||
        raw.intent === "entertainment" ||
        raw.intent === "satire" ||
        raw.intent === "personal_experience"
      ) {
        if (!hasRealViolations || raw.riskLevel !== "critical") {
          console.log("[ContentModeration] Override: creative/journalistic intent detected on rejection without critical risk → manual_review", {
            topic: raw.topic,
            intent: raw.intent,
            confidence: raw.confidenceScore,
            riskLevel: raw.riskLevel,
          });
          return { approved: false, policyAction: "manual_review" };
        }
      }

      // Low confidence rejection (< 0.75) or missing violation categories → manual review
      if (raw.confidenceScore < 0.75 || !hasRealViolations) {
        console.log("[ContentModeration] Override: low confidence or missing violation categories → manual_review", {
          confidence: raw.confidenceScore,
          violationCategories: raw.violationCategories,
        });
        return { approved: false, policyAction: "manual_review" };
      }

      // Default: trust the rejection
      return { approved: false, policyAction: "reject" };
    }

    // ─── 4. Default: trust approval ───────────────────────────────────
    return { approved: true, policyAction: "allow" };
  }
}

export const contentModerationService = new ContentModerationService();

// ─── Backward Compatibility Aliases ──────────────────────────────────────────
export {
  ContentModerationService as VideoModerationService,
  contentModerationService as videoModerationService,
  ContentModerationResponseSchema as VideoModerationResponseSchema,
};
