import { formatError } from "./errors";
import { assertCredentials } from "./credentials";
import { logVersion, rootLog } from "./logger";
import { onShutdown } from "./signals";
import { runAgentLoop } from "./bot/runner";

async function main(): Promise<void> {
  logVersion();
  assertCredentials();
  onShutdown(() => rootLog.info("shutdown requested"));
  await runAgentLoop();
}

void main().catch((e) => {
  rootLog.error(formatError(e));
  process.exit(1);
});
