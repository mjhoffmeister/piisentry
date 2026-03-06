using Azure.Core;
using Azure.Identity;

namespace PiiSentry.Cli.Auth;

/// <summary>
/// Provides Azure credential management with interactive browser login and token cache pre-warming.
/// </summary>
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

    /// <summary>
    /// Extracts the UPN or OID from a JWT access token payload.
    /// </summary>
    private static string ExtractIdentity(string jwt)
    {
        string[] parts = jwt.Split('.');
        if (parts.Length < 2)
            return "authenticated";

        try
        {
            string payload = parts[1];
            payload = payload.PadRight(payload.Length + (4 - payload.Length % 4) % 4, '=');
            string json = System.Text.Encoding.UTF8.GetString(Convert.FromBase64String(payload));
            using System.Text.Json.JsonDocument doc = System.Text.Json.JsonDocument.Parse(json);
            System.Text.Json.JsonElement root = doc.RootElement;

            string? upn = root.TryGetProperty("upn", out var u) ? u.GetString() : null;
            string? oid = root.TryGetProperty("oid", out var o) ? o.GetString() : null;

            return upn ?? oid ?? "authenticated";
        }
        catch
        {
            return "authenticated";
        }
    }
}
