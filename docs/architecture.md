# Architecture

```mermaid
flowchart LR
    CLI[PiiSentry.Cli]\n(Local Copilot SDK Agent)
    R1[Ring 1\nFabric Data Agent via Foundry]
    R2[Ring 2\nWork IQ MCP]
    R3[Ring 3\nFoundry IQ / AI Search]
    REP[Compliance Report\nJSON + HTML]

    CLI --> R1
    CLI --> R2
    CLI --> R3
    CLI --> REP
```
