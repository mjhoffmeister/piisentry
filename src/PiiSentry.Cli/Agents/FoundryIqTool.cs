using System.ComponentModel;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using Azure.Core;
using Microsoft.Extensions.AI;
using PiiSentry.Cli.Auth;

namespace PiiSentry.Cli.Agents;

/// <summary>
/// Ring 3 tool — queries the Foundry IQ knowledge base via Azure AI Search agentic retrieval.
/// </summary>
internal static class FoundryIqTool
{
    private static readonly HttpClient HttpClient = new();

    /// <summary>
    /// Creates an <see cref="AIFunction"/> that queries the agentic retrieval endpoint for regulatory intelligence.
    /// </summary>
    public static AIFunction Create(AgentRuntimeConfig config)
    {
        return AIFunctionFactory.Create(
            async ([Description("Natural-language query about regulatory requirements for PII/PHI handling, such as HIPAA, GDPR, or CCPA requirements")] string query) =>
            {
                if (config.AiSearchEndpoint is null || config.AiSearchKnowledgeBase is null)
                {
                    return "Ring 3 (Foundry IQ) is unavailable: AI_SEARCH_ENDPOINT or AI_SEARCH_KNOWLEDGE_BASE not configured.";
                }

                try
                {
                    AccessToken token = await AuthProvider.GetCredential()
                        .GetTokenAsync(new TokenRequestContext(["https://search.azure.com/.default"]), CancellationToken.None);

                    string url = $"{config.AiSearchEndpoint.TrimEnd('/')}/knowledgebases/{config.AiSearchKnowledgeBase}/retrieve?api-version=2025-11-01-preview";

                    var requestBody = new
                    {
                        messages = new[]
                        {
                            new { role = "user", content = new[] { new { type = "text", text = query } } }
                        },
                        retrievalReasoningEffort = new { kind = "medium" }
                    };

                    HttpRequestMessage request = new(HttpMethod.Post, url)
                    {
                        Content = new StringContent(
                            JsonSerializer.Serialize(requestBody),
                            Encoding.UTF8,
                            "application/json")
                    };

                    request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token.Token);

                    HttpResponseMessage response = null!;
                    string json = string.Empty;

                    for (int attempt = 0; attempt < 3; attempt++)
                    {
                        if (attempt > 0)
                        {
                            // Re-create request since HttpRequestMessage can only be sent once
                            request = new HttpRequestMessage(HttpMethod.Post, url)
                            {
                                Content = new StringContent(
                                    JsonSerializer.Serialize(requestBody),
                                    Encoding.UTF8,
                                    "application/json")
                            };
                            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token.Token);
                        }

                        response = await HttpClient.SendAsync(request);
                        json = await response.Content.ReadAsStringAsync();

                        if ((int)response.StatusCode != 429)
                            break;

                        // Respect Retry-After header, or default to exponential backoff
                        var delay = response.Headers.RetryAfter?.Delta
                            ?? TimeSpan.FromSeconds(Math.Pow(2, attempt) * 15);
                        Console.Error.WriteLine($"  [Ring 3] 429 rate-limited, retrying in {delay.TotalSeconds:F0}s (attempt {attempt + 1}/3)");
                        await Task.Delay(delay);
                    }

                    if (!response.IsSuccessStatusCode)
                    {
                        Console.Error.WriteLine($"  [Ring 3 error] HTTP {(int)response.StatusCode}: {json}");
                        return $"Ring 3 query returned HTTP {(int)response.StatusCode}: {json}";
                    }

                    using var doc = JsonDocument.Parse(json);
                    var root = doc.RootElement;

                    List<string> results = [];

                    if (root.TryGetProperty("response", out var responseElem)
                        && responseElem.ValueKind == JsonValueKind.Array)
                    {
                        foreach (var msg in responseElem.EnumerateArray())
                        {
                            if (msg.TryGetProperty("content", out var contentArr)
                                && contentArr.ValueKind == JsonValueKind.Array)
                            {
                                foreach (var part in contentArr.EnumerateArray())
                                {
                                    if (part.TryGetProperty("text", out var t))
                                    {
                                        var raw = t.GetString() ?? string.Empty;
                                        // The API sometimes returns the text as a JSON array of
                                        // {ref_id, title, content} objects. Parse those into
                                        // readable text so the agent gets clean regulatory content.
                                        results.AddRange(ExtractReadableChunks(raw));
                                    }
                                }
                            }
                        }
                    }
                    else if (root.TryGetProperty("response", out var respStr)
                        && respStr.ValueKind == JsonValueKind.String)
                    {
                        results.AddRange(ExtractReadableChunks(respStr.GetString() ?? string.Empty));
                    }

                    if (root.TryGetProperty("activity", out var activity)
                        && activity.ValueKind == JsonValueKind.Array)
                    {
                        foreach (var activityItem in activity.EnumerateArray())
                        {
                            if (activityItem.TryGetProperty("retrievalResults", out var retrievalResults)
                                && retrievalResults.ValueKind == JsonValueKind.Array)
                            {
                                foreach (var result in retrievalResults.EnumerateArray())
                                {
                                    var content = result.TryGetProperty("content", out var c)
                                        ? c.GetString() ?? string.Empty
                                        : string.Empty;
                                    var source = result.TryGetProperty("source", out var s)
                                        ? s.GetString() ?? "unknown"
                                        : "unknown";
                                    var score = result.TryGetProperty("score", out var sc)
                                        ? sc.GetDouble().ToString("F2")
                                        : "n/a";

                                    if (!string.IsNullOrWhiteSpace(content))
                                        results.Add($"[Source: {source}, Score: {score}] {content}");
                                }
                            }
                        }
                    }

                    return results.Count > 0
                        ? string.Join("\n\n---\n\n", results)
                        : $"Ring 3 returned an empty result. Raw response: {json[..Math.Min(500, json.Length)]}";
                }
                catch (Exception ex)
                {
                    Console.Error.WriteLine($"  [Ring 3 exception] {ex.Message}");
                    return $"Ring 3 (Foundry IQ) encountered an error: {ex.Message}";
                }
            },
            "query_foundry_iq",
            "Query the Foundry IQ knowledge base for the latest regulatory intelligence on PII/PHI requirements including HIPAA, GDPR, CCPA, and recent enforcement actions");
    }

    /// <summary>
    /// The agentic retrieval API can return the text field as a JSON array of
    /// {ref_id, title, content} objects. This helper detects that and extracts
    /// the title + content into readable text chunks. If the text is not JSON,
    /// it is returned as-is.
    /// </summary>
    private static List<string> ExtractReadableChunks(string raw)
    {
        var chunks = new List<string>();
        if (string.IsNullOrWhiteSpace(raw))
            return chunks;

        var trimmed = raw.TrimStart();
        if (trimmed.StartsWith('[') || trimmed.StartsWith('{'))
        {
            try
            {
                using var innerDoc = JsonDocument.Parse(raw);
                var inner = innerDoc.RootElement;

                if (inner.ValueKind == JsonValueKind.Array)
                {
                    foreach (var item in inner.EnumerateArray())
                    {
                        var title = item.TryGetProperty("title", out var tt) ? tt.GetString() : null;
                        var content = item.TryGetProperty("content", out var cc) ? cc.GetString() : null;
                        if (!string.IsNullOrWhiteSpace(content))
                            chunks.Add(string.IsNullOrWhiteSpace(title) ? content : $"[{title}] {content}");
                    }
                    return chunks;
                }

                if (inner.ValueKind == JsonValueKind.Object)
                {
                    var content = inner.TryGetProperty("content", out var cc) ? cc.GetString() : null;
                    if (!string.IsNullOrWhiteSpace(content))
                    {
                        var title = inner.TryGetProperty("title", out var tt) ? tt.GetString() : null;
                        chunks.Add(string.IsNullOrWhiteSpace(title) ? content : $"[{title}] {content}");
                        return chunks;
                    }
                }
            }
            catch (JsonException)
            {
                // Not valid JSON — fall through to return raw text
            }
        }

        chunks.Add(raw);
        return chunks;
    }
}
