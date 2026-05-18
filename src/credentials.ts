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
