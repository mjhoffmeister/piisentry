namespace PiiSentry.Core.Models;

/// <summary>
/// Runtime availability status of an intelligence source ring.
/// </summary>
/// <param name="Ring">The ring being reported on.</param>
/// <param name="Available">Whether the ring was operational during the scan.</param>
/// <param name="Message">Human-readable status or error detail.</param>
public sealed record RingAvailability(Ring Ring, bool Available, string Message);
