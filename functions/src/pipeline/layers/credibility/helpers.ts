/**
 * 🧹 Credibility Pipeline — Helpers
 *
 * Pure utility functions extracted from the monolith.
 * No class state, no side effects — just data transformations.
 */

import {
  ExtractedClaim,
  VerifiedClaim,
  ClaimStrength,
  ClaimNature,
  ExplainabilityResult,
} from '../../types';
import { normalizeClaimText } from '../../utils/claim-normalization';

/** Content-aware cache TTL in seconds per claim category */
export const CLAIM_TTL: Record<string, number> = {
  breaking_news: 4 * 3600,
  news:          86400,
  political:     86400 * 7,
  financial:     86400,
  statistics:    86400 * 14,
  scientific:    86400 * 90,
  historical:    86400 * 180,
  education:     86400 * 60,
  default:       86400 * 30,
};

/** Alert threshold: alert if cache hit rate drops below this */
export const MIN_HIT_RATE = 0.30;

export function categoriseClaim(text: string, category?: string): string {
  const validCategories = new Set(['breaking_news', 'political', 'financial', 'news', 'scientific', 'historical', 'education', 'statistics', 'default']);
  if (category && validCategories.has(category)) {
    return category;
  }
  
  const t = text.toLowerCase();
  
  // Breaking News (English, Spanish, Portuguese, French, German)
  if (/\b(breaking|just (announced|reported)|hours ago|minutes ago|live|última hora|urgente|en vivo|ao vivo|dernière minute|en direct|eilmeldung|dringend)\b/.test(t)) return 'breaking_news';
  
  // Political (English, Spanish, Portuguese, French, German)
  if (/\b(election|vote|candidate|campaign|poll|government|policy|legislation|congress|parliament|voto|votación|votacao|elección|eleicao|candidato|campaña|campanha|gobierno|governo|política|politica|congreso|parlamento|élection|gouvernement|congrès|parlement|président|ministre|wahl|stimmen|kandidat|kampagne|regierung|politik|kongress)\b/.test(t)) return 'political';
  
  // Financial (English, Spanish, Portuguese, French, German)
  if (/\b(stock|market|economy|gdp|inflation|revenue|profit|earnings|crypto|bitcoin|bolsa|mercado|economía|economia|inflación|inflacao|ingreso|receita|ganancia|lucro|cripto|finanzas|financas|inversión|investimento|banco|dólar|dolar|bourse|marché|inflation|revenu|banque|börse|wirtschaft|umsatz|gewinn|investition)\b/.test(t)) return 'financial';
  
  // News (English, Spanish, Portuguese, French, German)
  if (/\b(today|yesterday|this week|this month|recently|reported|announced|hoy|ayer|esta semana|hoje|ontem|esta semana|aujourd'hui|hier|cette semaine|heute|gestern|diese woche)\b/.test(t)) return 'news';
  
  // Scientific (English, Spanish, Portuguese, French, German)
  if (/\b(study|research|published|journal|peer.?review|experiment|hypothesis|clinical|trial|estudio|pesquisa|investigación|investigacao|publicado|revista|experimento|hipótesis|hipotese|clínico|clinico|científico|cientifico|ciencia|ciência|laboratorio|física|fisica|química|quimica|biología|biologia|étude|recherche|publié|revue|expérience|hypothèse|clinique|scientifique|laboratoire|physique|chimie|studie|forschung|veröffentlicht|klinisch|wissenschaftlich|wissenschaft|labor|physik|chemie)\b/.test(t)) return 'scientific';
  
  // Education (English, Spanish, Portuguese, French, German)
  if (/\b(teaches|education|curriculum|lesson|learning|textbook|theory of|enseña|educación|educação|currículo|lección|lição|aprendizagem|aprendizaje|apprendre|unterricht|bildung|lehrt)\b/.test(t)) return 'education';
  
  // Statistics
  if (/\b(%|million|billion|trillion|rate|ratio|percent|statistics|data shows|millón|bilón|milhão|bilhão|pourcent|prozent|statistische)\b/.test(t)) return 'statistics';
  
  // Historical
  if (/\b(ancient|century|history|historical|era|dynasty|founded in|established in|\d{3,4}\s?(ad|bc|ce|bce)|antiguo|siglo|historia|histórico|antigo|século|historique|fondé|fondée|jahrhundert|geschichte|historisch|gegründet)\b/.test(t)) return 'historical';
  
  return 'default';
}

/**
 * Classify claims by strength and rank by importance.
 */
export function classifyAndRank(claims: ExtractedClaim[]): Array<ExtractedClaim & { claimStrength: ClaimStrength; importance: number }> {
  return claims
    .map((claim) => {
      const text  = claim.text.toLowerCase();
      let strength: ClaimStrength = "moderate";

      if (text.includes("study") || text.includes("research") || text.includes("data") || text.includes("%")) {
        strength = "strong";
      } else if (text.includes("proven") || text.includes("confirmed") || text.includes("showed")) {
        strength = "absolute";
      } else if (text.includes("think") || text.includes("believe") || text.includes("feel") || text.includes("i think")) {
        strength = "hedged";
      }

      let importance = 0.5;
      if (claim.nature === ClaimNature.VERIFIABLE_FACT || claim.nature === ClaimNature.ESTIMATION) importance += 0.3;
      if (claim.nature === ClaimNature.BELIEF) importance += 0.1;
      if (strength === "strong")     importance += 0.2;
      if (strength === "absolute")   importance += 0.15;
      if (claim.confidence > 0.8)    importance += 0.1;
      if (strength === "hedged")     importance -= 0.3;

      return { ...claim, claimStrength: strength, importance: Math.min(1, Math.max(0, importance)) };
    })
    .sort((a, b) => b.importance - a.importance);
}

/**
 * Build explainability layer from verified claims.
 */
export function buildExplainability(verified: VerifiedClaim[]): ExplainabilityResult[] {
  return verified.map((claim, idx) => {
    const severityLabels: Record<string, string> = {
      low: "Minor error / Inaccuracy",
      medium: "Misleading context",
      high: "Factually false",
      extreme: "Dangerous fabrication"
    };

    const clinicalLabels: Record<string, { label: string; icon: string }> = {
      correct:                    { label: "Correct", icon: "✅" },
      mostly_correct:             { label: "Mostly Correct", icon: "🟢" },
      incorrect:                  { label: "Incorrect", icon: "❌" },
      outdated:                   { label: "Outdated", icon: "⏳" },
      unsupported:                { label: "Unsupported", icon: "🔍" },
      needs_context:              { label: "Needs Context", icon: "📎" },
      opinion:                    { label: "Opinion", icon: "💭" },
      anecdotal_experience:       { label: "Personal Experience", icon: "👤" },
      value_judgment:             { label: "Value Judgment", icon: "⚖️" },
      preference_statement:        { label: "Preference", icon: "❤️" },
      unverifiable_personal_claim: { label: "Personal Account", icon: "🗣️" },
      doctrinal_unverifiable:     { label: "Doctrinal Statement", icon: "🕊" },
      historical_tradition:       { label: "Scriptural Tradition", icon: "🏛" },
      historical_consensus_denial: { label: "Historical Reality Failure", icon: "❌" },
      incorrect_citation:         { label: "Incorrect Source Citation", icon: "📜" },
      contested_interpretation:    { label: "Contested Interpretation", icon: "⚖️" },
      unverifiable:               { label: "Unverifiable", icon: "❔" }
    };

    const mapped = clinicalLabels[claim.status] || { label: claim.status, icon: "❔" };

    return {
      claimId:        claim.claimId ?? `claim_${idx}`,
      claim:          `${mapped.icon} ${claim.text}`,
      status:         claim.status,
      nature:         claim.nature,
      framing:        claim.framing,
      evidenceLevel:  claim.evidenceLevel,
      ontology:       claim.nature as any,
      severity:       claim.severity,
      severityLabel:  claim.severity ? severityLabels[claim.severity] : undefined,
      whyWrong:       ['incorrect', 'historical_consensus_denial', 'incorrect_citation'].includes(claim.status) ? claim.reasoning : undefined,
      correction:     ['incorrect', 'historical_consensus_denial', 'incorrect_citation'].includes(claim.status)
        ? `Correction: ${claim.reasoning}`
        : undefined,
      sources:        claim.richSources && claim.richSources.length > 0
        ? claim.richSources.map(rs => ({
            title:          rs.title,
            url:            rs.url,
            snippet:        rs.snippet || "",
            relevanceScore: 0.9,
            tier:           rs.tier,
            provenance:     rs.snippet
          }))
        : (claim.sources ?? []).map((s: string) => ({
            title:          s,
            url:            s.startsWith("http") ? s : undefined,
            snippet:        "",
            relevanceScore: 0.8,
          })),
      timestampStart: claim.start ?? 0,
      timestampEnd:   claim.end   ?? 0,
      confidence:     claim.verificationConfidence ?? claim.confidence ?? 0.5,
    };
  });
}

const STOPWORDS = new Set(['the', 'a', 'an', 'is', 'are', 'was', 'were', 'in', 'on', 'at', 'to', 'for', 'of', 'and', 'or', 'but', 'that', 'this', 'it', 'its', 'with', 'from', 'by', 'as', 'has', 'had', 'have', 'not', 'been', 'be', 'can', 'will', 'would', 'could', 'should']);

/**
 * v17.0: Token-level semantic claim deduplication.
 * Uses Jaccard similarity on normalized word tokens instead of simple substring matching.
 * This catches semantic duplicates like "India invented chess" vs "Chess was invented in India"
 * without the latency/cost of embedding-based approaches.
 * 
 * Similarity threshold: 0.65 (empirically tuned — high enough to avoid false positives,
 * low enough to catch word-reordered duplicates).
 */
export function deduplicateClaims(claims: any[]): any[] {
  const SIMILARITY_THRESHOLD = 0.65;
  const kept: { tokens: Set<string>; claim: any }[] = [];
  
  for (const claim of claims) {
    const text = (claim.text || '');
    const normalized = normalizeClaimText(text);
    
    // Tokenize and remove very short/common words
    const tokens = new Set<string>(
      normalized.split(' ').filter((w: string) => w.length > 2 && !STOPWORDS.has(w))
    );
    
    if (tokens.size === 0) continue;
    
    // Check Jaccard similarity against all kept claims
    let isDuplicate = false;
    for (const existing of kept) {
      const intersection = new Set<string>([...tokens].filter((t: string) => existing.tokens.has(t)));
      const union = new Set<string>([...tokens, ...existing.tokens]);
      const similarity = union.size > 0 ? intersection.size / union.size : 0;
      
      if (similarity >= SIMILARITY_THRESHOLD) {
        isDuplicate = true;
        // Keep the higher-importance version
        if ((claim.importance || 0) > (existing.claim.importance || 0)) {
          existing.claim = claim;
          existing.tokens = tokens;
        }
        break;
      }
    }
    
    if (!isDuplicate) {
      kept.push({ tokens, claim });
    }
  }

  return kept.map(k => k.claim);
}
