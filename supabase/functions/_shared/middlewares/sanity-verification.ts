import { Context, Next } from "hono";
import { ENV } from "../config/env.ts";

export const sanityVerifyMiddleware = async (ctx: Context, next: Next) => {
  const verifyPassword = ctx.req.header("x-verify-password");

  if (!verifyPassword || verifyPassword !== ENV.sanity.verifyPassword) {
    return ctx.json({ message: "Unauthorized" }, 401);
  }
  await next();
};
