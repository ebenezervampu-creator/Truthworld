/**
 * 🎯 CONTENT INTENT DETECTOR (v4.3)
 *
 * Classifies the **intent** of video content before scoring.
 * This prevents promotional/opinion/entertainment content from being
 * unfairly penalized by the factual verification pipeline.
 *
 * Architecture: Fast keyword + structural analysis (no LLM call needed).
 */

import { Utterance } from "../types";

// ─── Intent Types ─────────────────────────────────────────────────────────────

export type ContentIntentType =
  | "factual"         // Hard news, documentary, investigative
  | "promotional"     // Product launch, demo, review, marketing
  | "editorial"       // Opinion piece, commentary, analysis
  | "educational"     // Tutorial, lecture, how-to
  | "entertainment"   // Comedy, vlog, lifestyle
  | "testimonial"     // Personal testimony, experience report
  | "commentary";      // Legal inquiry, political analysis, Q&A

export interface ContentIntent {
  primaryIntent: ContentIntentType;
  intentScores: Partial<Record<ContentIntentType, number>>; // Weighted multi-intent
  confidence: number;           // 0.0-1.0
  subjectiveRatio: number;      // % of text that is subjective
  promotionalSignals: string[]; // matched keywords for audit trail
  ratingFloor: number;          // minimum threshold based on intent
  ratingCeiling: number;        // maximum threshold based on intent
  genre?: string;               // v5.0: detected content genre
}

// ─── Signal Dictionaries ──────────────────────────────────────────────────────

/** Subjective "Hype" phrases (used for style, don't necessarily mean promotional) */
const HYPE_PHRASES: string[] = [
  "shocking", "unbelievable", "historic", "massive", "huge", "staggering",
  "insane", "unthinkable", "mind-blowing", "crazy", "incredible", "legendary",
  "epic", "next level", "game changer", "revolutionary", "groundbreaking",
];

/** Subjective adjectives that should NOT be treated as factual claims */
const SUBJECTIVE_PHRASES: string[] = [
  ...HYPE_PHRASES,
  "amazing", "beautiful", "best", "awesome", "stunning",
  "killer", "sick", "fire", "goated", "top tier", "world class",
  "cutting edge", "jaw-dropping", "phenomenal", "extraordinary",
  "perfect", "flawless", "superior", "ultimate", "absolute best",
  "hands down", "no doubt", "without question", "love it", "love this",
  "hate it", "terrible", "worst", "garbage", "trash", "horrible",
  "disgusting", "overrated", "underrated",
];

/** Promotional / marketing signal phrases (Commercial CTAs across languages) */
const PROMOTIONAL_SIGNALS: string[] = [
  "buy now", "limited offer", "sign up", "best product",
  "discount", "pricing", "free trial", "check it out", "check this out",
  "you need to", "you have to", "go try", "try it", "try this",
  "link in", "link below", "use my code", "use code", "promo code",
  "coupon", "affiliate link", "sponsored by", "brand partnership", "brand collaboration",
  "brand deal", "new product", "new tool", "new feature", "new release",
  "hit the bell", "smash the like", "like and subscribe", "comment below",
  "game changer for", "better than", "compared to",
  "alternative to", "switch to", "move to", "upgrade to",
  // Multilingual signals (Spanish, Hindi, French, German, Portuguese, Arabic)
  "comprar", "descuento", "código promocional", "enlace abajo", "suscríbete",
  "achetez", "rabais", "code promo", "lien ci-dessous", "abonnez-vous",
  "kaufen", "rabatt", "aktionscode", "abonnieren",
  "compre agora", "desconto", "código promocional", "inscreva-se",
  "खरीदें", "डिस्काउंट", "ऑफर", "प्रोमो कोड", "सब्सक्राइब", "लिंक नीचे",
  "اشتر الآن", "خصم", "رمز ترويجي", "اشترك",
];

/** Editorial / opinion signal phrases across languages */
const EDITORIAL_SIGNALS: string[] = [
  "i think", "i believe", "in my opinion", "my take", "my view",
  "i feel", "i predict", "my prediction", "my analysis",
  "here's the thing", "the real question", "let me explain",
  "controversial take", "hot take", "unpopular opinion",
  "what nobody tells you", "the truth about", "the problem with",
  "should we", "is it worth", "i personally", "from my perspective",
  "my experience",
  // Multilingual signals
  "en mi opinión", "yo creo", "pienso que", "a mi parecer", "mi punto de vista",
  "à mon avis", "je pense que", "selon moi", "mon avis",
  "meiner meinung nach", "ich denke", "ich glaube",
  "na minha opinião", "eu acho que", "no meu ponto de vista",
  "मेरे अनुसार", "मुझे लगता है", "मेरी राय", "मेरा मानना है",
  "في رأيي", "أعتقد أن", "وجهة نظري",
];

/** Educational signal phrases across languages */
const EDUCATIONAL_SIGNALS: string[] = [
  "how to", "tutorial", "step by step", "step-by-step",
  "let me show you", "in this lesson", "in this tutorial",
  "explained", "explanation", "breakdown", "deep dive",
  "beginner", "advanced", "complete guide", "ultimate guide",
  "everything you need to know", "101", "basics", "fundamentals",
  "learn", "course", "lecture", "class", "workshop",
  // Multilingual signals
  "cómo", "cómo hacer", "guía paso a paso", "aprender", "curso",
  "comment faire", "tutoriel", "guide complet", "apprendre",
  "anleitung", "schritt für schritt", "lernen", "kurs",
  "como fazer", "passo a passo", "aprenda",
  "कैसे करें", "ट्यूटोरियल", "स्टेप बाय स्टेप", "सीखें", "कक्षा",
  "كيفية", "شرح", "خطوة بخطوة", "تعلم",
];

/** Entertainment signal phrases across languages */
const ENTERTAINMENT_SIGNALS: string[] = [
  "vlog", "day in my life", "morning routine", "get ready with me",
  "challenge", "prank", "reaction", "reacting to", "storytime",
  "story time", "what happened", "you won't believe",
  "gone wrong", "gone right", "epic fail", "funny", "hilarious",
  "comedy", "skit", "parody", "roast",
  // Multilingual signals
  "comedia", "broma", "reacción", "divertido", "humor",
  "blague", "drôle", "réaction",
  "lustig", "streich", "unterhaltung",
  "comédia", "pegadinha", "engraçado",
  "कॉमेडी", "मजाक", "हंसी", "प्रैंक", "मनोरंजन",
  "مضحك", "مقلب", "ردة فعل", "كوميديا",
];

/** Testimonial signal phrases across languages */
const TESTIMONIAL_SIGNALS: string[] = [
  "it helped me", "changed my life", "my experience with",
  "my journey", "my story", "my results", "before and after",
  "i used to", "since i started", "after using", "after trying",
  "personally tested", "my honest review", "real results",
  "what happened when i", "i switched to", "transformation",
  "testimony", "i was healed", "prayer changed", "god helped",
  "miracle", "my healing journey",
  // Multilingual signals
  "mi experiencia", "mi historia", "mi testimonio", "antes y después",
  "mon expérience", "mon histoire", "avant et après",
  "meine erfahrung", "meine geschichte", "vorher und nachher",
  "minha experiência", "minha história", "antes e depois",
  "मेरा अनुभव", "मेरी कहानी", "पहले और बाद",
  "تجربتي", "قصتي", "شهادتي",
];

// ─── Floor/Ceiling Configuration ──────────────────────────────────────────────

interface IntentBounds {
  floor: number;   // Minimum threshold
  ceiling: number; // Maximum threshold
}

const INTENT_BOUNDS: Record<ContentIntentType, IntentBounds> = {
  factual:       { floor: 0,  ceiling: 100 }, // Full range — empirical news must be rigorous
  promotional:   { floor: 0,  ceiling: 90 },  // No artificial shielding of promotional marketing claims
  editorial:     { floor: 25, ceiling: 90 },  // Opinions are valid; only penalize if presented as false facts
  educational:   { floor: 0,  ceiling: 100 }, // Full range — educational content must be accurate
  entertainment: { floor: 35, ceiling: 85 },  // Low-risk creative content
  testimonial:   { floor: 25, ceiling: 85 },  // Personal experience
  commentary:    { floor: 25, ceiling: 95 },  // Critical analysis & investigative inquiry
};

// ─── Detector Class ───────────────────────────────────────────────────────────

export class ContentIntentDetector {

  /**
   * Detect the primary content intent from transcript utterances.
   * Uses fast keyword + structural analysis (no LLM call).
   */
  detectIntent(
    utterances: Utterance[],
    domainInfo?: { 
      domain?: string; 
      stance?: string; 
      isLaunchNews?: boolean;
      primaryIntent?: string;
      isSensitive?: boolean;
      detectedLanguage?: string;
    }
  ): ContentIntent {
    const fullText = utterances.map(u => u.text).join(" ").toLowerCase();
    const wordCount = fullText.split(/\s+/).length;

    // 0. Question Detection (v5.1: Critical for Political/Legal Neutrality)
    const sentences = fullText.split(/[.!?]+/).filter(s => s.trim().length > 5);
    const questionPatterns = [
        /\?$/,                          // Ends with question mark
        /^(?:what|which|should|will|can|does|is|are|how|why|when|where)\b/i, // Starts with interrogative
    ];
    let questionCount = 0;
    sentences.forEach(s => {
        const clean = s.trim();
        if (questionPatterns.some(p => p.test(clean))) questionCount++;
    });
    const questionDensity = sentences.length > 0 ? questionCount / sentences.length : 0;

    // 1. Count signal matches per intent
    const scores: Record<ContentIntentType, number> = {
      factual: 0,
      promotional: 0,
      editorial: 0,
      educational: 0,
      entertainment: 0,
      testimonial: 0,
      commentary: 0,
    };

    const matchedPromoSignals: string[] = [];

    // 3.0. LLM Discovery Override (v5.2: Multilingual Support)
    // If the LLM has already identified an intent, we give it massive weight 
    // to ensure non-English content (where keywords fail) is correctly classified.
    if (domainInfo?.primaryIntent && scores[domainInfo.primaryIntent as ContentIntentType] !== undefined) {
      scores[domainInfo.primaryIntent as ContentIntentType] += 12; // Decisive boost
    }

    // 3.1. Multilingual Keyword Signals
    // Evaluates matched intent signals across English and international languages
    for (const signal of PROMOTIONAL_SIGNALS) {
      if (fullText.includes(signal)) {
        scores.promotional += 1;
        matchedPromoSignals.push(signal);
      }
    }

    for (const signal of EDITORIAL_SIGNALS) {
      if (fullText.includes(signal)) {
        scores.editorial += 1;
      }
    }

    for (const signal of EDUCATIONAL_SIGNALS) {
      if (fullText.includes(signal)) {
        scores.educational += 1;
      }
    }

    for (const signal of ENTERTAINMENT_SIGNALS) {
      if (fullText.includes(signal)) {
        scores.entertainment += 1;
      }
    }

    for (const signal of TESTIMONIAL_SIGNALS) {
      if (fullText.includes(signal)) {
        scores.testimonial += 1;
      }
    }

    // 🚀 News / Geopolitical signals (multilingual)
    const NEWS_SIGNALS = [
      "breaking", "report", "official", "confirmed", "denied", "statement", "press release", "coverage", "update", "news",
      "noticias", "última hora", "comunicado", "nouvelles", "nachrichten", "ताज़ा ख़बर", "समाचार", "أخبار", "notícias"
    ];
    for (const signal of NEWS_SIGNALS) {
      if (fullText.includes(signal)) {
        scores.factual += 2; // Strong boost for news keywords
      }
    }


    // 2. Boost from domain detection
    if (domainInfo?.isLaunchNews) {
      scores.promotional += 3; // Strong boost
    }

    // 3. Subjectivity ratio
    // v5.1: Distinguish between "Style Hype" and "Factual Subjectivity"
    let subjectiveHits = 0;
    const coreSubjective = SUBJECTIVE_PHRASES.filter(p => !HYPE_PHRASES.includes(p));
    
    for (const phrase of coreSubjective) {
      const regex = new RegExp(`\\b${phrase.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\b`, 'gi');
      const matches = fullText.match(regex);
      if (matches) subjectiveHits += matches.length;
    }
    const subjectiveRatio = Math.min(1, subjectiveHits / Math.max(1, wordCount / 20));

    // High subjectivity boosts promo/editorial, but "Hype" (stunning, massive) 
    // is now excluded from this calculation to preserve News neutrality.
    if (subjectiveRatio > 0.3) {
      scores.promotional += 2;
      scores.editorial += 1;
    }

    // 3.5. Question Dominant Override (Commentary Path)
    if (questionDensity > 0.35) {
      scores.commentary += 5; // Direct route to commentary
      scores.factual += 2;    // Questions about facts are often serious
    }


    // 4. Baseline distribution — balanced and non-punitive across languages
    const nonFactualTotal = scores.promotional + scores.editorial +
                            scores.educational + scores.entertainment + scores.testimonial;
    if (nonFactualTotal < 2) {
      // Balanced baseline prior — does not force non-English creative/vlog content into 0-floor factual
      scores.factual = 3;
      scores.educational = 2;
      scores.editorial = 2;
      scores.entertainment = 2;
    } else {
      scores.factual = Math.max(0, 3 - nonFactualTotal * 0.5);
    }

    // 5. Normalize to weighted probabilities
    const totalSignals = Object.values(scores).reduce((a, b) => a + b, 0) || 1;
    const intentScores: Partial<Record<ContentIntentType, number>> = {};
    for (const [intent, score] of Object.entries(scores)) {
      if (score > 0) {
        intentScores[intent as ContentIntentType] = Number((score / totalSignals).toFixed(3));
      }
    }

    // 6. Determine primary intent
    const sorted = Object.entries(scores).sort((a, b) => b[1] - a[1]);
    const primaryIntent = sorted[0][0] as ContentIntentType;
    const primaryScore = sorted[0][1];

    // 7. Confidence = how dominant the primary intent is
    const confidence = Math.min(1, primaryScore / Math.max(1, totalSignals) + 0.2);

    // 8. Get bounds — if confidence is too low, fall back to factual (general scoring)
    let effectiveIntent = primaryIntent;
    if (confidence < 0.35 && primaryIntent !== 'factual') {
      effectiveIntent = 'factual'; // Fallback: don't lock into wrong mode
    }
    const bounds = INTENT_BOUNDS[effectiveIntent];

    return {
      primaryIntent: effectiveIntent,
      intentScores,
      confidence: Number(confidence.toFixed(3)),
      subjectiveRatio: Number(subjectiveRatio.toFixed(3)),
      promotionalSignals: matchedPromoSignals,
      ratingFloor: bounds.floor,
      ratingCeiling: bounds.ceiling,
      genre: this.detectGenre(fullText), // v5.0: Genre-aware intent
    };
  }

  /**
   * Detect content genre based on keyword clusters (v5.0)
   */
  private detectGenre(text: string): string {
    const genres = {
      tutorial: /\b(?:how to|tutorial|step by step|lesson|guide|walkthrough|learn|demo|demonstration)\b/i,
      news:     /\b(?:breaking|news|report|update|latest|headline|official|press release|coverage)\b/i,
      podcast:  /\b(?:podcast|episode|interview|guest|host|discussion|conversation|talk show)\b/i,
      vlog:     /\b(?:vlog|day in my life|grwm|lifestyle|morning routine|personal update|travel vlog)\b/i,
      review:   /\b(?:review|unboxing|honest thoughts|my opinion|verdict|rating|worth it|buy or not)\b/i,
    };

    for (const [genre, pattern] of Object.entries(genres)) {
      if (pattern.test(text)) return genre;
    }

    return "general";
  }

  /**
   * Check if the rating floor should be bypassed due to detected incorrect claims.
   * If a promo video makes provably false claims (e.g., "FDA approved" when it's not),
   * the floor protection is removed.
   */
  shouldBypassFloor(
    contentIntent: ContentIntent,
    stats: { incorrect: number; unsupported: number }
  ): boolean {
    // Any confirmed incorrect claim disables the floor
    if (stats.incorrect > 0) return true;

    // For factual/educational, floor is already 0 — no bypass needed
    if (contentIntent.primaryIntent === 'factual' || contentIntent.primaryIntent === 'educational') {
      return false;
    }

    return false;
  }

  /**
   * Get the public-facing badge label for a content intent.
   */
  getPublicBadge(intent: ContentIntentType): string {
    const badges: Record<ContentIntentType, string> = {
      factual: "News / Claims",
      promotional: "Product Showcase",
      editorial: "Opinion",
      educational: "Educational",
      entertainment: "Entertainment",
      testimonial: "Personal Experience",
      commentary: "Legal / Political Inquiry",
    };
    return badges[intent] || "General";
  }
}

// ─── Singleton Export ─────────────────────────────────────────────────────────

export const contentIntentDetector = new ContentIntentDetector();

// ─── Verifiable Predicate Detection ───────────────────────────────────────────

const POLITICAL_ACTIONS = ["passed", "vetoed", "signed", "introduced", "approved", "rejected", "voted", "named", "appointed", "successor"];
const MILITARY_ACTIONS = ["struck", "attacked", "launched", "retaliated", "deployed", "invaded", "withdrew", "unleashed", "fired"];
const DIPLOMATIC_ACTIONS = ["confirmed", "denied", "announced", "recognized", "condemned", "sanctioned", "called for"];
const ECONOMIC_ACTIONS = ["surged", "fell", "rose", "declined", "imposed tariffs", "defaulted", "shutdown"];
const CASUALTY_ACTIONS = ["died", "killed", "injured", "wounded", "missing", "dead", "death", "casualty", "eliminated"];
const INCIDENT_ACTIONS = ["crashed", "exploded", "collapsed", "burned", "sank", "strike", "operation"];
const PRODUCT_ACTIONS = ["launched", "released", "announced", "introduced", "unveiled", "deployed", "shipped", "rolled out", "updated", "supports", "features", "available"];

/**
 * Patterns that indicate a claim contains a factually checkable predicate.
 * v5.1: Expanded to include Geopolitical, News, and Event factuality.
 */
const VERIFIABLE_PREDICATE_PATTERNS: RegExp[] = [
  // 🏛 Geopolitical & News Actions (v5.1)
  new RegExp(`\\b(?:${[...POLITICAL_ACTIONS, ...DIPLOMATIC_ACTIONS].join('|')})\\b`, 'i'),
  // ⚔️ Military & Incident Actions (v5.1)
  new RegExp(`\\b(?:${[...MILITARY_ACTIONS, ...INCIDENT_ACTIONS].join('|')})\\b`, 'i'),
  // 📉 Economic & Casualty Actions (v5.1)
  new RegExp(`\\b(?:${[...ECONOMIC_ACTIONS, ...CASUALTY_ACTIONS].join('|')})\\b`, 'i'),
  // 📱 Product/SaaS Launches (v5.1)
  new RegExp(`\\b(?:${PRODUCT_ACTIONS.join('|')})\\b`, 'i'),

  // 📜 Historical & Cultural Innovations (v12.0 Hardening)
  /\b(?:invented|discovered|founded|established|created|pioneered|built|developed|designed|authored|composed|mapped|calculated|proven|proven by|recorded in)\b/i,
  /\b(?:dynasty|empire|civilization|period|era|century|bce|ace|ancient)\b/i,
  /\b(?:originated in|first seen in|earliest record|ancestors of)\b/i,

  // 🧪 Scientific & Empirical Facts (v12.0 Hardening)
  /\b(?:consists of|contains|made of|boils at|freezes at|weighs|measures|distance|speed|velocity|acceleration|gravity|orbit|planet|element|molecule|atom|dna|species|habitat)\b/i,
  /\b(?:study found|research shows|confirmed by|data indicates|statistics prove)\b/i,

  // 📦 Product/Company actions: "X launched/released/announced Y"
  /\b(?:launched|released|announced|introduced|unveiled|deployed|shipped|rolled out)\b/i,
  // 🛠 Capability claims: "can generate/build/create/support/handle"
  /\b(?:can|could|lets you|allows you to|enables)\s+(?:generate|build|create|make|produce|design|support|handle|process|export|import|convert)\b/i,
  // 🔢 Measurable features: numbers, prices, specs
  /\b(?:supports?|offers?|includes?|provides?|features?)\s+\d+/i,
  /\$\d+/,
  /\b\d+(?:\.\d+)?\s*(?:languages?|users?|countries|models?|tokens?|gb|mb|tb|fps|ms|seconds?)\b/i,
  // 🏗 Organizational facts: "built by", "created by", "developed by"
  /\b(?:built|created|developed|designed|made|founded|owned|acquired)\b\s+(?:in|by|during)\b/i,
  // 🔍 Existence claims: "X is a/an Y" (entity definition)
  /\b(?:is|are|was|were)\s+(?:a|an|the)\s+(?:tool|product|platform|service|company|feature|api|model|framework|app|application|extension|plugin|library|city|country|nation|continent|planet|star|galaxy|animal|plant|organism|element|isotope)\b/i,
  // 🤝 Partnership/Integration: "works with", "integrates with", "compatible with"
  /\b(?:works?|integrates?|compatible|partnered?)\s+with\b/i,
  // 🌍 Availability: "available on/in/for", "open source"
  /\b(?:available|accessible)\s+(?:on|in|for|at|via)\b/i,
  /\bopen[- ]?source\b/i,
  // 📅 Temporal facts: "founded in", "since 2020", "as of"
  /\b(?:founded|started|established|since|as of)\s+(?:in\s+)?\d{4}\b/i,
  /\b(?:during|throughout|following|preceding)\b\s+(?:the|a)\b\s+\d{4}\b/i,
];

/**
 * Checks if a claim text contains a verifiable factual predicate.
 * A verifiable predicate is an entity+action pattern that can be checked
 * against real-world data (web search, official sources, databases).
 *
 * This function exists to prevent the subjective classifier from
 * incorrectly filtering out claims that contain both promotional language
 * AND factually checkable assertions.
 *
 * @example
 * containsVerifiablePredicate("Anthropic launched Claude Design") → true
 * containsVerifiablePredicate("This tool is amazing") → false
 * containsVerifiablePredicate("Claude Design can generate slides from a prompt") → true
 * containsVerifiablePredicate("You need to check this out") → false
 */
export function containsVerifiablePredicate(claimText: string): boolean {
  return VERIFIABLE_PREDICATE_PATTERNS.some(pattern => pattern.test(claimText));
}

// ─── Utility: Subjective phrase filter for claim extraction ───────────────────

/**
 * Checks if a claim text is purely subjective (no factual content).
 * Used by the extraction layer to reclassify subjective claims as opinions.
 *
 * CRITICAL FIX (v5.0): This function now checks for verifiable predicates
 * BEFORE classifying as subjective. A claim like "Anthropic just launched
 * Claude Design" contains promotional language ("just launched") but also
 * contains a verifiable factual predicate (entity + launch action).
 * Such claims MUST NOT be classified as subjective.
 */
export function isSubjectiveClaim(claimText: string, isVerifiableEvent: boolean = false): boolean {
  const lower = claimText.toLowerCase().trim();

  // ═══ CRITICAL GATE (v5.2): If LLM flagged as verifiable event, bypass subjectivity
  if (isVerifiableEvent || containsVerifiablePredicate(claimText)) {
    return false;
  }

  // Check if the entire claim is a subjective phrase
  for (const phrase of SUBJECTIVE_PHRASES) {
    if (lower === phrase) return true;
  }

  // Check if claim is primarily subjective adjectives with no factual content
  const words = lower.split(/\s+/);
  let subjectiveWordCount = 0;
  for (const word of words) {
    if (SUBJECTIVE_PHRASES.includes(word)) subjectiveWordCount++;
  }

  // If > 50% of words are subjective adjectives, it's a subjective claim
  if (words.length <= 5 && subjectiveWordCount >= 2) return true;
  if (words.length > 5 && subjectiveWordCount / words.length > 0.4) return true;

  // Check for call-to-action patterns (not factual claims)
  const ctaPatterns = [
    /^you (need|have|should|must) to/,
    /^check (it |this )?out/,
    /^go (try|check|see|watch)/,
    /^subscribe/,
    /^hit the/,
    /^smash the/,
    /^like and subscribe/,
    /^let me know/,
    /^comment below/,
    /^link (in|below)/,
  ];

  for (const pattern of ctaPatterns) {
    if (pattern.test(lower)) return true;
  }

  return false;
}

/** Re-export for use by extraction layer */
export { SUBJECTIVE_PHRASES, VERIFIABLE_PREDICATE_PATTERNS };
