import { formatError } from "../errors";
import { AGENT_DRY_RUN, AGENT_POLL_MS, LEVERAGE, SYMBOL } from "../env";
import type { Balance, Position } from "../types";
import { createExchange } from "../exchange/registry";
import { resolveStrategy } from "../strategies";
import { buildTechnicalSnapshot } from "../analysis/build-snapshot";
import type { MarketContext } from "../analysis/types";
import { usdtEquity } from "../risk/position-size";
import { checkRisk } from "../risk/manager";
import { buildAgentSnapshot } from "../portfolio/snapshot";
import { execute } from "./executor";
import { createLogger } from "../logger";
import { sleep, retry } from "../backoff";
import { shouldStop } from "../signals";

const log = createLogger("runner");

export async function runAgentLoop(): Promise<void> {
  const ex = createExchange();
  const strategy = resolveStrategy();
  log.info(`exchange=${ex.id} strategy=${strategy.name} symbol=${SYMBOL}`);

  try {
    await retry(() => ex.setLeverage(SYMBOL, LEVERAGE));
    log.info(`leverage set to ${LEVERAGE}x on ${SYMBOL}`);
  } catch (e) {
    log.warn(
      "setLeverage failed; continuing (leverage may already be configured):",
      e instanceof Error ? e.message : e
    );
  }

  while (!shouldStop()) {
    try {
      const [ticker, klines] = await Promise.all([
        ex.fetchTicker(SYMBOL),
        ex.fetchKlines(SYMBOL, "15m", 120),
      ]);

      let positions: Position[] = [];
      let balances: Balance[] = [];
      try {
        [positions, balances] = await Promise.all([
          ex.fetchPositions(SYMBOL),
          ex.fetchBalances(),
        ]);
      } catch (authErr) {
        if (!AGENT_DRY_RUN) throw authErr;
        log.warn(
          "private endpoints unavailable; dry-run continues with synthetic USDT equity:",
          formatError(authErr)
        );
        balances = [{ asset: "USDT", equity: 1000, available: 1000 }];
      }
      const equity = usdtEquity(balances);
      const technical = buildTechnicalSnapshot(SYMBOL, klines, positions);
      const ctx: MarketContext = { ticker, klines, positions, technical, equityUsdt: equity };
      const snap = buildAgentSnapshot(ticker, technical, balances, positions, equity);
      log.debug("equity", snap.equityUsdt.toFixed(2), "exposure", snap.exposureUsdt.toFixed(2));

      const signal = await strategy.evaluate(ctx);
      const risk = checkRisk(signal, positions, equity);
      if (risk.ok) await execute(ex, signal, ticker.last, equity, positions);
      else if (signal.action !== "hold") log.warn("blocked", risk.reason);
    } catch (e) {
      log.error("tick failed:", formatError(e));
    }
    if (shouldStop()) break;
    await sleep(AGENT_POLL_MS);
  }
}
