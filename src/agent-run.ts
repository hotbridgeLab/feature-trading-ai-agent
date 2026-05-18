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
  rootLog.error(e instanceof Error ? e.message : e);
  process.exit(1);
});
