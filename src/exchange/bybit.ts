import type { FuturesExchange } from "./types";
import type { Balance, Kline, OrderRequest, OrderResult, Position, Ticker } from "../types";
import { httpJson } from "../http/client";
import { bybitSign } from "./signing";
import { API_KEY, API_SECRET, TESTNET } from "../env";
import { AgentError } from "../errors";

const BASE = TESTNET ? "https://api-testnet.bybit.com" : "https://api.bybit.com";
const RECV = "5000";

function hdr(sign: string, ct?: string) {
  const ts = String(Date.now());
  return { "X-BAPI-API-KEY": API_KEY, "X-BAPI-TIMESTAMP": ts, "X-BAPI-SIGN": bybitSign(API_SECRET, ts + API_KEY + RECV + sign), "X-BAPI-RECV-WINDOW": RECV, ...(ct ? { "Content-Type": ct } : {}) };
}

function ok<T>(p: { retCode: number; retMsg: string; result: T }): T {
  if (p.retCode !== 0) throw new AgentError(`Bybit ${p.retCode}: ${p.retMsg}`);
  return p.result;
}

export class BybitFutures implements FuturesExchange {
  readonly id = "bybit";
  async fetchTicker(symbol: string): Promise<Ticker> {
    const d = ok(await httpJson<{ retCode: number; retMsg: string; result: { list: { symbol: string; lastPrice: string; bid1Price: string; ask1Price: string; volume24h: string }[] } }>(`${BASE}/v5/market/tickers?category=linear&symbol=${symbol}`));
    const t = d.list[0];
    return { symbol: t.symbol, last: +t.lastPrice, bid: +t.bid1Price, ask: +t.ask1Price, volume24h: +t.volume24h };
  }
  async fetchKlines(symbol: string, interval: string, limit: number): Promise<Kline[]> {
    const q = `category=linear&symbol=${symbol}&interval=${interval}&limit=${limit}`;
    const d = ok(await httpJson<{ retCode: number; retMsg: string; result: { list: string[][] } }>(`${BASE}/v5/market/kline?${q}`));
    return d.list.map((r) => ({ time: +r[0], open: +r[1], high: +r[2], low: +r[3], close: +r[4], volume: +r[5] }));
  }
  async fetchBalances(): Promise<Balance[]> {
    const q = "accountType=UNIFIED";
    const d = ok(await httpJson<{ retCode: number; retMsg: string; result: { list: { coin: { coin: string; equity: string; availableToWithdraw: string }[] }[] } }>(`${BASE}/v5/account/wallet-balance?${q}`, { headers: hdr(q) }));
    return (d.list[0]?.coin ?? []).map((c) => ({ asset: c.coin, equity: +c.equity, available: +c.availableToWithdraw }));
  }
  async fetchPositions(symbol?: string): Promise<Position[]> {
    const q = symbol ? `category=linear&symbol=${symbol}` : "category=linear";
    const d = ok(await httpJson<{ retCode: number; retMsg: string; result: { list: { symbol: string; side: string; size: string; avgPrice: string; unrealisedPnl: string; leverage: string }[] } }>(`${BASE}/v5/position/list?${q}`, { headers: hdr(q) }));
    return d.list.filter((p) => +p.size > 0).map((p) => ({ symbol: p.symbol, side: p.side === "Buy" ? "long" : "short", size: +p.size, entryPrice: +p.avgPrice, unrealizedPnl: +p.unrealisedPnl, leverage: +p.leverage }));
  }
  async setLeverage(symbol: string, leverage: number): Promise<void> {
    const body = JSON.stringify({ category: "linear", symbol, buyLeverage: String(leverage), sellLeverage: String(leverage) });
    ok(await httpJson(`${BASE}/v5/position/set-leverage`, { method: "POST", headers: hdr(body, "application/json"), body }));
  }
  async placeOrder(req: OrderRequest): Promise<OrderResult> {
    const body = JSON.stringify({ category: "linear", symbol: req.symbol, side: req.side === "buy" ? "Buy" : "Sell", orderType: req.type === "market" ? "Market" : "Limit", qty: String(req.amount), ...(req.reduceOnly ? { reduceOnly: true } : {}) });
    const d = ok(await httpJson<{ retCode: number; retMsg: string; result: { orderId: string } }>(`${BASE}/v5/order/create`, { method: "POST", headers: hdr(body, "application/json"), body }));
    return { id: d.orderId, status: "created" };
  }
  async cancelAll(symbol: string): Promise<void> {
    const body = JSON.stringify({ category: "linear", symbol });
    ok(await httpJson(`${BASE}/v5/order/cancel-all`, { method: "POST", headers: hdr(body, "application/json"), body }));
  }
}
