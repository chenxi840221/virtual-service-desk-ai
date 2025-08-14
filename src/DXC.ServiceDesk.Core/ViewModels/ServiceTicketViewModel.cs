using DXC.ServiceDesk.Core.Models;
using DXC.ServiceDesk.Core.Services;
using System.Collections.ObjectModel;
using System.Windows.Input;

namespace DXC.ServiceDesk.Core.ViewModels;

public class ServiceTicketViewModel : BaseViewModel
{
    private readonly ITicketService _ticketService;
    private readonly IAIService _aiService;

    public ServiceTicketViewModel(ITicketService ticketService, IAIService aiService)
    {
        _ticketService = ticketService;
        _aiService = aiService;
        
        CreateTicketCommand = new RelayCommand(async () => await CreateTicketAsync());
        AnalyzeTicketCommand = new RelayCommand(async () => await AnalyzeTicketAsync(), () => SelectedTicket != null);
        RefreshTicketsCommand = new RelayCommand(async () => await LoadTicketsAsync());
        
        LoadTicketsAsync();
    }

    private ObservableCollection<ServiceTicket> _tickets = new();
    public ObservableCollection<ServiceTicket> Tickets
    {
        get => _tickets;
        set => SetProperty(ref _tickets, value);
    }

    private ServiceTicket? _selectedTicket;
    public ServiceTicket? SelectedTicket
    {
        get => _selectedTicket;
        set
        {
            SetProperty(ref _selectedTicket, value);
            (AnalyzeTicketCommand as RelayCommand)?.RaiseCanExecuteChanged();
        }
    }

    private ServiceTicket _newTicket = new();
    public ServiceTicket NewTicket
    {
        get => _newTicket;
        set => SetProperty(ref _newTicket, value);
    }

    public ICommand CreateTicketCommand { get; }
    public ICommand AnalyzeTicketCommand { get; }
    public ICommand RefreshTicketsCommand { get; }

    private async Task LoadTicketsAsync()
    {
        try
        {
            IsBusy = true;
            ClearError();
            
            var tickets = await _ticketService.GetAllTicketsAsync();
            Tickets = new ObservableCollection<ServiceTicket>(tickets);
        }
        catch (Exception ex)
        {
            ErrorMessage = $"Failed to load tickets: {ex.Message}";
        }
        finally
        {
            IsBusy = false;
        }
    }

    private async Task CreateTicketAsync()
    {
        try
        {
            IsBusy = true;
            ClearError();

            var createdTicket = await _ticketService.CreateTicketAsync(NewTicket);
            Tickets.Insert(0, createdTicket);
            
            NewTicket = new ServiceTicket();
            OnPropertyChanged(nameof(NewTicket));
        }
        catch (Exception ex)
        {
            ErrorMessage = $"Failed to create ticket: {ex.Message}";
        }
        finally
        {
            IsBusy = false;
        }
    }

    private async Task AnalyzeTicketAsync()
    {
        if (SelectedTicket == null) return;

        try
        {
            IsBusy = true;
            ClearError();

            var analysis = await _aiService.AnalyzeTicketAsync(SelectedTicket);
            SelectedTicket.AIAnalysis = analysis;
            
            var updatedTicket = await _ticketService.UpdateTicketAsync(SelectedTicket);
            var index = Tickets.IndexOf(SelectedTicket);
            if (index >= 0)
            {
                Tickets[index] = updatedTicket;
                SelectedTicket = updatedTicket;
            }
        }
        catch (Exception ex)
        {
            ErrorMessage = $"Failed to analyze ticket: {ex.Message}";
        }
        finally
        {
            IsBusy = false;
        }
    }
}