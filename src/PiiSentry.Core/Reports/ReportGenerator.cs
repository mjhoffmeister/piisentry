using System.Text.Json;
using System.Text.Json.Serialization;
using System.Net;
using System.Text;
using PiiSentry.Core.Models;

namespace PiiSentry.Core.Reports;

/// <summary>
/// Generates compliance reports in JSON, HTML, and Markdown formats.
/// </summary>
public static class ReportGenerator
{
    /// <summary>
    /// Serializes a compliance report to indented JSON.
    /// </summary>
    public static string ToJson(ComplianceReport report)
    {
        return JsonSerializer.Serialize(report, new JsonSerializerOptions
        {
            WriteIndented = true,
            Converters = { new JsonStringEnumConverter() }
        });
    }

    /// <summary>
    /// Renders a compliance report as a self-contained HTML page with concentric-ring visualization.
    /// </summary>
    public static string ToHtml(ComplianceReport report)
    {
        string byRingRows = string.Join(
                "",
                report.Summary.ByRing
                        .OrderBy(kvp => kvp.Key)
                        .Select(kvp => $"<tr><td>{Encode(kvp.Key.ToString())}</td><td>{kvp.Value}</td></tr>"));

        string bySeverityRows = string.Join(
                "",
                report.Summary.BySeverity
                        .OrderBy(kvp => kvp.Key)
                        .Select(kvp => $"<tr><td>{Encode(kvp.Key.ToString())}</td><td>{kvp.Value}</td></tr>"));

        string availabilityRows = string.Join(
                "",
                report.RingAvailability.Select(r =>
                        $"<tr><td>{Encode(r.Ring.ToString())}</td><td>{(r.Available ? "Available" : "Unavailable")}</td><td>{Encode(r.Message)}</td></tr>"));

        string findingCards = report.Findings.Count == 0
                ? "<p class=\"empty\">No findings were produced for the selected rings.</p>"
                : string.Join("", report.Findings.Select(BuildFindingCard));

        StringBuilder template = new(
                """
                        <!doctype html>
                        <html lang="en">
                        <head>
                            <meta charset="utf-8" />
                            <meta name="viewport" content="width=device-width, initial-scale=1" />
                            <title>PII Sentry Compliance Report</title>
                            <style>
                                :root {
                                    --bg: #f4f6fb;
                                    --fg: #102039;
                                    --card: #ffffff;
                                    --line: #d9e1ef;
                                    --ring-1: #1d4ed8;
                                    --ring-2: #d97706;
                                    --ring-3: #be185d;
                                    --critical: #b91c1c;
                                    --high: #dc2626;
                                    --medium: #ea580c;
                                    --low: #16a34a;
                                    --info: #0ea5e9;
                                }
                                body { margin: 0; font-family: Segoe UI, sans-serif; background: radial-gradient(circle at top left, #dbeafe, var(--bg)); color: var(--fg); }
                                main { max-width: 980px; margin: 0 auto; padding: 20px; }
                                .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 14px; }
                                .card { background: var(--card); border: 1px solid var(--line); border-radius: 12px; padding: 14px; box-shadow: 0 6px 16px rgba(16, 32, 57, 0.08); }
                                .hero { display: grid; grid-template-columns: 220px 1fr; gap: 20px; align-items: center; }
                                .rings { width: 200px; height: 200px; }
                                .pill { border-radius: 999px; padding: 2px 8px; font-size: 12px; border: 1px solid var(--line); }
                                .ring { background: #eff6ff; }
                                .severity-critical { background: #fee2e2; color: var(--critical); }
                                .severity-high { background: #fee2e2; color: var(--high); }
                                .severity-medium { background: #ffedd5; color: var(--medium); }
                                .severity-low { background: #dcfce7; color: var(--low); }
                                .severity-info { background: #e0f2fe; color: var(--info); }
                                table { width: 100%; border-collapse: collapse; }
                                th, td { text-align: left; border-bottom: 1px solid var(--line); padding: 6px 4px; font-size: 14px; }
                                .finding { border: 1px solid var(--line); border-radius: 10px; padding: 10px; margin-bottom: 10px; background: #fff; }
                                .finding header { display: flex; gap: 8px; align-items: center; margin-bottom: 6px; flex-wrap: wrap; }
                                dt { font-weight: 600; margin-top: 4px; }
                                dd { margin: 0; margin-bottom: 4px; }
                                .empty { margin: 0; color: #4b5563; }
                                @media (max-width: 760px) {
                                    .grid { grid-template-columns: 1fr; }
                                    .hero { grid-template-columns: 1fr; }
                                    .rings { width: 150px; height: 150px; }
                                }
                            </style>
                        </head>
                        <body>
                            <main>
                                <section class="card hero">
                                    <svg class="rings" viewBox="0 0 220 220" role="img" aria-label="Three compliance rings">
                                        <circle cx="110" cy="110" r="88" fill="none" stroke="var(--ring-3)" stroke-width="10" />
                                        <circle cx="110" cy="110" r="62" fill="none" stroke="var(--ring-2)" stroke-width="10" />
                                        <circle cx="110" cy="110" r="36" fill="none" stroke="var(--ring-1)" stroke-width="10" />
                                    </svg>
                                    <div>
                                        <h1>PII Sentry Compliance Report</h1>
                                        <p><strong>Scan path:</strong> {{SCAN_PATH}}</p>
                                        <p><strong>Timestamp:</strong> {{TIMESTAMP}}</p>
                                        <p><strong>Total findings:</strong> {{TOTAL}}</p>
                                    </div>
                                </section>

                                <section class="grid" style="margin-top:14px;">
                                    <article class="card">
                                        <h2>Ring Availability</h2>
                                        <table>
                                            <thead><tr><th>Ring</th><th>Status</th><th>Message</th></tr></thead>
                                            <tbody>{{AVAILABILITY_ROWS}}</tbody>
                                        </table>
                                    </article>

                                    <article class="card">
                                        <h2>Summary</h2>
                                        <h3>By Ring</h3>
                                        <table><tbody>{{RING_ROWS}}</tbody></table>
                                        <h3>By Severity</h3>
                                        <table><tbody>{{SEVERITY_ROWS}}</tbody></table>
                                    </article>
                                </section>

                                <section class="card" style="margin-top:14px;">
                                    <h2>Reconciliation</h2>
                                    <p><strong>Lakehouse Gaps:</strong> {{LAKEHOUSE_GAPS}}</p>
                                    <p><strong>Codification Recommendations:</strong> {{CODIFICATION_RECOMMENDATIONS}}</p>
                                    <p><strong>Regulatory Delta:</strong> {{REGULATORY_DELTA}}</p>
                                </section>

                                <section class="card" style="margin-top:14px;">
                                    <h2>Findings</h2>
                                    {{FINDINGS}}
                                </section>
                            </main>
                        </body>
                        </html>
                        """);

        return template
                .Replace("{{SCAN_PATH}}", Encode(report.ScanPath))
                .Replace("{{TIMESTAMP}}", Encode(report.Timestamp.ToString("u")))
                .Replace("{{TOTAL}}", report.Summary.TotalFindings.ToString())
                .Replace("{{AVAILABILITY_ROWS}}", availabilityRows)
                .Replace("{{RING_ROWS}}", byRingRows)
                .Replace("{{SEVERITY_ROWS}}", bySeverityRows)
                .Replace("{{LAKEHOUSE_GAPS}}", Encode(string.Join("; ", report.Reconciliation.LakehouseGaps)))
                .Replace("{{CODIFICATION_RECOMMENDATIONS}}", Encode(string.Join("; ", report.Reconciliation.CodificationRecommendations)))
                .Replace("{{REGULATORY_DELTA}}", Encode(string.Join("; ", report.Reconciliation.RegulatoryDelta)))
                .Replace("{{FINDINGS}}", findingCards)
                .ToString();
    }

    /// <summary>
    /// Renders a single finding as an HTML card with severity badge and details.
    /// </summary>
    private static string BuildFindingCard(Finding finding)
    {
        return $"""
                             <section class="finding">
                                 <header>
                                     <span class="pill ring">{Encode(finding.Ring.ToString())}</span>
                                     <span class="pill severity severity-{Encode(finding.Severity.ToString().ToLowerInvariant())}">{Encode(finding.Severity.ToString())}</span>
                                     <strong>{Encode(finding.ViolationType)}</strong>
                                 </header>
                                 <p>{Encode(finding.Description)}</p>
                                 <dl>
                                     <dt>Location</dt><dd>{Encode(finding.File)} ({Encode(finding.LineRange)})</dd>
                                     <dt>Requirement</dt><dd>{Encode(finding.Requirement)}</dd>
                                     <dt>Citation</dt><dd>{Encode(finding.Citation)}</dd>
                                     <dt>Remediation</dt><dd>{Encode(finding.Remediation)}</dd>
                                 </dl>
                             </section>
                             """;
    }

    /// <summary>
    /// HTML-encodes a string value for safe embedding in report markup.
    /// </summary>
    private static string Encode(string value) => WebUtility.HtmlEncode(value ?? string.Empty);

    /// <summary>
    /// Escapes pipe characters in Markdown content to prevent table formatting breaks.
    /// </summary>
    private static string EscapeMarkdown(string value) => (value ?? string.Empty).Replace("|", "\\|");

    /// <summary>
    /// Renders a compliance report as Markdown with findings and a file-grouped remediation plan.
    /// </summary>
    public static string ToMarkdown(ComplianceReport report)
    {
        StringBuilder sb = new();

        sb.AppendLine("# PII Sentry Compliance Report");
        sb.AppendLine();
        sb.AppendLine($"**Scan path:** `{report.ScanPath}`");
        sb.AppendLine($"**Timestamp:** {report.Timestamp:u}");
        sb.AppendLine($"**Total findings:** {report.Summary.TotalFindings}");
        sb.AppendLine();

        // Ring availability overview
        sb.AppendLine("## Ring Availability");
        sb.AppendLine();
        sb.AppendLine("| Ring | Status | Notes |");
        sb.AppendLine("|------|--------|-------|");
        foreach (RingAvailability r in report.RingAvailability)
        {
            string icon = r.Available ? "Operational" : "Unavailable";
            sb.AppendLine($"| {r.Ring} | {icon} | {EscapeMarkdown(r.Message)} |");
        }
        sb.AppendLine();

        // Summary
        sb.AppendLine("## Summary");
        sb.AppendLine();
        sb.AppendLine("### By Ring");
        sb.AppendLine();
        foreach (var kvp in report.Summary.ByRing.OrderBy(k => k.Key))
            sb.AppendLine($"- **{kvp.Key}:** {kvp.Value}");
        sb.AppendLine();
        sb.AppendLine("### By Severity");
        sb.AppendLine();
        foreach (var kvp in report.Summary.BySeverity.OrderBy(k => k.Key))
            sb.AppendLine($"- **{kvp.Key}:** {kvp.Value}");
        sb.AppendLine();

        // Findings
        sb.AppendLine("## Findings");
        sb.AppendLine();

        foreach (Finding f in report.Findings)
        {
            sb.AppendLine($"### {EscapeMarkdown(f.Id)}: {EscapeMarkdown(f.ViolationType)}");
            sb.AppendLine();
            sb.AppendLine($"| | |");
            sb.AppendLine($"|---|---|");
            sb.AppendLine($"| **Ring** | {f.Ring} |");
            sb.AppendLine($"| **Severity** | {f.Severity} |");
            sb.AppendLine($"| **File** | `{EscapeMarkdown(f.File)}` |");
            sb.AppendLine($"| **Lines** | {EscapeMarkdown(f.LineRange)} |");
            sb.AppendLine();
            sb.AppendLine($"**Description:** {f.Description}");
            sb.AppendLine();
            sb.AppendLine($"**Requirement:** {f.Requirement}");
            sb.AppendLine();
            sb.AppendLine($"**Citation:** {f.Citation}");
            sb.AppendLine();
        }

        // Reconciliation
        if (report.Reconciliation.LakehouseGaps.Count > 0 ||
            report.Reconciliation.CodificationRecommendations.Count > 0 ||
            report.Reconciliation.RegulatoryDelta.Count > 0)
        {
            sb.AppendLine("## Reconciliation");
            sb.AppendLine();

            if (report.Reconciliation.LakehouseGaps.Count > 0)
            {
                sb.AppendLine("### Lakehouse Gaps");
                sb.AppendLine();
                foreach (var g in report.Reconciliation.LakehouseGaps)
                    sb.AppendLine($"- {g}");
                sb.AppendLine();
            }

            if (report.Reconciliation.CodificationRecommendations.Count > 0)
            {
                sb.AppendLine("### Codification Recommendations");
                sb.AppendLine();
                foreach (var c in report.Reconciliation.CodificationRecommendations)
                    sb.AppendLine($"- {c}");
                sb.AppendLine();
            }

            if (report.Reconciliation.RegulatoryDelta.Count > 0)
            {
                sb.AppendLine("### Regulatory Delta");
                sb.AppendLine();
                foreach (var d in report.Reconciliation.RegulatoryDelta)
                    sb.AppendLine($"- {d}");
                sb.AppendLine();
            }
        }

        // Remediation plan for coding assistant
        sb.AppendLine("## Remediation Plan");
        sb.AppendLine();
        sb.AppendLine("The following tasks should be implemented to resolve the findings above. Each task maps to one or more findings and includes the specific file, what to change, and why.");
        sb.AppendLine();

        var taskNum = 1;
        foreach (var group in report.Findings.GroupBy(f => f.File).OrderBy(g => g.Key))
        {
            sb.AppendLine($"### Task {taskNum}: `{group.Key}`");
            sb.AppendLine();
            foreach (var f in group)
            {
                sb.AppendLine($"- **{f.Id} ({f.Severity}):** {f.Remediation}");
            }
            sb.AppendLine();
            taskNum++;
        }

        return sb.ToString();
    }
}
