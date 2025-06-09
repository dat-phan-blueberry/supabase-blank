import { Context, Next } from "hono";
import { AnyZodObject, ZodError } from "zod";

export interface ValidatorSchemas {
  body?: AnyZodObject;
  query?: AnyZodObject;
  params?: AnyZodObject;
}

/**
 * Middleware to validate request parts (body, query, params) using Zod schemas.
 * On failure, returns 400 with errors; on success, attaches `validated` object to context state.
 */
export const requestValidator = (schemas: ValidatorSchemas) => {
  return async (ctx: Context, next: Next) => {
    const errors: Record<string, any> = {};
    const validated: Record<string, any> = {};

    // Validate params
    if (schemas.params) {
      const rawParams: Record<string, string> = {};
      for (const key of Object.keys(schemas.params.shape)) {
        rawParams[key] = ctx.req.param(key) as string;
      }
      const result = schemas.params.safeParse(rawParams);
      if (!result.success) {
        errors.params = result.error.format();
      } else {
        validated.params = result.data;
      }
    }

    // Validate query
    if (schemas.query) {
      const rawQuery = ctx.req.query();
      const result = schemas.query.safeParse(rawQuery);
      if (!result.success) {
        errors.query = result.error.format();
      } else {
        validated.query = result.data;
      }
    }

    // Validate body
    if (schemas.body) {
      let rawBody: any;
      try {
        rawBody = await ctx.req.json();
      } catch (e) {
        errors.body = { _errors: ["Invalid JSON body"] };
      }
      if (rawBody !== undefined) {
        const result = schemas.body.safeParse(rawBody);
        if (!result.success) {
          errors.body = result.error.format();
        } else {
          validated.body = result.data;
        }
      }
    }

    // If any errors, respond
    if (Object.keys(errors).length > 0) {
      return ctx.json(
        { message: "Validation failed", errors },
        400,
      );
    }

    // Attach validated data and proceed
    ctx.set("validated", validated);
    await next();
  };
};
