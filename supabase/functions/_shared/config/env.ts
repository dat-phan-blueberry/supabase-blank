export const ENV = {
  supabase: {
    url: Deno.env.get("SUPABASE_URL") ?? "",
    serviceRoleKey: Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    jwtSecret: Deno.env.get("JWT_SECRET") ?? "",
  },
  cors: {
    allowOrigin: Deno.env.get("CORS_ALLOWED_ORIGINS") ?? "*",
  },
  sanity: {
    verifyPassword: Deno.env.get("SANITY_VERIFY_PASSWORD") ?? "",
    secret: Deno.env.get("SANITY_SECRET") ?? "",
  },
};
