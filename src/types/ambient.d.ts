declare module "helmet" {
  import type { RequestHandler } from "express";
  function helmet(): RequestHandler;
  export default helmet;
}

declare module "express-rate-limit" {
  import type { RequestHandler } from "express";
  interface Options {
    windowMs?: number;
    max?: number | ((req: any, res: any) => number | Promise<number>);
  }
  function rateLimit(options?: Options): RequestHandler;
  export default rateLimit;
}

