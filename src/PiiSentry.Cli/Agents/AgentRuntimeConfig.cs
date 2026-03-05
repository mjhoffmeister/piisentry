namespace PiiSentry.Cli.Agents;

internal sealed record AgentRuntimeConfig(string? FoundryFabricAgentId, string? FoundryProjectEndpoint)
{
    public static AgentRuntimeConfig Resolve(string? foundryFabricAgentIdOverride)
    {
        var foundryFabricAgentId = string.IsNullOrWhiteSpace(foundryFabricAgentIdOverride)
            ? Environment.GetEnvironmentVariable("FOUNDRY_FABRIC_AGENT_ID")
            : foundryFabricAgentIdOverride;

        var foundryProjectEndpoint = Environment.GetEnvironmentVariable("FOUNDRY_PROJECT_ENDPOINT");

        return new AgentRuntimeConfig(
            FoundryFabricAgentId: Normalize(foundryFabricAgentId),
            FoundryProjectEndpoint: Normalize(foundryProjectEndpoint));
    }

    private static string? Normalize(string? value) => string.IsNullOrWhiteSpace(value) ? null : value.Trim();
}
