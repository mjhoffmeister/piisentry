namespace PiiSentry.DemoApp.Services;

public sealed class GeneticScreeningService
{
    public GeneticScreeningResult ProcessMarkers(Guid patientId, string[] markers)
    {
        var elevatedMarkers = markers.Where(m => m.StartsWith("BRCA", StringComparison.OrdinalIgnoreCase)).ToArray();

        return new GeneticScreeningResult(
            patientId,
            markers.Length,
            elevatedMarkers,
            elevatedMarkers.Length > 0 ? "high-risk" : "standard-risk");
    }
}

public sealed record GeneticScreeningResult(
    Guid PatientId,
    int TotalMarkers,
    string[] ElevatedMarkers,
    string RiskTier);
