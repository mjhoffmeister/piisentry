using Microsoft.AspNetCore.Mvc;
using PiiSentry.DemoApp.Data;

namespace PiiSentry.DemoApp.Controllers;

[ApiController]
[Route("api/[controller]")]
public sealed class AnalyticsController(PatientStore patientStore) : ControllerBase
{
    [HttpPost("risk-score/{patientId:guid}")]
    public ActionResult<object> GenerateRiskScore(Guid patientId)
    {
        var patient = patientStore.GetById(patientId);
        if (patient is null)
        {
            return NotFound();
        }

        var markerRisk = patient.GeneticMarkers.Length * 12;
        var biometricRisk = string.IsNullOrWhiteSpace(patient.BiometricHash) ? 0 : 25;
        var score = Math.Min(100, 30 + markerRisk + biometricRisk);

        return Ok(new
        {
            patientId,
            score,
            riskBand = score >= 70 ? "high" : score >= 40 ? "medium" : "low",
            profilingModel = "auto-risk-v2"
        });
    }
}
