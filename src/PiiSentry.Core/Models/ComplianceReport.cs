namespace PiiSentry.Core.Models;

/// <summary>
/// Complete output of a PII Sentry compliance scan.
/// </summary>
/// <param name="ScanPath">Root directory or file that was scanned.</param>
/// <param name="Timestamp">UTC time the scan completed.</param>
/// <param name="Findings">All compliance violations grounded by ring evidence.</param>
/// <param name="RingAvailability">Per-ring operational status during the scan.</param>
/// <param name="Reconciliation">Cross-ring gap analysis and codification recommendations.</param>
/// <param name="Summary">Aggregate counts by ring and severity.</param>
public sealed record ComplianceReport(
    string ScanPath,
    DateTimeOffset Timestamp,
    IReadOnlyList<Finding> Findings,
    IReadOnlyList<RingAvailability> RingAvailability,
    ReconciliationSummary Reconciliation,
    ReportSummary Summary);
