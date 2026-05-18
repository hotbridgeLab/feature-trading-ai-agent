import type { Balance, Position, Ticker } from "../types";
import type { TechnicalSnapshot } from "../analysis/types";

export interface AgentSnapshot {
  at: number;
  ticker: Ticker;
  technical: TechnicalSnapshot;
  equityUsdt: number;
  exposureUsdt: number;
  positions: Position[];
}

export function buildAgentSnapshot(
  ticker: Ticker,
  technical: TechnicalSnapshot,
  balances: Balance[],
  positions: Position[],
  equityUsdt: number
): AgentSnapshot {
  return {
    at: Date.now(),
    ticker,
    technical,
    equityUsdt,
    exposureUsdt: positions.reduce((s, p) => s + p.size * p.entryPrice, 0),
    positions,
  };
}
