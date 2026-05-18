export function sma(v: number[], period: number): number[] {
  if (period < 1 || v.length < period) return [];
  const out: number[] = [];
  let s = 0;
  for (let i = 0; i < v.length; i++) {
    s += v[i];
    if (i >= period) s -= v[i - period];
    if (i >= period - 1) out.push(s / period);
  }
  return out;
}
