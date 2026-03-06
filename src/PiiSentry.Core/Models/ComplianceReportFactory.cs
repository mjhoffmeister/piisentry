using System.Linq;

namespace PiiSentry.Core.Models;

/// <summary>
/// Factory for assembling <see cref="ComplianceReport"/> instances with computed summaries.
/// </summary>
public static class ComplianceReportFactory
{
    /// <summary>
    /// Empty reconciliation placeholder used when no cross-ring analysis is available.
    /// </summary>
    public static readonly ReconciliationSummary EmptyReconciliation = new(
        LakehouseGaps: [],
        CodificationRecommendations: [],
        RegulatoryDelta: []);

    /// <summary>
    /// Creates a compliance report with an automatically computed summary.
    /// </summary>
    public static ComplianceReport Create(
        string scanPath,
        IReadOnlyList<Finding> findings,
        IReadOnlyList<RingAvailability> ringAvailability,
        ReconciliationSummary? reconciliation = null,
        DateTimeOffset? timestamp = null)
    {
        IReadOnlyList<Finding> reportFindings = findings ?? [];
        IReadOnlyList<RingAvailability> availability = ringAvailability ?? [];
        ReconciliationSummary reportReconciliation = reconciliation ?? EmptyReconciliation;

        return new ComplianceReport(
            ScanPath: scanPath,
            Timestamp: timestamp ?? DateTimeOffset.UtcNow,
            Findings: reportFindings,
            RingAvailability: availability,
            Reconciliation: reportReconciliation,
            Summary: BuildSummary(reportFindings));
    }

    /// <summary>
    /// Computes aggregate finding counts grouped by ring and severity.
    /// </summary>
    public static ReportSummary BuildSummary(IReadOnlyList<Finding> findings)
    {
        IReadOnlyList<Finding> reportFindings = findings ?? [];

        Dictionary<Ring, int> byRing = reportFindings
            .GroupBy(f => f.Ring)
            .ToDictionary(group => group.Key, group => group.Count());

        Dictionary<Severity, int> bySeverity = reportFindings
            .GroupBy(f => f.Severity)
            .ToDictionary(group => group.Key, group => group.Count());

        return new ReportSummary(
            TotalFindings: reportFindings.Count,
            ByRing: byRing,
            BySeverity: bySeverity);
    }
}
