/**
 * 🛡️ TRUTHWORLD STRUCTURED ERRORS & SANITIZER (SHARED CORE)
 *
 * Implements the TruthWorld Zero Raw Developer Error Policy:
 * 1. Never expose raw exceptions, stack traces, or developer logs to clients.
 * 2. Log full internal diagnostics, stack traces, and metadata on the server.
 * 3. Return polite, user-friendly standard English explanations with actionable advice.
 * 4. Map cleanly to Firebase HttpsError and standard HTTP status codes.
 */

import { HttpsError, FunctionsErrorCode } from "firebase-functions/v2/https";
import { Response } from "express";
import { logger } from "./logger";
import { applySecurityHeaders } from "../utils/securityHeaders";

export type AppErrorCode =
  | "VALIDATION_ERROR"
  | "UNAUTHENTICATED"
  | "FORBIDDEN"
  | "NOT_FOUND"
  | "CONFLICT"
  | "RATE_LIMITED"
  | "INTERNAL_ERROR"
  | "BAD_GATEWAY"
  | "SERVICE_UNAVAILABLE";

/**
 * Base Application Error class with dual personas:
 * - `userMessage`: Clean, user-friendly message intended for client display.
 * - `message`: Developer technical explanation for server logs.
 */
export class AppError extends Error {
  public readonly code: AppErrorCode;
  public readonly userMessage: string;
  public readonly statusCode: number;
  public readonly functionsErrorCode: FunctionsErrorCode;
  public readonly details?: any;

  constructor(options: {
    code: AppErrorCode;
    message: string;
    userMessage?: string;
    statusCode?: number;
    functionsErrorCode?: FunctionsErrorCode;
    details?: any;
  }) {
    super(options.message);
    this.name = this.constructor.name;
    this.code = options.code;
    this.userMessage = options.userMessage || options.message;
    this.statusCode = options.statusCode || 500;
    this.functionsErrorCode = options.functionsErrorCode || "internal";
    this.details = options.details;

    // Capture clean stack trace
    Error.captureStackTrace(this, this.constructor);
  }
}

export class ValidationError extends AppError {
  constructor(message: string, userMessage?: string, details?: any) {
    super({
      code: "VALIDATION_ERROR",
      message,
      userMessage: userMessage || "The request could not be processed due to invalid or missing data.",
      statusCode: 400,
      functionsErrorCode: "invalid-argument",
      details,
    });
  }
}

export class AuthenticationError extends AppError {
  constructor(message = "Authentication required", userMessage?: string) {
    super({
      code: "UNAUTHENTICATED",
      message,
      userMessage: userMessage || "Please sign in to continue.",
      statusCode: 401,
      functionsErrorCode: "unauthenticated",
    });
  }
}

export class ForbiddenError extends AppError {
  constructor(message = "Permission denied", userMessage?: string) {
    super({
      code: "FORBIDDEN",
      message,
      userMessage: userMessage || "You do not have permission to perform this action.",
      statusCode: 403,
      functionsErrorCode: "permission-denied",
    });
  }
}

export class NotFoundError extends AppError {
  constructor(resource = "Requested resource", userMessage?: string) {
    super({
      code: "NOT_FOUND",
      message: `${resource} not found`,
      userMessage: userMessage || "The requested item was not found.",
      statusCode: 404,
      functionsErrorCode: "not-found",
    });
  }
}

export class ConflictError extends AppError {
  constructor(message: string, userMessage?: string) {
    super({
      code: "CONFLICT",
      message,
      userMessage: userMessage || "A conflict occurred while processing your request. Please try again.",
      statusCode: 409,
      functionsErrorCode: "already-exists",
    });
  }
}

export class RateLimitError extends AppError {
  constructor(message = "Rate limit exceeded", userMessage?: string) {
    super({
      code: "RATE_LIMITED",
      message,
      userMessage: userMessage || "Too many requests. Please wait a moment and try again.",
      statusCode: 429,
      functionsErrorCode: "resource-exhausted",
    });
  }
}

export class InternalError extends AppError {
  constructor(message = "Internal server error", userMessage?: string, details?: any) {
    super({
      code: "INTERNAL_ERROR",
      message,
      userMessage: userMessage || "Something went wrong. Our team has been notified. Please try again shortly.",
      statusCode: 500,
      functionsErrorCode: "internal",
      details,
    });
  }
}

/**
 * Sanitizes any raw exception or AppError into a client-safe Firebase `HttpsError`.
 *
 * Strictly adheres to TruthWorld Zero Raw Developer Error Policy:
 * 1. Logs full technical details and stack trace internally.
 * 2. Emits friendly, standard English explanation to the caller.
 */
export function toHttpsError(error: unknown, fallbackMessage?: string): HttpsError {
  // If already a Firebase HttpsError
  if (error instanceof HttpsError) {
    logger.warn(`[HttpsError] ${error.code}: ${error.message}`, { details: error.details });
    return error;
  }

  // If structured AppError
  if (error instanceof AppError) {
    logger.error(`[${error.code}] ${error.message}`, {
      code: error.code,
      statusCode: error.statusCode,
      details: error.details,
      stack: error.stack,
    });
    return new HttpsError(error.functionsErrorCode, error.userMessage, error.details);
  }

  // Raw or unexpected error
  const rawError = error instanceof Error ? error : new Error(String(error));
  logger.error("[UnhandledException] An unexpected error occurred:", {
    errorMessage: rawError.message,
    errorName: rawError.name,
    stack: rawError.stack,
  });

  const safeMessage =
    fallbackMessage ||
    "An unexpected error occurred while processing your request. Please try again shortly.";

  return new HttpsError("internal", safeMessage);
}

/**
 * Sends a sanitized HTTP response for onRequest / Express endpoints.
 */
export function sendErrorResponse(
  res: Response,
  error: unknown,
  fallbackMessage?: string
): void {
  applySecurityHeaders(res);

  if (error instanceof AppError) {
    logger.error(`[HTTP ${error.statusCode}] ${error.message}`, {
      code: error.code,
      details: error.details,
      stack: error.stack,
    });
    res.status(error.statusCode).json({
      success: false,
      error: error.userMessage,
      code: error.code,
    });
    return;
  }

  const rawError = error instanceof Error ? error : new Error(String(error));
  logger.error("[HTTP 500] Unhandled Exception:", {
    errorMessage: rawError.message,
    stack: rawError.stack,
  });

  const safeMessage =
    fallbackMessage ||
    "Unable to process request at this time. Please check your connection and try again.";

  res.status(500).json({
    success: false,
    error: safeMessage,
    code: "INTERNAL_ERROR",
  });
}
