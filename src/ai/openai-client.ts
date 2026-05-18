import { request } from "undici";
import { Buffer } from "node:buffer";
import { AI_API_KEY, AI_BASE_URL } from "../env";
import { AgentError } from "../errors";
import type { LlmCompletionRequest } from "./types";
import type { LlmClient } from "./llm-client";
import { createLogger } from "../logger";

const log = createLogger("llm");

export class OpenAiCompatibleClient implements LlmClient {
  async complete(req: LlmCompletionRequest): Promise<string> {
    const body = JSON.stringify({
      model: req.model,
      messages: req.messages,
      temperature: req.temperature ?? 0.2,
      response_format: req.response_format,
    });
    const res = await request(`${AI_BASE_URL}/chat/completions`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${AI_API_KEY}`,
        "Content-Type": "application/json",
      },
      body,
      headersTimeout: 60000,
      bodyTimeout: 60000,
    });
    const text = Buffer.from(await res.body.arrayBuffer()).toString("utf8");
    if (res.statusCode < 200 || res.statusCode >= 300) {
      log.error("LLM HTTP", res.statusCode, text.slice(0, 200));
      throw new AgentError(`LLM HTTP ${res.statusCode}`, { code: text.slice(0, 200) });
    }
    const parsed = JSON.parse(text) as { choices?: { message?: { content?: string } }[] };
    const content = parsed.choices?.[0]?.message?.content;
    if (!content) throw new AgentError("LLM response missing content");
    return content;
  }
}
