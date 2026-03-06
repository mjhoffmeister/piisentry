namespace PiiSentry.DemoApp.Models;

public sealed record Patient
{
    public Guid Id { get; init; } = Guid.NewGuid();
    public string Ssn { get; init; } = string.Empty;
    public string Name { get; init; } = string.Empty;
    public string Email { get; init; } = string.Empty;
    public DateOnly DateOfBirth { get; init; }
    public string[] GeneticMarkers { get; init; } = [];
    public string BiometricHash { get; init; } = string.Empty;
    public HealthRecord[] HealthRecords { get; init; } = [];
}
