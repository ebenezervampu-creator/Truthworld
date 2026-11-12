import * as admin from "firebase-admin";
import { logger } from "../utils/logger";
import { sanitizeReportPayloadForClosedWorld } from "./urlVerificationService";

export interface AnalysisManifest {
  analysisId: string;
  currentVersion: number;
  versions: number[];
  latestVerifiedAt: string;
  latestSchema: string;
  latestModel: string;
  createdAt: string;
  updatedAt: string;
}

export interface AnalysisRepository {
  saveAnalysis(
    analysisId: string,
    category: "factChecks" | "final_outputs",
    data: any
  ): Promise<{ version: number; path: string }>;

  loadAnalysis(
    analysisId: string,
    category: "factChecks" | "final_outputs",
    version?: number
  ): Promise<any | null>;

  getManifest(
    analysisId: string,
    category: "factChecks" | "final_outputs"
  ): Promise<AnalysisManifest | null>;
}

/**
 * 📦 GCS Analysis Repository
 * Stores and manages immutable, versioned analysis results in Firebase Storage (Google Cloud Storage).
 * Uses optimistic concurrency via GCS object generation preconditions to avoid version races.
 */
export class GCSAnalysisRepository implements AnalysisRepository {
  async saveAnalysis(
    analysisId: string,
    category: "factChecks" | "final_outputs",
    data: any
  ): Promise<{ version: number; path: string }> {
    const sanitizedData = sanitizeReportPayloadForClosedWorld(data);
    const bucket = admin.storage().bucket();
    const manifestFile = bucket.file(`${category}/${analysisId}/manifest.json`);
    
    let attempts = 0;
    const maxAttempts = 5;
    
    while (attempts < maxAttempts) {
      attempts++;
      let currentVersion = 0;
      let versions: number[] = [];
      let createdAt = new Date().toISOString();
      let generation: number | string | undefined = undefined;
      
      try {
        const [exists] = await manifestFile.exists();
        if (exists) {
          const [metadata] = await manifestFile.getMetadata();
          generation = metadata.generation;
          
          const [content] = await manifestFile.download();
          const manifest = JSON.parse(content.toString()) as AnalysisManifest;
          currentVersion = manifest.currentVersion || 0;
          versions = manifest.versions || [];
          createdAt = manifest.createdAt || createdAt;
        }
      } catch (err) {
        logger.warn("[Repository] Error reading manifest, assuming first version", { analysisId, category, err: String(err) });
      }
      
      const nextVersion = currentVersion + 1;
      const nextVersions = [...versions, nextVersion];
      
      const manifest: AnalysisManifest = {
        analysisId,
        currentVersion: nextVersion,
        versions: nextVersions,
        latestVerifiedAt: new Date().toISOString(),
        latestSchema: "v9",
        latestModel: "Gemini 2.5 Pro",
        createdAt,
        updatedAt: new Date().toISOString()
      };
      
      const versionedPath = `${category}/${analysisId}/v${nextVersion}/full.json`;
      const latestPath = `${category}/${analysisId}/latest.json`;
      
      try {
        // Save the versioned file first (immutable, no race condition impact)
        const versionedFile = bucket.file(versionedPath);
        await versionedFile.save(JSON.stringify(sanitizedData), {
          metadata: { contentType: "application/json" }
        });
        
        // Save latest
        const latestFile = bucket.file(latestPath);
        await latestFile.save(JSON.stringify(sanitizedData), {
          metadata: { contentType: "application/json" }
        });
        
        // Save manifest using optimistic concurrency
        const saveOptions: any = {
          metadata: { contentType: "application/json" }
        };
        if (generation !== undefined) {
          saveOptions.preconditionOpts = { ifGenerationMatch: generation };
        } else {
          // If it didn't exist before, assert it still doesn't exist
          saveOptions.preconditionOpts = { ifGenerationMatch: 0 };
        }
        
        await manifestFile.save(JSON.stringify(manifest), saveOptions);
        
        logger.info("[Repository] Successfully saved versioned analysis and manifest", {
          analysisId,
          category,
          version: nextVersion,
          path: versionedPath
        });
        
        return { version: nextVersion, path: latestPath };
      } catch (err: any) {
        // Check if error is due to precondition failure (e.g. code 412)
        if (err.code === 412) {
          logger.warn("[Repository] Precondition failed, retrying manifest write", { analysisId, category, attempt: attempts });
          // Backoff briefly
          await new Promise((resolve) => setTimeout(resolve, Math.random() * 200 + 50));
          continue;
        }
        throw err;
      }
    }
    
    throw new Error(`Failed to save analysis due to persistent manifest write collisions for ${analysisId} / ${category}`);
  }

  async loadAnalysis(
    analysisId: string,
    category: "factChecks" | "final_outputs",
    version?: number
  ): Promise<any | null> {
    try {
      const bucket = admin.storage().bucket();
      const path = version
        ? `${category}/${analysisId}/v${version}/full.json`
        : `${category}/${analysisId}/latest.json`;
      
      const file = bucket.file(path);
      const [exists] = await file.exists();
      if (!exists) return null;
      
      const [content] = await file.download();
      return JSON.parse(content.toString());
    } catch (err) {
      logger.error("[Repository] Failed to load analysis from GCS", { analysisId, category, version, err: String(err) });
      return null;
    }
  }

  async getManifest(
    analysisId: string,
    category: "factChecks" | "final_outputs"
  ): Promise<AnalysisManifest | null> {
    try {
      const bucket = admin.storage().bucket();
      const file = bucket.file(`${category}/${analysisId}/manifest.json`);
      const [exists] = await file.exists();
      if (!exists) return null;
      
      const [content] = await file.download();
      return JSON.parse(content.toString()) as AnalysisManifest;
    } catch (err) {
      logger.error("[Repository] Failed to get manifest", { analysisId, category, err: String(err) });
      return null;
    }
  }
}

// Singleton Registry & Active Repository management
let activeRepository: AnalysisRepository = new GCSAnalysisRepository();

export function getAnalysisRepository(): AnalysisRepository {
  return activeRepository;
}

export function setAnalysisRepository(repository: AnalysisRepository) {
  activeRepository = repository;
}
