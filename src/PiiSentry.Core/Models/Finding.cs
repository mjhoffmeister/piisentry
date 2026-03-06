namespace PiiSentry.Core.Models;

/// <summary>
/// A single PII/PHI compliance violation identified during a scan.
/// </summary>
/// <param name="Id">Unique finding identifier (e.g. "F-1").</param>
/// <param name="Ring">Intelligence source ring that provided the evidence.</param>
/// <param name="Severity">Assessed severity of the violation.</param>
/// <param name="File">Relative path to the source file containing the violation.</param>
/// <param name="LineRange">Affected line number(s) within the file.</param>
/// <param name="ViolationType">Short category label (e.g. "Unencrypted PII Storage").</param>
/// <param name="Description">Detailed description of the violation.</param>
/// <param name="Requirement">The organizational or regulatory requirement being violated.</param>
/// <param name="Citation">Source reference grounding the finding (ring attribution).</param>
/// <param name="Remediation">Recommended steps to resolve the violation.</param>
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
