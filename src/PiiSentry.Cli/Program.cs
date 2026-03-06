using PiiSentry.Cli.Auth;
using PiiSentry.Cli.Agents;
using PiiSentry.Cli.Prompts;
using PiiSentry.Cli.Telemetry;
using PiiSentry.Core;
using PiiSentry.Core.Models;
using PiiSentry.Core.Reports;

if (args.Length == 0)
{
    PrintUsage();
    return;
}

if (!string.Equals(args[0], "scan", StringComparison.OrdinalIgnoreCase))
{
    Console.WriteLine($"Unknown command: {args[0]}");
    PrintUsage();
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
    PrintUsage();
    return;
}

if (!Directory.Exists(scanPath) && !File.Exists(scanPath))
{
    Console.WriteLine($"Scan path not found: {scanPath}");
    return;
}

var runtimeConfig = AgentRuntimeConfig.Resolve(foundryAgentIdOverride);
IReadOnlyList<Ring> ringSelection = selectedRing switch
{
    "fabric" => new[] { Ring.Fabric },
    "workiq" => new[] { Ring.WorkIq },
    "foundry" => new[] { Ring.Foundry },
    _ => new[] { Ring.Fabric, Ring.WorkIq, Ring.Foundry }
};

// Verify Azure auth upfront if any ring needs Azure services
var needsAzureAuth = ringSelection.Any(r => r is Ring.Fabric or Ring.Foundry);
if (needsAzureAuth)
{
    try
    {
        var identity = await AuthProvider.VerifyAsync();
        Console.WriteLine($"Azure identity: {identity}");
    }
    catch (InvalidOperationException ex)
    {
        Console.Error.WriteLine(ex.Message);
        return;
    }
}

Console.WriteLine($"[Phase 4] Starting compliance scan for: {scanPath}");
Console.WriteLine($"Rings selected: {string.Join(", ", ringSelection)}");
Console.WriteLine($"Phase marker: {PhaseMarker.Value}");
Console.WriteLine($"System prompt loaded ({SystemPrompt.Build(scanPath).Length} chars)");

using var telemetry = new ScanTelemetry(runtimeConfig.ApplicationInsightsConnectionString);
var orchestrator = new ScanOrchestrator(runtimeConfig, telemetry);
var report = await orchestrator.ScanAsync(scanPath, ringSelection, CancellationToken.None);

var resolvedOutput = ResolveOutputPath(outputFile);
var ext = Path.GetExtension(resolvedOutput);
var outputContent = ext switch
{
    ".html" => ReportGenerator.ToHtml(report),
    ".md" => ReportGenerator.ToMarkdown(report),
    _ => ReportGenerator.ToJson(report)
};

Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(resolvedOutput))!);
await File.WriteAllTextAsync(resolvedOutput, outputContent);

Console.WriteLine($"Report generated: {resolvedOutput}");
Console.WriteLine($"Total findings: {report.Summary.TotalFindings}");
foreach (var availability in report.RingAvailability)
{
    var status = availability.Available ? "available" : "unavailable";
    Console.WriteLine($"- {availability.Ring}: {status} ({availability.Message})");
}

static void PrintUsage()
{
    Console.WriteLine("PII Sentry CLI");
    Console.WriteLine("Usage: pii-sentry scan <path> [--ring fabric|workiq|foundry|all] [--output <file>] [--foundry-agent-id <id>]");
}

static string ResolveOutputPath(string? outputFile)
{
    if (!string.IsNullOrWhiteSpace(outputFile))
    {
        return outputFile;
    }

    return $"pii-sentry-report-{DateTime.UtcNow:yyyyMMdd-HHmmss}.json";
}
