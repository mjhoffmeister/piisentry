using System.Text.Json;
using System.Text.Json.Serialization;
using PiiSentry.Core.Models;

namespace PiiSentry.Cli.Agents;

/// <summary>
/// Parses the Copilot agent’s JSON response into a structured <see cref="ComplianceReport"/>.
/// </summary>
internal static class AgentResponseParser
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true,
        Converters = { new JsonStringEnumConverter(JsonNamingPolicy.CamelCase) }
    };

    /// <summary>
    /// Parses the agent response JSON into a compliance report, falling back to
    /// a raw-output report on failure.
    /// </summary>
    public static ComplianceReport Parse(
        string agentResponse,
        string scanPath,
        IReadOnlyList<RingAvailability> ringAvailability)
    {
        try
        {
            string? json = ExtractJson(agentResponse);
            if (json is null)
            {
                return FallbackReport(agentResponse, scanPath, ringAvailability);
            }

            using var doc = JsonDocument.Parse(json);
            var root = doc.RootElement;

            var findings = ParseFindings(root);
            var reconciliation = ParseReconciliation(root);

            return ComplianceReportFactory.Create(
                scanPath,
                findings,
                ringAvailability,
                reconciliation);
        }
        catch
        {
            return FallbackReport(agentResponse, scanPath, ringAvailability);
        }
    }

    private static string? ExtractJson(string text)
    {
        // Find the outermost JSON object in the agent's response
        var start = text.IndexOf('{');
        if (start < 0) return null;

        var depth = 0;
        for (var i = start; i < text.Length; i++)
        {
            if (text[i] == '{') depth++;
            else if (text[i] == '}') depth--;

            if (depth == 0)
            {
                return text[start..(i + 1)];
            }
        }

        return null;
    }

    private static List<Finding> ParseFindings(JsonElement root)
    {
        List<Finding> findings = [];

        if (!root.TryGetProperty("findings", out var findingsElem)
            || findingsElem.ValueKind != JsonValueKind.Array)
        {
            return findings;
        }

        foreach (var f in findingsElem.EnumerateArray())
        {
            findings.Add(new Finding(
                Id: GetString(f, "id") ?? $"F-{findings.Count + 1}",
                Ring: ParseEnum<Ring>(GetString(f, "ring")),
                Severity: ParseEnum<Severity>(GetString(f, "severity")),
                File: GetString(f, "file") ?? "unknown",
                LineRange: GetString(f, "lineRange") ?? "n/a",
                ViolationType: GetString(f, "violationType") ?? "unknown",
                Description: GetString(f, "description") ?? string.Empty,
                Requirement: GetString(f, "requirement") ?? string.Empty,
                Citation: GetString(f, "citation") ?? string.Empty,
                Remediation: GetString(f, "remediation") ?? string.Empty));
        }

        return findings;
    }

    private static ReconciliationSummary? ParseReconciliation(JsonElement root)
    {
        if (!root.TryGetProperty("reconciliation", out var recon))
        {
            return null;
        }

        return new ReconciliationSummary(
            LakehouseGaps: GetStringArray(recon, "lakehouseGaps"),
            CodificationRecommendations: GetStringArray(recon, "codificationRecommendations"),
            RegulatoryDelta: GetStringArray(recon, "regulatoryDelta"));
    }

    private static ComplianceReport FallbackReport(
        string rawText,
        string scanPath,
        IReadOnlyList<RingAvailability> ringAvailability)
    {
        var finding = new Finding(
            Id: "AGENT-RAW",
            Ring: Ring.Fabric,
            Severity: Severity.Info,
            File: "n/a",
            LineRange: "n/a",
            ViolationType: "Agent raw output",
            Description: rawText.Length > 2000 ? rawText[..2000] + "..." : rawText,
            Requirement: string.Empty,
            Citation: "Agent response (unstructured)",
            Remediation: "Review the raw agent output for compliance findings.");

        return ComplianceReportFactory.Create(
            scanPath,
            new[] { finding },
            ringAvailability);
    }

    private static string? GetString(JsonElement element, string property)
    {
        return element.TryGetProperty(property, out var val)
            ? val.GetString()
            : null;
    }

    private static T ParseEnum<T>(string? value) where T : struct, Enum
    {
        if (value is not null && Enum.TryParse<T>(value, ignoreCase: true, out var result))
        {
            return result;
        }

        return default;
    }

    private static string[] GetStringArray(JsonElement element, string property)
    {
        if (!element.TryGetProperty(property, out var arr)
            || arr.ValueKind != JsonValueKind.Array)
        {
            return [];
        }

        return arr.EnumerateArray()
            .Select(e => e.GetString() ?? string.Empty)
            .Where(s => s.Length > 0)
            .ToArray();
    }
}
