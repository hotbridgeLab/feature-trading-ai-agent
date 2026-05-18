import { AI_MODEL, AI_MIN_CONFIDENCE, EXCHANGE, SYMBOL } from "../env";
import { formatMarketContextForPrompt } from "../analysis/format-context";
import type { MarketContext } from "../analysis/types";
import { SYSTEM_PROMPT } from "./prompts/system";
import { buildUserPrompt } from "./prompts/user";
import type { AiTradeDecision } from "./types";
import type { StrategySignal } from "../types";
import { OpenAiCompatibleClient } from "./openai-client";
import { parseAiDecision } from "./parse-decision";
import { createLogger } from "../logger";

const log = createLogger("ai-agent");

export class TradingAgentService {
  private readonly llm = new OpenAiCompatibleClient();

  async decide(ctx: MarketContext): Promise<StrategySignal> {
    const block = formatMarketContextForPrompt(ctx);
    const content = await this.llm.complete({
      model: AI_MODEL,
      messages: [
        { role: "system", content: SYSTEM_PROMPT },
        { role: "user", content: buildUserPrompt(block, EXCHANGE, SYMBOL) },
      ],
      temperature: 0.2,
      response_format: { type: "json_object" },
    });
    const decision: AiTradeDecision = parseAiDecision(content);
    log.info("AI decision", decision.action, "conf=", decision.confidence.toFixed(2));
    log.debug("AI reasoning:", decision.reasoning);
    if (decision.confidence < AI_MIN_CONFIDENCE && decision.action !== "hold") {
      return {
        action: "hold",
        reason: `AI confidence ${decision.confidence} below min ${AI_MIN_CONFIDENCE}`,
        confidence: decision.confidence,
        source: "ai",
      };
    }
    return {
      action: decision.action,
      reason: decision.reasoning,
      confidence: decision.confidence,
      source: "ai",
    };
  }
}
