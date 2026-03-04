namespace PiiSentry.Core.Models;

public sealed record ReconciliationSummary(
    IReadOnlyList<string> LakehouseGaps,
    IReadOnlyList<string> CodificationRecommendations,
    IReadOnlyList<string> RegulatoryDelta);

public sealed record ReportSummary(
    int TotalFindings,
    IReadOnlyDictionary<Ring, int> ByRing,
    IReadOnlyDictionary<Severity, int> BySeverity);
