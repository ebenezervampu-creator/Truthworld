import axios from "axios";
import { logger } from "firebase-functions/v2";

export interface GeoResult {
  country: string;
  countryCode: string | null;
  region: string | null;
  regionKey: string; // India→state name, non-India→country name, unknown→"Others"
}

// In-memory LRU cache (100 entries max)
const geoCache = new Map<string, GeoResult>();
const MAX_CACHE = 100;

export async function resolveGeo(rawIp: string): Promise<GeoResult> {
  const ip = rawIp.split(",")[0].trim();

  // Handle private/localhost IPs
  if (!ip || ip === "::1" || ip.startsWith("127.") || ip.startsWith("::ffff:127.") || ip.startsWith("10.") || ip.startsWith("192.168.")) {
    return { country: "Others", countryCode: null, region: null, regionKey: "Others" };
  }

  if (geoCache.has(ip)) return geoCache.get(ip)!;

  try {
    const { data } = await axios.get(
      `http://ip-api.com/json/${ip}?fields=status,country,countryCode,regionName`,
      { timeout: 2000 }
    );

    if (data.status !== "success") {
      return { country: "Others", countryCode: null, region: null, regionKey: "Others" };
    }

    const result: GeoResult = {
      country: data.country ?? "Others",
      countryCode: data.countryCode ?? null,
      region: data.regionName ?? null,
      regionKey: data.countryCode === "IN"
        ? (data.regionName ?? "Others")
        : (data.country ?? "Others"),
    };

    // LRU eviction
    if (geoCache.size >= MAX_CACHE) {
      const oldest = geoCache.keys().next().value;
      if (oldest) geoCache.delete(oldest);
    }
    geoCache.set(ip, result);
    return result;
  } catch (err) {
    logger.warn("resolveGeo failed", { ip: ip.substring(0, 8) + "...", error: String(err) });
    return { country: "Others", countryCode: null, region: null, regionKey: "Others" };
  }
}
