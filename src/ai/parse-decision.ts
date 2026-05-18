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
