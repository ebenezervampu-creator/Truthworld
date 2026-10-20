import { GoogleAuth } from "google-auth-library";
import { logger } from "firebase-functions/v2";

let cachedAuthClient: any = null;

async function getAuthClient(): Promise<any> {
  if (!cachedAuthClient) {
    const auth = new GoogleAuth({
      scopes: ["https://www.googleapis.com/auth/cloud-platform"],
    });
    cachedAuthClient = await auth.getClient();
  }
  return cachedAuthClient;
}

/**
 * Computes a 768-dimensional vector embedding for text using Google Vertex AI text-embedding-004.
 * Returns null if embedding generation fails or is throttled.
 */
export async function computeTextEmbedding(text: string): Promise<number[] | null> {
  const cleanText = text.trim();
  if (!cleanText) return null;

  try {
    const client = await getAuthClient();
    const project =
      process.env.GCP_PROJECT_ID ||
      process.env.GCP_PROJECT ||
      process.env.GCLOUD_PROJECT ||
      process.env.FIREBASE_CONFIG
        ? JSON.parse(process.env.FIREBASE_CONFIG || "{}").projectId || "truthworld-1"
        : "truthworld-1";
    const location = process.env.GCP_LOCATION || "asia-south1";

    const url = `https://${location}-aiplatform.googleapis.com/v1/projects/${project}/locations/${location}/publishers/google/models/text-embedding-004:predict`;

    const res: any = await client.request({
      url,
      method: "POST",
      data: {
        instances: [
          {
            content: cleanText.slice(0, 2048), // limit text length
          },
        ],
      },
    });

    const values = res.data?.predictions?.[0]?.embeddings?.values;
    if (Array.isArray(values) && values.length > 0) {
      return values;
    }
    return null;
  } catch (err: any) {
    logger.warn("[computeTextEmbedding] Failed to generate embedding", {
      errorMessage: err instanceof Error ? err.message : String(err),
    });
    return null;
  }
}
