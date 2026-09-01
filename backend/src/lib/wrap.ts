import type { NextFunction, Request, Response } from "express";

type Handler = (req: Request, res: Response) => Promise<void>;

// Express 4 doesn't forward rejected promises from async handlers to error
// middleware on its own - this wrapper does that so HttpError instances
// thrown anywhere in a route reach the error handler in index.ts.
export function wrap(handler: Handler) {
  return (req: Request, res: Response, next: NextFunction) => {
    handler(req, res).catch(next);
  };
}
