using Microsoft.Extensions.Configuration;

namespace PiiSentry.Cli.Agents;

internal sealed record AgentRuntimeConfig(
    string? FoundryFabricAgentId,
    string? FoundryProjectEndpoint,
    string? AiSearchEndpoint,
    string? AiSearchKnowledgeBase,
    string? WorkIqTenantId,
    string? ApplicationInsightsConnectionString)
{
    /// <summary>
    /// Builds configuration from appsettings.json (base) with environment variable overrides.
    /// CLI --foundry-agent-id flag takes highest precedence for that one value.
    /// </summary>
    public static AgentRuntimeConfig Resolve(string? foundryFabricAgentIdOverride)
    {
        var config = new ConfigurationBuilder()
            .SetBasePath(AppContext.BaseDirectory)
            .AddJsonFile("appsettings.json", optional: true)
            .AddEnvironmentVariables()
            .Build();

        var foundryFabricAgentId = string.IsNullOrWhiteSpace(foundryFabricAgentIdOverride)
            ? config["FOUNDRY_FABRIC_AGENT_ID"] ?? config["FoundryFabricAgentId"]
            : foundryFabricAgentIdOverride;

        return new AgentRuntimeConfig(
            FoundryFabricAgentId: Normalize(foundryFabricAgentId),
            FoundryProjectEndpoint: Normalize(config["FOUNDRY_PROJECT_ENDPOINT"] ?? config["FoundryProjectEndpoint"]),
            AiSearchEndpoint: Normalize(config["AI_SEARCH_ENDPOINT"] ?? config["AiSearchEndpoint"]),
            AiSearchKnowledgeBase: Normalize(config["AI_SEARCH_KNOWLEDGE_BASE"] ?? config["AiSearchKnowledgeBase"]),
            WorkIqTenantId: Normalize(config["WORKIQ_TENANT_ID"] ?? config["WorkIqTenantId"]),
            ApplicationInsightsConnectionString: Normalize(config["APPLICATIONINSIGHTS_CONNECTION_STRING"] ?? config["ApplicationInsightsConnectionString"]));
    }

    private static string? Normalize(string? value) => string.IsNullOrWhiteSpace(value) ? null : value.Trim();
}
