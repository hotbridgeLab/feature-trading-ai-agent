import { Buffer } from "node:buffer";
import { request } from "undici";
import { AgentError } from "../errors";
import { decodeBody, firstHeader } from "./decode-body";

export interface HttpInit {
  method?: string;
  headers?: Record<string, string>;
  body?: string;
  timeoutMs?: number;
}

export async function httpJson<T>(url: string, init: HttpInit = {}): Promise<T> {
  let res;
  try {
    res = await request(url, {
      method: init.method ?? "GET",
      headers: init.headers,
      body: init.body,
      headersTimeout: init.timeoutMs ?? 20000,
      bodyTimeout: init.timeoutMs ?? 20000,
    });
  } catch (e) {
    throw new AgentError(`HTTP failed: ${e instanceof Error ? e.message : e}`);
  }
  const raw = Buffer.from(await res.body.arrayBuffer());
  const text = decodeBody(raw, firstHeader(res.headers["content-encoding"]));
  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw new AgentError(`HTTP ${res.statusCode}`, { status: res.statusCode, code: text.slice(0, 300) });
  }
  try {
    return JSON.parse(text) as T;
  } catch {
    throw new AgentError("Invalid JSON response", { code: text.slice(0, 300) });
  }
}
