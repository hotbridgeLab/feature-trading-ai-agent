import type { Balance } from "../types";
import { RISK_MAX_NOTIONAL, RISK_PCT } from "../env";

export function usdtEquity(balances: Balance[]): number {
  const u = balances.find((b) => b.asset === "USDT");
  return u?.equity ?? u?.available ?? 0;
}

export function sizeFromRisk(equity: number, price: number): number {
  if (price <= 0) return 0;
  const n = Math.min(equity * (RISK_PCT / 100), RISK_MAX_NOTIONAL);
  return Math.max(0.001, Math.floor((n / price) * 1000) / 1000);
}
