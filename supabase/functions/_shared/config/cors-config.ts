import { ENV } from "./env.ts";

export type CorsOptions = {
  origin: string | string[];
  allowMethods?: string[];
  allowHeaders?: string[];
  maxAge?: number;
  credentials?: boolean;
  exposeHeaders?: string[];
};

export const CORS: CorsOptions = {
  origin: ENV.cors.allowOrigin.split(","),
  allowMethods: ["GET", "HEAD", "PUT", "POST", "DELETE", "PATCH", "OPTIONS"],
  allowHeaders: [
    "Content-Type",
    "Authorization",
    "x-client-info",
    "apikey",
    "x-verify-password",
  ],
  exposeHeaders: [],
};
