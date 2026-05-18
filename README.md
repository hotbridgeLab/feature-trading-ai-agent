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
