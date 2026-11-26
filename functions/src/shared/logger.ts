/**
 * 📝 STRUCTURED LOGGER (SHARED CORE)
 *
 * Industry-standard structured logging layer wrapping `firebase-functions/logger`.
 *
 * Benefits:
 * - Emits Cloud Logging compliant JSON payloads with correct severities (INFO, WARN, ERROR, DEBUG).
 * - Automatically parses Error objects, preserving stack traces server-side.
 * - Supports contextual loggers via `logger.withContext({ videoId, userId })`.
 * - Zero dependency sprawl: leverages Firebase Functions native logging transport.
 */

import { logger as ffLogger } from "firebase-functions";

export type LogLevel = "debug" | "info" | "warn" | "error";

export interface LogContext {
  [key: string]: any;
}

/**
 * Normalizes input message and data payload into structured metadata.
 */
function normalizeLogData(message: string, data?: any): { message: string; meta?: Record<string, any> } {
  if (data === undefined || data === null) {
    return { message };
  }

  if (data instanceof Error) {
    return {
      message: `${message}: ${data.message}`,
      meta: {
        errorName: data.name,
        errorMessage: data.message,
        stack: data.stack,
      },
    };
  }

  if (typeof data === "object") {
    const errorProp = data.error || data.err;
    const errorDetails = errorProp instanceof Error
      ? {
          errorName: errorProp.name,
          errorMessage: errorProp.message,
          stack: errorProp.stack,
        }
      : {};

    return {
      message,
      meta: {
        ...data,
        ...errorDetails,
      },
    };
  }

  return {
    message,
    meta: { detail: data },
  };
}

export class StructuredLogger {
  constructor(private context: LogContext = {}) {}

  /**
   * Creates a contextual child logger with pre-bound metadata (e.g. videoId, jobId, userId).
   */
  withContext(additionalContext: LogContext): StructuredLogger {
    return new StructuredLogger({
      ...this.context,
      ...additionalContext,
    });
  }

  info(message: string, data?: any): void {
    const { message: msg, meta } = normalizeLogData(message, data);
    const combinedMeta = { ...this.context, ...meta };
    if (Object.keys(combinedMeta).length > 0) {
      ffLogger.info(msg, combinedMeta);
    } else {
      ffLogger.info(msg);
    }
  }

  warn(message: string, data?: any): void {
    const { message: msg, meta } = normalizeLogData(message, data);
    const combinedMeta = { ...this.context, ...meta };
    if (Object.keys(combinedMeta).length > 0) {
      ffLogger.warn(msg, combinedMeta);
    } else {
      ffLogger.warn(msg);
    }
  }

  error(message: string, data?: any): void {
    const { message: msg, meta } = normalizeLogData(message, data);
    const combinedMeta = { ...this.context, ...meta };
    if (Object.keys(combinedMeta).length > 0) {
      ffLogger.error(msg, combinedMeta);
    } else {
      ffLogger.error(msg);
    }
  }

  debug(message: string, data?: any): void {
    const { message: msg, meta } = normalizeLogData(message, data);
    const combinedMeta = { ...this.context, ...meta };
    if (Object.keys(combinedMeta).length > 0) {
      ffLogger.debug(msg, combinedMeta);
    } else {
      ffLogger.debug(msg);
    }
  }
}

/** Global default logger singleton */
export const logger = new StructuredLogger();
