namespace DXC.ServiceDesk.Core.Models;

public class AIAnalysisResult
{
    public string Id { get; set; } = string.Empty;
    public string TicketId { get; set; } = string.Empty;
    public string Intent { get; set; } = string.Empty;
    public double Confidence { get; set; }
    public string SuggestedCategory { get; set; } = string.Empty;
    public string SuggestedPriority { get; set; } = string.Empty;
    public string SuggestedResolution { get; set; } = string.Empty;
    public bool RequiresEscalation { get; set; }
    public List<string> ExtractedEntities { get; set; } = new();
    public Dictionary<string, object> MetaData { get; set; } = new();
    public DateTime AnalyzedAt { get; set; } = DateTime.UtcNow;
    public string ModelVersion { get; set; } = string.Empty;
}