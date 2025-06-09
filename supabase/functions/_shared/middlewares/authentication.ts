import { Context, Next } from "hono";
import { verify } from "hono/jwt";
import { ENV } from "../config/env.ts";

export const authMiddleware = async (ctx: Context, next: Next) => {
  const authHeader = ctx.req.header("Authorization");

  if (!authHeader?.startsWith("Bearer ")) {
    return ctx.json({ message: "Unauthorized" }, 401);
  }
  const token = authHeader.split(" ")[1];

  try {
    const payload = (await verify(token, ENV.supabase.jwtSecret)) as any;
    if (payload?.role !== "authenticated") {
      return ctx.json({ message: "Unauthorized" }, 401);
    }

    ctx.set("user", {
      sessionId: payload.session_id,
      userId: payload.sub,
      email: payload.email,
      role: payload.role,
      appMetadata: payload.app_metadata,
      userMetadata: payload.user_metadata,
    });
    await next();
  } catch (error) {
    console.error("Token verification failed:", error);
    return ctx.json({ message: "Unauthorized" }, 401);
  }
};
