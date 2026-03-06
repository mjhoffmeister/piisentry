namespace PiiSentry.Core.Models;

/// <summary>
/// Intelligence source ring used to gather compliance evidence.
/// </summary>
public enum Ring
{
    /// <summary>
    /// Ring 1 — Fabric Data Agent (codified lakehouse standards).
    /// </summary>
    Fabric = 0,

    /// <summary>
    /// Ring 2 — Work IQ MCP (uncodified M365 business artifacts).
    /// </summary>
    WorkIq = 1,

    /// <summary>
    /// Ring 3 — Foundry IQ / AI Search (regulatory intelligence).
    /// </summary>
    Foundry = 2
}
