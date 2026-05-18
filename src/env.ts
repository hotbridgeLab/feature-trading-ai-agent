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
