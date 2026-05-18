# Architecture

```mermaid
flowchart TB
  CLI[agent-run.ts] --> Runner[bot/runner.ts]
  Runner --> Analysis[analysis/build-snapshot.ts]
  Runner --> Strategy[strategies/*]
  Strategy --> AI[ai/agent-service.ts]
  AI --> LLM[ai/openai-client.ts]
  Runner --> Risk[risk/manager.ts]
  Runner --> Exec[bot/executor.ts]
  Exec --> Ex[exchange/registry.ts]
```
