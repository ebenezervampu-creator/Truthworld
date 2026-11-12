import { CollectionCreateSchema } from "typesense/lib/Typesense/Collections";
import { getTypesenseAdminClient } from "./typesenseClient";

export const VIDEO_COLLECTION_SCHEMA: CollectionCreateSchema = {
  name: "videos",
  fields: [
    { name: "id", type: "string" },
    { name: "title", type: "string" },
    { name: "description", type: "string", optional: true },
    { name: "channelId", type: "string", facet: true, optional: true },
    { name: "channelName", type: "string", facet: true },
    { name: "channelImage", type: "string", optional: true },
    { name: "thumbnailUrl", type: "string", optional: true },
    { name: "views", type: "int64" },
    { name: "isFactChecked", type: "bool", facet: true, optional: true },
    { name: "isTrusted", type: "bool", facet: true, optional: true },
    { name: "category", type: "string", facet: true, optional: true },
    { name: "tags", type: "string[]", facet: true, optional: true },
    { name: "topics", type: "string[]", facet: true, optional: true },
    { name: "language", type: "string", facet: true, optional: true },
    { name: "durationMs", type: "int64", optional: true },
    { name: "visibility", type: "string", facet: true },
    { name: "status", type: "string", facet: true },
    { name: "createdAt", type: "int64" },
  ],
  default_sorting_field: "views",
};

export const CHANNEL_COLLECTION_SCHEMA: CollectionCreateSchema = {
  name: "channels",
  fields: [
    { name: "id", type: "string" },
    { name: "channelName", type: "string" },
    { name: "handle", type: "string" },
    { name: "avatarUrl", type: "string", optional: true },
    { name: "subscriberCount", type: "int64" },
    { name: "category", type: "string", facet: true, optional: true },
    { name: "isVerified", type: "bool", facet: true, optional: true },
    { name: "isTrusted", type: "bool", facet: true, optional: true },
    { name: "status", type: "string", facet: true, optional: true },
    { name: "createdAt", type: "int64" },
  ],
  default_sorting_field: "subscriberCount",
};

export const TOPIC_COLLECTION_SCHEMA: CollectionCreateSchema = {
  name: "topics",
  fields: [
    { name: "id", type: "string" },
    { name: "title", type: "string" },
    { name: "slug", type: "string" },
    { name: "thumbnailUrl", type: "string", optional: true },
    { name: "videoCount", type: "int64" },
    { name: "category", type: "string", facet: true, optional: true },
    { name: "isActive", type: "bool", facet: true, optional: true },
    { name: "createdAt", type: "int64" },
  ],
  default_sorting_field: "videoCount",
};

export async function initializeCollections(): Promise<void> {
  const client = getTypesenseAdminClient();
  const schemas = [
    VIDEO_COLLECTION_SCHEMA,
    CHANNEL_COLLECTION_SCHEMA,
    TOPIC_COLLECTION_SCHEMA,
  ];

  console.log("🚀 Initializing Typesense collections...");

  for (const schema of schemas) {
    try {
      const existing = await client.collections(schema.name).retrieve();
      console.log(`✅ Collection "${schema.name}" already exists (${existing.num_documents} documents).`);
    } catch (err: any) {
      if (err.httpStatus === 404) {
        console.log(`📦 Creating collection "${schema.name}"...`);
        await client.collections().create(schema);
        console.log(`✅ Collection "${schema.name}" created successfully.`);
      } else {
        console.error(`❌ Error checking collection "${schema.name}":`, err);
        throw err;
      }
    }
  }

  console.log("🎉 All Typesense collections initialized!");
}

if (require.main === module) {
  initializeCollections()
    .then(() => process.exit(0))
    .catch((err) => {
      console.error("Fatal initialization error:", err);
      process.exit(1);
    });
}
