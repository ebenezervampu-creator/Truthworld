import type { VertexAI } from "@google-cloud/vertexai";

let vertexAIInstance: VertexAI | null = null;

/**
 * Returns a global singleton instance of VertexAI.
 * Avoids re-instantiating the SDK on every function execution / loop iteration.
 */
export function getVertexAI(): VertexAI {
  if (!vertexAIInstance) {
    const { VertexAI } = require("@google-cloud/vertexai");
    const project = process.env.GCP_PROJECT || process.env.GCLOUD_PROJECT || "truthworld-1";
    const location = process.env.GCP_LOCATION || "us-central1";
    vertexAIInstance = new VertexAI({ project, location });
  }
  return vertexAIInstance!;
}

