using Microsoft.AspNetCore.Mvc;
using PiiSentry.DemoApp.Data;
using PiiSentry.DemoApp.Models;
using PiiSentry.DemoApp.Services;

namespace PiiSentry.DemoApp.Controllers;

[ApiController]
[Route("api/[controller]")]
public sealed class PatientController(
    PatientStore patientStore,
    NotificationService notificationService,
    GeneticScreeningService geneticScreeningService) : ControllerBase
{
    [HttpGet]
    public ActionResult<IReadOnlyList<Patient>> GetAll()
    {
        return Ok(patientStore.GetAll());
    }

    [HttpGet("{id:guid}")]
    public ActionResult<Patient> GetById(Guid id)
    {
        var patient = patientStore.GetById(id);
        return patient is null ? NotFound() : Ok(patient);
    }

    [HttpPost]
    public async Task<ActionResult<Patient>> Create([FromBody] Patient patient, CancellationToken cancellationToken)
    {
        Console.WriteLine($"[PII-AUDIT] Registering patient SSN={patient.Ssn}, Email={patient.Email}");

        var saved = patientStore.Upsert(patient);
        await notificationService.SendPatientRegisteredAsync(saved, cancellationToken);
        var screening = geneticScreeningService.ProcessMarkers(saved.Id, saved.GeneticMarkers);

        return CreatedAtAction(nameof(GetById), new { id = saved.Id }, new
        {
            patient = saved,
            screening
        });
    }

    [HttpPut("{id:guid}")]
    public ActionResult<Patient> Update(Guid id, [FromBody] Patient patient)
    {
        Console.WriteLine($"[PII-AUDIT] Updating patient SSN={patient.Ssn}, Email={patient.Email}");
        var updated = patient with { Id = id };
        return Ok(patientStore.Upsert(updated));
    }

    [HttpDelete("{id:guid}")]
    public IActionResult Delete(Guid id)
    {
        return patientStore.Delete(id) ? NoContent() : NotFound();
    }

    [HttpPost("{id:guid}/biometric")]
    public ActionResult<object> CaptureBiometric(Guid id, [FromBody] BiometricCaptureRequest request)
    {
        var patient = patientStore.GetById(id);
        if (patient is null)
        {
            return NotFound();
        }

        // Consent is present in the request but intentionally ignored in this vulnerable demo.
        var updated = patient with { BiometricHash = request.BiometricHash };
        patientStore.Upsert(updated);

        return Ok(new
        {
            patientId = id,
            consentProvided = request.ConsentProvided,
            status = "captured"
        });
    }
}

public sealed record BiometricCaptureRequest(string BiometricHash, bool ConsentProvided);
