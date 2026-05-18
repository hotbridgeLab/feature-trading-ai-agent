export class AgentError extends Error {
  readonly code?: string;
  readonly status?: number;

  constructor(message: string, opts: { code?: string; status?: number } = {}) {
    super(message);
    this.name = "AgentError";
    this.code = opts.code;
    this.status = opts.status;
  }
}
