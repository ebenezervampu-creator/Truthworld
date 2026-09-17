import { logger as ffLogger } from "firebase-functions";

function formatLog(message: string, data?: any): { message: string; meta?: any } {
  if (data === undefined) {
    return { message };
  }
  if (data instanceof Error) {
    return {
      message: `${message} ${data.message}`,
      meta: {
        errorName: data.name,
        errorMessage: data.message,
        stack: data.stack,
      },
    };
  }
  if (typeof data === "string" || typeof data === "number" || typeof data === "boolean") {
    return {
      message: `${message} ${data}`,
      meta: { detail: data },
    };
  }
  if (typeof data === "object" && data !== null) {
    const errObj = data.err || data.error;
    const errorDetails = errObj instanceof Error
      ? {
          errorMessage: errObj.message,
          stack: errObj.stack,
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
  return { message, meta: { detail: data } };
}

export const logger = {
  info: (message: string, data?: any) => {
    const { message: msg, meta } = formatLog(message, data);
    if (meta) {
      ffLogger.info(msg, meta);
    } else {
      ffLogger.info(msg);
    }
  },

  warn: (message: string, data?: any) => {
    const { message: msg, meta } = formatLog(message, data);
    if (meta) {
      ffLogger.warn(msg, meta);
    } else {
      ffLogger.warn(msg);
    }
  },

  error: (message: string, data?: any) => {
    const { message: msg, meta } = formatLog(message, data);
    if (meta) {
      ffLogger.error(msg, meta);
    } else {
      ffLogger.error(msg);
    }
  },

  debug: (message: string, data?: any) => {
    const { message: msg, meta } = formatLog(message, data);
    if (meta) {
      ffLogger.debug(msg, meta);
    } else {
      ffLogger.debug(msg);
    }
  },
};

