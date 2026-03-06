using Azure.Core;
using Azure.Identity;

namespace PiiSentry.Cli.Auth;

internal static class AuthProvider
{
    private static TokenCredential? _credential;

    // Every Azure resource scope the CLI needs — acquired upfront so the user
    // signs in only once and the token cache is warm for all subsequent calls.
    private static readonly string[] AllScopes =
    [
        "https://management.azure.com/.default",
        "https://cognitiveservices.azure.com/.default",
        "https://search.azure.com/.default",
        "https://ai.azure.com/.default"
    ];

    /// <summary>
    /// Builds a credential chain: interactive browser first (best UX for a CLI),
    /// then falls back to Azure CLI / environment for CI scenarios.
    /// </summary>
    public static TokenCredential GetCredential()
    {
        _credential ??= new ChainedTokenCredential(
            new InteractiveBrowserCredential(new InteractiveBrowserCredentialOptions
            {
                TokenCachePersistenceOptions = new TokenCachePersistenceOptions { Name = "pii-sentry" }
            }),
            new AzureCliCredential(),
            new EnvironmentCredential());

        return _credential;
    }

    /// <summary>
    /// Signs the user in once and pre-warms the token cache for every Azure
    /// resource scope the CLI will need during the scan. Returns the UPN/OID.
    /// </summary>
    public static async Task<string> VerifyAsync(CancellationToken ct = default)
    {
        var credential = GetCredential();
        string? identity = null;

        foreach (var scope in AllScopes)
        {
            var token = await credential.GetTokenAsync(
                new TokenRequestContext([scope]), ct);

            identity ??= ExtractIdentity(token.Token);
        }

        return identity ?? "authenticated";
    }

    private static string ExtractIdentity(string jwt)
    {
        var parts = jwt.Split('.');
        if (parts.Length < 2)
            return "authenticated";

        var payload = parts[1];
        payload = payload.PadRight(payload.Length + (4 - payload.Length % 4) % 4, '=');
        var json = System.Text.Encoding.UTF8.GetString(Convert.FromBase64String(payload));
        using var doc = System.Text.Json.JsonDocument.Parse(json);
        var root = doc.RootElement;

        var upn = root.TryGetProperty("upn", out var u) ? u.GetString() : null;
        var oid = root.TryGetProperty("oid", out var o) ? o.GetString() : null;

        return upn ?? oid ?? "authenticated";
    }
}
