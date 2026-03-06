using System.ComponentModel;
using Azure.AI.Agents.Persistent;
using Azure.AI.Projects;
using Microsoft.Extensions.AI;
using PiiSentry.Cli.Auth;

namespace PiiSentry.Cli.Agents;

/// <summary>
/// Ring 1 tool — queries the Fabric Data Agent for codified PII/PHI organizational standards.
/// </summary>
internal static class FabricRingTool
{
    /// <summary>
    /// Creates an <see cref="AIFunction"/> that queries the pre-provisioned Foundry agent with a disposable thread.
    /// </summary>
    public static AIFunction Create(AgentRuntimeConfig config)
    {
        return AIFunctionFactory.Create(
            async ([Description("Natural-language query about the organization's PII/PHI handling requirements, data classification, encryption mandates, retention policies, or compliance controls")] string query) =>
            {
                if (config.FoundryProjectEndpoint is null || config.FoundryFabricAgentId is null)
                {
                    return "Ring 1 (Fabric Data Agent) is unavailable: FOUNDRY_PROJECT_ENDPOINT or FOUNDRY_FABRIC_AGENT_ID not configured.";
                }

                try
                {
                    var projectClient = new AIProjectClient(
                        new Uri(config.FoundryProjectEndpoint),
                        AuthProvider.GetCredential());

                    PersistentAgentsClient agentsClient = projectClient.GetPersistentAgentsClient();

                    PersistentAgentThread thread = await agentsClient.Threads.CreateThreadAsync();

                    try
                    {
                        await agentsClient.Messages.CreateMessageAsync(
                            thread.Id,
                            MessageRole.User,
                            query);

                        ThreadRun run = await agentsClient.Runs.CreateRunAsync(
                            thread.Id,
                            config.FoundryFabricAgentId);

                        while (run.Status == RunStatus.Queued || run.Status == RunStatus.InProgress)
                        {
                            await Task.Delay(500);
                            run = await agentsClient.Runs.GetRunAsync(thread.Id, run.Id);
                        }

                        if (run.Status != RunStatus.Completed)
                        {
                            return $"Ring 1 query failed: agent run ended with status '{run.Status}'.";
                        }

                        var messages = agentsClient.Messages.GetMessagesAsync(
                            thread.Id,
                            order: ListSortOrder.Descending,
                            limit: 1);

                        await foreach (var message in messages)
                        {
                            if (message.Role == MessageRole.Agent)
                            {
                                var parts = message.ContentItems
                                    .OfType<MessageTextContent>()
                                    .Select(t => t.Text);
                                return string.Join("\n", parts);
                            }
                        }

                        return "Ring 1 query returned no response from the Fabric Data Agent.";
                    }
                    finally
                    {
                        await agentsClient.Threads.DeleteThreadAsync(thread.Id);
                    }
                }
                catch (Exception ex)
                {
                    Console.Error.WriteLine($"  [Ring 1 error] {ex.GetType().Name}: {ex.Message}");
                    return $"Ring 1 (Fabric Data Agent) encountered an error: {ex.Message}";
                }
            },
            "query_fabric_data_agent",
            "Query the organization's Fabric Data Agent for codified PII/PHI handling standards, data classification rules, encryption mandates, and retention policies from lakehouse tables");
    }
}
