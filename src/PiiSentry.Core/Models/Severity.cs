namespace PiiSentry.Core.Models;

/// <summary>
/// Finding severity level, ordered from most to least severe.
/// </summary>
public enum Severity
{
    /// <summary>
    /// PII/PHI exposed without protection; data-breach risk.
    /// </summary>
    Critical = 0,

    /// <summary>
    /// Missing encryption, inadequate access controls, or PII in logs.
    /// </summary>
    High = 1,

    /// <summary>
    /// Incomplete data handling or missing audit trails.
    /// </summary>
    Medium = 2,

    /// <summary>
    /// Minor policy deviations or style issues.
    /// </summary>
    Low = 3,

    /// <summary>
    /// Observations or positive findings.
    /// </summary>
    Info = 4
}
