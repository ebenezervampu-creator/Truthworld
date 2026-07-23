/**
 * Base configuration and types for Schema.org JSON-LD generators.
 */
export const SCHEMA_VERSION = 1;
export const DOMAIN = "https://www.truthworld.in";

export interface BaseSeoMeta {
  title: string;
  description: string;
  url: string;
  image?: string;
  type?: string;
  robots?: string;
  jsonLd?: any[];
  rawData?: any;
  dataType?: string;
}

export function escapeHtml(unsafe: string): string {
  if (!unsafe) return "";
  return unsafe
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

export function cleanJsonLd(obj: any): any {
  if (Array.isArray(obj)) {
    const arr = obj
      .map(cleanJsonLd)
      .filter(v => v !== null && v !== undefined && v !== "" && (Array.isArray(v) ? v.length > 0 : true));
    return arr.length > 0 ? arr : undefined;
  }
  if (obj !== null && typeof obj === 'object') {
    const cleaned: any = {};
    for (const key in obj) {
      if (Object.prototype.hasOwnProperty.call(obj, key)) {
        const val = cleanJsonLd(obj[key]);
        if (val !== null && val !== undefined && val !== "" && (Array.isArray(val) ? val.length > 0 : true)) {
          cleaned[key] = val;
        }
      }
    }
    return Object.keys(cleaned).length > 0 ? cleaned : undefined;
  }
  return obj;
}

export function formatIsoDuration(durationMs?: number): string | undefined {
  if (!durationMs || durationMs <= 0) return undefined;
  const totalSeconds = Math.floor(durationMs / 1000);
  const hours = Math.floor(totalSeconds / 3600);
  const minutes = Math.floor((totalSeconds % 3600) / 60);
  const seconds = totalSeconds % 60;
  
  let result = "PT";
  if (hours > 0) result += `${hours}H`;
  if (minutes > 0) result += `${minutes}M`;
  if (seconds > 0 || result === "PT") result += `${seconds}S`;
  return result;
}

export function formatDate(timestamp?: any): string {
  if (!timestamp) return new Date().toISOString();
  if (typeof timestamp.toMillis === "function") {
    return new Date(timestamp.toMillis()).toISOString();
  }
  if (timestamp instanceof Date) {
    return timestamp.toISOString();
  }
  if (typeof timestamp === "number") {
    return new Date(timestamp).toISOString();
  }
  if (typeof timestamp === "string") {
    return new Date(timestamp).toISOString();
  }
  return new Date().toISOString();
}
