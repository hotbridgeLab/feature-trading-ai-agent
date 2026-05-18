import type { LlmCompletionRequest } from "./types";

export interface LlmClient {
  complete(req: LlmCompletionRequest): Promise<string>;
}
