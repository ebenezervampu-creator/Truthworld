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
    // Strip trailing slashes
    const cleanHandle = handle.replace(/\/+$/, "");
    return `${base}/@${cleanHandle}`;
  }

  // Strip trailing slashes for other paths
  if (path.length > 1 && path.endsWith("/")) {
    path = path.replace(/\/+$/, "");
  }

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

  // Watch route canonicalization
  if (path.startsWith("/watch")) {
    const v = query.v || query.V;
    return v ? `${base}/watch?v=${encodeURIComponent(String(v))}` : `${base}/watch`;
  }

  // Playlist route canonicalization
  if (path.startsWith("/playlist")) {
    const list = query.list || query.LIST;
    return list ? `${base}/playlist?list=${encodeURIComponent(String(list))}` : `${base}/playlist`;
  }

  if (queryString) {
    return `${base}${path}?${queryString}`;
  }

  return `${base}${path}`;
}
