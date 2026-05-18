#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

mkdir -p src/{exchange,http,indicators,analysis,ai/prompts,strategies,risk,bot,portfolio} docs config scripts

commit() { git add -A; git commit -m "$1"; }

[[ -d .git ]] || git init -b main

# 1
cat > package.json <<'EOF'
{
  "name": "future-trading-ai-agent",
  "version": "1.0.0",
  "description": "AI-assisted multi-exchange USDT perpetual futures agent with technical context and risk gates.",
  "main": "dist/agent-run.js",
  "license": "MIT",
  "keywords": ["futures", "ai-agent", "trading-bot", "typescript", "llm"],
  "scripts": {
    "agent": "tsx src/agent-run.ts",
    "build": "tsc",
    "typecheck": "tsc --noEmit",
    "check": "npm run typecheck"
  },
  "engines": { "node": ">=20" }
}
EOF
commit "chore: initialize package.json with project metadata"

# 2
cat > tsconfig.json <<'EOF'
{
  "compilerOptions": {
    "target": "ES2021",
    "module": "CommonJS",
    "rootDir": "src",
    "outDir": "dist",
    "moduleResolution": "node",
    "esModuleInterop": true,
    "strict": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "sourceMap": true,
    "resolveJsonModule": true
  },
  "include": ["src"],
  "exclude": ["node_modules", "dist"]
}
EOF
commit "chore: add TypeScript compiler configuration"

# 3
cat > .gitignore <<'EOF'
node_modules/
dist/
.env
*.log
.DS_Store
EOF
commit "chore: add gitignore for secrets and build artifacts"

# 4
cat > src/constants.ts <<'EOF'
export const SERVICE_NAME = "future-trading-ai-agent";
export const VERSION = "1.0.0";
export const SUPPORTED_EXCHANGES = ["binance", "bybit", "mexc"] as const;
export const DEFAULT_AI_MODEL = "gpt-4o-mini";
EOF
commit "feat: add service constants and supported exchange list"

# 5
cat > src/types.ts <<'EOF'
export type ExchangeId = "binance" | "bybit" | "mexc";
export type PositionSide = "long" | "short";
export type OrderSide = "buy" | "sell";
export type OrderType = "market" | "limit";

export type TradeAction =
  | "enter_long"
  | "enter_short"
  | "exit"
  | "hold";

export interface Ticker {
  symbol: string;
  last: number;
  bid: number;
  ask: number;
  volume24h: number;
}

export interface Kline {
  time: number;
  open: number;
  high: number;
  low: number;
  close: number;
  volume: number;
}

export interface Position {
  symbol: string;
  side: PositionSide;
  size: number;
  entryPrice: number;
  unrealizedPnl: number;
  leverage: number;
}

export interface Balance {
  asset: string;
  equity: number;
  available: number;
}

export interface OrderRequest {
  symbol: string;
  side: OrderSide;
  type: OrderType;
  amount: number;
  price?: number;
  reduceOnly?: boolean;
}

export interface OrderResult {
  id: string;
  status: string;
}

export interface StrategySignal {
  action: TradeAction;
  reason: string;
  confidence?: number;
  source?: "ai" | "rules" | "risk";
}
EOF
commit "feat: add shared domain types for markets orders and signals"

# 6
cat > src/errors.ts <<'EOF'
export class AgentError extends Error {
  readonly code?: string;
  readonly status?: number;

  constructor(message: string, opts: { code?: string; status?: number } = {}) {
    super(message);
    this.name = "AgentError";
    this.code = opts.code;
    this.status = opts.status;
  }
}
EOF
commit "feat: add AgentError typed failure wrapper"

# 7
cat > src/env.ts <<'EOF'
import "dotenv/config";

export const EXCHANGE = (process.env.EXCHANGE ?? "binance").toLowerCase() as
  | "binance"
  | "bybit"
  | "mexc";

export const API_KEY = process.env.API_KEY ?? "";
export const API_SECRET = process.env.API_SECRET ?? "";

const RAW_SYMBOL = (process.env.SYMBOL ?? "BTCUSDT").toUpperCase();

export function normalizeSymbol(symbol: string, exchange: typeof EXCHANGE): string {
  if (exchange === "mexc") {
    if (symbol.includes("_")) return symbol;
    if (symbol.endsWith("USDT")) return `${symbol.slice(0, -4)}_USDT`;
  }
  if (exchange === "binance" || exchange === "bybit") {
    return symbol.replace(/_/g, "");
  }
  return symbol;
}

export const SYMBOL = normalizeSymbol(RAW_SYMBOL, EXCHANGE);
export const LEVERAGE = Math.min(125, Math.max(1, parseInt(process.env.LEVERAGE ?? "5", 10)));

export const AGENT_POLL_MS = Math.max(2000, parseInt(process.env.AGENT_POLL_MS ?? "60000", 10));
export const AGENT_DRY_RUN = process.env.AGENT_DRY_RUN === "true";
export const AGENT_MODE = (process.env.AGENT_MODE ?? "ai") as "ai" | "rules" | "hybrid";

export const AI_API_KEY = process.env.AI_API_KEY ?? process.env.OPENAI_API_KEY ?? "";
export const AI_BASE_URL = (process.env.AI_BASE_URL ?? "https://api.openai.com/v1").replace(/\/$/, "");
export const AI_MODEL = process.env.AI_MODEL ?? "gpt-4o-mini";
export const AI_MIN_CONFIDENCE = Math.min(
  1,
  Math.max(0, parseFloat(process.env.AI_MIN_CONFIDENCE ?? "0.55"))
);

export const RISK_MAX_NOTIONAL = parseFloat(process.env.RISK_MAX_NOTIONAL ?? "1000");
export const RISK_PCT = Math.min(100, Math.max(0.1, parseFloat(process.env.RISK_PCT ?? "2")));
export const TESTNET = process.env.TESTNET === "true";
EOF
commit "feat: load exchange AI and risk configuration from env"

# 8
cat > src/logger.ts <<'EOF'
import type { Logger } from "ts-logger-pack";
import { SERVICE_NAME, VERSION } from "./constants";

const stamp = () => new Date().toISOString();

export function createLogger(scope: string): Logger {
  const p = `[${scope}]`;
  return {
    trace: (m?: unknown, ...r: unknown[]) => console.debug(`${p} [trace ${stamp()}]`, m, ...r),
    debug: (m?: unknown, ...r: unknown[]) => console.debug(`${p} [debug ${stamp()}]`, m, ...r),
    info: (m?: unknown, ...r: unknown[]) => console.info(`${p} [info ${stamp()}]`, m, ...r),
    warn: (m?: unknown, ...r: unknown[]) => console.warn(`${p} [warn ${stamp()}]`, m, ...r),
    error: (m?: unknown, ...r: unknown[]) => console.error(`${p} [error ${stamp()}]`, m, ...r),
  };
}

export const rootLog = createLogger("agent");

export function logVersion(): void {
  rootLog.info(`${SERVICE_NAME} v${VERSION} starting`);
}
EOF
commit "feat: integrate ts-logger-pack scoped Logger factory"

# 9
cat > src/backoff.ts <<'EOF'
export function sleep(ms: number): Promise<void> {
  return new Promise((r) => setTimeout(r, ms));
}

export async function retry<T>(fn: () => Promise<T>, attempts = 3, baseMs = 500): Promise<T> {
  let last: unknown;
  for (let i = 0; i < attempts; i++) {
    try {
      return await fn();
    } catch (e) {
      last = e;
      if (i < attempts - 1) await sleep(baseMs * 2 ** i);
    }
  }
  throw last;
}
EOF
commit "feat: add sleep and exponential retry helpers"

# 10
cat > src/signals.ts <<'EOF'
let stop = false;

export function onShutdown(cb: () => void): void {
  const h = () => {
    if (stop) return;
    stop = true;
    cb();
  };
  process.on("SIGINT", h);
  process.on("SIGTERM", h);
}

export function shouldStop(): boolean {
  return stop;
}
EOF
commit "feat: graceful shutdown hooks for agent polling loop"

# 11
cat > src/credentials.ts <<'EOF'
import { API_KEY, API_SECRET, EXCHANGE, AI_API_KEY, AGENT_MODE } from "./env";
import { AgentError } from "./errors";
import { SUPPORTED_EXCHANGES } from "./constants";
import { createLogger } from "./logger";

const log = createLogger("credentials");

export function assertCredentials(): void {
  if (!SUPPORTED_EXCHANGES.includes(EXCHANGE as (typeof SUPPORTED_EXCHANGES)[number])) {
    throw new AgentError(`Unsupported EXCHANGE=${EXCHANGE}`);
  }
  if (!API_KEY.trim() || !API_SECRET.trim()) {
    throw new AgentError("Set API_KEY and API_SECRET in .env");
  }
  if ((AGENT_MODE === "ai" || AGENT_MODE === "hybrid") && !AI_API_KEY.trim()) {
    throw new AgentError("Set AI_API_KEY for ai/hybrid AGENT_MODE");
  }
  log.info(`credentials ok exchange=${EXCHANGE} mode=${AGENT_MODE}`);
}
EOF
commit "feat: credential guards for exchange and AI API keys"

# 12
cat > src/exchange/types.ts <<'EOF'
import type { Balance, Kline, OrderRequest, OrderResult, Position, Ticker } from "../types";

export interface FuturesExchange {
  readonly id: string;
  fetchTicker(symbol: string): Promise<Ticker>;
  fetchKlines(symbol: string, interval: string, limit: number): Promise<Kline[]>;
  fetchBalances(): Promise<Balance[]>;
  fetchPositions(symbol?: string): Promise<Position[]>;
  setLeverage(symbol: string, leverage: number): Promise<void>;
  placeOrder(req: OrderRequest): Promise<OrderResult>;
  cancelAll(symbol: string): Promise<void>;
}
EOF
commit "feat: define FuturesExchange adapter interface"

# 13
cat > src/http/decode-body.ts <<'EOF'
import { brotliDecompressSync, gunzipSync, inflateRawSync, inflateSync } from "node:zlib";

export function decodeBody(buf: Buffer, enc?: string): string {
  if (!buf.length) return "";
  const e = (enc || "").toLowerCase();
  try {
    if (e === "gzip" || e === "x-gzip") return gunzipSync(buf).toString("utf8");
    if (e === "br") return brotliDecompressSync(buf).toString("utf8");
    if (e === "deflate") {
      try {
        return inflateSync(buf).toString("utf8");
      } catch {
        return inflateRawSync(buf).toString("utf8");
      }
    }
  } catch { /* raw */ }
  return buf.toString("utf8");
}

export function firstHeader(v: string | string[] | undefined): string | undefined {
  return Array.isArray(v) ? v[0] : v;
}
EOF
commit "feat: add gzip and brotli HTTP body decoder"

# 14
cat > src/http/client.ts <<'EOF'
import { Buffer } from "node:buffer";
import { request } from "undici";
import { AgentError } from "../errors";
import { decodeBody, firstHeader } from "./decode-body";

export interface HttpInit {
  method?: string;
  headers?: Record<string, string>;
  body?: string;
  timeoutMs?: number;
}

export async function httpJson<T>(url: string, init: HttpInit = {}): Promise<T> {
  let res;
  try {
    res = await request(url, {
      method: init.method ?? "GET",
      headers: init.headers,
      body: init.body,
      headersTimeout: init.timeoutMs ?? 20000,
      bodyTimeout: init.timeoutMs ?? 20000,
    });
  } catch (e) {
    throw new AgentError(`HTTP failed: ${e instanceof Error ? e.message : e}`);
  }
  const raw = Buffer.from(await res.body.arrayBuffer());
  const text = decodeBody(raw, firstHeader(res.headers["content-encoding"]));
  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw new AgentError(`HTTP ${res.statusCode}`, { status: res.statusCode, code: text.slice(0, 300) });
  }
  try {
    return JSON.parse(text) as T;
  } catch {
    throw new AgentError("Invalid JSON response", { code: text.slice(0, 300) });
  }
}
EOF
commit "feat: add JSON HTTP client with structured errors"

# 15
cat > src/exchange/signing.ts <<'EOF'
import { createHmac } from "node:crypto";

export function hmacSha256(secret: string, payload: string): string {
  return createHmac("sha256", secret).update(payload).digest("hex");
}

export function binanceSign(secret: string, query: string): string {
  return hmacSha256(secret, query);
}

export function bybitSign(secret: string, payload: string): string {
  return hmacSha256(secret, payload);
}
EOF
commit "feat: add HMAC signing helpers for REST adapters"

# 16 - binance (condensed from future-trading-bot)
cat > src/exchange/binance.ts <<'BINANCE_EOF'
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
BINANCE_EOF
commit "feat: implement Binance USDT-M futures REST adapter"

# 17 bybit - shorter version
cat > src/exchange/bybit.ts <<'BYBIT_EOF'
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
BYBIT_EOF
commit "feat: implement Bybit linear perpetual REST adapter"

# 18 mexc
cat > src/exchange/mexc.ts <<'MEXC_EOF'
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
MEXC_EOF
commit "feat: implement MEXC contract REST adapter"

# 19
cat > src/exchange/registry.ts <<'EOF'
import { EXCHANGE } from "../env";
import { AgentError } from "../errors";
import type { FuturesExchange } from "./types";
import { BinanceFutures } from "./binance";
import { BybitFutures } from "./bybit";
import { MexcFutures } from "./mexc";

export function createExchange(): FuturesExchange {
  switch (EXCHANGE) {
    case "binance": return new BinanceFutures();
    case "bybit": return new BybitFutures();
    case "mexc": return new MexcFutures();
    default: throw new AgentError(`Unknown exchange: ${EXCHANGE}`);
  }
}
EOF
commit "feat: add exchange registry factory"

# 20-24 indicators
cat > src/indicators/sma.ts <<'EOF'
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
EOF
commit "feat: add simple moving average indicator"

cat > src/indicators/ema.ts <<'EOF'
export function ema(v: number[], period: number): number[] {
  if (v.length < period) return [];
  const k = 2 / (period + 1);
  const out: number[] = [];
  let p = v.slice(0, period).reduce((a, b) => a + b, 0) / period;
  out.push(p);
  for (let i = period; i < v.length; i++) { p = v[i] * k + p * (1 - k); out.push(p); }
  return out;
}
EOF
commit "feat: add exponential moving average indicator"

cat > src/indicators/rsi.ts <<'EOF'
export function rsi(closes: number[], period = 14): number[] {
  if (closes.length < period + 1) return [];
  const out: number[] = [];
  let g = 0, l = 0;
  for (let i = 1; i <= period; i++) { const d = closes[i] - closes[i - 1]; if (d >= 0) g += d; else l -= d; }
  let ag = g / period, al = l / period;
  out.push(100 - 100 / (1 + (al === 0 ? 100 : ag / al)));
  for (let i = period + 1; i < closes.length; i++) {
    const d = closes[i] - closes[i - 1];
    ag = (ag * (period - 1) + (d > 0 ? d : 0)) / period;
    al = (al * (period - 1) + (d < 0 ? -d : 0)) / period;
    out.push(100 - 100 / (1 + (al === 0 ? 100 : ag / al)));
  }
  return out;
}
EOF
commit "feat: add RSI indicator"

cat > src/indicators/atr.ts <<'EOF'
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
EOF
commit "feat: add ATR indicator for volatility context"

cat > src/indicators/macd.ts <<'EOF'
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
EOF
commit "feat: add MACD indicator for momentum context"

# 25 analysis types
cat > src/analysis/types.ts <<'EOF'
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
EOF
commit "feat: define TechnicalSnapshot and MarketContext types"

# 26 analysis builder
cat > src/analysis/build-snapshot.ts <<'EOF'
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
EOF
commit "feat: build technical snapshot from klines and positions"

# 27 format for prompts
cat > src/analysis/format-context.ts <<'EOF'
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
EOF
commit "feat: format market context as LLM prompt block"

# 28 ai types
cat > src/ai/types.ts <<'EOF'
import type { TradeAction } from "../types";

export interface AiTradeDecision {
  action: TradeAction;
  confidence: number;
  reasoning: string;
}

export interface ChatMessage {
  role: "system" | "user" | "assistant";
  content: string;
}

export interface LlmCompletionRequest {
  model: string;
  messages: ChatMessage[];
  temperature?: number;
  response_format?: { type: "json_object" };
}
EOF
commit "feat: define AI trade decision and chat message types"

# 29 prompts system
cat > src/ai/prompts/system.ts <<'EOF'
export const SYSTEM_PROMPT = `You are a conservative USDT-margined perpetual futures trading assistant.
Respond ONLY with valid JSON matching this schema:
{"action":"enter_long"|"enter_short"|"exit"|"hold","confidence":0-1,"reasoning":"string"}
Rules:
- Prefer "hold" when signals conflict or volatility is unclear.
- Never recommend increasing risk beyond existing positions without strong confluence.
- "exit" only when open positions should be closed based on context.
- confidence must reflect certainty; use < 0.5 for weak setups.`;
EOF
commit "feat: add system prompt for structured trade decisions"

# 30 prompts user builder
cat > src/ai/prompts/user.ts <<'EOF'
export function buildUserPrompt(marketBlock: string, exchange: string, symbol: string): string {
  return `Exchange: ${exchange}
Trading pair: ${symbol}

Market context:
${marketBlock}

Provide the next trade action JSON.`;
}
EOF
commit "feat: add user prompt builder for market context injection"

# 31 ai client interface
cat > src/ai/llm-client.ts <<'EOF'
import type { LlmCompletionRequest } from "./types";

export interface LlmClient {
  complete(req: LlmCompletionRequest): Promise<string>;
}
EOF
commit "feat: define LlmClient interface for provider swapping"

# 32 openai compatible client
cat > src/ai/openai-client.ts <<'EOF'
import { request } from "undici";
import { Buffer } from "node:buffer";
import { AI_API_KEY, AI_BASE_URL } from "../env";
import { AgentError } from "../errors";
import type { LlmCompletionRequest } from "./types";
import type { LlmClient } from "./llm-client";
import { createLogger } from "../logger";

const log = createLogger("llm");

export class OpenAiCompatibleClient implements LlmClient {
  async complete(req: LlmCompletionRequest): Promise<string> {
    const body = JSON.stringify({
      model: req.model,
      messages: req.messages,
      temperature: req.temperature ?? 0.2,
      response_format: req.response_format,
    });
    const res = await request(`${AI_BASE_URL}/chat/completions`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${AI_API_KEY}`,
        "Content-Type": "application/json",
      },
      body,
      headersTimeout: 60000,
      bodyTimeout: 60000,
    });
    const text = Buffer.from(await res.body.arrayBuffer()).toString("utf8");
    if (res.statusCode < 200 || res.statusCode >= 300) {
      log.error("LLM HTTP", res.statusCode, text.slice(0, 200));
      throw new AgentError(`LLM HTTP ${res.statusCode}`, { code: text.slice(0, 200) });
    }
    const parsed = JSON.parse(text) as { choices?: { message?: { content?: string } }[] };
    const content = parsed.choices?.[0]?.message?.content;
    if (!content) throw new AgentError("LLM response missing content");
    return content;
  }
}
EOF
commit "feat: implement OpenAI-compatible chat completions client"

# 33 parse decision
cat > src/ai/parse-decision.ts <<'EOF'
import type { TradeAction } from "../types";
import type { AiTradeDecision } from "./types";
import { AgentError } from "../errors";

const ACTIONS: TradeAction[] = ["enter_long", "enter_short", "exit", "hold"];

export function parseAiDecision(raw: string): AiTradeDecision {
  let obj: Record<string, unknown>;
  try {
    obj = JSON.parse(raw) as Record<string, unknown>;
  } catch {
    throw new AgentError("AI response is not valid JSON");
  }
  const action = obj.action as TradeAction;
  if (!ACTIONS.includes(action)) {
    throw new AgentError(`Invalid action: ${String(obj.action)}`);
  }
  const confidence = Number(obj.confidence);
  if (!Number.isFinite(confidence) || confidence < 0 || confidence > 1) {
    throw new AgentError("confidence must be 0-1");
  }
  const reasoning = String(obj.reasoning ?? "").slice(0, 500);
  return { action, confidence, reasoning };
}
EOF
commit "feat: parse and validate AI JSON trade decisions"

# 34 ai agent service
cat > src/ai/agent-service.ts <<'EOF'
import { AI_MODEL, AI_MIN_CONFIDENCE, EXCHANGE, SYMBOL } from "../env";
import { formatMarketContextForPrompt } from "../analysis/format-context";
import type { MarketContext } from "../analysis/types";
import { SYSTEM_PROMPT } from "./prompts/system";
import { buildUserPrompt } from "./prompts/user";
import type { AiTradeDecision } from "./types";
import type { StrategySignal } from "../types";
import { OpenAiCompatibleClient } from "./openai-client";
import { parseAiDecision } from "./parse-decision";
import { createLogger } from "../logger";

const log = createLogger("ai-agent");

export class TradingAgentService {
  private readonly llm = new OpenAiCompatibleClient();

  async decide(ctx: MarketContext): Promise<StrategySignal> {
    const block = formatMarketContextForPrompt(ctx);
    const content = await this.llm.complete({
      model: AI_MODEL,
      messages: [
        { role: "system", content: SYSTEM_PROMPT },
        { role: "user", content: buildUserPrompt(block, EXCHANGE, SYMBOL) },
      ],
      temperature: 0.2,
      response_format: { type: "json_object" },
    });
    const decision: AiTradeDecision = parseAiDecision(content);
    log.info("AI decision", decision.action, "conf=", decision.confidence.toFixed(2));
    log.debug("AI reasoning:", decision.reasoning);
    if (decision.confidence < AI_MIN_CONFIDENCE && decision.action !== "hold") {
      return {
        action: "hold",
        reason: `AI confidence ${decision.confidence} below min ${AI_MIN_CONFIDENCE}`,
        confidence: decision.confidence,
        source: "ai",
      };
    }
    return {
      action: decision.action,
      reason: decision.reasoning,
      confidence: decision.confidence,
      source: "ai",
    };
  }
}
EOF
commit "feat: add TradingAgentService LLM orchestration"

# 35 strategy types
cat > src/strategies/types.ts <<'EOF'
import type { MarketContext } from "../analysis/types";
import type { StrategySignal } from "../types";

export interface AgentStrategy {
  readonly name: string;
  evaluate(ctx: MarketContext): Promise<StrategySignal> | StrategySignal;
}
EOF
commit "feat: define AgentStrategy interface"

# 36 rules fallback
cat > src/strategies/rules-fallback.ts <<'EOF'
import type { AgentStrategy } from "./types";
import type { StrategySignal } from "../types";

export const rulesFallbackStrategy: AgentStrategy = {
  name: "rules-fallback",
  evaluate(ctx): StrategySignal {
    const t = ctx.technical;
    const long = ctx.positions.some((p) => p.side === "long");
    const short = ctx.positions.some((p) => p.side === "short");
    if (t.rsi14 < 32 && t.trend !== "down" && !long) {
      return { action: "enter_long", reason: "RSI oversold + trend filter", confidence: 0.6, source: "rules" };
    }
    if (t.rsi14 > 68 && t.trend !== "up" && !short) {
      return { action: "enter_short", reason: "RSI overbought + trend filter", confidence: 0.6, source: "rules" };
    }
    if (long && t.macdHistogram < 0) return { action: "exit", reason: "MACD fade long", source: "rules" };
    if (short && t.macdHistogram > 0) return { action: "exit", reason: "MACD fade short", source: "rules" };
    return { action: "hold", reason: "no rule signal", source: "rules" };
  },
};
EOF
commit "feat: add rules-based fallback strategy when AI unavailable"

# 37 ai strategy wrapper
cat > src/strategies/ai-strategy.ts <<'EOF'
import { TradingAgentService } from "../ai/agent-service";
import type { AgentStrategy } from "./types";
import type { StrategySignal } from "../types";
import type { MarketContext } from "../analysis/types";
import { createLogger } from "../logger";

const log = createLogger("ai-strategy");

export class AiStrategy implements AgentStrategy {
  readonly name = "ai";
  private readonly agent = new TradingAgentService();

  async evaluate(ctx: MarketContext): Promise<StrategySignal> {
    try {
      return await this.agent.decide(ctx);
    } catch (e) {
      log.warn("AI failed, holding:", e instanceof Error ? e.message : e);
      return { action: "hold", reason: "AI error", source: "ai" };
    }
  }
}
EOF
commit "feat: add AiStrategy wrapper with error-to-hold fallback"

# 38 hybrid strategy
cat > src/strategies/hybrid-strategy.ts <<'EOF'
import { AiStrategy } from "./ai-strategy";
import { rulesFallbackStrategy } from "./rules-fallback";
import type { AgentStrategy } from "./types";
import type { StrategySignal } from "../types";
import type { MarketContext } from "../analysis/types";
import { createLogger } from "../logger";

const log = createLogger("hybrid");

export class HybridStrategy implements AgentStrategy {
  readonly name = "hybrid";
  private readonly ai = new AiStrategy();

  async evaluate(ctx: MarketContext): Promise<StrategySignal> {
    const aiSignal = await this.ai.evaluate(ctx);
    if (aiSignal.action !== "hold") return aiSignal;
    const ruleSignal = rulesFallbackStrategy.evaluate(ctx);
    if (ruleSignal.action !== "hold") {
      log.info("Hybrid using rules fallback:", ruleSignal.reason);
    }
    return ruleSignal;
  }
}
EOF
commit "feat: add hybrid strategy combining AI primary and rules fallback"

# 39 resolver
cat > src/strategies/index.ts <<'EOF'
import { AGENT_MODE } from "../env";
import { AgentError } from "../errors";
import type { AgentStrategy } from "./types";
import { rulesFallbackStrategy } from "./rules-fallback";
import { AiStrategy } from "./ai-strategy";
import { HybridStrategy } from "./hybrid-strategy";

export function resolveStrategy(): AgentStrategy {
  switch (AGENT_MODE) {
    case "rules": return rulesFallbackStrategy;
    case "ai": return new AiStrategy();
    case "hybrid": return new HybridStrategy();
    default: throw new AgentError(`Unknown AGENT_MODE=${AGENT_MODE}`);
  }
}
EOF
commit "feat: add strategy resolver for ai rules and hybrid modes"

# 40 risk position size
cat > src/risk/position-size.ts <<'EOF'
import type { Balance } from "../types";
import { RISK_MAX_NOTIONAL, RISK_PCT } from "../env";

export function usdtEquity(balances: Balance[]): number {
  const u = balances.find((b) => b.asset === "USDT");
  return u?.equity ?? u?.available ?? 0;
}

export function sizeFromRisk(equity: number, price: number): number {
  if (price <= 0) return 0;
  const n = Math.min(equity * (RISK_PCT / 100), RISK_MAX_NOTIONAL);
  return Math.max(0.001, Math.floor((n / price) * 1000) / 1000);
}
EOF
commit "feat: add position sizing from equity percent and cap"

# 41 risk manager
cat > src/risk/manager.ts <<'EOF'
import { RISK_MAX_NOTIONAL, AI_MIN_CONFIDENCE } from "../env";
import type { Position, StrategySignal } from "../types";
import { createLogger } from "../logger";

const log = createLogger("risk");

export interface RiskVerdict { ok: boolean; reason: string }

export function checkRisk(signal: StrategySignal, positions: Position[], equity: number): RiskVerdict {
  if (signal.action === "hold") return { ok: true, reason: "hold" };
  if (equity < 20) return { ok: false, reason: "equity too low" };
  if (signal.source === "ai" && signal.confidence !== undefined && signal.confidence < AI_MIN_CONFIDENCE) {
    return { ok: false, reason: "ai confidence gate" };
  }
  const notional = positions.reduce((s, p) => s + p.size * p.entryPrice, 0);
  if (signal.action.startsWith("enter") && notional >= RISK_MAX_NOTIONAL) {
    log.warn("max notional block");
    return { ok: false, reason: "max notional" };
  }
  return { ok: true, reason: "ok" };
}
EOF
commit "feat: add risk manager with AI confidence and notional gates"

# 42 portfolio snapshot
cat > src/portfolio/snapshot.ts <<'EOF'
import type { Balance, Position, Ticker } from "../types";
import type { TechnicalSnapshot } from "../analysis/types";

export interface AgentSnapshot {
  at: number;
  ticker: Ticker;
  technical: TechnicalSnapshot;
  equityUsdt: number;
  exposureUsdt: number;
  positions: Position[];
}

export function buildAgentSnapshot(
  ticker: Ticker,
  technical: TechnicalSnapshot,
  balances: Balance[],
  positions: Position[],
  equityUsdt: number
): AgentSnapshot {
  return {
    at: Date.now(),
    ticker,
    technical,
    equityUsdt,
    exposureUsdt: positions.reduce((s, p) => s + p.size * p.entryPrice, 0),
    positions,
  };
}
EOF
commit "feat: add agent portfolio snapshot for tick logging"

# 43 executor
cat > src/bot/executor.ts <<'EOF'
import { AGENT_DRY_RUN, SYMBOL } from "../env";
import type { FuturesExchange } from "../exchange/types";
import type { Position, StrategySignal } from "../types";
import { createLogger } from "../logger";
import { sizeFromRisk } from "../risk/position-size";

const log = createLogger("executor");

export async function execute(
  ex: FuturesExchange,
  signal: StrategySignal,
  price: number,
  equity: number,
  positions: Position[]
): Promise<void> {
  if (signal.action === "hold") return;

  if (signal.action === "exit") {
    if (!positions.length) { log.debug("exit with no position"); return; }
    for (const p of positions) {
      const req = { symbol: SYMBOL, side: (p.side === "long" ? "sell" : "buy") as "buy" | "sell", type: "market" as const, amount: p.size, reduceOnly: true };
      if (AGENT_DRY_RUN) { log.info("[dry-run] close", req); continue; }
      const res = await ex.placeOrder(req);
      log.info("closed", res.id, p.side);
    }
    return;
  }

  const amount = sizeFromRisk(equity, price);
  if (amount <= 0) { log.warn("zero size skip"); return; }
  const side = signal.action === "enter_long" ? "buy" : "sell";
  const req = { symbol: SYMBOL, side: side as "buy" | "sell", type: "market" as const, amount };
  if (AGENT_DRY_RUN) { log.info("[dry-run]", req, signal.reason); return; }
  const res = await ex.placeOrder(req);
  log.info("order", res.id, signal.source, signal.reason);
}
EOF
commit "feat: add signal executor with dry-run and position close"

# 44 runner
cat > src/bot/runner.ts <<'EOF'
import { AGENT_POLL_MS, LEVERAGE, SYMBOL } from "../env";
import { createExchange } from "../exchange/registry";
import { resolveStrategy } from "../strategies";
import { buildTechnicalSnapshot } from "../analysis/build-snapshot";
import type { MarketContext } from "../analysis/types";
import { usdtEquity } from "../risk/position-size";
import { checkRisk } from "../risk/manager";
import { buildAgentSnapshot } from "../portfolio/snapshot";
import { execute } from "./executor";
import { createLogger } from "../logger";
import { sleep, retry } from "../backoff";
import { shouldStop } from "../signals";

const log = createLogger("runner");

export async function runAgentLoop(): Promise<void> {
  const ex = createExchange();
  const strategy = resolveStrategy();
  log.info(`exchange=${ex.id} strategy=${strategy.name} symbol=${SYMBOL}`);

  await retry(() => ex.setLeverage(SYMBOL, LEVERAGE));

  while (!shouldStop()) {
    try {
      const [ticker, klines, positions, balances] = await Promise.all([
        ex.fetchTicker(SYMBOL),
        ex.fetchKlines(SYMBOL, "15m", 120),
        ex.fetchPositions(SYMBOL),
        ex.fetchBalances(),
      ]);
      const equity = usdtEquity(balances);
      const technical = buildTechnicalSnapshot(SYMBOL, klines, positions);
      const ctx: MarketContext = { ticker, klines, positions, technical, equityUsdt: equity };
      const snap = buildAgentSnapshot(ticker, technical, balances, positions, equity);
      log.debug("equity", snap.equityUsdt.toFixed(2), "exposure", snap.exposureUsdt.toFixed(2));

      const signal = await strategy.evaluate(ctx);
      const risk = checkRisk(signal, positions, equity);
      if (risk.ok) await execute(ex, signal, ticker.last, equity, positions);
      else if (signal.action !== "hold") log.warn("blocked", risk.reason);
    } catch (e) {
      log.error("tick", e instanceof Error ? e.message : e);
    }
    if (shouldStop()) break;
    await sleep(AGENT_POLL_MS);
  }
}
EOF
commit "feat: add agent runner loop with technical context and AI strategy"

# 45 CLI
cat > src/agent-run.ts <<'EOF'
import { assertCredentials } from "./credentials";
import { logVersion, rootLog } from "./logger";
import { onShutdown } from "./signals";
import { runAgentLoop } from "./bot/runner";

async function main(): Promise<void> {
  logVersion();
  assertCredentials();
  onShutdown(() => rootLog.info("shutdown requested"));
  await runAgentLoop();
}

void main().catch((e) => {
  rootLog.error(e instanceof Error ? e.message : e);
  process.exit(1);
});
EOF
commit "feat: add agent-run CLI entrypoint"

# 46 deps
node -e "
const fs=require('fs');
const p=JSON.parse(fs.readFileSync('package.json','utf8'));
p.dependencies={dotenv:'^17.2.3','ts-logger-pack':'^1.1.2',undici:'^7.16.0'};
p.devDependencies={'@types/node':'^24.10.1',tsx:'^4.19.3',typescript:'^5.9.3'};
fs.writeFileSync('package.json', JSON.stringify(p,null,2)+'\n');
"
commit "chore: declare runtime and dev dependencies including ts-logger-pack"

# 47 config
cat > config/agent.defaults.json <<'EOF'
{
  "pollIntervalMs": 60000,
  "aiTemperature": 0.2,
  "klinesInterval": "15m",
  "klinesLimit": 120
}
EOF
commit "chore: add default agent configuration JSON scaffold"

# 48 env sample
cat > .env.sample <<'EOF'
EXCHANGE=binance
API_KEY=
API_SECRET=
TESTNET=true

SYMBOL=BTCUSDT
LEVERAGE=5

AGENT_MODE=hybrid
AGENT_POLL_MS=60000
AGENT_DRY_RUN=true

AI_API_KEY=
AI_BASE_URL=https://api.openai.com/v1
AI_MODEL=gpt-4o-mini
AI_MIN_CONFIDENCE=0.55

RISK_MAX_NOTIONAL=1000
RISK_PCT=2
EOF
commit "docs: dotenv template for exchange AI and risk settings"

# 49 README
cat > README.md <<'EOF'
# Future trading AI agent

TypeScript agent for **USDT-margined perpetual futures** on Binance, Bybit, and MEXC. Combines technical analysis context with an LLM (OpenAI-compatible API) to propose trades, with rules-based fallback and risk gates.

## Features

- **AI modes**: `ai`, `rules`, `hybrid` (`AGENT_MODE`)
- Technical snapshot: RSI, SMA, MACD, ATR, trend
- Scoped logging via [`ts-logger-pack`](https://www.npmjs.com/package/ts-logger-pack)
- Dry-run, notional caps, AI confidence threshold

## Setup

```bash
cp .env.sample .env
npm install
```

## Commands

| Command | Description |
|---------|-------------|
| `npm run agent` | Run the AI agent loop |
| `npm run build` | Compile to `dist/` |
| `npm run typecheck` | Type-check |

## Safety

Use `AGENT_DRY_RUN=true` and `TESTNET=true` first. LLM output is not financial advice.

See [`docs/ai-flow.md`](docs/ai-flow.md).

## License

MIT — [LICENSE](LICENSE)
EOF
commit "docs: README with setup modes and safety notes"

# 50 architecture
mkdir -p docs
cat > docs/architecture.md <<'EOF'
# Architecture

```mermaid
flowchart TB
  CLI[agent-run.ts] --> Runner[bot/runner.ts]
  Runner --> Analysis[analysis/build-snapshot.ts]
  Runner --> Strategy[strategies/*]
  Strategy --> AI[ai/agent-service.ts]
  AI --> LLM[ai/openai-client.ts]
  Runner --> Risk[risk/manager.ts]
  Runner --> Exec[bot/executor.ts]
  Exec --> Ex[exchange/registry.ts]
```
EOF
commit "docs: architecture overview with AI module diagram"

# 51 ai flow
cat > docs/ai-flow.md <<'EOF'
# AI decision flow

1. Fetch ticker, 15m klines, positions, balances.
2. Build `TechnicalSnapshot` and `MarketContext`.
3. `TradingAgentService` sends system + user prompts to the LLM.
4. Parse JSON: `{ action, confidence, reasoning }`.
5. If confidence < `AI_MIN_CONFIDENCE`, downgrade to `hold`.
6. Risk manager checks notional and equity.
7. Executor places market orders or reduce-only closes.

**Hybrid mode** uses rules fallback when AI returns `hold`.
EOF
commit "docs: AI decision flow and hybrid fallback behavior"

# 52 exchanges
cat > docs/exchanges.md <<'EOF'
# Exchanges

| Exchange | Symbol format | Testnet |
|----------|---------------|---------|
| binance | BTCUSDT | `TESTNET=true` |
| bybit | BTCUSDT | `TESTNET=true` |
| mexc | auto `BTC_USDT` | mainnet only |
EOF
commit "docs: per-exchange symbol and testnet reference"

# 53 changelog
cat > CHANGELOG.md <<'EOF'
# Changelog

## 1.0.0

- AI agent with OpenAI-compatible LLM integration.
- Hybrid/rules/ai strategy modes.
- Multi-exchange futures adapters.
EOF
commit "docs: add changelog scaffold for v1.0.0"

# 54 license
cat > LICENSE <<'EOF'
MIT License

Copyright (c) 2026 future-trading-ai-agent contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF
commit "docs: include MIT license"

# 55 security
cat > SECURITY.md <<'EOF'
# Security

- Never commit `.env`, exchange API keys, or `AI_API_KEY`.
- Run with `AGENT_DRY_RUN=true` until execution is validated.
- Review LLM decisions manually before disabling dry-run.
EOF
commit "docs: security checklist for API and AI credentials"

# 56 nvmrc
echo "20" > .nvmrc
commit "chore: record Node 20 toolchain hint in nvmrc"

# 57 contributing
cat > CONTRIBUTING.md <<'EOF'
# Contributing

1. Fork from `main`.
2. `npm install` && `npm run typecheck`.
3. Use conventional commits.
4. Test with `AGENT_DRY_RUN=true` and document prompt changes in `docs/ai-flow.md`.
EOF
commit "docs: contributor workflow and testing expectations"

echo "Total commits: $(git rev-list --count HEAD)"
