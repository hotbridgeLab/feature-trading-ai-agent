export class AgentError extends Error {
  readonly code?: string;
  readonly status?: number;

  constructor(message: string, opts: { code?: string; status?: number } = {}) {
    const detail = opts.code ? `: ${opts.code}` : "";
    super(`${message}${detail}`);
    this.name = "AgentError";
    this.code = opts.code;
    this.status = opts.status;
  }
}

export function formatError(e: unknown): string {
  if (e instanceof AgentError) {
    return e.status ? `${e.message} (status ${e.status})` : e.message;
  }
  return e instanceof Error ? e.message : String(e);
}
