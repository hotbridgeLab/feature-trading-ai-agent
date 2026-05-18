export function atr(h: number[], l: number[], c: number[], period = 14): number[] {
  if (c.length < period + 1) return [];
  const trs: number[] = [];
  for (let i = 1; i < c.length; i++) trs.push(Math.max(h[i] - l[i], Math.abs(h[i] - c[i - 1]), Math.abs(l[i] - c[i - 1])));
  const out: number[] = [];
  let s = trs.slice(0, period).reduce((a, b) => a + b, 0);
  out.push(s / period);
  for (let i = period; i < trs.length; i++) { s = (s * (period - 1) + trs[i]) / period; out.push(s); }
  return out;
}
