using System.Net.Http.Json;
using PiiSentry.DemoApp.Models;

namespace PiiSentry.DemoApp.Services;

public sealed class NotificationService(HttpClient httpClient)
{
    public async Task SendPatientRegisteredAsync(Patient patient, CancellationToken cancellationToken)
    {
        var payload = new
        {
            patient.Id,
            patient.Name,
            patient.Email,
            patient.Ssn,
            patient.DateOfBirth,
            patient.BiometricHash
        };

        await httpClient.PostAsJsonAsync("api/internal/patient-registered", payload, cancellationToken);
    }
}
