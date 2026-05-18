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
