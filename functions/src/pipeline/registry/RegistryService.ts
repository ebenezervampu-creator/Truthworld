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

  // resolveTruthCheck() was removed (2026-11-20): it marked any claim that merely mentioned
  // "capital of india" or "speed of light in a vacuum" as correct, whatever value it stated.
  // Settled facts are now ruled on only by DeterministicRegistryService, which compares the
  // stated value with the reference value.
}

// Export singleton
export const registryService = new RegistryService();
