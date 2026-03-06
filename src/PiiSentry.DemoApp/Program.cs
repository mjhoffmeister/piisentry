var builder = WebApplication.CreateBuilder(args);
builder.Services.AddControllers();
builder.Services.AddOpenApi();
builder.Services.AddSingleton<PiiSentry.DemoApp.Data.PatientStore>();
builder.Services.AddScoped<PiiSentry.DemoApp.Services.GeneticScreeningService>();
builder.Services.AddHttpClient<PiiSentry.DemoApp.Services.NotificationService>(client =>
{
    client.BaseAddress = new Uri("http://internal-notify.contoso.local/");
});

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.MapGet("/health", () => Results.Ok(new
{
    service = "PiiSentry.DemoApp",
    status = "ok",
    phase = "phase3"
}));

app.MapControllers();

app.Run();
