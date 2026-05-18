import { sma } from "../indicators/sma";
import { rsi } from "../indicators/rsi";
import { macd } from "../indicators/macd";
import { atr } from "../indicators/atr";
import type { Kline, Position } from "../types";
import type { TechnicalSnapshot } from "./types";

export function buildTechnicalSnapshot(symbol: string, klines: Kline[], positions: Position[]): TechnicalSnapshot {
  const closes = klines.map((k) => k.close);
  const price = closes[closes.length - 1] ?? 0;
  const rs = rsi(closes, 14);
  const s20 = sma(closes, 20);
  const s50 = sma(closes, 50);
  const m = macd(closes);
  const a = atr(klines.map((k) => k.high), klines.map((k) => k.low), closes, 14);
  const sma20 = s20[s20.length - 1] ?? price;
  const sma50 = s50[s50.length - 1] ?? price;
  let trend: "up" | "down" | "flat" = "flat";
  if (sma20 > sma50 * 1.002) trend = "up";
  else if (sma20 < sma50 * 0.998) trend = "down";
  const pos = positions.length
    ? positions.map((p) => `${p.side} ${p.size}@${p.entryPrice}`).join(", ")
    : "flat";
  return {
    symbol,
    price,
    rsi14: rs[rs.length - 1] ?? 50,
    sma20,
    sma50,
    macdHistogram: m[m.length - 1]?.histogram ?? 0,
    atr14: a[a.length - 1] ?? 0,
    trend,
    positionSummary: pos,
  };
}
