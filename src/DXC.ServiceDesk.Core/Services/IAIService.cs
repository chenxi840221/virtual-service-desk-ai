using DXC.ServiceDesk.Core.Models;

namespace DXC.ServiceDesk.Core.Services;

public interface IAIService
{
    Task<AIAnalysisResult> AnalyzeTicketAsync(ServiceTicket ticket);
    Task<string> GenerateResponseAsync(string query, string context);
    Task<double> AnalyzeSentimentAsync(string text);
    Task<string> ClassifyTicketAsync(ServiceTicket ticket);
    Task<IEnumerable<string>> ExtractEntitiesAsync(string text);
    Task<string> SuggestResolutionAsync(ServiceTicket ticket);
    Task<bool> RequiresEscalationAsync(ServiceTicket ticket);
}