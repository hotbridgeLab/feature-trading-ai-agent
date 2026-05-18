import { AiStrategy } from "./ai-strategy";
import { rulesFallbackStrategy } from "./rules-fallback";
import type { AgentStrategy } from "./types";
import type { StrategySignal } from "../types";
import type { MarketContext } from "../analysis/types";
import { createLogger } from "../logger";

const log = createLogger("hybrid");

export class HybridStrategy implements AgentStrategy {
  readonly name = "hybrid";
  private readonly ai = new AiStrategy();

  async evaluate(ctx: MarketContext): Promise<StrategySignal> {
    const aiSignal = await this.ai.evaluate(ctx);
    if (aiSignal.action !== "hold") return aiSignal;
    const ruleSignal = rulesFallbackStrategy.evaluate(ctx);
    if (ruleSignal.action !== "hold") {
      log.info("Hybrid using rules fallback:", ruleSignal.reason);
    }
    return ruleSignal;
  }
}
