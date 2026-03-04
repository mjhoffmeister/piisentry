using System.Linq;

namespace PiiSentry.Core.Models;

public static class ComplianceReportFactory
{
    public static readonly ReconciliationSummary EmptyReconciliation = new(
        LakehouseGaps: Array.Empty<string>(),
        CodificationRecommendations: Array.Empty<string>(),
        RegulatoryDelta: Array.Empty<string>());

    public static ComplianceReport Create(
        string scanPath,
        IReadOnlyList<Finding> findings,
        IReadOnlyList<RingAvailability> ringAvailability,
        ReconciliationSummary? reconciliation = null,
        DateTimeOffset? timestamp = null)
    {
        var reportFindings = findings ?? Array.Empty<Finding>();
        var availability = ringAvailability ?? Array.Empty<RingAvailability>();
        var reportReconciliation = reconciliation ?? EmptyReconciliation;

        return new ComplianceReport(
            ScanPath: scanPath,
            Timestamp: timestamp ?? DateTimeOffset.UtcNow,
            Findings: reportFindings,
            RingAvailability: availability,
            Reconciliation: reportReconciliation,
            Summary: BuildSummary(reportFindings));
    }

    public static ReportSummary BuildSummary(IReadOnlyList<Finding> findings)
    {
        var reportFindings = findings ?? Array.Empty<Finding>();

        var byRing = reportFindings
            .GroupBy(f => f.Ring)
            .ToDictionary(group => group.Key, group => group.Count());

        var bySeverity = reportFindings
            .GroupBy(f => f.Severity)
            .ToDictionary(group => group.Key, group => group.Count());

        return new ReportSummary(
            TotalFindings: reportFindings.Count,
            ByRing: byRing,
            BySeverity: bySeverity);
    }
}
