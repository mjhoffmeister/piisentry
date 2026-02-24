# Plan: PII Sentry — Copilot SDK PII/PHI Code Review CLI

## TL;DR
PII Sentry is a .NET 10 CLI powered by the GitHub Copilot SDK that performs concentric-ring regulatory review of PII/PHI handling in codebases. It reconciles three data sources — a **Fabric Data Agent** backed by an IQ ontology (codified org standards), **Work IQ** (uncodified business artifacts), and **Foundry IQ** (latest regulatory intelligence via Bing Search + vector store) — to produce a unified compliance gap analysis. Each ring runs under the **signed-in user's identity** (OBO) so results respect the user's actual permissions. Azure infrastructure is provisioned via Terraform (AzApi v2.8.0) with CI/CD using a WIF service principal for **infra provisioning only** (not data-plane queries).

---

## Architecture: What Runs Where

| Component | Where it runs | What it is |
|---|---|---|
| **PiiSentry.Cli** | Developer machine | .NET 10 global tool — the single deployable artifact |
| **Copilot SDK agent** | In-process (inside CLI) | `CopilotClient` + Agent Framework `AIAgent` abstraction (`Microsoft.Agents.AI.GitHub.Copilot`). Orchestrates tool calls, cross-references findings |
| **Foundry agent** | Azure (data-plane) | Server-side resource in AI Foundry project. Created once at CI/CD time. Wraps Fabric Data Agent via `FabricTool` |
| **Fabric Data Agent** | Fabric | Ontology-backed agent; only reachable through Foundry Agent Service |
| **Work IQ MCP server** | Child process (CLI machine) | `npx -y @microsoft/workiq mcp` — stdio MCP; queries M365 artifacts |
| **Foundry IQ (AI Search)** | Azure (REST) | Agentic retrieval endpoint — direct REST call from CLI, no Foundry agent needed |

### Two-layer agent model

1. **Copilot SDK agent (local):** Runs inside `PiiSentry.Cli`. Provides the reasoning loop — reads code, calls ring tools, compares findings, produces the report. This is the "brain."
2. **Foundry agent (remote, Ring 1 only):** A pre-created server-side resource that wraps the Fabric Data Agent via `FabricTool`. The CLI doesn't create this agent per-scan; it references a stable agent ID and creates a disposable **thread** per scan. Ring 2 (Work IQ) and Ring 3 (Foundry IQ) do NOT use a Foundry agent.

### Runtime call flow

```
CLI
 ├─ Copilot SDK agent (in-process reasoning)
 │   ├─ [built-in file ops]          → local filesystem (approved via OnPermissionRequest)
 │   ├─ query_fabric_data_agent     → Foundry Agent Service (pre-created agent + new thread)
 │   │                                  └─ FabricTool → Fabric Data Agent (OBO)
 │   ├─ [Work IQ MCP tools]          → native MCP via SessionConfig.McpServers (SDK-managed child process, user's M365 identity)
 │   └─ query_foundry_iq            → AI Search agentic retrieval REST API (direct, no Foundry agent)
 │
 └─ Report generation (local)
```

### Single-project architecture

There is **one deployable artifact**: `PiiSentry.Cli` (a `dotnet tool` global tool). Everything else is either an Azure resource (provisioned by Terraform + CI/CD) or an in-process SDK. No separate hosted apps, no sidecar services.

---

## Phase 0: Project Scaffolding & Repo Structure (Day 1)

1. Initialize repo structure per challenge brief:
   ```
   /src/PiiSentry.Cli/          — .NET 10 CLI app (GitHub.Copilot.SDK + Microsoft.Agents.AI.GitHub.Copilot NuGet)
   /src/PiiSentry.Core/         — Shared models, contracts, report generation
   /src/PiiSentry.DemoApp/      — Intentionally-violating demo app (ASP.NET Core)
   /infra/                      — Terraform (AzApi v2.8.0) modules
   /docs/                       — README, architecture diagram, RAI notes
   /presentations/              — PiiSentry.pptx
   /demo-data/                  — Ontology JSON, Word docs, regulatory PDFs
   AGENTS.md                    — Custom instructions for Copilot
   mcp.json                     — MCP server config (Work IQ only — for VS Code Copilot discovery; CLI uses SessionConfig.McpServers in code)
   ```
2. Create `.github/workflows/deploy.yml` — CI/CD pipeline with WIF auth
3. Create `AGENTS.md` with PII Sentry agent instructions:
   - Persona: "You are PII Sentry, a compliance analyst agent specializing in PII/PHI code review."
   - Behavior: analyze code for PII/PHI handling violations, cross-reference against organizational standards (Ring 1), business artifacts (Ring 2), and regulatory requirements (Ring 3)
   - Output format: structured findings with severity, ring source, code location, citation, and remediation guidance
   - Constraints: never store or log PII found in code, attribute every finding to its source, flag uncertainty
4. Create `mcp.json`:
   ```json
   {
     "workiq": {
       "command": "npx",
       "args": ["-y", "@microsoft/workiq", "mcp"],
       "tools": ["*"]
     }
   }
   ```

**Deliverables:** Repo skeleton passes lint, CI pipeline stubs run green

---

## Phase 1: Azure Infrastructure (Days 1-2)

5. **Terraform modules** (`/infra/`) using AzApi v2.8.0:
   - `main.tf` — Resource group, provider config
   - `modules/ai-search/` — Azure AI Search service (for Foundry IQ knowledge sources/bases)
   - `modules/ai-foundry/` — Azure AI Foundry project + AI Services (for Foundry Agents + agentic retrieval + Fabric Data Agent connection)
   - `modules/storage/` — Azure Blob Storage (regulatory docs for vector indexing)
   - `modules/observability/` — Application Insights + Log Analytics workspace (scan telemetry, ring latency, error tracking)
   - `modules/fabric/` — Fabric capacity — Fabric workspace, ontology, data agent, and Foundry connection are portal-only; document as manual prerequisite
   - `modules/identity/` — WIF service principal (infra + ALM only), managed identity, RBAC role assignments (including `AI Developer` role for Foundry users)

   **AzApi resource types and API versions:**
   | Resource | AzApi type | API version |
   |---|---|---|
   | Resource Group | `azapi_resource` type `Microsoft.Resources/resourceGroups` | `2024-03-01` |
   | AI Search Service | `azapi_resource` type `Microsoft.Search/searchServices` | `2024-06-01-preview` |
   | AI Services (multi-service) | `azapi_resource` type `Microsoft.CognitiveServices/accounts` (kind: `AIServices`) | `2024-10-01` |
   | AI Foundry Hub | `azapi_resource` type `Microsoft.MachineLearningServices/workspaces` (kind: `Hub`) | `2024-10-01` |
   | AI Foundry Project | `azapi_resource` type `Microsoft.MachineLearningServices/workspaces` (kind: `Project`) | `2024-10-01` |
   | Foundry Connection (Fabric) | `azapi_resource` type `Microsoft.MachineLearningServices/workspaces/connections` | `2024-10-01` |
   | Storage Account | `azapi_resource` type `Microsoft.Storage/storageAccounts` | `2023-05-01` |
   | Blob Container | `azapi_resource` type `Microsoft.Storage/storageAccounts/blobServices/containers` | `2023-05-01` |
   | App Insights | `azapi_resource` type `Microsoft.Insights/components` | `2020-02-02` |
   | Log Analytics Workspace | `azapi_resource` type `Microsoft.OperationalInsights/workspaces` | `2023-09-01` |
   | Fabric Capacity | `azapi_resource` type `Microsoft.Fabric/capacities` | `2023-11-01` |
   | User Assigned Identity | `azapi_resource` type `Microsoft.ManagedIdentity/userAssignedIdentities` | `2023-01-31` |
   | Role Assignment | `azapi_resource` type `Microsoft.Authorization/roleAssignments` | `2022-04-01` |

   **Key Terraform config:**
   - Provider block: `azapi = { source = "azure/azapi", version = "~> 2.8.0" }`
   - Backend: `azurerm` backend with storage account for state (or local for demo)
   - Variables: `location`, `project_name`, `fabric_capacity_sku` (default `F2`), `search_sku` (default `basic`), `admin_object_id` (Entra user for RBAC)

6. **CI/CD pipeline** (`.github/workflows/deploy.yml`):
   - Authenticate via WIF (federated identity credential on Entra app registration) — **infra provisioning + Fabric ALM only**

   **WIF setup prerequisites (manual, one-time):**
   - Create Entra ID App Registration (e.g., "piisentry-cicd")
   - Add federated identity credential:
     - Issuer: `https://token.actions.githubusercontent.com`
     - Subject: `repo:{org}/{repo}:ref:refs/heads/main` (restrict to main branch)
     - Audience: `api://AzureADTokenExchange`
   - Assign `Contributor` role on the resource group (for Terraform)
   - Assign `Search Service Contributor` on the AI Search resource
   - Store as GitHub Actions secrets: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`
   - Pipeline auth step uses `azure/login@v2` with `client-id`, `tenant-id`, `subscription-id` (no client secret — WIF)

   - `terraform init/plan/apply` for infra provisioning
   - **Post-provisioning:** Run `/infra/scripts/create-foundry-agent.sh` to create (or verify) the Foundry agent with `FabricTool`. This step runs after `terraform apply` since it depends on the Foundry project endpoint and Fabric connection ID from Terraform outputs. See step 8c.
   - `dotnet build` + `dotnet test` for CLI
   - Publish CLI as a tool or artifact
   - **Fabric Data Agent ALM:** WIF SPN can sync Git → Fabric workspace (data agent config) and trigger deployment pipeline promotion (dev → test → prod). This is the only supported SPN use for Fabric data agents.
   - **Note:** Data-plane queries (Fabric Data Agent via Foundry, Work IQ, Foundry IQ) run under the end user's identity at CLI runtime, not the CI/CD SPN

**Deliverables:** `terraform apply` provisions all resources; pipeline runs end-to-end
**SDK feedback opportunity:** First contact with Copilot SDK — note setup/install experience, .NET 10 compatibility, documentation clarity for getting started.

---

## Phase 2: Demo Data Generation (Days 2-3)

### 2A: Fabric IQ Ontology — Codified Org Standards (via Fabric Data Agent)
7. Generate a realistic PII/PHI compliance ontology (`/demo-data/ontology/`):
   - **Entity types:** `PIIDataCategory`, `PHIDataCategory`, `DataHandlingRequirement`, `ComplianceControl`, `ApplicationSystem`, `DataFlow`, `ConsentRecord`
   - **Relationships:** `DataFlow --handles--> PIIDataCategory`, `ComplianceControl --enforces--> DataHandlingRequirement`, `ApplicationSystem --processes--> DataFlow`
   - **Properties with constraints:** retention periods, encryption requirements, access control levels, geographic storage restrictions
   - **Content:** Organization's *current codified interpretation* of HIPAA, GDPR, CCPA — deliberately slightly outdated (e.g., still references pre-2025 HIPAA Safe Harbor categories, missing recent CCPA amendment requirements)

7b. **Ontology seed data — lakehouse table schemas** (`/demo-data/ontology/`):
    Each CSV maps 1:1 to a lakehouse table. The ontology item then defines entity types pointing at these tables.

    - `pii_data_categories.csv` — Columns: `CategoryId, Name, Description, SensitivityLevel, RetentionDays, EncryptionRequired, EncryptionAlgorithm, GeographicRestriction`
      - Sample rows: `SSN, Social Security Number, Direct identifier, Critical, 90, true, AES-128, US-only` ← note AES-128 is deliberately weaker than the Word doc's AES-256
      - `EMAIL, Email Address, Pseudonymizable identifier, High, 365, true, AES-128, None`
      - `BIOMETRIC, Biometric Data, Special category, Critical, 30, true, AES-256, EU-only`
      - `GENETIC, Genetic Data, Special category, Critical, 30, true, AES-256, None` ← missing state-level restrictions (Work IQ gap)

    - `phi_data_categories.csv` — Columns: `CategoryId, Name, Description, HIPAACategory, EncryptionRequired, MinimumAccessLevel`
      - Rows for: Diagnosis, Medications, LabResults, TreatmentPlan, InsuranceInfo

    - `data_handling_requirements.csv` — Columns: `RequirementId, CategoryId, Action, Constraint, Source, LastUpdated`
      - Sample: `REQ-001, SSN, Storage, Must be encrypted at rest, HIPAA Safe Harbor, 2023-06-01` ← outdated date, pre-2025
      - `REQ-002, *, Logging, Never log PII identifiers to application logs, Internal Policy, 2024-01-15`
      - `REQ-003, *, Transmission, All PII must be transmitted over TLS 1.2+, HIPAA §164.312(e), 2023-06-01`
      - `REQ-004, *, AccessControl, All PHI endpoints require authentication, HIPAA §164.312(d), 2023-06-01`
      - `REQ-005, *, Retention, Non-active records must be purged after retention period, Internal Policy, 2024-03-01`
      - Missing: No requirement for DPIA (Foundry IQ gap), no consent flow requirement for biometric (Work IQ gap)

    - `compliance_controls.csv` — Columns: `ControlId, RequirementId, ControlType, Description, VerificationMethod`
    - `application_systems.csv` — Columns: `SystemId, Name, DataCategories, DataFlows, Owner`
    - `data_flows.csv` — Columns: `FlowId, SourceSystem, DestSystem, DataCategories, EncryptionInTransit, Protocol`

    **Ontology item definition** (created in Fabric portal, stored as JSON via Git sync):
    - Maps each CSV/table to an entity type
    - Defines relationships: `DataFlow.handles → PIIDataCategory`, `ComplianceControl.enforces → DataHandlingRequirement`
    - `stage_config.json` contains AI instructions: "You are a compliance knowledge base. Answer questions about the organization's PII and PHI data handling standards, encryption requirements, retention policies, and access control rules. Always cite the specific requirement ID and source."

8. Load ontology into Fabric IQ and configure Fabric Data Agent:
   - Create ontology item in Fabric workspace (portal)
   - Bind entity types to lakehouse tables (populated from seed CSVs)
   - Create a **Fabric Data Agent** with the ontology as its source — this is the only supported query path for Ring 1
   - The data agent runs under the calling user's identity (OBO); no service-principal access to the data agent for queries
   - **Publish** the data agent so it can be consumed via Foundry Agent Service
   - Create a **Foundry connection** to the published data agent (workspace-id + artifact-id) in AI Foundry project

### 2A-Git: Fabric Data Agent Source Control
8b. Connect the Fabric workspace to the project's Git repo (GitHub) for version control of data agent config:
   - Data agent config is stored as structured JSON: `data_agent.json`, `publish_info.json`, `draft/` and `published/` folders
   - Each data source folder is named with prefix (e.g., `ontology-PiiPhiCompliance/`) and contains `datasource.json` (schema, instructions, `is_selected` flags) and `fewshots.json` (example NL→query pairs)
   - `stage_config.json` contains the `aiInstructions` for the data agent
   - Service principals are supported **only for ALM operations** (git sync, deployment pipeline promotion), not for querying
   - Use Fabric deployment pipelines (dev → test → prod workspaces) for controlled promotion

### 2A-Post: Foundry Agent Creation (CI/CD Post-Provisioning)
8c. **Create the Foundry agent via CI/CD post-provisioning** (`/infra/scripts/create-foundry-agent.sh`):
   - Runs in the CI/CD pipeline **after** `terraform apply` completes (Foundry agents are data-plane resources, not ARM — they cannot be managed by Terraform)
   - Uses the Foundry Agent Service REST API (data-plane) to create one agent with `FabricTool` attached:
     ```
     POST {foundry-project-endpoint}/assistants?api-version=2025-05-15-preview
     {
       "name": "piisentry-fabric-agent",
       "model": "gpt-4o",
       "instructions": "You are a compliance knowledge base. Answer questions about PII/PHI handling standards.",
       "tools": [{ "type": "fabric", "fabric": { "connection_id": "{connection-id}" } }]
     }
     ```
   - **Idempotent:** Script first lists existing agents, checks for one named `piisentry-fabric-agent`. If it exists, captures its ID and exits. If not, creates it.
   - Stores the resulting agent ID as a Terraform output or pipeline variable (`FOUNDRY_FABRIC_AGENT_ID`) for the CLI to consume at runtime
   - Authenticates with the CI/CD WIF SPN token (the SPN needs `AI Developer` role on the Foundry project)
   - This agent is **reused across all scans** — the CLI creates a new disposable **thread** per scan, not a new agent

### 2B: Work IQ Artifacts — Uncodified Business Knowledge
9. Create realistic M365 artifacts (Word docs, meeting transcripts) stored in SharePoint/OneDrive:
   - **Word doc:** "Updated PII Handling Guidelines Q1 2026" — contains newer requirements that haven't been codified into the ontology (e.g., "we agreed to start encrypting SSNs at rest with AES-256" but ontology still says "encrypt PII" generically)
     - Key content to include: "Effective Q1 2026, all SSNs must be encrypted at rest using AES-256-GCM. The previous AES-128-CBC standard is no longer acceptable." (This is MORE specific than the ontology's generic "EncryptionRequired: true, Algorithm: AES-128")
     - "Biometric data collected from employees or patients must have an explicit consent workflow with opt-out capability before any processing occurs."
   - **Meeting transcript summary:** Legal team discussing new state-level genetic data privacy requirements
     - Key content: "Illinois Genetic Information Privacy Act (GIPA) — effective 2026, requires explicit written consent before collecting, analyzing, or retaining genetic data. We need to update our systems to add consent checks for any genetic marker processing. This applies even in non-clinical contexts."
   - **Email thread:** Security team flagging that biometric data needs separate consent workflows
     - Key content: "Following the Q4 2025 audit, the security team recommends that all biometric hash storage be isolated from regular patient records and requires separate access logging. Current architecture violates this by co-locating biometric hashes with patient demographics."
   - **Key gap:** These documents contain requirements MORE current than the ontology but LESS authoritative than actual regulations
   - **Setup:** Create these as actual Word/email files in a SharePoint site accessible to the demo user. Work IQ will surface them when queried about PII handling policies.

### 2C: Foundry IQ — Latest Regulatory Intelligence
10. Configure Foundry IQ knowledge base with two knowledge sources:
    - **Web (Bing) knowledge source:** Configured to search for latest HIPAA, GDPR, CCPA regulatory updates, enforcement actions, guidance documents
    - **Azure Blob (vector) knowledge source:** Upload actual regulatory text (HIPAA Privacy Rule excerpts, GDPR Articles 5/6/9/32, CCPA/CPRA text) into blob storage → auto-indexed with chunking + vector embeddings
    - **Key gap:** Actual regulations will reveal requirements that neither the ontology nor the Word docs capture (e.g., GDPR Art. 35 DPIA requirements for high-risk processing)

    **Regulatory text files to upload** (`/demo-data/regulatory/`):
    - `hipaa-privacy-rule-excerpt.txt` — Focus on §164.502 (uses and disclosures), §164.514 (de-identification), §164.312 (technical safeguards — access control, audit controls, integrity, transmission security). Include the 18 Safe Harbor identifiers list.
    - `gdpr-selected-articles.txt` — Articles 5 (principles), 6 (lawful basis), 9 (special categories including genetic/biometric), 15 (right of access), 17 (right to erasure), 25 (data protection by design), 32 (security of processing), 35 (DPIA — this is the key gap: "Where a type of processing... is likely to result in a high risk... the controller shall carry out an assessment"). Include Recital 71 on automated profiling.
    - `ccpa-cpra-excerpt.txt` — §1798.100 (right to know), §1798.105 (right to delete), §1798.140 (definition of personal information including biometric/genetic), CPRA amendments on sensitive personal information and purpose limitation.
    - These are plain-text excerpts (~2-5 pages each), not full regulatory text. Enough to ground vector search answers with citations.

**Deliverables:** Three data sources with realistic, intentional gaps between them
**SDK feedback opportunity:** MCP server integration is confirmed working via `SessionConfig.McpServers`. Focus feedback on: `AIFunctionFactory` developer experience, `SessionConfig` API discoverability, permission handler patterns, and any gaps when connecting external data sources to Copilot agents.

---

## Phase 3: Demo Violation App (Day 3)

11. Create `/src/PiiSentry.DemoApp/` — ASP.NET Core Web API with deliberate PII/PHI violations:

    **Project structure:**
    - `Program.cs` — Minimal API setup, no auth middleware configured
    - `Models/Patient.cs` — `Patient` record with SSN, Name, Email, DateOfBirth, GeneticMarkers, BiometricHash fields
    - `Models/HealthRecord.cs` — `HealthRecord` record with Diagnosis, Medications, LabResults, PatientId
    - `Data/PatientStore.cs` — In-memory store backed by a plain JSON file (`patients.json`), no encryption
    - `Controllers/PatientController.cs` — CRUD endpoints, no auth attributes, logs PII to console
    - `Controllers/AnalyticsController.cs` — Automated profiling endpoint, no DPIA, returns risk scores
    - `Services/NotificationService.cs` — Sends PII over `HttpClient` with `http://` (not HTTPS) base URL
    - `Services/GeneticScreeningService.cs` — Processes genetic markers without consent verification

    **Mapped violations (one per ring to demonstrate gap detection):**
    | Violation | File | Ring that catches it |
    |---|---|---|
    | Logging SSN/email to console | `PatientController.cs` | Ring 1 (ontology says "never log PII identifiers") |
    | Plain-text PHI in JSON file | `PatientStore.cs` | Ring 1 (ontology: "encrypt PHI at rest") |
    | No RBAC on PHI endpoints | `PatientController.cs` | Ring 1 (ontology: "authenticate all PHI access") |
    | No retention TTL on records | `PatientStore.cs` | Ring 1 (ontology: "90-day retention for non-active records") |
    | SSNs not encrypted with AES-256 | `PatientStore.cs` | Ring 2 (Word doc says AES-256 specifically; ontology only says "encrypt") |
    | Biometric data without consent flow | `PatientController.cs` | Ring 2 (email thread discusses consent requirement) |
    | Genetic data without state protections | `GeneticScreeningService.cs` | Ring 2 (meeting transcript: new state genetic data laws) |
    | HTTP not HTTPS for internal PII transfer | `NotificationService.cs` | Ring 1+3 (both ontology and HIPAA require encrypted transmission) |
    | Automated profiling without DPIA | `AnalyticsController.cs` | Ring 3 (GDPR Art. 35 — only in regulatory text) |
    | No data subject access/deletion endpoint | Missing entirely | Ring 3 (GDPR Art. 15/17 — only in regulatory text) |

**Deliverables:** A realistic-looking app with ~8-10 distinct violation categories

---

## Phase 4: PII Sentry CLI Core (Days 3-5)

12. **CLI structure** (`/src/PiiSentry.Cli/`):
    - `dotnet tool` global tool, invoked as `pii-sentry scan <path> [--ring fabric|workiq|foundry|all] [--output report.json|report.html]`
    - Uses `GitHub.Copilot.SDK` + `Microsoft.Agents.AI.GitHub.Copilot` (Agent Framework integration) for agentic code analysis
    - Three-ring architecture implemented as sequential analysis passes
    - **Graceful availability model:** Each ring is attempted in order. If a ring's IQ source is unreachable (auth failure, service unavailable, tenant not configured), the CLI logs that the ring was skipped and why, continues with the remaining rings, and includes a "Ring Availability" section in the report listing which sources were consulted and which were unavailable. No fallback logic — the ring is simply absent from the results.
    - **SDK feedback (ongoing):** As you implement the CLI and agent tools, capture friction points — unclear docs, missing APIs, surprising behaviors, feature gaps. Log these in `/docs/sdk-feedback.md` as you go. This becomes the basis for the bonus-point submission.

    **NuGet packages:**
    - `GitHub.Copilot.SDK` — Low-level Copilot SDK (`CopilotClient`, JSON-RPC process lifecycle)
    - `Microsoft.Agents.AI.GitHub.Copilot` — Agent Framework integration (`GitHubCopilotAgent`, `AIAgent` abstraction, `SessionConfig`). Install with `--prerelease`.
    - `Microsoft.Extensions.AI` — `AIFunctionFactory.Create()` for registering custom tools
    - `Azure.AI.Projects` — Foundry Agent Service client (`AIProjectClient`, `FabricTool`)
    - `Azure.Identity` — `InteractiveBrowserCredential` / `DefaultAzureCredential` for OBO
    - `Azure.Search.Documents` — Foundry IQ agentic retrieval API calls (if needed directly)
    - `Microsoft.ApplicationInsights` — Telemetry
    - `Microsoft.Extensions.Logging.ApplicationInsights` — ILogger sink
    - `System.CommandLine` — CLI argument parsing (`--ring`, `--output`, `<path>`)

    **Authentication flow:**
    - On first run, CLI triggers interactive browser login via `InteractiveBrowserCredential` (Entra ID)
    - Acquire tokens scoped to: Foundry (`https://management.azure.com/.default`), M365 (for Work IQ — handled by Work IQ MCP server's own auth), AI Search
    - Cache tokens via MSAL token cache so subsequent runs don't re-prompt
    - `--tenant-id` optional CLI flag for multi-tenant scenarios

    **Configuration (`appsettings.json` or env vars):**
    - `FOUNDRY_PROJECT_ENDPOINT` — AI Foundry project endpoint
    - `FOUNDRY_FABRIC_AGENT_ID` — Pre-created Foundry agent ID (from CI/CD post-provisioning, step 8c). The CLI uses this to create threads, not agents.
    - `FABRIC_CONNECTION_ID` — Foundry connection ID for Fabric Data Agent (format: `/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.MachineLearningServices/workspaces/{project}/connections/{name}`). Used at **CI/CD setup time** (step 8c) to attach the Fabric Data Agent to the Foundry agent; not used at CLI runtime.
    - `AI_SEARCH_ENDPOINT` — Azure AI Search endpoint for Foundry IQ knowledge base
    - `AI_SEARCH_KNOWLEDGE_BASE` — Knowledge base name
    - `APPLICATIONINSIGHTS_CONNECTION_STRING` — App Insights telemetry
    - `WORKIQ_TENANT_ID` — (optional) M365 tenant ID for Work IQ

12b. **Copilot SDK integration pattern (Microsoft Agent Framework):**
    The SDK communicates with Copilot CLI via JSON-RPC. The Agent Framework provides a consistent `AIAgent` abstraction. The programming model:
    1. Create a `CopilotClient` and call `StartAsync()` to launch the Copilot CLI process
    2. Create a `SessionConfig` with:
       - `OnPermissionRequest` — permission handler callback (required for file reads, shell commands, URL fetches)
       - `McpServers` — dictionary of MCP server configs (Work IQ as `McpLocalServerConfig` with stdio transport)
    3. Register custom **function tools** via `AIFunctionFactory.Create()` (from `Microsoft.Extensions.AI`):
       - `query_fabric_data_agent` — invokes Ring 1 (calls Foundry Agent Service → Fabric Data Agent)
       - `query_foundry_iq` — invokes Ring 3 (calls Foundry IQ agentic retrieval API)
       - *(Ring 2 tools are provided natively by the Work IQ MCP server via `SessionConfig.McpServers`)*
       - **File reading:** The Copilot agent has built-in capabilities for file reads and shell commands (gated by `OnPermissionRequest`). Use these for code scanning instead of custom `scan_directory`/`read_file` tools — the agent already knows how to navigate codebases. The permission handler auto-approves reads within the target scan path and denies everything else.
    4. Create the agent via `copilotClient.AsAIAgent(sessionConfig, tools: [...], instructions: "...")` — returns `AIAgent` with native MCP, permissions, and custom tools. *(Note: `new GitHubCopilotAgent(copilotClient, ...)` also works and adds multi-turn `AgentSession` support, but how `SessionConfig` is passed to this constructor needs verification during implementation — prefer `AsAIAgent` as the primary path.)*
    5. Run the agent: `await agent.RunAsync("Scan this codebase for PII/PHI handling violations using all available rings")`
       - For streaming output: `await foreach (var update in agent.RunStreamingAsync(...))`
       - For multi-turn (reconciliation pass): create `AgentSession session = await agent.GetNewSessionAsync()` and pass to subsequent `RunAsync` calls
    6. The agent autonomously calls tools: reads code files, queries each ring for requirements, compares, and produces structured findings
    7. Parse the agent's structured response into `ComplianceReport` model

    **How code analysis works:**
    - The agent does NOT receive the entire codebase in one prompt. Instead, it uses its built-in file reading capabilities (approved via `OnPermissionRequest`) to discover and selectively read relevant files (controllers, services, data access layers, config files)
    - The system prompt in AGENTS.md instructs the agent to look for patterns: logging calls with PII fields, unencrypted storage, HTTP endpoints without auth, data retention logic, consent flows
    - Each ring's tool returns requirements text; the agent cross-references requirements against code it has read
    - The agent outputs findings in a structured JSON schema (defined in the system prompt): `{ ring, severity, file, line, violation, requirement, citation, remediation }`

13. **Ring 1 — Fabric Data Agent (Ontology-Backed Codified Standards) via Foundry Agent Service:**
    - The Fabric Data Agent is **consumed through Foundry Agent Service** using a **pre-created Foundry agent** (provisioned at CI/CD time — see step 8c). The CLI does NOT create agents per scan.
    - At runtime the CLI:
      1. Reads `FOUNDRY_FABRIC_AGENT_ID` from config
      2. Creates a **disposable thread** on that agent via `AIProjectClient.CreateThread()`
      3. Posts a message to the thread: "What are our organization's PII/PHI handling requirements, data classification rules, encryption mandates, and retention policies?"
      4. Runs the thread — the pre-attached `FabricTool` automatically invokes the Fabric Data Agent
      5. Collects the response and deletes the thread
    - All queries use **OBO identity passthrough** — the signed-in user's Entra identity flows through Foundry → Fabric, so results respect Fabric permissions
    - Copilot SDK agent analyzes target codebase against these codified rules
    - Produces: list of violations against *current org standards*

14. **Ring 2 — Work IQ (Uncodified Business Knowledge):**
    - Work IQ is configured as a **native MCP server** via `SessionConfig.McpServers` — the SDK manages the child process lifecycle automatically:
      ```csharp
      McpServers = new Dictionary<string, object>
      {
          ["workiq"] = new McpLocalServerConfig
          {
              Type = "stdio",
              Command = "npx",
              Args = ["-y", "@microsoft/workiq", "mcp"],
              Tools = ["*"],
          },
      }
      ```
    - Work IQ tools are available as **first-class agent tools** — no custom `query_work_iq` wrapper needed. The agent can directly invoke Work IQ's MCP tools during its reasoning loop.
    - The agent queries for: "What recent decisions, policies, or guidelines about PII/PHI handling have been discussed in documents, meetings, or emails?"
    - Receives: unstructured text from Word docs, transcripts, emails
    - Runs under the **signed-in user's M365 identity** (Work IQ handles its own auth via browser login); only surfaces content the user has permission to see
    - Work IQ will prompt for EULA acceptance on first use (`workiq accept-eula`)
    - Copilot SDK agent compares these against Ring 1 findings to find:
      a. New requirements not yet in the ontology (gaps in codification)
      b. Additional violations in code that only the informal docs would catch

15. **Ring 3 — Foundry IQ (Regulatory Intelligence):**
    - The `query_foundry_iq` tool implementation calls the Azure AI Search agentic retrieval REST API:
      `POST https://{search-service}.search.windows.net/knowledgebases/{kb-name}/retrieve?api-version=2025-11-01-preview`
    - Request body includes the NL query plus `retrievalReasoningEffort: "medium"` for LLM-powered multi-source query planning
    - The knowledge base automatically selects between the Bing web source and the vector-indexed regulatory corpus based on the query
    - Uses both Bing (real-time regulatory news/enforcement actions) and vector search (regulatory text corpus)
    - Authenticate with the signed-in user's Entra token (scope: `https://search.azure.com/.default`) or API key from config
    - Copilot SDK agent compares actual regulatory requirements against Rings 1+2 to find:
      a. Regulatory requirements missing from both org standards AND informal docs
      b. Code violations that only current regulatory text would catch
    - Responses include extractive content with **citations** (source document, chunk offset) — pass these through to the report

16. **Report Generation:**
    - The Copilot SDK agent outputs findings in structured JSON as part of its response. The CLI parses this into `ComplianceReport` model objects.
    - **JSON report schema:**
      ```
      ComplianceReport {
        scanPath, timestamp, ringAvailability[],
        findings[]: { id, ring (fabric|workiq|foundry), severity (critical|high|medium|low|info),
                      file, lineRange, violationType, description, requirement, citation, remediation },
        reconciliation: { ontologyGaps[], codificationRecommendations[], regulatoryDelta[] },
        summary: { totalFindings, byRing{}, bySeverity{} }
      }
      ```
    - **HTML report:** Use a single-file HTML template embedded as a resource in `PiiSentry.Core`. Inline CSS + minimal JS for the concentric-ring visualization (three nested SVG circles, findings listed in expandable sections per ring). No external dependencies — the HTML file is self-contained and opens in any browser.
    - **Reconciliation logic** (`ReconciliationAgent.cs`): After all rings complete, a final Copilot SDK prompt takes the combined findings and identifies:
      - Gaps where the ontology is silent but Work IQ docs or regulations have requirements → "Codify this into your ontology"
      - Gaps where Work IQ docs discuss a requirement but it's not in the ontology AND not in regulations → "Verify if this is internal policy or regulatory"
      - Requirements found only in regulations (Ring 3) that neither ontology nor docs capture → "Critical: regulatory requirement not tracked anywhere in your org"
    - "Ring Availability" section listing which sources were consulted and which were unavailable
    - Summary: "X violations found against org standards, Y additional from business artifacts, Z additional from regulatory intelligence"

16b. **Observability:**
    - Integrate Application Insights SDK (`Microsoft.ApplicationInsights`) into the CLI
    - Emit custom telemetry: scan duration, per-ring latency, findings count per ring, ring availability status, errors
    - Structured logging via `ILogger` with Application Insights sink
    - Connection string configured via environment variable or `appsettings.json`

**Deliverables:** Working CLI that scans code and produces multi-ring compliance report

---

## Phase 5: Integration, Polish, and Submission Assets (Days 5-7)

17. **End-to-end demo flow:**
    - Run `pii-sentry scan ./src/PiiSentry.DemoApp/ --ring all --output report.html`
    - Show concentric ring expansion of findings
    - Highlight the reconciliation: "Your ontology says X, but your legal team discussed Y, and the actual regulation requires Z"

18. **Documentation** (`/docs/`):
    - README: Problem → Solution, prerequisites, setup, deployment instructions (Terraform + portal steps + CLI install), architecture diagram
    - Architecture diagram (Mermaid) — include in both README and presentation deck: CLI → Copilot SDK → [Fabric Data Agent (via Foundry) | Work IQ | Foundry IQ] → Report
    - RAI notes (`/docs/rai-notes.md`):
      - **Data minimization:** CLI reads source code locally; only sends NL queries to IQ sources, never sends raw code or PII to external services
      - **Transparency:** Report cites which IQ source produced each finding with source attribution
      - **Permission-aware:** All IQ queries run under end-user identity (OBO) — respects Fabric, M365, and Foundry ACLs
      - **Human oversight:** Findings are recommendations, not automated enforcement; human review is required before action
      - **No data retention:** CLI does not persist any PII/PHI; reports are generated locally
      - **Bias and fairness:** Regulatory analysis is grounded in source documents, not model opinion; citations ensure auditability

19. **AGENTS.md:** Custom Copilot instructions for PII Sentry agent persona
20. **mcp.json:** Work IQ MCP server config
21. **Presentation deck** (`/presentations/PiiSentry.pptx`): 1-2 slides, business value proposition, architecture diagram, **link to GitHub repo** (required by brief)
22. **Demo video** (3 min max): Show scan of demo app, walkthrough of three rings, reconciliation
23. **150-word project summary:** Write concise summary for submission form (required deliverable)

### Bonus Point Actions
24. **Copilot SDK product feedback (10 pts):** Compile `/docs/sdk-feedback.md` (accumulated during Phases 1-4) into actionable feedback. Post to the Copilot SDK Teams channel. Take screenshot and include in submission. Categories to capture:
    - Documentation gaps or inaccuracies (especially .NET cookbook)
    - Missing APIs or SDK features (e.g., `FabricTool` .NET parity, `SessionConfig` API discoverability)
    - Surprising behaviors or error messages
    - Feature requests based on real implementation needs
25. **Customer validation (10 pts):** If possible, validate with an internal compliance/security team or external customer. Include testimonial release form in `/customer/` folder, or document the validation interaction.

---

## Relevant Files

- `/src/PiiSentry.Cli/Program.cs` — CLI entry point, command parser, orchestrator
- `/src/PiiSentry.Cli/Agents/FabricDataAgent.cs` — Ring 1: creates a thread on the pre-provisioned Foundry agent (by ID), queries ontology-backed data agent via `AIProjectClient`
- `/src/PiiSentry.Cli/Agents/WorkIqAgent.cs` — Ring 2: configures `McpLocalServerConfig` for Work IQ, parses MCP tool results into ring findings
- `/src/PiiSentry.Cli/Agents/FoundryIqAgent.cs` — Ring 3: queries Foundry IQ knowledge base for regulatory intel
- `/src/PiiSentry.Cli/Agents/ReconciliationAgent.cs` — Cross-ring analysis and gap reconciliation
- `/src/PiiSentry.Core/Models/` — Violation, Finding, ComplianceReport, Ring, RingAvailability models
- `/src/PiiSentry.Core/Reports/ReportGenerator.cs` — JSON + HTML report output
- `/src/PiiSentry.DemoApp/` — Intentionally-violating demo ASP.NET Core app
- `/infra/main.tf` — Root Terraform config (AzApi v2.8.0)
- `/infra/modules/` — AI Search, AI Foundry, Storage, Observability (App Insights + Log Analytics), Fabric (capacity), Identity modules
- `/demo-data/ontology/` — Ontology definition JSON + seed CSV data for lakehouse tables
- `/demo-data/fabric-data-agent/` — Fabric Data Agent config (synced via Git integration): `data_agent.json`, `stage_config.json` (aiInstructions), `draft/ontology-PiiPhiCompliance/datasource.json`, `draft/ontology-PiiPhiCompliance/fewshots.json`
- `/demo-data/docs/` — Word docs and meeting transcript content for Work IQ
- `/demo-data/regulatory/` — Regulatory text PDFs for Foundry IQ vector store
- `/.github/workflows/deploy.yml` — CI/CD with WIF auth (infra + Fabric ALM), build, test
- `/AGENTS.md` — Copilot agent instructions
- `/mcp.json` — MCP server config for VS Code Copilot discovery (Work IQ only; the CLI uses `SessionConfig.McpServers` in code)
- `/docs/README.md` — Full documentation
- `/docs/architecture.md` — Architecture diagram
- `/docs/rai-notes.md` — Responsible AI notes (data minimization, transparency, permissions, human oversight, no retention, auditability)
- `/docs/sdk-feedback.md` — Running log of Copilot SDK friction points, bugs, and feature requests (captured during Phases 1-4, compiled into Teams post in Phase 5)
- `/infra/scripts/create-foundry-agent.sh` — CI/CD post-provisioning script: idempotently creates the Foundry agent with `FabricTool`, stores agent ID
- `/customer/` — (optional) Customer/internal validation testimonial release

## Verification

1. `dotnet build /src/PiiSentry.Cli/` compiles without errors on .NET 10
2. `terraform validate` passes on `/infra/`
3. `terraform plan` shows expected resources (AI Search, AI Foundry, Storage, App Insights, Log Analytics, identity)
4. CI/CD pipeline authenticates via WIF and runs `terraform apply` + `dotnet build` successfully
5. `pii-sentry scan ./src/PiiSentry.DemoApp/ --ring fabric` returns Ring 1 findings
6. `pii-sentry scan ./src/PiiSentry.DemoApp/ --ring workiq` returns Ring 1 + Ring 2 findings
7. `pii-sentry scan ./src/PiiSentry.DemoApp/ --ring all` returns all three rings with reconciliation
8. HTML report renders concentric ring visualization with per-ring findings and "Ring Availability" section
9. Application Insights shows custom telemetry events (scan duration, ring latency, findings count) after a scan
10. Demo video captures full scan flow in under 3 minutes
11. 150-word project summary is written and ready for submission form
12. Presentation deck includes repo link, architecture diagram, and business value proposition

## Decisions

- **Fabric IQ integration:** The Fabric Data Agent (ontology-backed) is **consumed via Foundry Agent Service** using a **pre-created Foundry agent**. The agent is created once at CI/CD time (post-provisioning script, step 8c) with `FabricTool` attached via a Foundry connection. Foundry agents are data-plane resources — they cannot be managed by Terraform. The CLI reads the agent ID from config (`FOUNDRY_FABRIC_AGENT_ID`), creates a disposable thread per scan, queries the ontology, and deletes the thread. All queries use OBO identity passthrough. There is no direct REST/MCP to the Fabric Data Agent.
- **Single-project architecture:** There is one deployable artifact (`PiiSentry.Cli`). The Copilot SDK agent runs in-process (local reasoning). The Foundry agent is a remote resource (Ring 1 only). Work IQ is an SDK-managed native MCP server (via `McpLocalServerConfig`). Foundry IQ (AI Search) is a direct REST call. No separate hosted apps or sidecar services are needed.
- **Fabric Data Agent source control:** Data agent config (ontology schema selection, AI instructions, few-shot examples) is versioned in Git via Fabric Git integration. The repo stores `datasource.json`, `fewshots.json`, and `stage_config.json` under the data agent folder. CI/CD SPN can sync Git → Fabric workspace and promote via deployment pipelines (dev → test → prod). SPN is **not** supported for data agent queries.
- **Identity model:** All three IQ data-plane queries (Fabric Data Agent via Foundry, Work IQ, Foundry IQ) run under the **end user's identity** (OBO/delegated). The WIF service principal is used **only for CI/CD infrastructure provisioning and Fabric ALM operations** (git sync, deployment pipeline promotion). Users need at minimum `AI Developer` RBAC role in the Foundry project.
- **.NET 10 + Copilot SDK + Agent Framework:** Use `GitHub.Copilot.SDK` (low-level) + `Microsoft.Agents.AI.GitHub.Copilot` (Agent Framework integration). The `CopilotClient` manages the Copilot CLI process lifecycle; the CLI creates an `AIAgent` (or `GitHubCopilotAgent`) with custom function tools (via `AIFunctionFactory.Create()`) and MCP servers (via `SessionConfig.McpServers`). This provides the consistent `AIAgent` abstraction, multi-turn `AgentSession`, streaming, and native MCP server management.
- **AzApi v2.8.0:** Use azapi_resource for all Azure resources, avoiding azurerm provider. Pin version explicitly.
- **Work IQ as native MCP server:** Work IQ is configured as an `McpLocalServerConfig` (stdio) in `SessionConfig.McpServers`. The Copilot SDK manages the child process lifecycle — no manual spawning needed. Work IQ tools become first-class agent tools. Runs under the signed-in user's M365 identity.
- **No fallbacks:** If an IQ source is unavailable, the CLI skips that ring, notes it in the report, and proceeds with the remaining rings. No mock data, no alternative query paths.
- **Scope boundaries:**
  - IN: CLI tool, three-ring analysis, demo app, infra, docs, presentation
  - OUT: Web UI, SaaS deployment, multi-tenant, real customer data
- **Timeline simplification:** Pre-generate the M365 artifacts (Word docs, transcripts) manually rather than scripting their creation. Focus engineering effort on the CLI and ring integration.
- **Fabric provisioning:** Fabric workspace, ontology, data agent, publishing, and Foundry connection are set up via portal (not Terraform-automatable). Terraform provisions Fabric capacity only. Data agent config is then synced to Git for version control. Prerequisites include: F2+ capacity, data agent tenant settings enabled, cross-geo AI processing/storing enabled, `AI Developer` role for Foundry users.

## Further Considerations

1. **Foundry Agent Service .NET SDK maturity:** The Fabric Data Agent → Foundry integration docs show Python examples (`Azure.AI.Projects`, `Azure.AI.Agents`). The .NET equivalent (`Azure.AI.Projects` NuGet) needs to support `FabricTool`. Verify this early. If the .NET SDK doesn't yet have `FabricTool`, options: (a) wrap a thin Python script that the .NET CLI invokes, or (b) call the Foundry Agent REST API directly from .NET.

2. **Work IQ tenant consent:** Work IQ requires admin consent in the M365 tenant. For the demo, this needs to be set up in advance. If Work IQ is unavailable, Ring 2 is simply skipped and the report notes it.

3. **Scoring optimization for the challenge:**
   - Enterprise applicability (30 pts): PII/PHI compliance is a universal enterprise need. The concentric-ring approach is novel and reusable across industries.
   - Azure integration (25 pts): AI Search, AI Foundry (Agent Service), Fabric IQ (ontology + data agent), Blob Storage, Entra ID, Application Insights, Log Analytics — deep Microsoft stack.
   - Operational readiness (15 pts): Terraform IaC, WIF CI/CD, Fabric deployment pipelines (dev→test→prod), Application Insights telemetry (scan latency, ring metrics, errors), structured logging.
   - Security/RAI (15 pts): OBO identity passthrough on all rings, no PII stored, data minimization (NL queries only, no code exfiltrated), transparent source attribution, human-in-the-loop design, detailed RAI notes.
   - Storytelling (15 pts): "Your compliance posture has blind spots between what you've codified, what your teams know, and what regulations actually require. PII Sentry closes all three gaps in one scan."
   - **Bonus: Work IQ / Fabric IQ / Foundry IQ (15 pts total):** All three IQ workloads used — Fabric Data Agent (ontology-backed via Foundry), Work IQ (MCP), Foundry IQ (Bing + vector search).
   - **Bonus: Copilot SDK product feedback (10 pts):** File feedback + post screenshot in Teams channel.
   - **Bonus: Customer validation (10 pts):** Validate with internal compliance team or customer if feasible.
   - **Total addressable: 100 base + 35 bonus = 135 pts**
