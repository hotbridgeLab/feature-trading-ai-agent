import { RISK_MAX_NOTIONAL } from "../env";
import type { Position, StrategySignal } from "../types";
import { createLogger } from "../logger";

const log = createLogger("risk");

export interface RiskVerdict { ok: boolean; reason: string }

export function checkRisk(signal: StrategySignal, positions: Position[], equity: number): RiskVerdict {
  if (signal.action === "hold") return { ok: true, reason: "hold" };
  if (equity < 20) return { ok: false, reason: "equity too low" };
  const notional = positions.reduce((s, p) => s + p.size * p.entryPrice, 0);
  if (signal.action.startsWith("enter") && notional >= RISK_MAX_NOTIONAL) {
    log.warn("max notional block");
    return { ok: false, reason: "max notional" };
  }
  return { ok: true, reason: "ok" };
}
