namespace PiiSentry.Core.Models;

public sealed record ComplianceReport(
    string ScanPath,
    DateTimeOffset Timestamp,
    IReadOnlyList<Finding> Findings,
    IReadOnlyList<RingAvailability> RingAvailability);
