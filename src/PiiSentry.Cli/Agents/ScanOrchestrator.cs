using System.Text;
using GitHub.Copilot.SDK;
using Microsoft.Extensions.AI;
using PiiSentry.Cli.Prompts;
using PiiSentry.Cli.Telemetry;
using PiiSentry.Core.Models;

namespace PiiSentry.Cli.Agents;

/// <summary>
/// Orchestrates a PII/PHI compliance scan using the Copilot SDK with concentric-ring intelligence tools.
/// </summary>
internal sealed class ScanOrchestrator
{
    private const string DefaultModel = "gpt-5.3-codex";

    private readonly AgentRuntimeConfig _config;
    private readonly ScanTelemetry _telemetry;

    public ScanOrchestrator(AgentRuntimeConfig config, ScanTelemetry telemetry)
    {
        _config = config;
        _telemetry = telemetry;
    }

    /// <summary>
    /// Runs a compliance scan against the target path using the selected intelligence rings.
    /// Returns the report and the elapsed scan duration.
    /// </summary>
    public async Task<(ComplianceReport Report, TimeSpan Elapsed)> ScanAsync(
        string scanPath,
        IReadOnlyList<Ring> selectedRings,
        CancellationToken cancellationToken)
    {
        _telemetry.TrackScanStarted(scanPath, selectedRings);
        var sw = System.Diagnostics.Stopwatch.StartNew();

        ConsoleUI.PrintPhase("Preparing scan...");

        List<RingAvailability> ringAvailability = BuildRingAvailability(selectedRings);
        List<AIFunction> tools = BuildTools(selectedRings);
        Dictionary<string, object> mcpServers = BuildMcpServers(selectedRings);

        await using var client = new CopilotClient(new CopilotClientOptions
        {
            Cwd = Path.GetFullPath(scanPath)
        });
        
        await client.StartAsync();

        SessionConfig sessionConfig = new()
        {
            Model = DefaultModel,
            Tools = tools,
            OnPermissionRequest = PermissionHandler.ApproveAll,
            SystemMessage = new SystemMessageConfig
            {
                Mode = SystemMessageMode.Append,
                Content = SystemPrompt.Build(scanPath)
            },
            Hooks = new SessionHooks
            {
                OnPreToolUse = async (input, _) =>
                {
                    ConsoleUI.PrintToolCall(input.ToolName);
                    return new PreToolUseHookOutput
                    {
                        PermissionDecision = "allow"
                    };
                }
            }
        };

        if (mcpServers.Count > 0)
            sessionConfig.McpServers = mcpServers;

        await using var session = await client.CreateSessionAsync(sessionConfig);

        ConsoleUI.PrintPhase("Scanning source files and querying rings...");

        StringBuilder responseBuilder = new();
        TaskCompletionSource done = new();

        using var registration = cancellationToken.Register(() => done.TrySetCanceled());

        session.On(evt =>
        {
            switch (evt)
            {
                case AssistantMessageEvent msg:
                    responseBuilder.Append(msg.Data.Content);
                    break;
                case SessionErrorEvent err:
                    Console.Error.WriteLine($"  [error] {err.Data.Message}");
                    done.TrySetException(new InvalidOperationException(
                        $"Copilot session error: {err.Data.Message}"));
                    break;
                case SessionIdleEvent:
                    done.TrySetResult();
                    break;
            }
        });

        var prompt = $"Scan the directory '{scanPath}' for PII/PHI compliance violations. " +
                     $"Read all relevant source files, query the available ring tools, " +
                     $"and produce your findings as specified in your system instructions.";

        await session.SendAsync(new MessageOptions { Prompt = prompt });
        await done.Task;

        ConsoleUI.PrintPhase("Generating report...");

        string agentResponse = responseBuilder.ToString();
        ComplianceReport report = AgentResponseParser.Parse(agentResponse, scanPath, ringAvailability);

        sw.Stop();
        _telemetry.TrackScanCompleted(sw.Elapsed, report.Summary.TotalFindings);

        return (report, sw.Elapsed);
    }

    /// <summary>
    /// Builds the custom AIFunction tools for the selected rings (Fabric, Foundry).
    /// </summary>
    private List<AIFunction> BuildTools(IReadOnlyList<Ring> selectedRings)
    {
        List<AIFunction> tools = [];

        foreach (var ring in selectedRings)
        {
            switch (ring)
            {
                case Ring.Fabric:
                    tools.Add(FabricRingTool.Create(_config));
                    break;
                case Ring.Foundry:
                    tools.Add(FoundryIqTool.Create(_config));
                    break;
                    // Ring.WorkIq is exposed via MCP server, not a custom tool
            }
        }

        return tools;
    }

    /// <summary>
    /// Configures Work IQ as an MCP server when Ring 2 is selected.
    /// </summary>
    private Dictionary<string, object> BuildMcpServers(IReadOnlyList<Ring> selectedRings)
    {
        Dictionary<string, object> servers = new();

        if (!selectedRings.Contains(Ring.WorkIq))
            return servers;

        Dictionary<string, string> env = new();
        if (!string.IsNullOrWhiteSpace(_config.WorkIqTenantId))
            env["WORKIQ_TENANT_ID"] = _config.WorkIqTenantId;

        servers["workiq"] = new McpLocalServerConfig
        {
            Type = "stdio",
            Command = "npx",
            Args = ["-y", "@microsoft/workiq", "mcp"],
            Env = env,
            Tools = ["*"]
        };

        return servers;
    }

    /// <summary>
    /// Creates ring availability entries defaulting to available for each selected ring.
    /// </summary>
    private static List<RingAvailability> BuildRingAvailability(IReadOnlyList<Ring> selectedRings)
    {
        List<RingAvailability> availability = [];

        foreach (var ring in selectedRings)
        {
            availability.Add(new RingAvailability(ring, true, $"{ring} ring selected for analysis."));
        }

        return availability;
    }
}
