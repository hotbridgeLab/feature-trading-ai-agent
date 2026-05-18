import { ema } from "./ema";

export interface MacdPoint { macd: number; signal: number; histogram: number }

export function macd(closes: number[], fast = 12, slow = 26, sig = 9): MacdPoint[] {
  const ef = ema(closes, fast), es = ema(closes, slow);
  const off = slow - fast;
  const line: number[] = [];
  for (let i = 0; i < es.length; i++) { const fi = i + off; if (fi < ef.length) line.push(ef[fi] - es[i]); }
  const signal = ema(line, sig);
  const out: MacdPoint[] = [];
  for (let i = sig - 1; i < line.length; i++) {
    const m = line[i], s = signal[i - (sig - 1)];
    out.push({ macd: m, signal: s, histogram: m - s });
  }
  return out;
}
