import type { MarketContext } from "../analysis/types";
import type { StrategySignal } from "../types";

export interface AgentStrategy {
  readonly name: string;
  evaluate(ctx: MarketContext): Promise<StrategySignal>;
}
