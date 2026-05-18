export function buildUserPrompt(marketBlock: string, exchange: string, symbol: string): string {
  return `Exchange: ${exchange}
Trading pair: ${symbol}

Market context:
${marketBlock}

Provide the next trade action JSON.`;
}
