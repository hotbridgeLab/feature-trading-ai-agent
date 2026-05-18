import type { Kline, Position, Ticker } from "../types";

export interface TechnicalSnapshot {
  symbol: string;
  price: number;
  rsi14: number;
  sma20: number;
  sma50: number;
  macdHistogram: number;
  atr14: number;
  trend: "up" | "down" | "flat";
  positionSummary: string;
}

export interface MarketContext {
  ticker: Ticker;
  klines: Kline[];
  positions: Position[];
  technical: TechnicalSnapshot;
  equityUsdt: number;
}
