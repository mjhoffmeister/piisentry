using PiiSentry.Core.Models;

namespace PiiSentry.Cli;

/// <summary>
/// Provides styled terminal output with ANSI color codes.
/// Falls back to plain text when output is redirected.
/// </summary>
internal static class ConsoleUI
{
    private static bool UseColor => !Console.IsOutputRedirected;

    // ANSI color codes
    private const string Reset = "\x1b[0m";
    private const string Bold = "\x1b[1m";
    private const string Dim = "\x1b[2m";
    private const string Cyan = "\x1b[36m";
    private const string Yellow = "\x1b[33m";
    private const string Magenta = "\x1b[35m";
    private const string Green = "\x1b[32m";
    private const string Red = "\x1b[31m";
    private const string Blue = "\x1b[34m";
    private const string White = "\x1b[97m";
    private const string BoldCyan = "\x1b[1;36m";
    private const string BoldYellow = "\x1b[1;33m";
    private const string BoldMagenta = "\x1b[1;35m";
    private const string BoldRed = "\x1b[1;31m";
    private const string BoldGreen = "\x1b[1;32m";
    private const string BoldWhite = "\x1b[1;97m";

    /// <summary>
    /// Built-in tool names that are suppressed from individual output.
    /// </summary>
    private static readonly HashSet<string> SuppressedTools = ["view", "glob", "sql", "report_intent"];

    /// <summary>
    /// Returns the branded display name for a ring.
    /// </summary>
    private static string DisplayName(Ring ring) => ring switch
    {
        Ring.Fabric => "Fabric IQ",
        Ring.WorkIq => "Work IQ",
        Ring.Foundry => "Foundry IQ",
        _ => ring.ToString()
    };

    /// <summary>
    /// Returns a short subtitle describing the ring's intelligence source.
    /// </summary>
    private static string Subtitle(Ring ring) => ring switch
    {
        Ring.Fabric => "Codified Standards",
        Ring.WorkIq => "Business Knowledge",
        Ring.Foundry => "Regulatory Intelligence",
        _ => ""
    };

    /// <summary>
    /// Returns the ANSI color code for a ring.
    /// </summary>
    private static string RingColor(Ring ring) => ring switch
    {
        Ring.Fabric => Cyan,
        Ring.WorkIq => Yellow,
        Ring.Foundry => Magenta,
        _ => White
    };

    /// <summary>
    /// Returns the bold ANSI color code for a ring.
    /// </summary>
    private static string RingBoldColor(Ring ring) => ring switch
    {
        Ring.Fabric => BoldCyan,
        Ring.WorkIq => BoldYellow,
        Ring.Foundry => BoldMagenta,
        _ => BoldWhite
    };

    /// <summary>
    /// Prints the PII Sentry startup banner.
    /// </summary>
    public static void PrintBanner()
    {
        if (UseColor)
        {
            Console.WriteLine();
            Console.WriteLine($"  {BoldCyan}o{Reset} {BoldYellow}o{Reset} {BoldMagenta}o{Reset}  {BoldWhite}PII Sentry{Reset}");
            Console.WriteLine($"  {Dim}Concentric-ring PII/PHI compliance analysis{Reset}");
            Console.WriteLine();
        }
        else
        {
            Console.WriteLine();
            Console.WriteLine("  PII Sentry — Concentric-ring PII/PHI compliance analysis");
            Console.WriteLine();
        }
    }

    /// <summary>
    /// Prints the scan configuration header with branded ring names.
    /// </summary>
    public static void PrintScanHeader(string scanPath, IReadOnlyList<Ring> rings, string identity)
    {
        string ringList = string.Join(", ", rings.Select(DisplayName));
        if (UseColor)
        {
            Console.WriteLine($"  {Dim}Identity:{Reset}  {identity}");
            Console.WriteLine($"  {Dim}Target:{Reset}    {scanPath}");
            Console.Write($"  {Dim}Rings:{Reset}     ");
            for (int i = 0; i < rings.Count; i++)
            {
                if (i > 0) Console.Write(", ");
                Console.Write($"{RingColor(rings[i])}{DisplayName(rings[i])}{Reset}");
            }
            Console.WriteLine();
            Console.WriteLine();
        }
        else
        {
            Console.WriteLine($"  Identity:  {identity}");
            Console.WriteLine($"  Target:    {scanPath}");
            Console.WriteLine($"  Rings:     {ringList}");
            Console.WriteLine();
        }
    }

    /// <summary>
    /// Prints a phase transition message.
    /// </summary>
    public static void PrintPhase(string message)
    {
        if (UseColor)
            Console.WriteLine($"  {Bold}▸{Reset} {message}");
        else
            Console.WriteLine($"  > {message}");
    }

    /// <summary>
    /// Prints a tool invocation with ring-appropriate coloring.
    /// Built-in tools (view, glob, sql) are silently suppressed.
    /// </summary>
    public static void PrintToolCall(string toolName)
    {
        // Suppress noisy built-in tools entirely
        if (SuppressedTools.Contains(toolName))
            return;

        if (UseColor)
        {
            string styled = toolName switch
            {
                "query_fabric_data_agent" =>
                    $"  {BoldCyan}* Fabric IQ{Reset} {Dim}Querying codified standards{Reset}",
                "query_foundry_iq" =>
                    $"  {BoldMagenta}* Foundry IQ{Reset} {Dim}Querying regulatory intelligence{Reset}",
                _ when toolName.StartsWith("workiq-") =>
                    $"  {BoldYellow}* Work IQ{Reset} {Dim}Querying business knowledge{Reset}",
                _ =>
                    $"  {Dim}  · {toolName}{Reset}"
            };
            Console.WriteLine(styled);
        }
        else
        {
            string label = toolName switch
            {
                "query_fabric_data_agent" => "Fabric IQ: Querying codified standards",
                "query_foundry_iq" => "Foundry IQ: Querying regulatory intelligence",
                _ when toolName.StartsWith("workiq-") => "Work IQ: Querying business knowledge",
                _ => toolName
            };
            Console.WriteLine($"  [{label}]");
        }
    }

    /// <summary>
    /// Prints the final scan summary with colored severity and ring status.
    /// </summary>
    public static void PrintSummary(ComplianceReport report, string outputPath, TimeSpan elapsed)
    {
        Console.WriteLine();

        if (UseColor)
        {
            // Ring availability
            Console.WriteLine($"  {BoldWhite}Ring Availability{Reset}");
            foreach (RingAvailability r in report.RingAvailability)
            {
                string icon = r.Available ? $"{BoldGreen}✓{Reset}" : $"{BoldRed}✗{Reset}";
                string color = RingColor(r.Ring);
                string boldColor = RingBoldColor(r.Ring);
                Console.WriteLine($"    {icon} {boldColor}{DisplayName(r.Ring)}{Reset} {Dim}{Subtitle(r.Ring)}{Reset}");
            }
            Console.WriteLine();

            // Findings by severity
            Console.WriteLine($"  {BoldWhite}Findings{Reset}  {Bold}{report.Summary.TotalFindings}{Reset} total");
            foreach (var kvp in report.Summary.BySeverity.OrderBy(k => k.Key))
            {
                string sevColor = kvp.Key switch
                {
                    Severity.Critical => BoldRed,
                    Severity.High => Yellow,
                    Severity.Medium => BoldYellow,
                    Severity.Low => Green,
                    Severity.Info => Blue,
                    _ => White
                };
                Console.WriteLine($"    {sevColor}■{Reset} {kvp.Key}: {kvp.Value}");
            }
            Console.WriteLine();

            // By ring
            foreach (var kvp in report.Summary.ByRing.OrderBy(k => k.Key))
            {
                Console.Write($"    {RingColor(kvp.Key)}*{Reset} {DisplayName(kvp.Key)}: {kvp.Value}  ");
            }
            Console.WriteLine();
            Console.WriteLine();

            // Output
            string format = Path.GetExtension(outputPath).ToUpperInvariant() switch
            {
                ".MD" => "Markdown",
                ".HTML" => "HTML",
                ".JSON" => "JSON",
                _ => Path.GetExtension(outputPath)
            };
            Console.WriteLine($"  {Dim}Report:{Reset}   {outputPath} {Dim}({format}){Reset}");
            Console.WriteLine($"  {Dim}Elapsed:{Reset}  {elapsed.TotalSeconds:F1}s");
            Console.WriteLine();
        }
        else
        {
            Console.WriteLine("  Ring Availability");
            foreach (RingAvailability r in report.RingAvailability)
            {
                string icon = r.Available ? "[OK]" : "[--]";
                Console.WriteLine($"    {icon} {DisplayName(r.Ring)} — {Subtitle(r.Ring)}");
            }
            Console.WriteLine();

            Console.WriteLine($"  Findings: {report.Summary.TotalFindings} total");
            foreach (var kvp in report.Summary.BySeverity.OrderBy(k => k.Key))
                Console.WriteLine($"    {kvp.Key}: {kvp.Value}");
            Console.WriteLine();

            Console.WriteLine($"  Report: {outputPath}");
            Console.WriteLine($"  Elapsed: {elapsed.TotalSeconds:F1}s");
            Console.WriteLine();
        }
    }
}
