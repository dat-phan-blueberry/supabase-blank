// deno-lint-ignore-file no-explicit-any
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createHonoServer } from "../_shared/helpers/hono.ts";
import { RequestResult } from "../_shared/helpers/request.ts";
import { createSupabaseClient } from "../_shared/services/supabase.ts";
import { sanityVerifyMiddleware } from "../_shared/middlewares/sanity-verification.ts";

const app = createHonoServer("/membership");

app.get("/", async (c) => {
  const result = new RequestResult(c);
  try {
    const supabase = createSupabaseClient();

    const { data, error } = await supabase
      .from("user_membership")
      .select(
        `
        id,
        name,
        description,
        additional_info,
        created_at,
        active
        `,
      )
      .eq("active", true);

    if (error) throw error;

    return result.SuccessResponse({
      message: "Fetched membership data successfully",
      data,
    });
  } catch (error: any) {
    return result.ErrorResponse({
      message: error.message || "Failed to fetch membership data",
    });
  }
});
app.get("/price", async (c) => {
  const result = new RequestResult(c);
  try {
    const supabase = createSupabaseClient();
    const membershipId = c.req.query("membership_id");

    const { data, error } = await supabase
      .from("user_membership_price")
      .select(
        `
          id,
          name,
          description,
          payment_type,
          final_price,
          created_at,
          payment_interval,
          provider,
          user_membership,
          active
        `,
      )
      .eq("user_membership", membershipId)
      .eq("active", true);

    if (error) throw error;

    return result.SuccessResponse({
      message: "Fetched membership prices data successfully",
      data,
    });
  } catch (error: any) {
    return result.ErrorResponse({
      message: error.message || "Failed to fetch membership prices data",
    });
  }
});
app.put("/sync", sanityVerifyMiddleware, async (c) => {
  const result = new RequestResult(c);
  try {
    const body = await c.req.json();
    console.log(body);
    if (!body) {
      return result.SuccessResponse({
        message: "Body not found. skip!",
      });
    }

    const { prices, ...membershipData } = body;
    if (!membershipData.id) {
      return result.ErrorResponse({
        message: "Membership id not found",
      });
    }

    const supabase = createSupabaseClient();

    await Promise.all([
      // Update user_membership
      supabase.from("user_membership").update({
        name: membershipData.name,
        description: membershipData.description,
        active: membershipData.active,
        additional_info: membershipData.additional_info,
        created_at: membershipData.created_at,
      }).eq("id", membershipData.id),

      // Update user_membership_price
      ...((prices ?? []).map((p: any) =>
        supabase.from("user_membership_price").update({
          name: p.name,
          description: p.description,
          active: p.active,
        }).eq("id", p.id)
      )),
    ]);

    return result.SuccessResponse({
      message: "Update membership successfully",
    });
  } catch (error: any) {
    return result.ErrorResponse({
      message: error.message || "Failed to update membership",
    });
  }
});

Deno.serve(app.fetch);
