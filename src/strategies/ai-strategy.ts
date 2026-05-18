import { TradingAgentService } from "../ai/agent-service";
import type { AgentStrategy } from "./types";
import type { StrategySignal } from "../types";
import type { MarketContext } from "../analysis/types";
import { createLogger } from "../logger";

const log = createLogger("ai-strategy");

export class AiStrategy implements AgentStrategy {
  readonly name = "ai";
  private readonly agent = new TradingAgentService();

  async evaluate(ctx: MarketContext): Promise<StrategySignal> {
    try {
      return await this.agent.decide(ctx);
    } catch (e) {
      log.warn("AI failed, holding:", e instanceof Error ? e.message : e);
      return { action: "hold", reason: "AI error", source: "ai" };
    }
  }
}
