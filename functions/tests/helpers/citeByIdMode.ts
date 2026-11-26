import { PIPELINE_CONFIG } from "../../src/pipeline/config";

/**
 * Closed-world (Cite-by-ID) tests exercise a mode that is OFF by default in production
 * (config.ts ENFORCE_CITE_BY_ID). This turns it on for the suite and turns off the live
 * fused-grounding cascade, so the suite runs offline. Restores both afterwards.
 */
export function useCiteByIdMode(): void {
  const cfg: any = PIPELINE_CONFIG;
  let prevCite: any;
  let prevFused: any;
  beforeAll(() => {
    prevCite = cfg.CLOSED_WORLD_CITATIONS?.ENFORCE_CITE_BY_ID;
    prevFused = cfg.ENABLE_FUSED_GROUNDING;
    cfg.CLOSED_WORLD_CITATIONS = { ...(cfg.CLOSED_WORLD_CITATIONS || {}), ENFORCE_CITE_BY_ID: true };
    cfg.ENABLE_FUSED_GROUNDING = false;
  });
  afterAll(() => {
    cfg.CLOSED_WORLD_CITATIONS = { ...cfg.CLOSED_WORLD_CITATIONS, ENFORCE_CITE_BY_ID: prevCite };
    cfg.ENABLE_FUSED_GROUNDING = prevFused;
  });
}

/** Deterministic stand-in for the stance step (a model call): flagged-contradicting → CONTRADICTS, else SUPPORTS. */
export const fixedStanceModule = {
  classifySourceStances: async (_claim: string, sources: any[]) =>
    sources.map((s: any) =>
      s.claimStance
        ? s
        : { ...s, claimStance: s.isContradictory ? "CONTRADICTS" : "SUPPORTS", sourceKind: "INDEPENDENT_REPORTING" }
    ),
  isWeightedStance: (st: string) => st === "SUPPORTS" || st === "CONTRADICTS" || st === "MIXED",
  sourceOwnText: () => "",
};
