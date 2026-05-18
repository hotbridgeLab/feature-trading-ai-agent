# AI decision flow

1. Fetch ticker, 15m klines, positions, balances.
2. Build `TechnicalSnapshot` and `MarketContext`.
3. `TradingAgentService` sends system + user prompts to the LLM.
4. Parse JSON: `{ action, confidence, reasoning }`.
5. If confidence < `AI_MIN_CONFIDENCE`, downgrade to `hold`.
6. Risk manager checks notional and equity.
7. Executor places market orders or reduce-only closes.

**Hybrid mode** uses rules fallback when AI returns `hold`.
