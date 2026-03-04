namespace PiiSentry.Core.Models;

public sealed record Finding(
    string Id,
    Ring Ring,
    Severity Severity,
    string File,
    string LineRange,
    string ViolationType,
    string Description,
    string Requirement,
    string Citation,
    string Remediation);
