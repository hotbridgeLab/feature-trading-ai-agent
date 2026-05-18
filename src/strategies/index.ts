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
