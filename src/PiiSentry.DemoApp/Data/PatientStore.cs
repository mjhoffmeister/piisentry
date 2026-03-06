using System.Text.Json;
using PiiSentry.DemoApp.Models;

namespace PiiSentry.DemoApp.Data;

public sealed class PatientStore
{
    private readonly string _filePath;
    private readonly JsonSerializerOptions _jsonOptions = new(JsonSerializerDefaults.Web)
    {
        WriteIndented = true
    };
    private readonly object _sync = new();

    public PatientStore(IWebHostEnvironment environment)
    {
        _filePath = Path.Combine(environment.ContentRootPath, "patients.json");
    }

    public IReadOnlyList<Patient> GetAll()
    {
        lock (_sync)
        {
            return LoadUnsafe();
        }
    }

    public Patient? GetById(Guid id)
    {
        lock (_sync)
        {
            return LoadUnsafe().FirstOrDefault(p => p.Id == id);
        }
    }

    public Patient Upsert(Patient patient)
    {
        lock (_sync)
        {
            var patients = LoadUnsafe();
            var index = patients.FindIndex(p => p.Id == patient.Id);
            if (index >= 0)
            {
                patients[index] = patient;
            }
            else
            {
                patients.Add(patient);
            }

            SaveUnsafe(patients);
            return patient;
        }
    }

    public bool Delete(Guid id)
    {
        lock (_sync)
        {
            var patients = LoadUnsafe();
            var removed = patients.RemoveAll(p => p.Id == id) > 0;
            if (removed)
            {
                SaveUnsafe(patients);
            }

            return removed;
        }
    }

    private List<Patient> LoadUnsafe()
    {
        if (!File.Exists(_filePath))
        {
            return [];
        }

        var json = File.ReadAllText(_filePath);
        if (string.IsNullOrWhiteSpace(json))
        {
            return [];
        }

        return JsonSerializer.Deserialize<List<Patient>>(json, _jsonOptions) ?? [];
    }

    private void SaveUnsafe(List<Patient> patients)
    {
        var json = JsonSerializer.Serialize(patients, _jsonOptions);
        File.WriteAllText(_filePath, json);
    }
}
