using PiiSentry.Cli.Agents;
using PiiSentry.Cli.Prompts;
using PiiSentry.Core;

if (args.Length == 0)
{
    Console.WriteLine("PII Sentry CLI");
    Console.WriteLine("Usage: pii-sentry scan <path> [--ring fabric|workiq|foundry|all] [--output <file>] [--foundry-agent-id <id>]");
    return;
}

if (!string.Equals(args[0], "scan", StringComparison.OrdinalIgnoreCase))
{
    Console.WriteLine($"Unknown command: {args[0]}");
    Console.WriteLine("Try: pii-sentry scan <path>");
    return;
}

var scanPath = args.Length > 1 ? args[1] : ".";
var selectedRing = "all";
string? outputFile = null;
string? foundryAgentIdOverride = null;

for (var i = 2; i < args.Length; i++)
{
    if (string.Equals(args[i], "--ring", StringComparison.OrdinalIgnoreCase))
    {
        if (i + 1 >= args.Length)
        {
            Console.WriteLine("Missing value for --ring. Expected one of: fabric, workiq, foundry, all");
            return;
        }

        selectedRing = args[++i].ToLowerInvariant();
        if (selectedRing is not ("fabric" or "workiq" or "foundry" or "all"))
        {
            Console.WriteLine($"Invalid ring value: {selectedRing}");
            Console.WriteLine("Expected one of: fabric, workiq, foundry, all");
            return;
        }

        continue;
    }

    if (string.Equals(args[i], "--output", StringComparison.OrdinalIgnoreCase))
    {
        if (i + 1 >= args.Length)
        {
            Console.WriteLine("Missing value for --output. Expected a file path.");
            return;
        }

        outputFile = args[++i];
        continue;
    }

    if (string.Equals(args[i], "--foundry-agent-id", StringComparison.OrdinalIgnoreCase))
    {
        if (i + 1 >= args.Length)
        {
            Console.WriteLine("Missing value for --foundry-agent-id. Expected an assistant id.");
            return;
        }

        foundryAgentIdOverride = args[++i];
        continue;
    }

    Console.WriteLine($"Unknown option: {args[i]}");
    Console.WriteLine("Usage: pii-sentry scan <path> [--ring fabric|workiq|foundry|all] [--output <file>] [--foundry-agent-id <id>]");
    return;
}

var runtimeConfig = AgentRuntimeConfig.Resolve(foundryAgentIdOverride);
var ring1Enabled = selectedRing is "fabric" or "all";

Console.WriteLine($"[Phase 2] Scan stub initialized for path: {scanPath}");
Console.WriteLine($"Ring selection: {selectedRing}");
Console.WriteLine($"Output path: {outputFile ?? "(not set)"}");
Console.WriteLine($"Foundry project endpoint: {runtimeConfig.FoundryProjectEndpoint ?? "(not set)"}");
Console.WriteLine($"Foundry Fabric agent id: {runtimeConfig.FoundryFabricAgentId ?? "(not set)"}");

if (ring1Enabled)
{
    if (runtimeConfig.FoundryProjectEndpoint is null)
    {
        Console.WriteLine("[Warning] Ring 1 selected but FOUNDRY_PROJECT_ENDPOINT is not set.");
    }

    if (runtimeConfig.FoundryFabricAgentId is null)
    {
        Console.WriteLine("[Warning] Ring 1 selected but Foundry agent id is not set. Use --foundry-agent-id or FOUNDRY_FABRIC_AGENT_ID.");
    }
}

Console.WriteLine($"Phase marker: {PhaseMarker.Value}");
Console.WriteLine("System prompt loaded successfully.");
Console.WriteLine($"Prompt length: {SystemPrompt.Text.Length} characters");
