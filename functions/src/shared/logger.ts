/**
 * 📝 LOGGER (SHARED CORE)
 * 
 * Standardized logging for all microservices.
 */

export const logger = {
  info: (message: string, meta: Record<string, any> = {}) => {
    console.log(`[INFO] ${message}`, JSON.stringify(meta));
  },
  warn: (message: string, meta: Record<string, any> = {}) => {
    console.warn(`[WARN] ${message}`, JSON.stringify(meta));
  },
  error: (message: string, meta: Record<string, any> = {}) => {
    console.error(`[ERROR] ${message}`, JSON.stringify(meta));
  },
  debug: (message: string, meta: Record<string, any> = {}) => {
    if (process.env.DEBUG || process.env.NODE_ENV !== 'production') {
      console.debug(`[DEBUG] ${message}`, JSON.stringify(meta));
    }
  }
};
