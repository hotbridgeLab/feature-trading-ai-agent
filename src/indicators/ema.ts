export function ema(v: number[], period: number): number[] {
  if (v.length < period) return [];
  const k = 2 / (period + 1);
  const out: number[] = [];
  let p = v.slice(0, period).reduce((a, b) => a + b, 0) / period;
  out.push(p);
  for (let i = period; i < v.length; i++) { p = v[i] * k + p * (1 - k); out.push(p); }
  return out;
}
