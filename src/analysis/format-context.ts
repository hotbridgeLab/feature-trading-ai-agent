import type { MarketContext } from "./types";

export function formatMarketContextForPrompt(ctx: MarketContext): string {
  const t = ctx.technical;
  return [
    `Symbol: ${t.symbol}`,
    `Price: ${t.price}`,
    `Trend: ${t.trend}`,
    `RSI(14): ${t.rsi14.toFixed(2)}`,
    `SMA20: ${t.sma20.toFixed(2)} SMA50: ${t.sma50.toFixed(2)}`,
    `MACD histogram: ${t.macdHistogram.toFixed(4)}`,
    `ATR(14): ${t.atr14.toFixed(2)}`,
    `Positions: ${t.positionSummary}`,
    `Equity USDT: ${ctx.equityUsdt.toFixed(2)}`,
    `24h volume: ${ctx.ticker.volume24h}`,
  ].join("\n");
}
