import type { FuturesExchange } from "./types";
import type { Balance, Kline, OrderRequest, OrderResult, Position, Ticker } from "../types";
import { httpJson } from "../http/client";
import { binanceSign } from "./signing";
import { API_KEY, API_SECRET, TESTNET } from "../env";

const BASE = TESTNET ? "https://testnet.binancefuture.com" : "https://fapi.binance.com";

function signedQuery(params: Record<string, string>): string {
  const qs = new URLSearchParams({ ...params, timestamp: String(Date.now()), recvWindow: "10000" });
  qs.set("signature", binanceSign(API_SECRET, qs.toString()));
  return qs.toString();
}

export class BinanceFutures implements FuturesExchange {
  readonly id = "binance";

  async fetchTicker(symbol: string): Promise<Ticker> {
    const d = await httpJson<{ symbol: string; lastPrice: string; bidPrice: string; askPrice: string; volume: string }>(
      `${BASE}/fapi/v1/ticker/24hr?symbol=${symbol}`
    );
    return { symbol: d.symbol, last: +d.lastPrice, bid: +d.bidPrice, ask: +d.askPrice, volume24h: +d.volume };
  }

  async fetchKlines(symbol: string, interval: string, limit: number): Promise<Kline[]> {
    const rows = await httpJson<(string | number)[][]>(`${BASE}/fapi/v1/klines?symbol=${symbol}&interval=${interval}&limit=${limit}`);
    return rows.map((r) => ({ time: +r[0], open: +r[1], high: +r[2], low: +r[3], close: +r[4], volume: +r[5] }));
  }

  async fetchBalances(): Promise<Balance[]> {
    const q = signedQuery({});
    const rows = await httpJson<{ asset: string; balance: string; availableBalance: string }[]>(
      `${BASE}/fapi/v2/balance?${q}`, { headers: { "X-MBX-APIKEY": API_KEY } }
    );
    return rows.map((b) => ({ asset: b.asset, equity: +b.balance, available: +b.availableBalance }));
  }

  async fetchPositions(symbol?: string): Promise<Position[]> {
    const q = signedQuery(symbol ? { symbol } : {});
    const rows = await httpJson<{ symbol: string; positionAmt: string; entryPrice: string; unRealizedProfit: string; leverage: string }[]>(
      `${BASE}/fapi/v2/positionRisk?${q}`, { headers: { "X-MBX-APIKEY": API_KEY } }
    );
    return rows.filter((p) => +p.positionAmt !== 0).map((p) => ({
      symbol: p.symbol, side: +p.positionAmt > 0 ? "long" : "short", size: Math.abs(+p.positionAmt),
      entryPrice: +p.entryPrice, unrealizedPnl: +p.unRealizedProfit, leverage: +p.leverage,
    }));
  }

  async setLeverage(symbol: string, leverage: number): Promise<void> {
    const q = signedQuery({ symbol, leverage: String(leverage) });
    await httpJson(`${BASE}/fapi/v1/leverage?${q}`, { method: "POST", headers: { "X-MBX-APIKEY": API_KEY } });
  }

  async placeOrder(req: OrderRequest): Promise<OrderResult> {
    const params: Record<string, string> = { symbol: req.symbol, side: req.side.toUpperCase(), type: req.type.toUpperCase(), quantity: String(req.amount) };
    if (req.type === "limit" && req.price) { params.price = String(req.price); params.timeInForce = "GTC"; }
    if (req.reduceOnly) params.reduceOnly = "true";
    const q = signedQuery(params);
    const d = await httpJson<{ orderId: number; status: string }>(`${BASE}/fapi/v1/order?${q}`, { method: "POST", headers: { "X-MBX-APIKEY": API_KEY } });
    return { id: String(d.orderId), status: d.status };
  }

  async cancelAll(symbol: string): Promise<void> {
    const q = signedQuery({ symbol });
    await httpJson(`${BASE}/fapi/v1/allOpenOrders?${q}`, { method: "DELETE", headers: { "X-MBX-APIKEY": API_KEY } });
  }
}
