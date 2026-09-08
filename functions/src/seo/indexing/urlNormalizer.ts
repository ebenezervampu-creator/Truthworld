import { DOMAIN } from "../schema/schemaConfig";

const TRACKING_PARAMS = new Set([
  "utm_source",
  "utm_medium",
  "utm_campaign",
  "utm_term",
  "utm_content",
  "fbclid",
  "gclid",
  "msclkid",
  "ref",
  "spm",
  "_ga",
  "_gl"
]);

/**
 * Normalizes URLs for strict canonical consistency across search engines.
 * Preserves case for identifier values like video IDs (?v=...), playlist IDs (?list=...),
 * and user handles (/@UserHandle).
 */
export function normalizeUrl(host: string, rawPath: string, query: Record<string, any> = {}): string {
  const isStudio = host.includes("studio") || rawPath.startsWith("/studio");
  const base = isStudio
    ? (host.includes("localhost") || host.includes("127.0.0.1") ? `http://${host}` : "https://studio.truthworld.in")
    : DOMAIN;

  // Clean path
  let path = rawPath.split("?")[0] || "/";

  // Handle studio root
  if (isStudio && (path === "/" || path === "/studio" || path === "" || path === "/index.html")) {
    return "https://studio.truthworld.in/";
  }

  // Preserve handle casing if starts with /@
  if (path.startsWith("/@")) {
    const handle = path.substring(2);
    const cleanHandle = handle.replace(/\/+$/, "");
    return `${base}/@${cleanHandle}`;
  }

  const rawParts = path.split("/").filter(p => p.length > 0);
  const lowerParts = rawParts.map(p => p.toLowerCase());

  // Preserve ID casing for channel routes (/channel/ID, /c/ID, /user/ID)
  if (lowerParts.length >= 2 && (lowerParts[0] === "channel" || lowerParts[0] === "c" || lowerParts[0] === "user")) {
    const channelId = rawParts[1].replace(/\/+$/, "");
    return `${base}/channel/${channelId}`;
  }

  // Preserve ID casing and canonicalize post/community routes (/post/ID, /community/ID)
  if (lowerParts.length >= 2 && (lowerParts[0] === "post" || lowerParts[0] === "community")) {
    const postId = rawParts[1].replace(/\/+$/, "");
    return `${base}/post/${postId}`;
  }

  // Canonicalize topic routes (/topic/slug, /topics/slug, /T/slug, /t/slug)
  if (lowerParts.length >= 2 && (lowerParts[0] === "topic" || lowerParts[0] === "topics" || lowerParts[0] === "t")) {
    const slug = rawParts[1].replace(/\/+$/, "").toLowerCase();
    return `${base}/topic/${slug}`;
  }

  // Strip trailing slashes for other paths
  if (path.length > 1 && path.endsWith("/")) {
    path = path.replace(/\/+$/, "");
  }

  // Lowercase path for case-insensitive route matching (prevents /Watch vs /watch duplicates)
  path = path.toLowerCase();

  // Clean query params (filtering tracking params)
  const cleanQueryParams = new URLSearchParams();
  for (const key of Object.keys(query)) {
    const lowerKey = key.toLowerCase();
    if (!TRACKING_PARAMS.has(lowerKey) && query[key] !== undefined && query[key] !== null) {
      // Preserve exact case of query value!
      cleanQueryParams.set(key, String(query[key]));
    }
  }

  const queryString = cleanQueryParams.toString();

  // Watch & video route canonicalization (/watch?v=..., /watch/ID, /v/ID, /shorts/ID, /embed/ID, /embed/watch?v=...)
  if (
    path.startsWith("/watch") ||
    path.startsWith("/v/") ||
    path.startsWith("/shorts/") ||
    path.startsWith("/embed")
  ) {
    let v = query.v || query.V;
    if (!v) {
      if (rawParts.length >= 2 && rawParts[1].toLowerCase() !== "watch") {
        v = rawParts[1];
      }
    }
    return v ? `${base}/watch?v=${encodeURIComponent(String(v))}` : `${base}/watch`;
  }

  // Playlist route canonicalization (/playlist?list=..., /playlist/ID)
  if (path.startsWith("/playlist")) {
    let list = query.list || query.LIST;
    if (!list) {
      if (rawParts.length >= 2) {
        list = rawParts[1];
      }
    }
    return list ? `${base}/playlist?list=${encodeURIComponent(String(list))}` : `${base}/playlist`;
  }

  if (queryString) {
    return `${base}${path}?${queryString}`;
  }

  return `${base}${path}`;
}
