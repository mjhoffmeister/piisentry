namespace PiiSentry.Core.Models;

/// <summary>
/// Cross-ring reconciliation identifying gaps between intelligence sources.
/// </summary>
/// <param name="LakehouseGaps">Standards found in code that are missing from Ring 1 lakehouse data.</param>
/// <param name="CodificationRecommendations">Uncodified Ring 2 practices that should be formalized.</param>
/// <param name="RegulatoryDelta">Ring 3 regulatory requirements not yet reflected in organizational standards.</param>
public sealed record ReconciliationSummary(
    IReadOnlyList<string> LakehouseGaps,
    IReadOnlyList<string> CodificationRecommendations,
    IReadOnlyList<string> RegulatoryDelta);

/// <summary>
/// Aggregate finding counts for the compliance report.
/// </summary>
/// <param name="TotalFindings">Total number of findings across all rings.</param>
/// <param name="ByRing">Finding count per intelligence source ring.</param>
/// <param name="BySeverity">Finding count per severity level.</param>
public sealed record ReportSummary(
    int TotalFindings,
    IReadOnlyDictionary<Ring, int> ByRing,
    IReadOnlyDictionary<Severity, int> BySeverity);
