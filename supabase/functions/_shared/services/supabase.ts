import { createClient, SupabaseClientOptions } from "@supabase/supabase-js";
import { ENV } from "../config/env.ts";

export const createSupabaseClient = (
    option?: SupabaseClientOptions<"public">,
) => createClient(
    ENV.supabase.url!,
    ENV.supabase.serviceRoleKey!,
    option,
);
