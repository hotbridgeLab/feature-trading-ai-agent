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
