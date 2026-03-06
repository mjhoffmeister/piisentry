namespace PiiSentry.DemoApp.Models;

public sealed record HealthRecord
{
    public Guid RecordId { get; init; } = Guid.NewGuid();
    public Guid PatientId { get; init; }
    public string Diagnosis { get; init; } = string.Empty;
    public string[] Medications { get; init; } = [];
    public string[] LabResults { get; init; } = [];
}
