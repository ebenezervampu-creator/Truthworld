import { Client } from "typesense";

/**
 * Returns true if Typesense host and admin API key are configured in environment.
 */
export function isTypesenseConfigured(): boolean {
  const host = process.env.TYPESENSE_HOST?.trim();
  const apiKey = process.env.TYPESENSE_ADMIN_API_KEY?.trim();
  return Boolean(host && apiKey);
}

export const getTypesenseAdminClient = (): Client => {
  const host = process.env.TYPESENSE_HOST?.trim();
  const apiKey = process.env.TYPESENSE_ADMIN_API_KEY?.trim();
  const port = parseInt(process.env.TYPESENSE_PORT || "443", 10);
  const protocol = process.env.TYPESENSE_PROTOCOL || "https";

  if (!host || !apiKey) {
    throw new Error(
      "Typesense is not configured. Both TYPESENSE_HOST and TYPESENSE_ADMIN_API_KEY environment variables are required."
    );
  }

  return new Client({
    nodes: [
      {
        host,
        port,
        protocol,
      },
    ],
    apiKey,
    connectionTimeoutSeconds: 5,
  });
};

export const getTypesenseClient = getTypesenseAdminClient;

export const getTypesenseSearchClient = (): Client => {
  const host = process.env.TYPESENSE_HOST?.trim();
  const apiKey = (process.env.TYPESENSE_SEARCH_API_KEY || process.env.TYPESENSE_ADMIN_API_KEY)?.trim();
  const port = parseInt(process.env.TYPESENSE_PORT || "443", 10);
  const protocol = process.env.TYPESENSE_PROTOCOL || "https";

  if (!host || !apiKey) {
    throw new Error(
      "Typesense search client is not configured. TYPESENSE_HOST and TYPESENSE_SEARCH_API_KEY (or TYPESENSE_ADMIN_API_KEY) are required."
    );
  }

  return new Client({
    nodes: [
      {
        host,
        port,
        protocol,
      },
    ],
    apiKey,
    connectionTimeoutSeconds: 3,
  });
};
