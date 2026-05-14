/**
 * Simple logging utility with structured JSON output
 */

export const logger = {
  info: (message: string, data?: any) => {
    console.log(JSON.stringify({ level: "INFO", message, ...data }));
  },
  
  warn: (message: string, data?: any) => {
    console.warn(JSON.stringify({ level: "WARN", message, ...data }));
  },
  
  error: (message: string, data?: any) => {
    console.error(JSON.stringify({ level: "ERROR", message, ...data }));
  },
  
  debug: (message: string, data?: any) => {
    console.log(JSON.stringify({ level: "DEBUG", message, ...data }));
  },
};
