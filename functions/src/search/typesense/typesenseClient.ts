import { Client } from "typesense";
import * as dotenv from "dotenv";
import * as path from "path";

dotenv.config({ path: path.resolve(__dirname, "../../../.env") });

const host = process.env.TYPESENSE_HOST || "26z51dwhpsoq0kv8p-1.a1.typesense.net";
const port = parseInt(process.env.TYPESENSE_PORT || "443", 10);
const protocol = process.env.TYPESENSE_PROTOCOL || "https";
const adminApiKey = process.env.TYPESENSE_ADMIN_API_KEY || "qDSW599rFjHEimnmVcBOJ2y1P42PkXAK";
const searchApiKey = process.env.TYPESENSE_SEARCH_API_KEY || "pw6fZJ3XVEdZHcSJAEGwwYh3xZXsMPyc";

export const getTypesenseAdminClient = (): Client => {
  return new Client({
    nodes: [
      {
        host,
        port,
        protocol,
      },
    ],
    apiKey: adminApiKey,
    connectionTimeoutSeconds: 5,
  });
};

export const getTypesenseSearchClient = (): Client => {
  return new Client({
    nodes: [
      {
        host,
        port,
        protocol,
      },
    ],
    apiKey: searchApiKey,
    connectionTimeoutSeconds: 3,
  });
};
