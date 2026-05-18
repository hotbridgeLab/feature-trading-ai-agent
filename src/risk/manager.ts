import { RISK_MAX_NOTIONAL, AI_MIN_CONFIDENCE } from "../env";
import type { Position, StrategySignal } from "../types";
import { createLogger } from "../logger";

const log = createLogger("risk");

export interface RiskVerdict { ok: boolean; reason: string }

export function checkRisk(signal: StrategySignal, positions: Position[], equity: number): RiskVerdict {
  if (signal.action === "hold") return { ok: true, reason: "hold" };
  if (equity < 20) return { ok: false, reason: "equity too low" };
  if (signal.source === "ai" && signal.confidence !== undefined && signal.confidence < AI_MIN_CONFIDENCE) {
    return { ok: false, reason: "ai confidence gate" };
  }
  const notional = positions.reduce((s, p) => s + p.size * p.entryPrice, 0);
  if (signal.action.startsWith("enter") && notional >= RISK_MAX_NOTIONAL) {
    log.warn("max notional block");
    return { ok: false, reason: "max notional" };
  }
  return { ok: true, reason: "ok" };
}
