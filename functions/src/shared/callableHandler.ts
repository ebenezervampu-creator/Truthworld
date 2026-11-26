/**
 * ⚡ CALLABLE HANDLER UTILITIES (SHARED CORE)
 *
 * Industry-standard wrapper for Firebase Cloud Functions (v2) Callable Functions.
 *
 * Standardizes:
 * - Default runtime options (region: "asia-south1", maxInstances: 10, scale-to-zero).
 * - Pre-flight authentication & authorization enforcement (user, admin, director).
 * - Execution latency tracking and structured audit logging.
 * - Zero Raw Developer Error sanitization via `toHttpsError`.
 */

import {
  onCall,
  CallableRequest,
  CallableOptions,
} from "firebase-functions/v2/https";
import { logger } from "./logger";
import { toHttpsError, AuthenticationError } from "./errors";
import { assertAdminCaller, AuthenticatedUser } from "../utils/auth";

export interface CallableFunctionConfig extends Partial<CallableOptions> {
  /** Require authenticated user token (throws unauthenticated if missing) */
  requireAuth?: boolean;
  /** Require administrator privileges via JWT custom claims or admin_members doc */
  requireAdmin?: boolean;
  /** Optional function name for structured log tagging */
  name?: string;
}

export type AuthenticatedCallableRequest<TData = any> = CallableRequest<TData> & {
  caller?: AuthenticatedUser;
};

/**
 * Standard factory for building production-ready Firebase v2 Callable Functions.
 *
 * Example:
 * ```ts
 * export const getDashboardData = createCallableHandler(
 *   { name: "getDashboardData", requireAuth: true },
 *   async (request) => {
 *     return { stats: await fetchStats(request.auth.uid) };
 *   }
 * );
 * ```
 */
export function createCallableHandler<TData = any, TResponse = any>(
  config: CallableFunctionConfig,
  handler: (request: AuthenticatedCallableRequest<TData>) => Promise<TResponse>
) {
  const functionName = config.name || "CallableEndpoint";

  const options: CallableOptions = {
    region: config.region || "asia-south1",
    maxInstances: config.maxInstances ?? 10,
    memory: config.memory || "256MiB",
    timeoutSeconds: config.timeoutSeconds || 60,
    cors: config.cors ?? true,
    ...config,
  };

  return onCall(options, async (request) => {
    const startTime = Date.now();
    const structuredReq = request as AuthenticatedCallableRequest<TData>;

    try {
      // 1. Enforce Authentication if required
      if (config.requireAuth && !request.auth) {
        throw new AuthenticationError(
          "Authentication required for callable endpoint.",
          "Please sign in to proceed with this request."
        );
      }

      // 2. Enforce Admin privileges if required
      if (config.requireAdmin) {
        if (!request.auth) {
          throw new AuthenticationError(
            "Admin authentication required.",
            "Please sign in with administrator credentials."
          );
        }
        structuredReq.caller = await assertAdminCaller(request.auth);
      }

      // 3. Execute business logic
      const result = await handler(structuredReq);
      const latencyMs = Date.now() - startTime;

      logger.debug(`[${functionName}] Handled successfully (${latencyMs}ms)`, {
        uid: request.auth?.uid,
        latencyMs,
      });

      return result;
    } catch (error) {
      const latencyMs = Date.now() - startTime;
      logger.error(`[${functionName}] Handler error (${latencyMs}ms):`, {
        error,
        uid: request.auth?.uid,
        latencyMs,
      });

      // Strict enforcement of Zero Raw Developer Error Policy
      throw toHttpsError(error);
    }
  });
}
