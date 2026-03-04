using PiiSentry.Cli.Prompts;
using PiiSentry.Core;

if (args.Length == 0)
{
    Console.WriteLine("PII Sentry CLI");
    Console.WriteLine("Usage: pii-sentry scan <path> [--ring fabric|workiq|foundry|all] [--output <file>]");
    return;
}

if (!string.Equals(args[0], "scan", StringComparison.OrdinalIgnoreCase))
{
    Console.WriteLine($"Unknown command: {args[0]}");
    Console.WriteLine("Try: pii-sentry scan <path>");
    return;
}

var scanPath = args.Length > 1 ? args[1] : ".";
var selectedRing = "all";
string? outputFile = null;

for (var i = 2; i < args.Length; i++)
{
    if (string.Equals(args[i], "--ring", StringComparison.OrdinalIgnoreCase))
    {
        if (i + 1 >= args.Length)
        {
            Console.WriteLine("Missing value for --ring. Expected one of: fabric, workiq, foundry, all");
            return;
        }

        selectedRing = args[++i].ToLowerInvariant();
        if (selectedRing is not ("fabric" or "workiq" or "foundry" or "all"))
        {
            Console.WriteLine($"Invalid ring value: {selectedRing}");
            Console.WriteLine("Expected one of: fabric, workiq, foundry, all");
            return;
        }

        continue;
    }

    if (string.Equals(args[i], "--output", StringComparison.OrdinalIgnoreCase))
    {
        if (i + 1 >= args.Length)
        {
            Console.WriteLine("Missing value for --output. Expected a file path.");
            return;
        }

        outputFile = args[++i];
        continue;
    }

    Console.WriteLine($"Unknown option: {args[i]}");
    Console.WriteLine("Usage: pii-sentry scan <path> [--ring fabric|workiq|foundry|all] [--output <file>]");
    return;
}

Console.WriteLine($"[Phase 2] Scan stub initialized for path: {scanPath}");
Console.WriteLine($"Ring selection: {selectedRing}");
Console.WriteLine($"Output path: {outputFile ?? "(not set)"}");
Console.WriteLine($"Phase marker: {PhaseMarker.Value}");
Console.WriteLine("System prompt loaded successfully.");
Console.WriteLine($"Prompt length: {SystemPrompt.Text.Length} characters");
