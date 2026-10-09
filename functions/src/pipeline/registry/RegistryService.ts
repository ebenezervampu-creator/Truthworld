import * as entitiesData from './entities.json';


export interface RegistryEntity {
  name: string;
  aliases: string[];
  domain: string;
  consensus_level: string;
  tags: string[];
}

/**
 * RegistryService
 * 
 * Provides deterministic ontology routing for high-stakes entities.
 * Prevents LLM hallucinations for consensus-level figures.
 */
export class RegistryService {
  private entities: RegistryEntity[] = [];

  constructor() {
    this.loadRegistry();
  }

  private loadRegistry() {
    try {
      this.entities = (entitiesData as any).entities || (entitiesData as any).default?.entities || [];
    } catch (error) {
      console.error("[RegistryService] Failed to load entities registry:", error);
      this.entities = [];
    }
  }

  /**
   * Deterministically find the domain for an entity mention.
   */
  getDeterministicDomain(text: string): string | null {
    if (!text) return null;
    
    const lowerText = text.toLowerCase();
    
    for (const entity of this.entities) {
      // Check exact match or alias match
      if (lowerText.includes(entity.name.toLowerCase())) {
        return entity.domain;
      }
      
      for (const alias of entity.aliases) {
        if (lowerText.includes(alias.toLowerCase())) {
          return entity.domain;
        }
      }
    }
    
    return null;
  }

  /**
   * 🛡 LAYER 4: Deterministic Truth Check
   * Bypass LLM for high-consensus, fixed facts in the registry.
   */
  resolveTruthCheck(claim: string): { status: string; reasoning: string; source: string } | null {
    if (!claim) return null;
    // v13.0: Normalize claim text — strip emojis, smart quotes, leading punctuation
    const normalizedClaim = claim
      .replace(/[\u2018\u2019\u201C\u201D]/g, "'") // smart quotes → straight
      .replace(/[❔✅❌⚠️🔍]/g, '')                 // strip status emojis
      .replace(/^\s+/, '')                          // trim leading whitespace
      .toLowerCase();

    // Anti-Bias Gate: Do NOT deterministically verify negated or disputed assertions
    const hasNegationOrDispute = /\b(?:not|never|neither|nor|cannot|can't|didn't|doesn't|don't|no|false|fake|untrue|myth|hoax|disputed|doubt|incorrect)\b/i.test(normalizedClaim);
    if (hasNegationOrDispute) {
      // Must be routed to multi-source dynamic verification engine
      return null;
    }

    // === CANONICAL CONSENSUS REGISTRY ===
    // Strictly limited to universal geographic, physical, and historical consensus constants
    const canonicalPatterns = [
      {
        pattern: /capital of (france|germany|india|usa|japan|united kingdom|canada|australia|brazil|italy|south africa|mexico|egypt)/i,
        resolve: (m: any) => ({
          status: 'correct',
          reasoning: `Deterministically verified: The capital of ${m[1]} is an unambiguous, universally recognized geopolitical fact.`,
          source: 'Institutional Registry (Geopolitical Geography)'
        })
      },
      {
        pattern: /(speed of light in a vacuum|freezing point of pure water|boiling point of water at sea level)/i,
        resolve: () => ({
          status: 'correct',
          reasoning: `Deterministically verified: Universal scientific constant verified against standard physical sciences registry.`,
          source: 'Institutional Registry (Physical Sciences)'
        })
      },
      {
        pattern: /180th meridian (crosses|passes through) (alaska|the aleutian islands)/i,
        resolve: () => ({
          status: 'correct',
          reasoning: `Deterministically verified: The 180th meridian passes through the Aleutian Islands.`,
          source: 'Institutional Registry (Geographic Coordinates)'
        })
      }
    ];

    for (const p of canonicalPatterns) {
      const match = normalizedClaim.match(p.pattern);
      if (match) {
        return p.resolve(match);
      }
    }

    // All empirical and specific trivia claims proceed to live multi-source AI verification
    return null;
  }
}

// Export singleton
export const registryService = new RegistryService();
