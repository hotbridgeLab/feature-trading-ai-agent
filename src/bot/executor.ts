import { AGENT_DRY_RUN, SYMBOL } from "../env";
import type { FuturesExchange } from "../exchange/types";
import type { Position, StrategySignal } from "../types";
import { createLogger } from "../logger";
import { sizeFromRisk } from "../risk/position-size";

const log = createLogger("executor");

export async function execute(
  ex: FuturesExchange,
  signal: StrategySignal,
  price: number,
  equity: number,
  positions: Position[]
): Promise<void> {
  if (signal.action === "hold") return;

  if (signal.action === "exit") {
    if (!positions.length) { log.debug("exit with no position"); return; }
    for (const p of positions) {
      const req = { symbol: SYMBOL, side: (p.side === "long" ? "sell" : "buy") as "buy" | "sell", type: "market" as const, amount: p.size, reduceOnly: true };
      if (AGENT_DRY_RUN) { log.info("[dry-run] close", req); continue; }
      const res = await ex.placeOrder(req);
      log.info("closed", res.id, p.side);
    }
    return;
  }

  const amount = sizeFromRisk(equity, price);
  if (amount <= 0) { log.warn("zero size skip"); return; }
  const side = signal.action === "enter_long" ? "buy" : "sell";
  const req = { symbol: SYMBOL, side: side as "buy" | "sell", type: "market" as const, amount };
  if (AGENT_DRY_RUN) { log.info("[dry-run]", req, signal.reason); return; }
  const res = await ex.placeOrder(req);
  log.info("order", res.id, signal.source, signal.reason);
}
