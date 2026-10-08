/**
 * 🌐 TEST HTTP SERVER UTILITY FOR SUPERTEST
 *
 * Wraps Firebase Cloud Functions onRequest handlers into an Express application
 * suitable for real HTTP integration tests via Supertest, with support for
 * rawBody preservation (critical for cryptographic webhook verification).
 */

import express, { Express, Request, Response } from 'express';

export function createTestApp(handler: (req: any, res: any) => any): Express {
  const app = express();

  // Preserve rawBody Buffer for webhook HMAC signature verification
  app.use(
    express.json({
      verify: (req: any, _res, buf) => {
        req.rawBody = buf;
      },
    })
  );

  app.use(
    express.urlencoded({
      extended: true,
      verify: (req: any, _res, buf) => {
        req.rawBody = buf;
      },
    })
  );

  // Fallback for text/plain or raw payloads
  app.use(
    express.raw({
      type: '*/*',
      verify: (req: any, _res, buf) => {
        req.rawBody = buf;
      },
    })
  );

  // Route all methods & paths to handler
  app.all('*', async (req: Request, res: Response) => {
    try {
      await handler(req, res);
    } catch (err: any) {
      if (!res.headersSent) {
        res.status(500).json({ error: 'Internal test server error', details: err?.message });
      }
    }
  });

  return app;
}
