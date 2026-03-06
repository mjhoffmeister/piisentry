using System.Text;
using GitHub.Copilot.SDK;
using Microsoft.Extensions.AI;
using PiiSentry.Cli.Prompts;
using PiiSentry.Cli.Telemetry;
using PiiSentry.Core.Models;

namespace PiiSentry.Cli.Agents;

internal sealed class ScanOrchestrator
{
    private readonly AgentRuntimeConfig _config;
    private readonly ScanTelemetry _telemetry;

    public ScanOrchestrator(AgentRuntimeConfig config, ScanTelemetry telemetry)
    {
        _config = config;
        _telemetry = telemetry;
    }

    public async Task<ComplianceReport> ScanAsync(
        string scanPath,
        IReadOnlyList<Ring> selectedRings,
        CancellationToken cancellationToken)
    {
        _telemetry.TrackScanStarted(scanPath, selectedRings);
        var sw = System.Diagnostics.Stopwatch.StartNew();

        var ringAvailability = BuildRingAvailability(selectedRings);
        var tools = BuildTools(selectedRings);
        var mcpServers = BuildMcpServers(selectedRings);

        await using var client = new CopilotClient(new CopilotClientOptions
        {
            Cwd = Path.GetFullPath(scanPath)
        });
        await client.StartAsync();

        var sessionConfig = new SessionConfig
        {
            Model = "gpt-5",
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
                    Console.WriteLine($"  [tool] {input.ToolName}");
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

        var responseBuilder = new StringBuilder();
        var done = new TaskCompletionSource();

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

        var agentResponse = responseBuilder.ToString();
        var report = AgentResponseParser.Parse(agentResponse, scanPath, ringAvailability);

        sw.Stop();
        _telemetry.TrackScanCompleted(sw.Elapsed, report.Summary.TotalFindings);

        return report;
    }

    private List<AIFunction> BuildTools(IReadOnlyList<Ring> selectedRings)
    {
        var tools = new List<AIFunction>();

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

    private Dictionary<string, object> BuildMcpServers(IReadOnlyList<Ring> selectedRings)
    {
        var servers = new Dictionary<string, object>();

        if (!selectedRings.Contains(Ring.WorkIq))
            return servers;

        var env = new Dictionary<string, string>();
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

    private static List<RingAvailability> BuildRingAvailability(IReadOnlyList<Ring> selectedRings)
    {
        var availability = new List<RingAvailability>();

        foreach (var ring in selectedRings)
        {
            availability.Add(new RingAvailability(ring, true, $"{ring} ring selected for analysis."));
        }

        return availability;
    }
}
