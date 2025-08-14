using System.ComponentModel.DataAnnotations;

namespace DXC.ServiceDesk.Core.Models;

public class ServiceTicket
{
    public string Id { get; set; } = string.Empty;
    
    [Required]
    public string Subject { get; set; } = string.Empty;
    
    [Required]
    public string Description { get; set; } = string.Empty;
    
    public TicketPriority Priority { get; set; } = TicketPriority.Medium;
    
    public TicketCategory Category { get; set; } = TicketCategory.General;
    
    public TicketStatus Status { get; set; } = TicketStatus.New;
    
    public string EmployeeId { get; set; } = string.Empty;
    
    public string Department { get; set; } = string.Empty;
    
    public string Location { get; set; } = string.Empty;
    
    public DateTime CreatedDate { get; set; } = DateTime.UtcNow;
    
    public DateTime? ResolvedDate { get; set; }
    
    public string AssignedAgent { get; set; } = string.Empty;
    
    public List<TicketComment> Comments { get; set; } = new();
    
    public AIAnalysisResult? AIAnalysis { get; set; }
    
    public double? SentimentScore { get; set; }
    
    public List<string> Tags { get; set; } = new();
}

public enum TicketPriority
{
    Low = 1,
    Medium = 2,
    High = 3,
    Critical = 4
}

public enum TicketCategory
{
    General = 0,
    PasswordReset = 1,
    SoftwareRequest = 2,
    HardwareIssue = 3,
    NetworkAccess = 4,
    AccountManagement = 5,
    Security = 6
}

public enum TicketStatus
{
    New = 0,
    InProgress = 1,
    Waiting = 2,
    Resolved = 3,
    Closed = 4,
    Escalated = 5
}