import type { FuturesExchange } from "./types";
import type { Balance, Kline, OrderRequest, OrderResult, Position, Ticker } from "../types";
import { httpJson } from "../http/client";
import { hmacSha256 } from "./signing";
import { API_KEY, API_SECRET } from "../env";
import { AgentError } from "../errors";

const BASE = "https://contract.mexc.com";
interface Env<T> { success: boolean; data?: T; message?: string; code?: number }

function hdr(body?: string) {
  const ts = Date.now().toString();
  return { ApiKey: API_KEY, "Request-Time": ts, Signature: hmacSha256(API_SECRET, API_KEY + ts + (body ?? "")), "Content-Type": "application/json" };
}
function unwrap<T>(p: Env<T>): T {
  if (!p.success) throw new AgentError(p.message ?? "MEXC error", { code: p.code !== undefined ? String(p.code) : undefined });
  if (p.data === undefined) throw new AgentError("MEXC missing data");
  return p.data;
}

export class MexcFutures implements FuturesExchange {
  readonly id = "mexc";
  async fetchTicker(symbol: string): Promise<Ticker> {
    const d = unwrap(await httpJson<Env<{ lastPrice: number; symbol: string }>>(`${BASE}/api/v1/contract/ticker?symbol=${symbol}`, { headers: hdr() }));
    return { symbol: d.symbol, last: d.lastPrice, bid: d.lastPrice, ask: d.lastPrice, volume24h: 0 };
  }
  async fetchKlines(symbol: string, interval: string, limit: number): Promise<Kline[]> {
    const rows = unwrap(await httpJson<Env<number[][]>>(`${BASE}/api/v1/contract/kline/${symbol}?interval=${interval}&limit=${limit}`, { headers: hdr() }));
    return rows.map((r) => ({ time: r[0], open: r[1], close: r[2], high: r[3], low: r[4], volume: r[5] }));
  }
  async fetchBalances(): Promise<Balance[]> {
    const rows = unwrap(await httpJson<Env<{ currency: string; equity: number; availableBalance: number }[]>>(`${BASE}/api/v1/private/account/assets`, { headers: hdr() }));
    return rows.map((a) => ({ asset: a.currency, equity: a.equity, available: a.availableBalance }));
  }
  async fetchPositions(symbol?: string): Promise<Position[]> {
    const q = symbol ? `?symbol=${symbol}` : "";
    const rows = unwrap(await httpJson<Env<{ symbol: string; holdVol: number; holdAvgPrice: number; unrealised: number; leverage: number; positionType: number }[]>>(`${BASE}/api/v1/private/position/open_positions${q}`, { headers: hdr() }));
    return rows.filter((p) => p.holdVol > 0).map((p) => ({ symbol: p.symbol, side: p.positionType === 1 ? "long" : "short", size: p.holdVol, entryPrice: p.holdAvgPrice, unrealizedPnl: p.unrealised, leverage: p.leverage }));
  }
  async setLeverage(symbol: string, leverage: number): Promise<void> {
    const body = JSON.stringify({ symbol, leverage, openType: 1 });
    unwrap(await httpJson<Env<unknown>>(`${BASE}/api/v1/private/position/change_leverage`, { method: "POST", headers: hdr(body), body }));
  }
  async placeOrder(req: OrderRequest): Promise<OrderResult> {
    const body = JSON.stringify({ symbol: req.symbol, vol: req.amount, side: req.side === "buy" ? (req.reduceOnly ? 4 : 1) : req.reduceOnly ? 2 : 3, type: req.type === "market" ? 5 : 1, openType: 1, price: req.price ?? 0 });
    const d = unwrap(await httpJson<Env<{ orderId: string }>>(`${BASE}/api/v1/private/order/submit`, { method: "POST", headers: hdr(body), body }));
    return { id: d.orderId, status: "submitted" };
  }
  async cancelAll(symbol: string): Promise<void> {
    const body = JSON.stringify({ symbol });
    unwrap(await httpJson<Env<unknown>>(`${BASE}/api/v1/private/order/cancel_all`, { method: "POST", headers: hdr(body), body }));
  }
}
