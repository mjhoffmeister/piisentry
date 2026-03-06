using Microsoft.ApplicationInsights;
using Microsoft.ApplicationInsights.DataContracts;
using Microsoft.ApplicationInsights.Extensibility;
using PiiSentry.Core.Models;

namespace PiiSentry.Cli.Telemetry;

internal sealed class ScanTelemetry : IDisposable
{
    private readonly TelemetryClient? _client;

    public ScanTelemetry(string? connectionString)
    {
        if (string.IsNullOrWhiteSpace(connectionString))
        {
            _client = null;
            return;
        }

        var config = new TelemetryConfiguration
        {
            ConnectionString = connectionString
        };

        _client = new TelemetryClient(config);
    }

    public void TrackScanStarted(string scanPath, IReadOnlyList<Ring> rings)
    {
        _client?.TrackEvent("ScanStarted", new Dictionary<string, string>
        {
            ["scanPath"] = scanPath,
            ["rings"] = string.Join(",", rings)
        });
    }

    public void TrackRingCompleted(Ring ring, TimeSpan duration, int findingsCount, bool available, string message)
    {
        if (_client is null) return;

        var evt = new EventTelemetry("RingCompleted");
        evt.Properties["ring"] = ring.ToString();
        evt.Properties["available"] = available.ToString();
        evt.Properties["message"] = message;
        evt.Properties["durationMs"] = duration.TotalMilliseconds.ToString("F0");
        evt.Properties["findingsCount"] = findingsCount.ToString();
        _client.TrackEvent(evt);
    }

    public void TrackScanCompleted(TimeSpan duration, int totalFindings)
    {
        if (_client is null) return;

        var evt = new EventTelemetry("ScanCompleted");
        evt.Properties["durationMs"] = duration.TotalMilliseconds.ToString("F0");
        evt.Properties["totalFindings"] = totalFindings.ToString();
        _client.TrackEvent(evt);
    }

    public void Flush()
    {
        _client?.Flush();
    }

    public void Dispose()
    {
        Flush();
    }
}
