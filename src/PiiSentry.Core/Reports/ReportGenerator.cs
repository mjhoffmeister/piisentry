using System.Text.Json;
using PiiSentry.Core.Models;

namespace PiiSentry.Core.Reports;

public static class ReportGenerator
{
    public static string ToJson(ComplianceReport report)
    {
        return JsonSerializer.Serialize(report, new JsonSerializerOptions
        {
            WriteIndented = true
        });
    }
}
