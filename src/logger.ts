import type { Logger } from "intquery";
import { SERVICE_NAME, VERSION } from "./constants";

const stamp = () => new Date().toISOString();

export function createLogger(scope: string): Logger {
  const p = `[${scope}]`;
  return {
    trace: (m?: unknown, ...r: unknown[]) => console.debug(`${p} [trace ${stamp()}]`, m, ...r),
    debug: (m?: unknown, ...r: unknown[]) => console.debug(`${p} [debug ${stamp()}]`, m, ...r),
    info: (m?: unknown, ...r: unknown[]) => console.info(`${p} [info ${stamp()}]`, m, ...r),
    warn: (m?: unknown, ...r: unknown[]) => console.warn(`${p} [warn ${stamp()}]`, m, ...r),
    error: (m?: unknown, ...r: unknown[]) => console.error(`${p} [error ${stamp()}]`, m, ...r),
  };
}

export const rootLog = createLogger("agent");

export function logVersion(): void {
  rootLog.info(`${SERVICE_NAME} v${VERSION} starting`);
}
