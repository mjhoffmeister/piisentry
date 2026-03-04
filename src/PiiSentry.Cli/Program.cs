using PiiSentry.Cli.Prompts;

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
Console.WriteLine($"[Phase 0] Scan stub initialized for path: {scanPath}");
Console.WriteLine("System prompt loaded successfully.");
Console.WriteLine($"Prompt length: {SystemPrompt.Text.Length} characters");
