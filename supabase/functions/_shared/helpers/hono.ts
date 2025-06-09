// deno-lint-ignore-file no-explicit-any
import { Hono } from "hono";

import { cors } from "hono/cors";
import { CORS, CorsOptions } from "../config/cors-config.ts";

export function createHonoServer(
  basePath: string,
  corsPaths?: {
    path: string;
    corsConfig: CorsOptions;
  }[],
) {
  const app = new Hono<{
    Variables: any;
  }>().basePath(basePath);
  // Handle cors
  if (corsPaths) {
    corsPaths.forEach(({ path, corsConfig }) => {
      app.use(path, cors(corsConfig));
    });
  } else {
    app.use("*", cors(CORS));
  }
  return app;
}
