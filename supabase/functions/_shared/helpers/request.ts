import { Context, HonoRequest } from "hono";
import {
    ClientErrorStatusCode,
    InfoStatusCode,
    RedirectStatusCode,
    ServerErrorStatusCode,
    SuccessStatusCode,
} from "../constants/status-code.ts";

export type StatusCode =
    | InfoStatusCode
    | SuccessStatusCode
    | RedirectStatusCode
    | ClientErrorStatusCode
    | ServerErrorStatusCode;

export async function safeParseRequestBody<T>(
    body: HonoRequest<`${string}/submit`, any>,
): Promise<T | null> {
    try {
        return await body.json<T>();
    } catch (error) {
        return null;
    }
}

export class RequestResult {
    private context;
    constructor(c: Context) {
        this.context = c;
    }
    ErrorResponse = (payload: any, statusCode?: StatusCode) =>
        this.context.json(
            payload,
            statusCode ?? ClientErrorStatusCode.BadRequest,
        );
    SuccessResponse = (payload: any, statusCode?: StatusCode) =>
        this.context.json(payload, statusCode ?? SuccessStatusCode.OK);
}
