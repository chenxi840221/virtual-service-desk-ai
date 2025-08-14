namespace DXC.ServiceDesk.Core.Models;

public class TicketComment
{
    public string Id { get; set; } = string.Empty;
    public string TicketId { get; set; } = string.Empty;
    public string Content { get; set; } = string.Empty;
    public string Author { get; set; } = string.Empty;
    public CommentType Type { get; set; } = CommentType.User;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public bool IsInternal { get; set; }
}

public enum CommentType
{
    User = 0,
    Agent = 1,
    System = 2,
    AI = 3
}