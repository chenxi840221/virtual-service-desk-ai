using DXC.ServiceDesk.Core.Models;

namespace DXC.ServiceDesk.Core.Services;

public interface ITicketService
{
    Task<ServiceTicket> CreateTicketAsync(ServiceTicket ticket);
    Task<ServiceTicket> GetTicketByIdAsync(string id);
    Task<IEnumerable<ServiceTicket>> GetAllTicketsAsync();
    Task<ServiceTicket> UpdateTicketAsync(ServiceTicket ticket);
    Task<bool> DeleteTicketAsync(string id);
    Task<IEnumerable<ServiceTicket>> SearchTicketsAsync(string query);
    Task<IEnumerable<ServiceTicket>> GetTicketsByStatusAsync(TicketStatus status);
    Task<IEnumerable<ServiceTicket>> GetTicketsByPriorityAsync(TicketPriority priority);
}