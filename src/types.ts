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
