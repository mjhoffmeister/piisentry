using Microsoft.ApplicationInsights;
using Microsoft.ApplicationInsights.DataContracts;
using Microsoft.ApplicationInsights.Extensibility;
using PiiSentry.Core.Models;

namespace PiiSentry.Cli.Telemetry;

/// <summary>
/// Emits scan lifecycle telemetry to Application Insights when a connection string is configured.
/// </summary>
internal sealed class ScanTelemetry : IDisposable
{
    private readonly TelemetryClient? _client;

    /// <summary>
    /// Initializes telemetry. If <paramref name="connectionString"/> is null or empty, telemetry is silently disabled.
    /// </summary>
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

    /// <summary>
    /// Records that a scan has started with the given path and ring selection.
    /// </summary>
    public void TrackScanStarted(string scanPath, IReadOnlyList<Ring> rings)
    {
        _client?.TrackEvent("ScanStarted", new Dictionary<string, string>
        {
            ["scanPath"] = scanPath,
            ["rings"] = string.Join(",", rings)
        });
    }

    /// <summary>
    /// Records the completion of an individual ring query.
    /// </summary>
    public void TrackRingCompleted(Ring ring, TimeSpan duration, int findingsCount, bool available, string message)
    {
        if (_client is null) return;

        EventTelemetry evt = new("RingCompleted");
        evt.Properties["ring"] = ring.ToString();
        evt.Properties["available"] = available.ToString();
        evt.Properties["message"] = message;
        evt.Properties["durationMs"] = duration.TotalMilliseconds.ToString("F0");
        evt.Properties["findingsCount"] = findingsCount.ToString();
        _client.TrackEvent(evt);
    }

    /// <summary>
    /// Records overall scan completion with total duration and finding count.
    /// </summary>
    public void TrackScanCompleted(TimeSpan duration, int totalFindings)
    {
        if (_client is null) return;

        EventTelemetry evt = new("ScanCompleted");
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
