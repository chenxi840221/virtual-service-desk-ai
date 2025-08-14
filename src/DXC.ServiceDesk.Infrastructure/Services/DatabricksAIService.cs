using DXC.ServiceDesk.Core.Models;
using DXC.ServiceDesk.Core.Services;
using System.Text.Json;
using Azure.Identity;

namespace DXC.ServiceDesk.Infrastructure.Services;

public class DatabricksAIService : IAIService
{
    private readonly HttpClient _httpClient;
    private readonly IConfiguration _configuration;
    private readonly string _databricksEndpoint;

    public DatabricksAIService(HttpClient httpClient, IConfiguration configuration)
    {
        _httpClient = httpClient;
        _configuration = configuration;
        _databricksEndpoint = configuration["Databricks:Endpoint"] ?? throw new ArgumentNullException("Databricks:Endpoint");
        
        ConfigureAuthentication();
    }

    private void ConfigureAuthentication()
    {
        var credential = new DefaultAzureCredential();
        var token = credential.GetToken(
            new Azure.Core.TokenRequestContext(new[] { "https://cognitiveservices.azure.com/.default" })
        );
        
        _httpClient.DefaultRequestHeaders.Authorization = 
            new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", token.Token);
    }

    public async Task<AIAnalysisResult> AnalyzeTicketAsync(ServiceTicket ticket)
    {
        var analysisRequest = new
        {
            ticket_id = ticket.Id,
            subject = ticket.Subject,
            description = ticket.Description,
            priority = ticket.Priority.ToString(),
            category = ticket.Category.ToString()
        };

        var json = JsonSerializer.Serialize(analysisRequest);
        var content = new StringContent(json, System.Text.Encoding.UTF8, "application/json");

        var response = await _httpClient.PostAsync($"{_databricksEndpoint}/api/2.0/jobs/run-now", content);
        response.EnsureSuccessStatusCode();

        var responseContent = await response.Content.ReadAsStringAsync();
        var analysisResult = JsonSerializer.Deserialize<AIAnalysisResult>(responseContent);

        return analysisResult ?? new AIAnalysisResult
        {
            Id = Guid.NewGuid().ToString(),
            TicketId = ticket.Id,
            Intent = "Unknown",
            Confidence = 0.0
        };
    }

    public async Task<string> GenerateResponseAsync(string query, string context)
    {
        var request = new
        {
            query = query,
            context = context,
            max_tokens = 500
        };

        var json = JsonSerializer.Serialize(request);
        var content = new StringContent(json, System.Text.Encoding.UTF8, "application/json");

        var response = await _httpClient.PostAsync($"{_databricksEndpoint}/api/generate-response", content);
        response.EnsureSuccessStatusCode();

        var responseContent = await response.Content.ReadAsStringAsync();
        var result = JsonSerializer.Deserialize<Dictionary<string, object>>(responseContent);
        
        return result?["response"]?.ToString() ?? "Unable to generate response";
    }

    public async Task<double> AnalyzeSentimentAsync(string text)
    {
        var request = new { text = text };
        var json = JsonSerializer.Serialize(request);
        var content = new StringContent(json, System.Text.Encoding.UTF8, "application/json");

        var response = await _httpClient.PostAsync($"{_databricksEndpoint}/api/analyze-sentiment", content);
        response.EnsureSuccessStatusCode();

        var responseContent = await response.Content.ReadAsStringAsync();
        var result = JsonSerializer.Deserialize<Dictionary<string, object>>(responseContent);
        
        if (result?.TryGetValue("sentiment_score", out var score) == true)
        {
            return Convert.ToDouble(score);
        }
        
        return 0.5;
    }

    public async Task<string> ClassifyTicketAsync(ServiceTicket ticket)
    {
        var request = new
        {
            subject = ticket.Subject,
            description = ticket.Description
        };

        var json = JsonSerializer.Serialize(request);
        var content = new StringContent(json, System.Text.Encoding.UTF8, "application/json");

        var response = await _httpClient.PostAsync($"{_databricksEndpoint}/api/classify-ticket", content);
        response.EnsureSuccessStatusCode();

        var responseContent = await response.Content.ReadAsStringAsync();
        var result = JsonSerializer.Deserialize<Dictionary<string, object>>(responseContent);
        
        return result?["category"]?.ToString() ?? "General";
    }

    public async Task<IEnumerable<string>> ExtractEntitiesAsync(string text)
    {
        var request = new { text = text };
        var json = JsonSerializer.Serialize(request);
        var content = new StringContent(json, System.Text.Encoding.UTF8, "application/json");

        var response = await _httpClient.PostAsync($"{_databricksEndpoint}/api/extract-entities", content);
        response.EnsureSuccessStatusCode();

        var responseContent = await response.Content.ReadAsStringAsync();
        var result = JsonSerializer.Deserialize<Dictionary<string, object>>(responseContent);
        
        if (result?.TryGetValue("entities", out var entities) == true)
        {
            return JsonSerializer.Deserialize<List<string>>(entities.ToString()!) ?? new List<string>();
        }
        
        return new List<string>();
    }

    public async Task<string> SuggestResolutionAsync(ServiceTicket ticket)
    {
        var request = new
        {
            ticket_id = ticket.Id,
            subject = ticket.Subject,
            description = ticket.Description,
            category = ticket.Category.ToString()
        };

        var json = JsonSerializer.Serialize(request);
        var content = new StringContent(json, System.Text.Encoding.UTF8, "application/json");

        var response = await _httpClient.PostAsync($"{_databricksEndpoint}/api/suggest-resolution", content);
        response.EnsureSuccessStatusCode();

        var responseContent = await response.Content.ReadAsStringAsync();
        var result = JsonSerializer.Deserialize<Dictionary<string, object>>(responseContent);
        
        return result?["suggested_resolution"]?.ToString() ?? "Please contact your system administrator for assistance.";
    }

    public async Task<bool> RequiresEscalationAsync(ServiceTicket ticket)
    {
        var request = new
        {
            priority = ticket.Priority.ToString(),
            sentiment_score = ticket.SentimentScore ?? 0.5,
            category = ticket.Category.ToString(),
            description = ticket.Description
        };

        var json = JsonSerializer.Serialize(request);
        var content = new StringContent(json, System.Text.Encoding.UTF8, "application/json");

        var response = await _httpClient.PostAsync($"{_databricksEndpoint}/api/escalation-prediction", content);
        response.EnsureSuccessStatusCode();

        var responseContent = await response.Content.ReadAsStringAsync();
        var result = JsonSerializer.Deserialize<Dictionary<string, object>>(responseContent);
        
        if (result?.TryGetValue("requires_escalation", out var escalation) == true)
        {
            return Convert.ToBoolean(escalation);
        }
        
        return ticket.Priority == TicketPriority.Critical;
    }
}