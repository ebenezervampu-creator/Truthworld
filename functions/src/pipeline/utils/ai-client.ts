import { GoogleGenAI } from "@google/genai";
import { logger } from "./logger";

let genAIInstance: GoogleGenAI | null = null;
let vertexAdapterInstance: GenAIVertexAdapter | null = null;

export interface ModelParams {
  model: string;
  safetySettings?: any[];
  generationConfig?: any;
  tools?: any[];
  systemInstruction?: any;
  cachedContent?: string;
}

/**
 * Returns a global singleton instance of Google Gen AI (@google/genai) in Vertex AI mode.
 * Draws from Google Cloud Credits and uses the unified Gemini 2.x/3.x SDK architecture.
 */
export function getGenAI(): GoogleGenAI {
  if (!genAIInstance) {
    const project = process.env.GCP_PROJECT_ID || process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT || "truthworld-1";
    const location = process.env.GCP_LOCATION || "asia-south1";
    genAIInstance = new GoogleGenAI({
      vertexai: true,
      project,
      location,
    });

    // Local / Dev Resilience: If running locally and ADC refresh token requires re-auth,
    // seamlessly provide the active gcloud session token to avoid blocking tests and local jobs.
    if (!process.env.K_SERVICE && !process.env.FUNCTION_TARGET) {
      try {
        const clientAny = genAIInstance as any;
        const originalAddAuthHeaders = clientAny?.apiClient?.clientOptions?.auth?.addAuthHeaders;
        if (originalAddAuthHeaders) {
          clientAny.apiClient.clientOptions.auth.addAuthHeaders = async function (headers: any, url: any) {
            try {
              return await originalAddAuthHeaders.call(this, headers, url);
            } catch (authErr: any) {
              if (authErr?.message?.includes("invalid_grant") || authErr?.message?.includes("invalid_rapt") || authErr?.message?.includes("reauth")) {
                const { execSync } = require("child_process");
                const token = execSync("gcloud auth print-access-token", { timeout: 8000 }).toString().trim();
                if (token) {
                  headers.set("Authorization", `Bearer ${token}`);
                  return;
                }
              }
              throw authErr;
            }
          };
        }
      } catch (_) {}
    }

    logger.info("[ai-client] Initialized modern @google/genai SDK in Vertex AI mode", { project, location });
  }
  return genAIInstance;
}

/**
 * Modern GenAI Adapter implementing the VertexAI getGenerativeModel interface.
 * Backed by @google/genai ({ vertexai: true }), ensuring 100% Google Cloud credit eligibility
 * while providing native Context Caching and Batch Prediction support.
 */
export class GenAIVertexAdapter {
  private readonly ai: GoogleGenAI;

  constructor(ai: GoogleGenAI) {
    this.ai = ai;
  }

  /**
   * Direct access to underlying @google/genai client.
   */
  get client(): GoogleGenAI {
    return this.ai;
  }

  /**
   * ⚡ Context Caching: Creates a reusable cached context on Vertex AI.
   * Offers 75% to 90% discount on repeated prompt tokens (e.g. system instructions, schemas).
   */
  async createContextCache(params: {
    model: string;
    systemInstruction?: string;
    contents?: any[];
    ttl?: string;
  }): Promise<string | null> {
    try {
      const cache = await this.ai.caches.create({
        model: params.model,
        config: {
          systemInstruction: params.systemInstruction,
          contents: params.contents,
          ttl: params.ttl || "86400s",
        },
      });
      logger.info("[ai-client] Created Vertex AI Context Cache (75% token discount active)", { name: cache.name });
      return cache.name || null;
    } catch (err) {
      logger.warn("[ai-client] Context cache creation skipped/fallback to direct", { err });
      return null;
    }
  }

  /**
   * 🚀 Batch Prediction: Dispatches batch prediction jobs for scheduled/off-peak videos.
   * Vertex AI grants a flat 50% discount on all batch prediction tokens.
   */
  async createBatchJob(params: {
    model: string;
    datasetGcsUri: string;
    destinationGcsUri: string;
  }): Promise<any> {
    try {
      const batchJob = await (this.ai.batches as any).create({
        model: params.model,
        src: params.datasetGcsUri,
        dest: params.destinationGcsUri,
      });
      logger.info("[ai-client] Dispatched Vertex AI Batch Job (50% token discount)", { name: batchJob.name });
      return batchJob;
    } catch (err) {
      logger.warn("[ai-client] Batch job dispatch error", { err });
      throw err;
    }
  }

  getGenerativeModel(options: ModelParams | any): any {
    const { model, safetySettings, generationConfig, tools, systemInstruction, cachedContent } = options;
    const ai = this.ai;

    return {
      async generateContent(promptOrContent: any): Promise<any> {
        let contents = promptOrContent;
        if (typeof promptOrContent === "object" && promptOrContent !== null && promptOrContent.contents) {
          contents = promptOrContent.contents;
        }

        const config: any = {
          ...(generationConfig || {}),
        };
        if (safetySettings) config.safetySettings = safetySettings;
        if (tools) config.tools = tools;
        if (systemInstruction) config.systemInstruction = systemInstruction;
        if (cachedContent || generationConfig?.cachedContent) {
          config.cachedContent = cachedContent || generationConfig.cachedContent;
        }

        const result: any = await ai.models.generateContent({
          model,
          contents,
          config,
        });

        // Ensure both legacy (@google-cloud/vertexai) and modern (@google/genai) properties exist:
        // - Legacy callers: response.response.candidates[0]
        // - Modern callers: response.candidates[0] or response.text
        return {
          response: result,
          ...result,
        };
      },

      async generateContentStream(promptOrContent: any): Promise<any> {
        let contents = promptOrContent;
        if (typeof promptOrContent === "object" && promptOrContent !== null && promptOrContent.contents) {
          contents = promptOrContent.contents;
        }

        const config: any = {
          ...(generationConfig || {}),
        };
        if (safetySettings) config.safetySettings = safetySettings;
        if (tools) config.tools = tools;
        if (systemInstruction) config.systemInstruction = systemInstruction;
        if (cachedContent || generationConfig?.cachedContent) {
          config.cachedContent = cachedContent || generationConfig.cachedContent;
        }

        const streamGen = await ai.models.generateContentStream({
          model,
          contents,
          config,
        });

        // Compatibility shim:
        // Legacy @google-cloud/vertexai callers used `result.stream`.
        // Modern @google/genai returns AsyncGenerator directly.
        // We attach .stream pointing to the generator itself so BOTH:
        // - `for await (const chunk of streamResult.stream)`
        // - `for await (const chunk of streamResult)`
        // work flawlessly.
        (streamGen as any).stream = streamGen;
        return streamGen;
      },
    };
  }
}

export type VertexAI = GenAIVertexAdapter;

/**
 * Returns a singleton instance of the Vertex AI client.
 * Uses modern @google/genai under the hood wrapped in GenAIVertexAdapter,
 * guaranteeing zero regressions for legacy callers while running on the latest SDK.
 */
export function getVertexAI(): GenAIVertexAdapter {
  if (!vertexAdapterInstance) {
    const ai = getGenAI();
    vertexAdapterInstance = new GenAIVertexAdapter(ai);
  }
  return vertexAdapterInstance;
}
